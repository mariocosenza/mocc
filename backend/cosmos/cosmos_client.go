package cosmos

import (
	"context"
	"fmt"
	"os"

	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos"
)

func NewClientCosmos(ctx context.Context) (*azcosmos.Client, error) {
	url := os.Getenv("COSMOS_URL")
	if url == "" {
		return nil, fmt.Errorf("COSMOS_URL environment variable is not set")
	}

	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to obtain credential: %w", err)
	}
	client, err := azcosmos.NewClient(url, cred, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create cosmos client: %w", err)
	}

	return client, nil
}
