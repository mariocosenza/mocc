package cosmos

import (
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos"
)

func NewClientCosmos(ctx context.Context) (*azcosmos.Client, error) {
	url := os.Getenv("COSMOS_URL")
	if url == "" {
		return nil, fmt.Errorf("COSMOS_URL environment variable is not set")
	}

	key := os.Getenv("COSMOS_KEY")

	// If no key is provided and we are running locally (emulator), use the well-known emulator key.
	if key == "" && (strings.Contains(url, "localhost") || strings.Contains(url, "127.0.0.1")) {
		key = "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==" //SAFE IS THE DEFAULT KEY FOR ALL COSMOS EMULATOR
	}

	if key != "" {
		cred, err := azcosmos.NewKeyCredential(key)
		if err != nil {
			return nil, fmt.Errorf("failed to create key credential: %w", err)
		}

		client, err := azcosmos.NewClientWithKey(url, cred, nil)
		if err != nil {
			return nil, fmt.Errorf("failed to create cosmos client with key: %w", err)
		}

		return client, nil
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
