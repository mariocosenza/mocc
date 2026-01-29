package logic

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos"
	"github.com/google/uuid"
	"github.com/mariocosenza/mocc/graph/model"
)

func (l *Logic) CreateFridgeForUser(ctx context.Context, userID string) error {
	logger := l.GetLogger()

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerInventory)
	if err != nil {
		logger.Printf("level=error op=CreateFridgeForUser stage=new_container db=%s container=%s userId=%s err=%v",
			CosmosDatabase, ContainerInventory, userID, err)
		return err
	}

	fridge := &model.Fridge{
		ID:      userID,
		Name:    "Il mio Frigo",
		OwnerID: []string{userID},
		Items:   []*model.InventoryItem{},
	}

	dataMap := map[string]interface{}{}
	tempJSON, mErr := json.Marshal(fridge)
	if mErr != nil {
		logger.Printf("level=error op=CreateFridgeForUser stage=json_marshal_fridge userId=%s err=%v", userID, mErr)
		return mErr
	}
	if uErr := json.Unmarshal(tempJSON, &dataMap); uErr != nil {
		logger.Printf("level=error op=CreateFridgeForUser stage=json_unmarshal_map userId=%s err=%v", userID, uErr)
		return uErr
	}
	dataMap["fridgeId"] = fridge.ID

	data, err := json.Marshal(dataMap)
	if err != nil {
		logger.Printf("level=error op=CreateFridgeForUser stage=json_marshal_map userId=%s err=%v", userID, err)
		return err
	}

	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(userID), data, nil)
	if err != nil {
		logger.Printf("level=error op=CreateFridgeForUser stage=upsert userId=%s pk=%s err=%v", userID, userID, err)
	}
	return err
}

func (l *Logic) FetchFridges(ctx context.Context, userID string) ([]*model.Fridge, error) {
	logger := l.GetLogger()

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerInventory)
	if err != nil {
		logger.Printf("level=error op=GetFridges stage=new_container db=%s container=%s userId=%s err=%v",
			CosmosDatabase, ContainerInventory, userID, err)
		return nil, err
	}

	query := "SELECT * FROM c WHERE c.id = @id or ARRAY_CONTAINS(c.ownerId, @id)"
	qOpts := azcosmos.QueryOptions{
		QueryParameters: []azcosmos.QueryParameter{
			{Name: "@id", Value: userID},
		},
	}
	pager := container.NewQueryItemsPager(query, azcosmos.PartitionKey{}, &qOpts)

	var fridges []*model.Fridge
	for pager.More() {
		resp, err := pager.NextPage(ctx)
		if err != nil {
			logger.Printf("level=error op=GetFridges stage=query_next_page userId=%s err=%v", userID, err)
			return nil, err
		}
		for _, item := range resp.Items {
			var fridge model.Fridge
			if err := json.Unmarshal(item, &fridge); err != nil {
				logger.Printf("level=warn op=GetFridges stage=json_unmarshal userId=%s err=%v", userID, err)
				continue
			}
			fridges = append(fridges, &fridge)
		}
	}

	return fridges, nil
}

func (l *Logic) FetchFridge(ctx context.Context, userID string) (*model.Fridge, error) {
	fridges, err := l.FetchFridges(ctx, userID)
	if err != nil {
		return nil, err
	}
	if len(fridges) == 0 {
		return nil, fmt.Errorf("not found")
	}
	for _, f := range fridges {
		if f.ID == userID {
			return f, nil
		}
	}
	return fridges[0], nil
}

func (l *Logic) UpsertFridge(ctx context.Context, fridge *model.Fridge) error {
	logger := l.GetLogger()

	container, err := l.Cosmos.NewContainer(CosmosDatabase, ContainerInventory)
	if err != nil {
		logger.Printf("level=error op=SaveFridge stage=new_container db=%s container=%s fridgeId=%s err=%v",
			CosmosDatabase, ContainerInventory, fridge.ID, err)
		return err
	}

	dataMap := map[string]interface{}{}
	tempJSON, mErr := json.Marshal(fridge)
	if mErr != nil {
		logger.Printf("level=error op=SaveFridge stage=json_marshal_fridge fridgeId=%s err=%v", fridge.ID, mErr)
		return mErr
	}
	if uErr := json.Unmarshal(tempJSON, &dataMap); uErr != nil {
		logger.Printf("level=error op=SaveFridge stage=json_unmarshal_map fridgeId=%s err=%v", fridge.ID, uErr)
		return uErr
	}
	dataMap["fridgeId"] = fridge.ID

	data, err := json.Marshal(dataMap)
	if err != nil {
		logger.Printf("level=error op=SaveFridge stage=json_marshal_map fridgeId=%s err=%v", fridge.ID, err)
		return err
	}

	_, err = container.UpsertItem(ctx, azcosmos.NewPartitionKeyString(fridge.ID), data, nil)
	if err != nil {
		logger.Printf("level=error op=SaveFridge stage=upsert fridgeId=%s pk=%s err=%v", fridge.ID, fridge.ID, err)
	}
	return err
}

