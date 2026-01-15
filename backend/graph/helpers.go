package graph

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos"
	"github.com/mariocosenza/mocc/auth"
	"github.com/mariocosenza/mocc/graph/model"
)

const (
	userCacheDuration    = 24 * time.Hour
	cosmosDatabase       = "mocc-db"
	containerUsers       = "Users"
	containerInventory   = "Inventory"   // PK: /fridgeId
	containerCookbook    = "Cookbook"    // PK: /authorId
	containerSocial      = "Social"      // PK: /type
	containerHistory     = "History"     // PK: /userId
	containerStaging     = "Staging"     // PK: /id
	containerLeaderboard = "Leaderboard" // PK: /period
)

func (r *Resolver) getUser(ctx context.Context, userID string) (*model.User, error) {
	// 1. Try Redis
	val, err := r.Redis.Get(ctx, "user:"+userID).Result()
	if err == nil {
		var user model.User
		if err := json.Unmarshal([]byte(val), &user); err == nil {
			return &user, nil
		}
	}

	// 2. Try Cosmos
	user, err := r.getUserFromCosmos(ctx, userID)
	if err == nil && user != nil {
		r.cacheUser(ctx, user)
		return user, nil
	}

	// 3. Try Graph (if newly provisioned or missing) and Create
	defaultPortions := int32(1)
	newUser := &model.User{
		ID:     userID,
		Email:  "user@" + userID + ".com", // Placeholder: ideally fetch from Graph
		Origin: model.AccountOriginMicrosoft,
		Gamification: &model.GamificationProfile{
			TotalEcoPoints:     0,
			CurrentLevel:       "Novice",
			NextLevelThreshold: 100,
			Badges:             []string{},
		},
		Preferences: &model.UserPreferences{
			DefaultPortions: &defaultPortions,
			Currency:        model.CurrencyEur,
		},
	}

	// 4. Save to Cosmos
	if err := r.saveUserToCosmos(ctx, newUser); err != nil {
		return nil, err
	}


	// 5. Cache
	r.cacheUser(ctx, newUser)

	// Create Fridge for new user
	r.createFridgeForUser(ctx, userID)


	return newUser, nil
}

func (r *Resolver) cacheUser(ctx context.Context, user *model.User) {
	data, _ := json.Marshal(user)
	r.Redis.Set(ctx, "user:"+user.ID, data, userCacheDuration)
}

func (r *Resolver) getUserFromCosmos(ctx context.Context, userID string) (*model.User, error) {
	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerUsers)
	if err != nil {
		return nil, err
	}

	itemResponse, err := container.ReadItem(ctx, azcosmos.NewPartitionKeyString(userID), userID, nil)

	if err != nil {
		return nil, err
	}

	var user model.User
	if err := json.Unmarshal(itemResponse.Value, &user); err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *Resolver) saveUserToCosmos(ctx context.Context, user *model.User) error {
	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerUsers)
	if err != nil {
		return err
	}

	data, err := json.Marshal(user)
	if err != nil {
		return err
	}

	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(user.ID), data, nil)
	return err
}

func (r *Resolver) createFridgeForUser(ctx context.Context, userID string) error {
	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerInventory)
	if err != nil {
		return err
	}

	// Assume 1 fridge per user for now, ID = userID
	fridge := &model.Fridge{
		ID:      userID,
		Name:    "My Fridge",
		OwnerID: []string{userID},
		Items:   []*model.InventoryItem{},
	}


	dataMap := map[string]interface{}{}
	tempJSON, _ := json.Marshal(fridge)
	json.Unmarshal(tempJSON, &dataMap)
	dataMap["fridgeId"] = fridge.ID // Enforce PK

	data, err := json.Marshal(dataMap)
	if err != nil {
		return err
	}

	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(userID), data, nil)
	return err
}

func (r *Resolver) getFridge(ctx context.Context, userID string) (*model.Fridge, error) {
	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerInventory)
	if err != nil {
		return nil, err
	}

	// ID is userID for simplicity
	// PK is fridgeId which we set to userID
	itemResponse, err := container.ReadItem(ctx, azcosmos.NewPartitionKeyString(userID), userID, nil)
	if err != nil {
		return nil, err
	}

	var fridge model.Fridge
	if err := json.Unmarshal(itemResponse.Value, &fridge); err != nil {
		return nil, err
	}
	return &fridge, nil
}

func (r *Resolver) saveFridge(ctx context.Context, fridge *model.Fridge) error {
	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerInventory)
	if err != nil {
		return err
	}

	dataMap := map[string]interface{}{}
	tempJSON, _ := json.Marshal(fridge)
	json.Unmarshal(tempJSON, &dataMap)
	dataMap["fridgeId"] = fridge.ID

	data, err := json.Marshal(dataMap)
	if err != nil {
		return err
	}

	// PK is fridgeId -> userID
	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(fridge.ID), data, nil)
	return err
}

func (r *Resolver) getUserID(ctx context.Context) (string, error) {
	uid := auth.GetUserID(ctx)
	if uid == "" {
		return "", fmt.Errorf("unauthorized")
	}
	return uid, nil
}

