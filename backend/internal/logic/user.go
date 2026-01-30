package logic

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"math/big"

	"github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos"
	"github.com/mariocosenza/mocc/auth"
	"github.com/mariocosenza/mocc/graph/model"
)

func GenerateRandomNickname() string {
	const letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, 10)
	for i := range b {
		num, _ := rand.Int(rand.Reader, big.NewInt(int64(len(letters))))
		b[i] = letters[num.Int64()]
	}
	return "User_" + string(b)
}

func (l *Logic) FetchUser(ctx context.Context, userID string) (*model.User, error) {
	logger := l.GetLogger()

	val, err := l.Redis.Get(ctx, "user:"+userID).Result()
	if err == nil {
		var user model.User
		if uErr := json.Unmarshal([]byte(val), &user); uErr == nil {
			return &user, nil
		} else {
			logger.Printf("level=warn op=GetUser stage=redis_unmarshal userId=%s err=%v", userID, uErr)
		}
	} else {
		logger.Printf("level=info op=GetUser stage=redis_get userId=%s err=%v", userID, err)
	}

	user, err := l.GetUserFromCosmos(ctx, userID)
	if err == nil && user != nil {
		l.SetUserCache(ctx, user)
		return user, nil
	}
	if err != nil {
		logger.Printf("level=warn op=GetUser stage=cosmos_read userId=%s err=%v", userID, err)
	}

	defaultPortions := int32(1)
	newUser := &model.User{
		ID:       userID,
		Email:    "user@" + userID + ".com",
		Origin:   model.AccountOriginMicrosoft,
		Nickname: GenerateRandomNickname(),
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

	if err := l.UpsertUser(ctx, newUser); err != nil {
		logger.Printf("level=error op=GetUser stage=cosmos_upsert_user userId=%s err=%v", userID, err)
		return nil, err
	}

	l.SetUserCache(ctx, newUser)

	if err := l.CreateFridgeForUser(ctx, userID); err != nil {
		logger.Printf("level=error op=GetUser stage=create_fridge userId=%s err=%v", userID, err)
	}

	return newUser, nil
}

func (l *Logic) SetUserCache(ctx context.Context, user *model.User) {
	logger := l.GetLogger()

	data, err := json.Marshal(user)
	if err != nil {
		logger.Printf("level=warn op=CacheUser stage=json_marshal userId=%s err=%v", user.ID, err)
		return
	}

	if err := l.Redis.Set(ctx, "user:"+user.ID, data, UserCacheDuration).Err(); err != nil {
		logger.Printf("level=warn op=CacheUser stage=redis_set userId=%s err=%v", user.ID, err)
	}
}

func (l *Logic) GetUserFromCosmos(ctx context.Context, userID string) (*model.User, error) {
	logger := l.GetLogger()

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerUsers)
	if err != nil {
		logger.Printf("level=error op=GetUserFromCosmos stage=new_container db=%s container=%s userId=%s err=%v",
			CosmosDatabase, ContainerUsers, userID, err)
		return nil, err
	}

	itemResponse, err := container.ReadItem(ctx, azcosmos.NewPartitionKeyString(userID), userID, nil)
	if err != nil {
		logger.Printf("level=warn op=GetUserFromCosmos stage=read_item userId=%s pk=%s err=%v", userID, userID, err)
		return nil, err
	}

	var user model.User
	if err := json.Unmarshal(itemResponse.Value, &user); err != nil {
		logger.Printf("level=warn op=GetUserFromCosmos stage=json_unmarshal userId=%s err=%v", userID, err)
		return nil, err
	}

	return &user, nil
}

func (l *Logic) UpsertUser(ctx context.Context, user *model.User) error {
	logger := l.GetLogger()

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerUsers)
	if err != nil {
		logger.Printf("level=error op=SaveUserToCosmos stage=new_container db=%s container=%s userId=%s err=%v",
			CosmosDatabase, ContainerUsers, user.ID, err)
		return err
	}

	data, err := json.Marshal(user)
	if err != nil {
		logger.Printf("level=error op=SaveUserToCosmos stage=json_marshal userId=%s err=%v", user.ID, err)
		return err
	}

	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(user.ID), data, nil)
	if err != nil {
		logger.Printf("level=error op=SaveUserToCosmos stage=upsert userId=%s pk=%s err=%v", user.ID, user.ID, err)
	}
	return err
}

func (l *Logic) ResolveUserID(ctx context.Context) (string, error) {
	logger := l.GetLogger()

	uid := auth.GetUserID(ctx)
	if uid == "" {
		logger.Printf("level=warn op=GetUserID stage=auth_missing_user")
		return "", fmt.Errorf("unauthorized")
	}

	val, err := l.Redis.Get(ctx, "user:"+uid).Result()
	if err != nil || len(val) < 2 {
		if err != nil {
			logger.Printf("level=info op=GetUserID stage=redis_get userId=%s err=%v", uid, err)
		}
		if _, uErr := l.FetchUser(ctx, uid); uErr != nil {
			logger.Printf("level=error op=GetUserID stage=ensure_user userId=%s err=%v", uid, uErr)
			return "", uErr
		}
	}

	return uid, nil
}
