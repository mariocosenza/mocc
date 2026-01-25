package graph

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
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

	errItemNotFound = "item not found"
)

func (r *Resolver) logger() *log.Logger {
	if r.Logger != nil {
		return r.Logger
	}
	return log.Default()
}

func generateRandomNickname() string {
	const letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, 10)
	for i := range b {
		num, _ := rand.Int(rand.Reader, big.NewInt(int64(len(letters))))
		b[i] = letters[num.Int64()]
	}
	return "User_" + string(b)
}

func (r *Resolver) getUser(ctx context.Context, userID string) (*model.User, error) {
	l := r.logger()

	// 1. Try Redis
	val, err := r.Redis.Get(ctx, "user:"+userID).Result()
	if err == nil {
		var user model.User
		if uErr := json.Unmarshal([]byte(val), &user); uErr == nil {
			return &user, nil
		} else {
			l.Printf("level=warn op=getUser stage=redis_unmarshal userId=%s err=%v", userID, uErr)
		}
	} else {
		l.Printf("level=info op=getUser stage=redis_get userId=%s err=%v", userID, err)
	}

	// 2. Try Cosmos
	user, err := r.getUserFromCosmos(ctx, userID)
	if err == nil && user != nil {
		r.cacheUser(ctx, user)
		return user, nil
	}
	if err != nil {
		l.Printf("level=warn op=getUser stage=cosmos_read userId=%s err=%v", userID, err)
	}

	// 3. Try Graph (placeholder) and Create
	defaultPortions := int32(1)
	newUser := &model.User{
		ID:       userID,
		Email:    "user@" + userID + ".com",
		Origin:   model.AccountOriginMicrosoft,
		Nickname: generateRandomNickname(),
		Gamification: &model.GamificationProfile{
			TotalEcoPoints:     0,
			CurrentLevel:       1,
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
		l.Printf("level=error op=getUser stage=cosmos_upsert_user userId=%s err=%v", userID, err)
		return nil, err
	}

	// 5. Cache
	r.cacheUser(ctx, newUser)

	// 6. Create Fridge
	if err := r.createFridgeForUser(ctx, userID); err != nil {
		l.Printf("level=error op=getUser stage=create_fridge userId=%s err=%v", userID, err)
	}

	return newUser, nil
}

func (r *Resolver) cacheUser(ctx context.Context, user *model.User) {
	l := r.logger()

	data, err := json.Marshal(user)
	if err != nil {
		l.Printf("level=warn op=cacheUser stage=json_marshal userId=%s err=%v", user.ID, err)
		return
	}

	if err := r.Redis.Set(ctx, "user:"+user.ID, data, userCacheDuration).Err(); err != nil {
		l.Printf("level=warn op=cacheUser stage=redis_set userId=%s err=%v", user.ID, err)
	}
}

func (r *Resolver) getUserFromCosmos(ctx context.Context, userID string) (*model.User, error) {
	l := r.logger()

	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerUsers)
	if err != nil {
		l.Printf("level=error op=getUserFromCosmos stage=new_container db=%s container=%s userId=%s err=%v",
			cosmosDatabase, containerUsers, userID, err)
		return nil, err
	}

	itemResponse, err := container.ReadItem(ctx, azcosmos.NewPartitionKeyString(userID), userID, nil)
	if err != nil {
		l.Printf("level=warn op=getUserFromCosmos stage=read_item userId=%s pk=%s err=%v", userID, userID, err)
		return nil, err
	}

	var user model.User
	if err := json.Unmarshal(itemResponse.Value, &user); err != nil {
		l.Printf("level=warn op=getUserFromCosmos stage=json_unmarshal userId=%s err=%v", userID, err)
		return nil, err
	}

	return &user, nil
}

func (r *Resolver) saveUserToCosmos(ctx context.Context, user *model.User) error {
	l := r.logger()

	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerUsers)
	if err != nil {
		l.Printf("level=error op=saveUserToCosmos stage=new_container db=%s container=%s userId=%s err=%v",
			cosmosDatabase, containerUsers, user.ID, err)
		return err
	}

	data, err := json.Marshal(user)
	if err != nil {
		l.Printf("level=error op=saveUserToCosmos stage=json_marshal userId=%s err=%v", user.ID, err)
		return err
	}

	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(user.ID), data, nil)
	if err != nil {
		l.Printf("level=error op=saveUserToCosmos stage=upsert userId=%s pk=%s err=%v", user.ID, user.ID, err)
	}
	return err
}

