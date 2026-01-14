package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/99designs/gqlgen/graphql/handler"
	"github.com/99designs/gqlgen/graphql/handler/extension"
	"github.com/99designs/gqlgen/graphql/handler/lru"
	"github.com/99designs/gqlgen/graphql/handler/transport"
	"github.com/99designs/gqlgen/graphql/playground"
	"github.com/mariocosenza/mocc/auth"
	"github.com/mariocosenza/mocc/cosmos"
	"github.com/mariocosenza/mocc/graph"
	redisx "github.com/mariocosenza/mocc/redis"
	"github.com/vektah/gqlparser/v2/ast"
)

const defaultPort = "80"

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}

	ctx := context.Background()

	// Initialize Redis
	redisCfg := redisx.Config{
		RedisURL:                os.Getenv("REDIS_URL"),
		ManagedIdentityClientID: os.Getenv("MANAGED_IDENTITY_CLIENT_ID"),
		DialTimeout:             5 * time.Second,
	}
	redisClient, redisClose, err := redisx.NewClient(ctx, redisCfg)
	if err != nil {
		log.Fatalf("failed to init redis: %v", err)
	}
	defer redisClose()

	// Initialize Cosmos
	cosmosClient, err := cosmos.NewClientCosmos(ctx)
	if err != nil {
		log.Fatalf("failed to init cosmos: %v", err)
	}

	requireAuth := strings.EqualFold(os.Getenv("RUNNING_ON_AZURE"), "true")

	validator, err := auth.NewEntraValidator(auth.EntraConfig{
		TenantID:         os.Getenv("TENANT_ID"),
		ExpectedAudience: os.Getenv("EXPECTED_AUDIENCE"),
		RequiredScope:    os.Getenv("REQUIRED_SCOPE"),
		RequireAuth:      requireAuth,
	})
	if err != nil {
		log.Fatalf("auth init error: %v", err)
	}

	srv := handler.New(graph.NewExecutableSchema(graph.Config{
		Resolvers: &graph.Resolver{
			Redis:  redisClient,
			Cosmos: cosmosClient,
		},
	}))

	srv.AddTransport(transport.Options{})
	srv.AddTransport(transport.GET{})
	srv.AddTransport(transport.POST{})

	srv.SetQueryCache(lru.New[*ast.QueryDocument](1000))

	srv.Use(extension.AutomaticPersistedQuery{
		Cache: lru.New[string](100),
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	http.Handle("/", playground.Handler("GraphQL playground", "/query"))
	http.Handle("/query", validator.Middleware(srv))

	log.Printf("connect to http://localhost:%s/ for GraphQL playground", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
