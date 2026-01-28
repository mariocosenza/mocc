package graph

import (
	"context"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/sas"
)

func (r *queryResolver) signReceiptURL(ctx context.Context, rawURL string) (string, error) {
	if rawURL == "" {
		return "", fmt.Errorf("empty URL")
	}

	parsed, err := url.Parse(rawURL)
	if err != nil {
		return rawURL, nil
	}

	var containerName, blobName string

	if strings.Contains(parsed.Host, "127.0.0.1") ||
		strings.Contains(parsed.Host, "localhost") ||
		strings.Contains(rawURL, "devstoreaccount1") {
		path := strings.TrimPrefix(parsed.Path, "/")
		parts := strings.SplitN(path, "/", 3)
		if len(parts) < 3 {
			return rawURL, nil
		}
		containerName = parts[1]
		blobName = parts[2]
	} else {
		path := strings.TrimPrefix(parsed.Path, "/")
		parts := strings.SplitN(path, "/", 2)
		if len(parts) < 2 {
			return rawURL, nil
		}
		containerName = parts[0]
		blobName = parts[1]
	}

	perms := sas.BlobPermissions{Read: true}
	signedURL, err := r.CreateSAS(ctx, containerName, blobName, perms, 1*time.Hour)
	if err != nil {
		return rawURL, nil
	}

	return signedURL, nil
}
