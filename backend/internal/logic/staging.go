package logic

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos"
	"github.com/mariocosenza/mocc/graph/model"
)

func (l *Logic) UpsertStagingSession(ctx context.Context, session *model.StagingSession) error {
	logger := l.GetLogger()

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerStaging)
	if err != nil {
		logger.Printf("level=error op=UpsertStagingSession stage=get_container err=%v", err)
		return err
	}

	data, err := json.Marshal(session)
	if err != nil {
		logger.Printf("level=error op=UpsertStagingSession stage=json_marshal err=%v", err)
		return err
	}

	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(session.AuthorID), data, nil)
	if err != nil {
		logger.Printf("level=error op=UpsertStagingSession stage=cosmos_upsert sessionId=%s err=%v", session.ID, err)
		return err
	}

	return nil
}

func (l *Logic) FetchStagingSession(ctx context.Context, sessionID, authorID string) (*model.StagingSession, error) {
	logger := l.GetLogger()

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerStaging)
	if err != nil {
		return nil, err
	}

	res, err := container.ReadItem(ctx, azcosmos.NewPartitionKeyString(authorID), sessionID, nil)
	if err != nil {
		logger.Printf("level=warn op=FetchStagingSession stage=cosmos_read sessionId=%s err=%v", sessionID, err)
		return nil, fmt.Errorf(ErrItemNotFound)
	}

	var session model.StagingSession
	if err := json.Unmarshal(res.Value, &session); err != nil {
		logger.Printf("level=error op=FetchStagingSession stage=json_unmarshal sessionId=%s err=%v", sessionID, err)
		return nil, err
	}

	return &session, nil
}

func (l *Logic) FetchUserStagingSession(ctx context.Context, userID string) (*model.StagingSession, error) {
	logger := l.GetLogger()

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerStaging)
	if err != nil {
		return nil, err
	}

	query := "SELECT * FROM c WHERE c.authorId = @userId"
	opts := azcosmos.QueryOptions{
		QueryParameters: []azcosmos.QueryParameter{
			{Name: "@userId", Value: userID},
		},
	}

	logger.Printf("level=info op=FetchUserStagingSession stage=start userId=%s", userID)

	pager := container.NewQueryItemsPager(query, azcosmos.NewPartitionKeyString(userID), &opts)

	for pager.More() {
		resp, err := pager.NextPage(ctx)
		if err != nil {
			logger.Printf("level=error op=FetchUserStagingSession stage=next_page userId=%s err=%v", userID, err)
			return nil, err
		}
		logger.Printf("level=info op=FetchUserStagingSession stage=got_page userId=%s itemCount=%d", userID, len(resp.Items))
		for _, bytes := range resp.Items {
			var session model.StagingSession
			if err := json.Unmarshal(bytes, &session); err != nil {
				logger.Printf("level=error op=FetchUserStagingSession stage=unmarshal_item userId=%s err=%v", userID, err)
				continue
			}
			return &session, nil
		}
	}

	logger.Printf("level=info op=FetchUserStagingSession stage=not_found userId=%s", userID)
	return nil, fmt.Errorf("session not found")
}

func (l *Logic) FetchUserStagingID(ctx context.Context, userID string) (string, error) {
	session, err := l.FetchUserStagingSession(ctx, userID)
	if err != nil {
		return "", err
	}
	return session.ID, nil
}

func (l *Logic) PurgeUserStaging(ctx context.Context, userID string) {
	logger := l.GetLogger()
	session, err := l.FetchUserStagingSession(ctx, userID)
	if err != nil {
		return
	}

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerStaging)
	if err != nil {
		return
	}

	_, err = container.DeleteItem(ctx, azcosmos.NewPartitionKeyString(session.AuthorID), session.ID, nil)
	if err != nil {
		logger.Printf("level=error op=PurgeUserStaging stage=delete_item sessionId=%s err=%v", session.ID, err)
	}
}
