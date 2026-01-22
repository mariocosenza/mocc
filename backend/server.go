package main

import (
	"context"
	"log"
	"net/http"
	"os"
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
	redisx "github.com/mariocosenza/mocc/redis"
	msgraphsdk "github.com/microsoftgraph/msgraph-sdk-go"
	"github.com/rs/cors"
	"github.com/vektah/gqlparser/v2/ast"
)

const defaultPort = "80"

func logRequestMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("[QUERY] %s %s from %s", r.Method, r.URL.Path, r.RemoteAddr)
		next.ServeHTTP(w, r)
	})
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}

	ctx := context.Background()
	logger := log.New(os.Stdout, "", log.LstdFlags|log.LUTC)

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

	cosmosClient, err := cosmos.NewClientCosmos(ctx)
	if err != nil {
		log.Fatalf("failed to init cosmos: %v", err)
	}

	// Initialize Microsoft Graph
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		log.Fatalf("failed to create credential: %v", err)
	}
	graphClient, err := msgraphsdk.NewGraphServiceClientWithCredentials(cred, []string{"https://graph.microsoft.com/.default"})
	if err != nil {
		log.Fatalf("failed to create graph client: %v", err)
	}

	validator, err := auth.NewEntraValidator(auth.EntraConfig{
		TenantID:         os.Getenv("AUTH_AUTHORITY"),
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
		// Production: Use DefaultAzureCredential and Account URL
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

	srv := handler.New(graph.NewExecutableSchema(graph.Config{
		Resolvers: &graph.Resolver{
			Redis:       redisClient,
			Cosmos:      cosmosClient,
			GraphClient: graphClient,
			BlobClient:  blobClient,
			Logger:      logger,
		},
	}))

	// Setup CORS on Blob Storage for browser uploads
	resolver := &graph.Resolver{BlobClient: blobClient}
	if err := resolver.SetupBlobCORS(ctx); err != nil {
		log.Printf("Warning: %v", err)
	}

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
	http.Handle("/query", logRequestMiddleware(validator.Middleware(srv)))

	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{http.MethodGet, http.MethodPost, http.MethodOptions},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: false,
	})

	log.Printf("connect to http://localhost:%s/ for GraphQL playground", port)
	log.Fatal(http.ListenAndServe(":"+port, c.Handler(http.DefaultServeMux)))
}

func strPtr(s string) *string { return &s }
func int32Ptr(i int32) *int32 { return &i }
