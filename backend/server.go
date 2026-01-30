package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"strings"
	"sync/atomic"
	"time"

	"github.com/99designs/gqlgen/graphql/handler"
	"github.com/99designs/gqlgen/graphql/handler/extension"
	"github.com/99designs/gqlgen/graphql/handler/lru"
	"github.com/99designs/gqlgen/graphql/handler/transport"
	"github.com/99designs/gqlgen/graphql/playground"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/mariocosenza/mocc/auth"
	"github.com/mariocosenza/mocc/cosmos"
	"github.com/mariocosenza/mocc/graph"
	"github.com/mariocosenza/mocc/internal/logic"
	redisx "github.com/mariocosenza/mocc/redis"
	msgraphsdk "github.com/microsoftgraph/msgraph-sdk-go"
	"github.com/redis/go-redis/v9"
	"github.com/rs/cors"
	"github.com/vektah/gqlparser/v2/ast"
)

const defaultPort = "8080"

func logRequestMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("[QUERY] %s %s from %s", r.Method, r.URL.Path, r.RemoteAddr)
		next.ServeHTTP(w, r)
	})
}

func normalizeTenantOrAuthority(s string) string {
	if s == "" {
		return s
	}
	if strings.HasPrefix(s, "https://login.microsoftonline.com/") {
		rest := strings.TrimPrefix(s, "https://login.microsoftonline.com/")
		rest = strings.TrimPrefix(rest, "/")
		if i := strings.Index(rest, "/"); i >= 0 {
			rest = rest[:i]
		}
		return rest
	}
	return s
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}

	var ready atomic.Bool
	var gqlHandler atomic.Value

	gqlHandler.Store(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "starting", http.StatusServiceUnavailable)
	}))

	mux := http.NewServeMux()

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("OK"))
	})

	mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		if ready.Load() {
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte("READY"))
			return
		}
		http.Error(w, "NOT_READY", http.StatusServiceUnavailable)
	})

	mux.Handle("/", playground.Handler("GraphQL playground", "/query"))

	mux.Handle("/query", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := gqlHandler.Load().(http.Handler)
		h.ServeHTTP(w, r)
	}))

	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{http.MethodGet, http.MethodPost, http.MethodOptions},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: false,
	})

	srvHTTP := &http.Server{
		Addr:              ":" + port,
		Handler:           c.Handler(mux),
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("listening on :%s", port)
		err := srvHTTP.ListenAndServe()
		if err != nil && err != http.ErrServerClosed {
			log.Fatalf("http server error: %v", err)
		}
	}()

	ctx := context.Background()
	logger := log.New(os.Stdout, "", log.LstdFlags|log.LUTC)

	redisCfg := redisx.Config{
		RedisURL:                os.Getenv("REDIS_URL"),
		ManagedIdentityClientID: os.Getenv("MANAGED_IDENTITY_CLIENT_ID"),
		DialTimeout:             5 * time.Second,
	}

	var redisClient *redis.Client
	var redisClose func() error
	var err error

	for i := 0; i < 5; i++ {
		redisClient, redisClose, err = redisx.NewClient(ctx, redisCfg)
		if err == nil {
			break
		}
		log.Printf("failed to init redis (attempt %d/5): %v. Retrying in 5 seconds...", i+1, err)
		time.Sleep(5 * time.Second)
	}
	if err != nil {
		log.Fatalf("failed to init redis after 5 attempts: %v", err)
	}
	defer func() { _ = redisClose() }()

	cosmosClient, err := cosmos.NewClientCosmos(ctx)
	if err != nil {
		log.Fatalf("failed to init cosmos: %v", err)
	}

	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		log.Fatalf("failed to create credential: %v", err)
	}

	graphClient, err := msgraphsdk.NewGraphServiceClientWithCredentials(
		cred,
		[]string{"https://graph.microsoft.com/.default"},
	)
	if err != nil {
		log.Fatalf("failed to create graph client: %v", err)
	}

	tenantOrAuthority := normalizeTenantOrAuthority(os.Getenv("AUTH_AUTHORITY"))
	validator, err := auth.NewEntraValidator(auth.EntraConfig{
		TenantID:         tenantOrAuthority,
		ExpectedAudience: os.Getenv("EXPECTED_AUDIENCE"),
		RequiredScope:    os.Getenv("REQUIRED_SCOPE"),
	})
	if err != nil {
		log.Fatalf("auth init error: %v", err)
	}

	var blobClient *azblob.Client
	storageConnStr := os.Getenv("AZURE_STORAGE_CONNECTION_STRING")
	if storageConnStr != "" {
		blobClient, err = azblob.NewClientFromConnectionString(storageConnStr, nil)
		if err != nil {
			log.Fatalf("failed to create blob client from connection string: %v", err)
		}
	} else {
		accountName := os.Getenv("AZURE_STORAGE_ACCOUNT_NAME")
		if accountName == "" {
			log.Fatalf("AZURE_STORAGE_ACCOUNT_NAME required in production")
		}
		serviceURL := "https://" + accountName + ".blob.core.windows.net/"
		blobClient, err = azblob.NewClient(serviceURL, cred, nil)
		if err != nil {
			log.Fatalf("failed to create blob client: %v", err)
		}
	}

	logicLayer := logic.NewLogic(redisClient, cosmosClient, graphClient, blobClient, logger)

	srv := handler.New(graph.NewExecutableSchema(graph.Config{
		Resolvers: &graph.Resolver{
			Logic: logicLayer,
		},
	}))

	srv.AddTransport(transport.Options{})
	srv.AddTransport(transport.GET{})
	srv.AddTransport(transport.POST{})

	srv.SetQueryCache(lru.New[*ast.QueryDocument](1000))

	srv.Use(extension.AutomaticPersistedQuery{
		Cache: lru.New[string](100),
	})

	gqlHandler.Store(logRequestMiddleware(validator.Middleware(srv)))
	ready.Store(true)

	select {}
}
