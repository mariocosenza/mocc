package logic

import (
	"log"

	"github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	msgraphsdk "github.com/microsoftgraph/msgraph-sdk-go"
	"github.com/redis/go-redis/v9"
)

type Logic struct {
	Redis       *redis.Client
	Cosmos      *azcosmos.Client
	GraphClient *msgraphsdk.GraphServiceClient
	BlobClient  *azblob.Client
	Logger      *log.Logger
}

func NewLogic(redis *redis.Client, cosmos *azcosmos.Client, graph *msgraphsdk.GraphServiceClient, blob *azblob.Client, logger *log.Logger) *Logic {
	return &Logic{
		Redis:       redis,
		Cosmos:      cosmos,
		GraphClient: graph,
		BlobClient:  blob,
		Logger:      logger,
	}
}

func (l *Logic) GetLogger() *log.Logger {
	if l.Logger != nil {
		return l.Logger
	}
	return log.Default()
}