func (r *Resolver) getRecipe(ctx context.Context, id string) (*model.Recipe, error) {
	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerCookbook)
	if err != nil {
		return nil, err
	}

	// Assume PK is /authorId. Wait.
	// If I only have ID, I cannot read efficienty if PK is authorId.
	// I need authorId to ReadItem.
	// Queries can use checking "id" matches.
	// For now, let's use Query to find by ID if we don't have author ID.
	// But getRecipe is called when we have ID.

	// Query: SELECT * FROM c WHERE c.id = @id
	query := "SELECT * FROM c WHERE c.id = @id"
	qOpts := azcosmos.QueryOptions{
		QueryParameters: []azcosmos.QueryParameter{
			{Name: "@id", Value: id},
		},
	}

	// Cross-partition query since we don't know authorId here?
	// If we knew user context we could optimize, but this is a generic get.

	pager := container.NewQueryItemsPager(query, azcosmos.PartitionKey{}, &qOpts)

	for pager.More() {
		resp, err := pager.NextPage(ctx)
		if err != nil {
			return nil, err
		}
		if len(resp.Items) > 0 {
			var recipe model.Recipe
			if err := json.Unmarshal(resp.Items[0], &recipe); err == nil {
				return &recipe, nil
			}
		}
	}
	return nil, fmt.Errorf("not found")
}

func (r *Resolver) saveRecipe(ctx context.Context, recipe *model.Recipe) error {
	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerCookbook)
	if err != nil {
		return err
	}

	data, err := json.Marshal(recipe)
	if err != nil {
		return err
	}

	// PK is AuthorID
	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(recipe.AuthorID), data, nil)
	return err
}

func (r *Resolver) queryRecipes(ctx context.Context, query string, pk string) ([]*model.Recipe, error) {
	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerCookbook)
	if err != nil {
		return nil, err
	}

	opts := azcosmos.QueryOptions{}
	pager := container.NewQueryItemsPager(query, azcosmos.PartitionKey{}, &opts)
	if pk != "" {
		pager = container.NewQueryItemsPager(query, azcosmos.NewPartitionKeyString(pk), &opts)
	}

	var recipes []*model.Recipe
	for pager.More() {
		resp, err := pager.NextPage(ctx)
		if err != nil {
			return nil, err
		}
		for _, bytes := range resp.Items {
			var recipe model.Recipe
			if err := json.Unmarshal(bytes, &recipe); err == nil {
				recipes = append(recipes, &recipe)
			}
		}
	}
	return recipes, nil
}

func (r *Resolver) saveStagingSession(ctx context.Context, session *model.StagingSession) error {
	data, err := json.Marshal(session)
	if err != nil {
		return err
	}
	// Expire in 24 hours
	if err := r.Redis.Set(ctx, "staging:session:"+session.ID, data, 24*time.Hour).Err(); err != nil {
		return err
	}
	// Also map user to session if needed?
	// But session owner? Schema doesn't say.
	// But `currentStagingSession` query implies one per user.
	// Let's assume one active session per user.
	// But mutation takes `sessionId`.
	return nil
}

func (r *Resolver) getStagingSession(ctx context.Context, sessionID string) (*model.StagingSession, error) {
	val, err := r.Redis.Get(ctx, "staging:session:"+sessionID).Result()
	if err != nil {
		return nil, fmt.Errorf("session not found")
	}

	var session model.StagingSession
	if err := json.Unmarshal([]byte(val), &session); err != nil {
		return nil, err
	}
	return &session, nil
}

const (
	stagingUserPrefix = "staging:user:"
	leaderboardGlobal = "leaderboard:global"
)

func (r *Resolver) setUserStagingSession(ctx context.Context, userID, sessionID string) error {
	return r.Redis.Set(ctx, stagingUserPrefix+userID, sessionID, 24*time.Hour).Err()
}

func (r *Resolver) getUserStagingSessionID(ctx context.Context, userID string) (string, error) {
	return r.Redis.Get(ctx, stagingUserPrefix+userID).Result()
}

func (r *Resolver) clearUserStagingSession(ctx context.Context, userID string) {
	r.Redis.Del(ctx, stagingUserPrefix+userID)
}

func (r *Resolver) updateLeaderboard(ctx context.Context, userID string, points int) {
	r.Redis.ZIncrBy(ctx, leaderboardGlobal, float64(points), userID)
}

func (r *Resolver) getLeaderboard(ctx context.Context, top int) ([]*model.LeaderboardEntry, error) {
	limit := int64(top) - 1
	if limit < 0 {
		return []*model.LeaderboardEntry{}, nil
	}

	results, err := r.Redis.ZRevRangeWithScores(ctx, leaderboardGlobal, 0, limit).Result()
	if err != nil {
		return nil, err
	}

	entries := []*model.LeaderboardEntry{}
	for i, z := range results {
		userID := z.Member.(string)
		score := int(z.Score)

		user, _ := r.getUser(ctx, userID)
		if user == nil {
			id := userID
			nick := "Unknown"
			user = &model.User{ID: id, Nickname: &nick}
		}

		entries = append(entries, &model.LeaderboardEntry{
			Rank:  int32(i + 1),
			User:  user,
			Score: int32(score),
		})
	}
	return entries, nil
}
