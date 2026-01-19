package graph

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/mariocosenza/mocc/graph/model"
)

func (r *Resolver) lockRecipeIngredients(ctx context.Context, uid string, recipe *model.Recipe) error {
	fridge, err := r.getFridge(ctx, uid)
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
				for _, l := range item.ActiveLocks {
					if l.RecipeID == recipe.ID {
						existingLock = l
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
				for _, l := range item.ActiveLocks {
					item.VirtualAvailable -= l.Amount
				}

				if item.VirtualAvailable < 0 {
					return fmt.Errorf("insufficient quantity for item %s", item.Name)
				}
			}
		}
	}

	if changed {
		return r.saveFridge(ctx, fridge)
	}
	return nil
}

func (r *Resolver) completeRecipeCooking(ctx context.Context, uid string, recipe *model.Recipe) error {
	fridge, err := r.getFridge(ctx, uid)
	if err != nil {
		return err
	}

	if recipe.CookedItems == nil {
		recipe.CookedItems = []*model.RecipeCookedItem{}
	}
	changed := false

	for _, ing := range recipe.Ingredients {
		if ing.InventoryItemID != nil && *ing.InventoryItemID != "" {
			for _, item := range fridge.Items {
				if item.ID == *ing.InventoryItemID {
					item.Quantity.Value -= ing.Quantity
					if item.Quantity.Value < 0 {
						item.Quantity.Value = 0
					}

					item.VirtualAvailable = item.Quantity.Value
					for _, l := range item.ActiveLocks {
						item.VirtualAvailable -= l.Amount
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
		}
	}

	if changed {
		return r.saveFridge(ctx, fridge)
	}
	return nil
}

func (r *Resolver) unlockRecipeIngredients(ctx context.Context, uid string, recipeID string) error {
	fridge, err := r.getFridge(ctx, uid)
	if err != nil {
		return err
	}

	changed := false
	for _, item := range fridge.Items {
		newLocks := []*model.ProductLock{}
		itemChanged := false
		for _, l := range item.ActiveLocks {
			if l.RecipeID == recipeID {
				itemChanged = true
				continue
			}
			newLocks = append(newLocks, l)
		}
		if itemChanged {
			item.ActiveLocks = newLocks
			item.VirtualAvailable = item.Quantity.Value
			for _, l := range item.ActiveLocks {
				item.VirtualAvailable -= l.Amount
			}
			changed = true
		}
	}

	if changed {
		return r.saveFridge(ctx, fridge)
	}
	return nil
}
