package logic

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"

	"github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos"
	"github.com/mariocosenza/mocc/graph/model"
	"github.com/redis/go-redis/v9"
)

func (l *Logic) UpsertLeaderboardEntry(ctx context.Context, user *model.User) {
	logger := l.GetLogger()

	score := 0
	if user.Gamification != nil {
		score = int(user.Gamification.TotalEcoPoints)
	}

	if err := l.Redis.ZAdd(ctx, LeaderboardGlobal, redis.Z{
		Score:  float64(score),
		Member: user.ID,
	}).Err(); err != nil {
		logger.Printf("level=warn op=UpdateLeaderboard stage=redis userId=%s score=%d err=%v", user.ID, score, err)
	}

	lbItem := map[string]interface{}{
		"id":       user.ID,
		"period":   "global",
		"nickname": user.Nickname,
		"score":    score,
	}

	data, err := json.Marshal(lbItem)
	if err != nil {
		logger.Printf("level=error op=UpdateLeaderboard stage=json_marshal userId=%s err=%v", user.ID, err)
		return
	}

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerLeaderboard)
	if err != nil {
		logger.Printf("level=error op=UpdateLeaderboard stage=new_container db=%s container=%s err=%v",
			CosmosDatabase, ContainerLeaderboard, err)
		return
	}

	if _, err := container.UpsertItem(ctx, azcosmos.NewPartitionKeyString("global"), data, nil); err != nil {
		logger.Printf("level=error op=UpdateLeaderboard stage=cosmos_upsert userId=%s err=%v", user.ID, err)
	}
}

func (l *Logic) FetchLeaderboard(ctx context.Context, top int) ([]*model.LeaderboardEntry, error) {
	logger := l.GetLogger()

	if top <= 0 {
		return []*model.LeaderboardEntry{}, nil
	}

	entries, used, err := l.fetchLeaderboardFromRedis(ctx, top)
	if used {
		return entries, nil
	}
	if err != nil {
		logger.Printf("level=info op=GetLeaderboard stage=redis_zrevrange err=%v", err)
	}

	allRows, err := l.fetchLeaderboardFromCosmos(ctx)
	if err != nil {
		return nil, err
	}
	if len(allRows) == 0 {
		allRows = l.rebuildLeaderboardFromUsers(ctx)
	}

	return rankLeaderboard(allRows, top), nil
}

func (l *Logic) fetchLeaderboardFromRedis(ctx context.Context, top int) ([]*model.LeaderboardEntry, bool, error) {
	vals, err := l.Redis.ZRevRangeWithScores(ctx, LeaderboardGlobal, 0, int64(top-1)).Result()
	if err != nil {
		return nil, false, err
	}
	if len(vals) == 0 {
		return nil, false, nil
	}

	entries := make([]*model.LeaderboardEntry, 0, len(vals))
	for i, z := range vals {
		uid, ok := z.Member.(string)
		if !ok {
			continue
		}
		score := int(z.Score)

		nickname := "Unknown"
		if user, uErr := l.FetchUser(ctx, uid); uErr == nil && user != nil {
			nickname = user.Nickname
		}

		entries = append(entries, &model.LeaderboardEntry{
			Rank:     int32(i + 1),
			Nickname: nickname,
			Score:    int32(score),
		})
	}

	return entries, true, nil
}

func (l *Logic) fetchLeaderboardFromCosmos(ctx context.Context) ([]*model.LeaderboardEntry, error) {
	logger := l.GetLogger()

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerLeaderboard)
	if err != nil {
		logger.Printf("level=error op=GetLeaderboard stage=new_container db=%s container=%s err=%v",
			CosmosDatabase, ContainerLeaderboard, err)
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
			logger.Printf("level=warn op=GetLeaderboard stage=query_next_page err=%v", err)
			break
		}

		for _, itemBytes := range resp.Items {
			var doc lbDoc
			if err := json.Unmarshal(itemBytes, &doc); err == nil {
				if err := l.Redis.ZAdd(ctx, LeaderboardGlobal, redis.Z{
					Score:  float64(doc.Score),
					Member: doc.ID,
				}).Err(); err != nil {
					logger.Printf("level=warn op=GetLeaderboard stage=redis_heal key=%s err=%v", LeaderboardGlobal, err)
				}

				allRows = append(allRows, &model.LeaderboardEntry{
					Nickname: doc.Nickname,
					Score:    int32(doc.Score),
				})
			}
		}
	}

	sort.Slice(allRows, func(i, j int) bool {
		return allRows[i].Score > allRows[j].Score
	})

	return allRows, nil
}

func (l *Logic) rebuildLeaderboardFromUsers(ctx context.Context) []*model.LeaderboardEntry {
	logger := l.GetLogger()
	logger.Printf("level=info op=GetLeaderboard stage=fallback_migration msg=leaderboard_empty_scanning_users")

	userContainer, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerUsers)
	if err != nil {
		return []*model.LeaderboardEntry{}
	}

	uQuery := "SELECT * FROM c WHERE c.gamification.totalEcoPoints > 0"
	uPager := userContainer.NewQueryItemsPager(uQuery, azcosmos.PartitionKey{}, &azcosmos.QueryOptions{})

	allRows := []*model.LeaderboardEntry{}
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

				l.UpsertLeaderboardEntry(ctx, &user)
			}
		}
	}

	sort.Slice(allRows, func(i, j int) bool {
		return allRows[i].Score > allRows[j].Score
	})

	return allRows
}

func rankLeaderboard(allRows []*model.LeaderboardEntry, top int) []*model.LeaderboardEntry {
	entries := []*model.LeaderboardEntry{}
	for i, row := range allRows {
		if i >= top {
			break
		}
		row.Rank = int32(i + 1)
		entries = append(entries, row)
	}
	return entries
}

func (l *Logic) SyncNickname(ctx context.Context, userID, nickname string) error {
	logger := l.GetLogger()

	user, err := l.FetchUser(ctx, userID)
	if err != nil {
		logger.Printf("level=error op=UpdateNickname stage=get_user userId=%s err=%v", userID, err)
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
	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerUsers)
	if err != nil {
		logger.Printf("level=error op=UpdateNickname stage=new_container db=%s container=%s userId=%s err=%v",
			CosmosDatabase, ContainerUsers, userID, err)
		return err
	}

	pager := container.NewQueryItemsPager(query, azcosmos.PartitionKey{}, &qOpts)
	for pager.More() {
		resp, err := pager.NextPage(ctx)
		if err != nil {
			logger.Printf("level=error op=UpdateNickname stage=query_next_page userId=%s err=%v", userID, err)
			return nil
		}
		if len(resp.Items) > 0 {
			logger.Printf("level=error op=UpdateNickname stage=nickname_exists userId=%s nickname=%s", userID, nickname)
			return fmt.Errorf("nickname already in use")
		}
	}

	user.Nickname = nickname
	if err := l.UpsertUser(ctx, user); err != nil {
		logger.Printf("level=error op=UpdateNickname stage=save_user userId=%s err=%v", userID, err)
		return err
	}
	l.SetUserCache(ctx, user)

	l.UpsertLeaderboardEntry(ctx, user)

	return nil
}

func (l *Logic) EvaluateLevelUp(user *model.User) {
	for user.Gamification.TotalEcoPoints >= user.Gamification.NextLevelThreshold {
		user.Gamification.CurrentLevel++
		newThreshold := float64(user.Gamification.NextLevelThreshold) * 1.5
		user.Gamification.NextLevelThreshold = int32(newThreshold)
	}
}
