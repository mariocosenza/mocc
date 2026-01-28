package logic

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos"
	"github.com/mariocosenza/mocc/auth"
	"github.com/mariocosenza/mocc/graph/model"
)

func (l *Logic) UpsertShoppingHistory(ctx context.Context, entry *model.ShoppingHistoryEntry) error {
	logger := l.GetLogger()

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerHistory)
	if err != nil {
		logger.Printf("level=error op=SaveShoppingHistory stage=new_container db=%s container=%s userId=%s err=%v",
			CosmosDatabase, ContainerHistory, entry.AuthorID, err)
		return err
	}

	data, err := json.Marshal(entry)
	if err != nil {
		logger.Printf("level=error op=SaveShoppingHistory stage=json_marshal entryId=%s err=%v", entry.ID, err)
		return err
	}

	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(entry.AuthorID), data, nil)
	if err != nil {
		logger.Printf("level=error op=SaveShoppingHistory stage=upsert entryId=%s pk=%s err=%v", entry.ID, entry.AuthorID, err)
	}
	return err
}

func (l *Logic) FetchShoppingHistory(ctx context.Context, id string) (*model.ShoppingHistoryEntry, error) {
	logger := l.GetLogger()

	uid := auth.GetUserID(ctx)
	if uid == "" {
		return nil, fmt.Errorf("unauthorized")
	}

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerHistory)
	if err != nil {
		return nil, err
	}

	itemResponse, err := container.ReadItem(ctx, azcosmos.NewPartitionKeyString(uid), id, nil)
	if err != nil {
		logger.Printf("level=warn op=GetShoppingHistory stage=read_item id=%s pk=%s err=%v", id, uid, err)
		return nil, err
	}

	var entry model.ShoppingHistoryEntry
	if err := json.Unmarshal(itemResponse.Value, &entry); err != nil {
		return nil, err
	}

	return &entry, nil
}

func (l *Logic) FetchShoppingHistoryList(ctx context.Context, userID string, limit, offset int) ([]*model.ShoppingHistoryEntry, error) {
	logger := l.GetLogger()

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerHistory)
	if err != nil {
		return nil, err
	}

	query := "SELECT * FROM c WHERE c.authorId = @uid ORDER BY c.date DESC"
	qOpts := azcosmos.QueryOptions{
		QueryParameters: []azcosmos.QueryParameter{
			{Name: "@uid", Value: userID},
		},
	}

	pager := container.NewQueryItemsPager(query, azcosmos.NewPartitionKeyString(userID), &qOpts)

	var entries []*model.ShoppingHistoryEntry
	for pager.More() {
		resp, err := pager.NextPage(ctx)
		if err != nil {
			logger.Printf("level=error op=GetShoppingHistoryList stage=query_next_page userId=%s err=%v", userID, err)
			return nil, err
		}
		for _, bytes := range resp.Items {
			var entry model.ShoppingHistoryEntry
			if err := json.Unmarshal(bytes, &entry); err == nil {
				entries = append(entries, &entry)
			}
		}
		if len(entries) >= offset+limit {
			break
		}
	}

	if offset > len(entries) {
		return []*model.ShoppingHistoryEntry{}, nil
	}
	end := offset + limit
	if end > len(entries) {
		end = len(entries)
	}

	return entries[offset:end], nil
}
