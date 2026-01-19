package graph

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"

	"github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos"
	"github.com/mariocosenza/mocc/graph/model"
	"github.com/redis/go-redis/v9"
)

func (r *Resolver) updateLeaderboard(ctx context.Context, user *model.User) {
	l := r.logger()

	score := 0
	if user.Gamification != nil {
		score = int(user.Gamification.TotalEcoPoints)
	}

	// 1. Update Redis ZSET
	if err := r.Redis.ZAdd(ctx, leaderboardGlobal, redis.Z{
		Score:  float64(score),
		Member: user.ID,
	}).Err(); err != nil {
		l.Printf("level=warn op=updateLeaderboard stage=redis userId=%s score=%d err=%v", user.ID, score, err)
	}

	// 2. Persist to Cosmos DB "Leaderboard" container
	lbItem := map[string]interface{}{
		"id":       user.ID,
		"period":   "global",
		"nickname": user.Nickname,
		"score":    score,
	}

	data, err := json.Marshal(lbItem)
	if err != nil {
		l.Printf("level=error op=updateLeaderboard stage=json_marshal userId=%s err=%v", user.ID, err)
		return
	}

	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerLeaderboard)
	if err != nil {
		l.Printf("level=error op=updateLeaderboard stage=new_container db=%s container=%s err=%v",
			cosmosDatabase, containerLeaderboard, err)
		return
	}

	// Upsert (Insert or Replace)
	if _, err := container.UpsertItem(ctx, azcosmos.NewPartitionKeyString("global"), data, nil); err != nil {
		l.Printf("level=error op=updateLeaderboard stage=cosmos_upsert userId=%s err=%v", user.ID, err)
	}
}

func (r *Resolver) getLeaderboard(ctx context.Context, top int) ([]*model.LeaderboardEntry, error) {
	l := r.logger()

	if top <= 0 {
		return []*model.LeaderboardEntry{}, nil
	}

	entries := []*model.LeaderboardEntry{}

	// 1. Try Redis ZSET
	vals, err := r.Redis.ZRevRangeWithScores(ctx, leaderboardGlobal, 0, int64(top-1)).Result()
	if err == nil && len(vals) > 0 {
		for i, z := range vals {
			uid, ok := z.Member.(string)
			if !ok {
				continue
			}
			score := int(z.Score)

			nickname := "Unknown"
			if user, uErr := r.getUser(ctx, uid); uErr == nil && user != nil {
				nickname = user.Nickname
			}

			entries = append(entries, &model.LeaderboardEntry{
				Rank:     int32(i + 1),
				Nickname: nickname,
				Score:    int32(score),
			})
		}
		return entries, nil
	} else if err != nil {
		l.Printf("level=info op=getLeaderboard stage=redis_zrevrange err=%v", err)
	}

	// 2. Fallback: Query CosmosDB "Leaderboard" container
	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerLeaderboard)
	if err != nil {
		l.Printf("level=error op=getLeaderboard stage=new_container db=%s container=%s err=%v",
			cosmosDatabase, containerLeaderboard, err)
		return nil, err
	}


	query := "SELECT * FROM c"
	qOpts := azcosmos.QueryOptions{}

	pager := container.NewQueryItemsPager(query, azcosmos.NewPartitionKeyString("global"), &qOpts)

	type lbDoc struct {
		ID       string `json:"id"`
		Nickname string `json:"nickname"`
		Score    int    `json:"score"`
	}

	var allRows []*model.LeaderboardEntry

	for pager.More() {
		resp, err := pager.NextPage(ctx)
		if err != nil {
			l.Printf("level=warn op=getLeaderboard stage=query_next_page err=%v", err)
			break
		}

		for _, itemBytes := range resp.Items {
			var doc lbDoc
			if err := json.Unmarshal(itemBytes, &doc); err == nil {
				if err := r.Redis.ZAdd(ctx, leaderboardGlobal, redis.Z{
					Score:  float64(doc.Score),
					Member: doc.ID,
				}).Err(); err != nil {
					l.Printf("level=warn op=getLeaderboard stage=redis_heal key=%s err=%v", leaderboardGlobal, err)
				}

				allRows = append(allRows, &model.LeaderboardEntry{
					Nickname: doc.Nickname,
					Score:    int32(doc.Score),
				})
			}
		}
	}

	// Sort in memory
	sort.Slice(allRows, func(i, j int) bool {
		return allRows[i].Score > allRows[j].Score
	})

	if len(allRows) == 0 {
		l.Printf("level=info op=getLeaderboard stage=fallback_migration msg=leaderboard_empty_scanning_users")

		userContainer, err := r.Cosmos.NewContainer(cosmosDatabase, containerUsers)
		if err == nil {
			uQuery := "SELECT * FROM c WHERE c.gamification.totalEcoPoints > 0"
			uPager := userContainer.NewQueryItemsPager(uQuery, azcosmos.PartitionKey{}, &azcosmos.QueryOptions{})

			for uPager.More() {
				resp, err := uPager.NextPage(ctx)
				if err != nil {
					break
				}
				for _, itemBytes := range resp.Items {
					var user model.User
					if err := json.Unmarshal(itemBytes, &user); err == nil && user.Gamification != nil {
						score := int(user.Gamification.TotalEcoPoints)

						allRows = append(allRows, &model.LeaderboardEntry{
							Nickname: user.Nickname,
							Score:    int32(score),
						})

						r.updateLeaderboard(ctx, &user)
					}
				}
			}

			sort.Slice(allRows, func(i, j int) bool {
				return allRows[i].Score > allRows[j].Score
			})
		}
	}

	for i, row := range allRows {
		if i >= top {
			break
		}
		row.Rank = int32(i + 1)
		entries = append(entries, row)
	}

	return entries, nil
}