func (r *Resolver) createFridgeForUser(ctx context.Context, userID string) error {
	l := r.logger()

	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerInventory)
	if err != nil {
		l.Printf("level=error op=createFridgeForUser stage=new_container db=%s container=%s userId=%s err=%v",
			cosmosDatabase, containerInventory, userID, err)
		return err
	}

	fridge := &model.Fridge{
		ID:      userID,
		Name:    "My Fridge",
		OwnerID: []string{userID},
		Items:   []*model.InventoryItem{},
	}

	dataMap := map[string]interface{}{}
	tempJSON, mErr := json.Marshal(fridge)
	if mErr != nil {
		l.Printf("level=error op=createFridgeForUser stage=json_marshal_fridge userId=%s err=%v", userID, mErr)
		return mErr
	}
	if uErr := json.Unmarshal(tempJSON, &dataMap); uErr != nil {
		l.Printf("level=error op=createFridgeForUser stage=json_unmarshal_map userId=%s err=%v", userID, uErr)
		return uErr
	}
	dataMap["fridgeId"] = fridge.ID

	data, err := json.Marshal(dataMap)
	if err != nil {
		l.Printf("level=error op=createFridgeForUser stage=json_marshal_map userId=%s err=%v", userID, err)
		return err
	}

	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(userID), data, nil)
	if err != nil {
		l.Printf("level=error op=createFridgeForUser stage=upsert userId=%s pk=%s err=%v", userID, userID, err)
	}
	return err
}

func (r *Resolver) getFridge(ctx context.Context, userID string) (*model.Fridge, error) {
	l := r.logger()

	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerInventory)
	if err != nil {
		l.Printf("level=error op=getFridge stage=new_container db=%s container=%s userId=%s err=%v",
			cosmosDatabase, containerInventory, userID, err)
		return nil, err
	}

	query := "SELECT * FROM c WHERE c.id = @id or ARRAY_CONTAINS(c.ownerId, @id)"
	qOpts := azcosmos.QueryOptions{
		QueryParameters: []azcosmos.QueryParameter{
			{Name: "@id", Value: userID},
		},
	}
	pager := container.NewQueryItemsPager(query, azcosmos.PartitionKey{}, &qOpts)

	for pager.More() {
		resp, err := pager.NextPage(ctx)
		if err != nil {
			l.Printf("level=error op=getFridge stage=query_next_page userId=%s err=%v", userID, err)
			return nil, err
		}
		if len(resp.Items) > 0 {
			var fridge model.Fridge
			if err := json.Unmarshal(resp.Items[0], &fridge); err != nil {
				l.Printf("level=warn op=getFridge stage=json_unmarshal userId=%s err=%v", userID, err)
				continue
			}
			return &fridge, nil
		}
	}

	return nil, fmt.Errorf("not found")
}

func (r *Resolver) saveFridge(ctx context.Context, fridge *model.Fridge) error {
	l := r.logger()

	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerInventory)
	if err != nil {
		l.Printf("level=error op=saveFridge stage=new_container db=%s container=%s fridgeId=%s err=%v",
			cosmosDatabase, containerInventory, fridge.ID, err)
		return err
	}

	dataMap := map[string]interface{}{}
	tempJSON, mErr := json.Marshal(fridge)
	if mErr != nil {
		l.Printf("level=error op=saveFridge stage=json_marshal_fridge fridgeId=%s err=%v", fridge.ID, mErr)
		return mErr
	}
	if uErr := json.Unmarshal(tempJSON, &dataMap); uErr != nil {
		l.Printf("level=error op=saveFridge stage=json_unmarshal_map fridgeId=%s err=%v", fridge.ID, uErr)
		return uErr
	}
	dataMap["fridgeId"] = fridge.ID

	data, err := json.Marshal(dataMap)
	if err != nil {
		l.Printf("level=error op=saveFridge stage=json_marshal_map fridgeId=%s err=%v", fridge.ID, err)
		return err
	}

	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(fridge.ID), data, nil)
	if err != nil {
		l.Printf("level=error op=saveFridge stage=upsert fridgeId=%s pk=%s err=%v", fridge.ID, fridge.ID, err)
	}
	return err
}

func (r *Resolver) getUserID(ctx context.Context) (string, error) {
	l := r.logger()

	uid := auth.GetUserID(ctx)
	if uid == "" {
		l.Printf("level=warn op=getUserID stage=auth_missing_user")
		return "", fmt.Errorf("unauthorized")
	}

	val, err := r.Redis.Get(ctx, "user:"+uid).Result()
	if err != nil || len(val) < 2 {
		if err != nil {
			l.Printf("level=info op=getUserID stage=redis_get userId=%s err=%v", uid, err)
		}
		if _, uErr := r.getUser(ctx, uid); uErr != nil {
			l.Printf("level=error op=getUserID stage=ensure_user userId=%s err=%v", uid, uErr)
			return "", uErr
		}
	}

	return uid, nil
}