func (l *Logic) LockIngredients(ctx context.Context, uid string, recipe *model.Recipe) error {
	fridge, err := l.FetchFridge(ctx, uid)
	if err != nil {
		return err
	}

	changed := false
	now := time.Now().Format(time.RFC3339)

	requirements := make(map[string]float64)
	for _, ing := range recipe.Ingredients {
		if ing.InventoryItemID != nil && *ing.InventoryItemID != "" {
			requirements[*ing.InventoryItemID] += ing.Quantity
		}
	}

	if len(requirements) == 0 {
		return nil
	}

	for itemID, reqQty := range requirements {
		for _, item := range fridge.Items {
			if item.ID == itemID {
				var existingLock *model.ProductLock
				for _, lock := range item.ActiveLocks {
					if lock.RecipeID == recipe.ID {
						existingLock = lock
						break
					}
				}

				if existingLock != nil {
					if existingLock.Amount != reqQty {
						existingLock.Amount = reqQty
						existingLock.StartedAt = now
						changed = true
					}
				} else {
					item.ActiveLocks = append(item.ActiveLocks, &model.ProductLock{
						RecipeID:  recipe.ID,
						Amount:    reqQty,
						StartedAt: now,
					})
					changed = true
				}

				item.VirtualAvailable = item.Quantity.Value
				for _, lock := range item.ActiveLocks {
					item.VirtualAvailable -= lock.Amount
				}

				if item.VirtualAvailable < -0.001 {
					return fmt.Errorf("insufficient quantity for item %s", item.Name)
				}
			}
		}
	}

	if changed {
		return l.UpsertFridge(ctx, fridge)
	}
	return nil
}

func (l *Logic) ApplyCooking(ctx context.Context, uid string, recipe *model.Recipe) error {
	fridge, err := l.FetchFridge(ctx, uid)
	if err != nil {
		return err
	}

	if recipe.CookedItems == nil {
		recipe.CookedItems = []*model.RecipeCookedItem{}
	}
	changed := false

	for _, ing := range recipe.Ingredients {
		if ing.InventoryItemID != nil && *ing.InventoryItemID != "" {
			itemsToRemove := []int{}
			for idx, item := range fridge.Items {
				if item.ID == *ing.InventoryItemID {
					item.Quantity.Value -= ing.Quantity

					if item.Quantity.Value <= 0.001 {
						itemsToRemove = append(itemsToRemove, idx)
					} else {
						item.VirtualAvailable = item.Quantity.Value
						for _, lock := range item.ActiveLocks {
							item.VirtualAvailable -= lock.Amount
						}
					}

					recipe.CookedItems = append(recipe.CookedItems, &model.RecipeCookedItem{
						ID:                  uuid.New().String(),
						Name:                item.Name,
						Brand:               item.Brand,
						Category:            item.Category,
						Quantity:            item.Quantity,
						Price:               item.Price,
						UsedQuantity:        ing.Quantity,
						OriginalInventoryID: &item.ID,
					})
					changed = true
				}
			}

			for i := len(itemsToRemove) - 1; i >= 0; i-- {
				idx := itemsToRemove[i]
				fridge.Items = append(fridge.Items[:idx], fridge.Items[idx+1:]...)
			}
		}
	}

	if changed {
		return l.UpsertFridge(ctx, fridge)
	}
	return nil
}

func (l *Logic) UnlockIngredients(ctx context.Context, uid string, recipeID string) error {
	fridge, err := l.FetchFridge(ctx, uid)
	if err != nil {
		return err
	}

	changed := false
	for _, item := range fridge.Items {
		newLocks := []*model.ProductLock{}
		itemChanged := false
		for _, lock := range item.ActiveLocks {
			if lock.RecipeID == recipeID {
				itemChanged = true
				continue
			}
			newLocks = append(newLocks, lock)
		}
		if itemChanged {
			item.ActiveLocks = newLocks
			item.VirtualAvailable = item.Quantity.Value
			for _, lock := range item.ActiveLocks {
				item.VirtualAvailable -= lock.Amount
			}
			item.VirtualAvailable = math.Round(item.VirtualAvailable*1000) / 1000
			changed = true
		}
	}

	if changed {
		return l.UpsertFridge(ctx, fridge)
	}
	return nil
}