func (r *Resolver) updateNickname(ctx context.Context, userID, nickname string) error {
	l := r.logger()

	user, err := r.getUser(ctx, userID)
	if err != nil {
		l.Printf("level=error op=updateNickname stage=get_user userId=%s err=%v", userID, err)
		return err
	}

	if user.Nickname == nickname {
		return nil
	}

	query := "SELECT * FROM c WHERE c.nickname = @nickname"
	qOpts := azcosmos.QueryOptions{
		QueryParameters: []azcosmos.QueryParameter{
			{Name: "@nickname", Value: nickname},
		},
	}
	container, err := r.Cosmos.NewContainer(cosmosDatabase, containerUsers)
	if err != nil {
		l.Printf("level=error op=updateNickname stage=new_container db=%s container=%s userId=%s err=%v",
			cosmosDatabase, containerUsers, userID, err)
		return err
	}

	pager := container.NewQueryItemsPager(query, azcosmos.PartitionKey{}, &qOpts)
	for pager.More() {
		resp, err := pager.NextPage(ctx)
		if err != nil {
			l.Printf("level=error op=updateNickname stage=query_next_page userId=%s err=%v", userID, err)
			return nil
		}
		if len(resp.Items) > 0 {
			l.Printf("level=error op=updateNickname stage=nickname_exists userId=%s nickname=%s", userID, nickname)
			return fmt.Errorf("nickname already in use")
		}
	}

	user.Nickname = nickname
	if err := r.saveUserToCosmos(ctx, user); err != nil {
		l.Printf("level=error op=updateNickname stage=save_user userId=%s err=%v", userID, err)
		return err
	}
	user.Nickname = nickname
	if err := r.saveUserToCosmos(ctx, user); err != nil {
		l.Printf("level=error op=updateNickname stage=save_user userId=%s err=%v", userID, err)
		return err
	}
	r.cacheUser(ctx, user)
	return nil
}

func (r *Resolver) checkAndApplyLevelUp(user *model.User) {
	for user.Gamification.TotalEcoPoints >= user.Gamification.NextLevelThreshold {
		user.Gamification.CurrentLevel++
		newThreshold := float64(user.Gamification.NextLevelThreshold) * 1.5
		user.Gamification.NextLevelThreshold = int32(newThreshold)
	}
}
