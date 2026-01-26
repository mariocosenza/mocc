package logic

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos"
	"github.com/mariocosenza/mocc/graph/model"
)

func (l *Logic) FetchRecipe(ctx context.Context, id string) (*model.Recipe, error) {
	logger := l.GetLogger()

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerCookbook)
	if err != nil {
		logger.Printf("level=error op=GetRecipe stage=new_container db=%s container=%s recipeId=%s err=%v",
			CosmosDatabase, ContainerCookbook, id, err)
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
			logger.Printf("level=error op=GetRecipe stage=query_next_page recipeId=%s err=%v", id, err)
			return nil, err
		}
		if len(resp.Items) > 0 {
			var recipe model.Recipe
			if err := json.Unmarshal(resp.Items[0], &recipe); err != nil {
				logger.Printf("level=warn op=GetRecipe stage=json_unmarshal recipeId=%s err=%v", id, err)
				continue
			}
			return &recipe, nil
		}
	}
	return nil, fmt.Errorf("not found")
}

func (l *Logic) UpsertRecipe(ctx context.Context, recipe *model.Recipe) error {
	logger := l.GetLogger()

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerCookbook)
	if err != nil {
		logger.Printf("level=error op=SaveRecipe stage=new_container db=%s container=%s authorId=%s recipeId=%s err=%v",
			CosmosDatabase, ContainerCookbook, recipe.AuthorID, recipe.ID, err)
		return err
	}

	data, err := json.Marshal(recipe)
	if err != nil {
		logger.Printf("level=error op=SaveRecipe stage=json_marshal authorId=%s recipeId=%s err=%v",
			recipe.AuthorID, recipe.ID, err)
		return err
	}

	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(recipe.AuthorID), data, nil)
	if err != nil {
		logger.Printf("level=error op=SaveRecipe stage=upsert authorId=%s recipeId=%s pk=%s err=%v",
			recipe.AuthorID, recipe.ID, recipe.AuthorID, err)
	}
	return err
}
