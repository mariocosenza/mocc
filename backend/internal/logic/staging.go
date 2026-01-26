package logic

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/mariocosenza/mocc/graph/model"
)

func (l *Logic) UpsertStagingSession(ctx context.Context, session *model.StagingSession) error {
	logger := l.GetLogger()

	data, err := json.Marshal(session)
	if err != nil {
		logger.Printf("level=error op=SaveStagingSession stage=json_marshal sessionId=%s err=%v", session.ID, err)
		return err
	}

	if err := l.Redis.Set(ctx, "staging:session:"+session.ID, data, 24*time.Hour).Err(); err != nil {
		logger.Printf("level=error op=SaveStagingSession stage=redis_set sessionId=%s err=%v", session.ID, err)
		return err
	}

	return nil
}

func (l *Logic) FetchStagingSession(ctx context.Context, sessionID string) (*model.StagingSession, error) {
	logger := l.GetLogger()

	val, err := l.Redis.Get(ctx, "staging:session:"+sessionID).Result()
	if err != nil {
		logger.Printf("level=warn op=GetStagingSession stage=redis_get sessionId=%s err=%v", sessionID, err)
		return nil, fmt.Errorf("session not found")
	}

	var session model.StagingSession
	if err := json.Unmarshal([]byte(val), &session); err != nil {
		logger.Printf("level=warn op=GetStagingSession stage=json_unmarshal sessionId=%s err=%v", sessionID, err)
		return nil, err
	}
	return &session, nil
}

func (l *Logic) AssociateStagingWithUser(ctx context.Context, userID, sessionID string) error {
	logger := l.GetLogger()

	if err := l.Redis.Set(ctx, StagingUserPrefix+userID, sessionID, 24*time.Hour).Err(); err != nil {
		logger.Printf("level=error op=SetUserStagingSession userId=%s sessionId=%s err=%v", userID, sessionID, err)
		return err
	}
	return nil
}

func (l *Logic) FetchUserStagingID(ctx context.Context, userID string) (string, error) {
	logger := l.GetLogger()

	val, err := l.Redis.Get(ctx, StagingUserPrefix+userID).Result()
	if err != nil {
		logger.Printf("level=warn op=GetUserStagingSessionID userId=%s err=%v", userID, err)
		return "", err
	}
	return val, nil
}

func (l *Logic) PurgeUserStaging(ctx context.Context, userID string) {
	logger := l.GetLogger()

	if err := l.Redis.Del(ctx, StagingUserPrefix+userID).Err(); err != nil {
		logger.Printf("level=warn op=ClearUserStagingSession userId=%s err=%v", userID, err)
	}
}