func (r *Resolver) getRecipe(ctx context.Context, id string) (*model.Recipe, error) {
	l := r.logger()

	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerCookbook)
	if err != nil {
		l.Printf("level=error op=getRecipe stage=new_container db=%s container=%s recipeId=%s err=%v",
			cosmosDatabase, containerCookbook, id, err)
		return nil, err
	}

	query := "SELECT * FROM c WHERE c.id = @id"
	qOpts := azcosmos.QueryOptions{
		QueryParameters: []azcosmos.QueryParameter{
			{Name: "@id", Value: id},
		},
	}

	pager := container.NewQueryItemsPager(query, azcosmos.PartitionKey{}, &qOpts)

	for pager.More() {
		resp, err := pager.NextPage(ctx)
		if err != nil {
			l.Printf("level=error op=getRecipe stage=query_next_page recipeId=%s err=%v", id, err)
			return nil, err
		}
		if len(resp.Items) > 0 {
			var recipe model.Recipe
			if err := json.Unmarshal(resp.Items[0], &recipe); err != nil {
				l.Printf("level=warn op=getRecipe stage=json_unmarshal recipeId=%s err=%v", id, err)
				continue
			}
			return &recipe, nil
		}
	}
	return nil, fmt.Errorf("not found")
}

func (r *Resolver) saveRecipe(ctx context.Context, recipe *model.Recipe) error {
	l := r.logger()

	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerCookbook)
	if err != nil {
		l.Printf("level=error op=saveRecipe stage=new_container db=%s container=%s authorId=%s recipeId=%s err=%v",
			cosmosDatabase, containerCookbook, recipe.AuthorID, recipe.ID, err)
		return err
	}

	data, err := json.Marshal(recipe)
	if err != nil {
		l.Printf("level=error op=saveRecipe stage=json_marshal authorId=%s recipeId=%s err=%v",
			recipe.AuthorID, recipe.ID, err)
		return err
	}

	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(recipe.AuthorID), data, nil)
	if err != nil {
		l.Printf("level=error op=saveRecipe stage=upsert authorId=%s recipeId=%s pk=%s err=%v",
			recipe.AuthorID, recipe.ID, recipe.AuthorID, err)
	}
	return err
}

func (r *Resolver) saveStagingSession(ctx context.Context, session *model.StagingSession) error {
	l := r.logger()

	data, err := json.Marshal(session)
	if err != nil {
		l.Printf("level=error op=saveStagingSession stage=json_marshal sessionId=%s err=%v", session.ID, err)
		return err
	}

	if err := r.Redis.Set(ctx, "staging:session:"+session.ID, data, 24*time.Hour).Err(); err != nil {
		l.Printf("level=error op=saveStagingSession stage=redis_set sessionId=%s err=%v", session.ID, err)
		return err
	}

	return nil
}

func (r *Resolver) getStagingSession(ctx context.Context, sessionID string) (*model.StagingSession, error) {
	l := r.logger()

	val, err := r.Redis.Get(ctx, "staging:session:"+sessionID).Result()
	if err != nil {
		l.Printf("level=warn op=getStagingSession stage=redis_get sessionId=%s err=%v", sessionID, err)
		return nil, fmt.Errorf("session not found")
	}

	var session model.StagingSession
	if err := json.Unmarshal([]byte(val), &session); err != nil {
		l.Printf("level=warn op=getStagingSession stage=json_unmarshal sessionId=%s err=%v", sessionID, err)
		return nil, err
	}
	return &session, nil
}

const (
	stagingUserPrefix = "staging:user:"
	leaderboardGlobal = "leaderboard:global"
)

func (r *Resolver) setUserStagingSession(ctx context.Context, userID, sessionID string) error {
	l := r.logger()

	if err := r.Redis.Set(ctx, stagingUserPrefix+userID, sessionID, 24*time.Hour).Err(); err != nil {
		l.Printf("level=error op=setUserStagingSession userId=%s sessionId=%s err=%v", userID, sessionID, err)
		return err
	}
	return nil
}

func (r *Resolver) getUserStagingSessionID(ctx context.Context, userID string) (string, error) {
	l := r.logger()

	val, err := r.Redis.Get(ctx, stagingUserPrefix+userID).Result()
	if err != nil {
		l.Printf("level=warn op=getUserStagingSessionID userId=%s err=%v", userID, err)
		return "", err
	}
	return val, nil
}

func (r *Resolver) clearUserStagingSession(ctx context.Context, userID string) {
	l := r.logger()

	if err := r.Redis.Del(ctx, stagingUserPrefix+userID).Err(); err != nil {
		l.Printf("level=warn op=clearUserStagingSession userId=%s err=%v", userID, err)
	}
}
