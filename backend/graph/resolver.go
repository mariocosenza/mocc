package graph

import (
	"github.com/mariocosenza/mocc/internal/logic"
)

// Dependency injection for app services.

type Resolver struct {
	*logic.Logic
}
