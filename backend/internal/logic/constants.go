package logic

import "time"

const (
	UserCacheDuration    = 24 * time.Hour
	CosmosDatabase       = "mocc-db"
	ContainerUsers       = "Users"
	ContainerInventory   = "Inventory"   // PK: /fridgeId
	ContainerCookbook    = "Cookbook"    // PK: /authorId
	ContainerSocial      = "Social"      // PK: /type
	ContainerHistory     = "History"     // PK: /authorId
	ContainerStaging     = "Staging"     // PK: /id
	ContainerLeaderboard = "Leaderboard" // PK: /period

	ErrItemNotFound = "item not found"

	StagingUserPrefix = "staging:user:"
	LeaderboardGlobal = "leaderboard:global"
)
