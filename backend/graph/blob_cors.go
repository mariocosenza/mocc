package graph

import (
	"context"
	"fmt"
	"strings"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/service"
)

// SetupBlobCORS configures CORS on the Blob Storage service to allow all origins.
// This is necessary for browser-based uploads to work without --disable-web-security.
func (r *Resolver) SetupBlobCORS(ctx context.Context) error {
	corsRule := service.CORSRule{
		AllowedOrigins:  strPtr("*"),
		AllowedMethods:  strPtr("GET,POST,PUT,DELETE,OPTIONS,HEAD,PATCH"),
		AllowedHeaders:  strPtr("*"),
		ExposedHeaders:  strPtr("*"),
		MaxAgeInSeconds: int32Ptr(3600),
	}

	_, err := r.BlobClient.ServiceClient().SetProperties(ctx, &service.SetPropertiesOptions{
		CORS: []*service.CORSRule{&corsRule},
	})
	if err != nil {
		// Check if it's an Azurite version error, which we can ignore
		if strings.Contains(err.Error(), "InvalidHeaderValue") && strings.Contains(err.Error(), "Azurite") {
			fmt.Printf("Warning: Azurite CORS setup failed (version mismatch), CORS may not be configured: %v\n", err)
			return nil
		}
		return fmt.Errorf("failed to set CORS on Blob Storage: %v", err)
	}

	fmt.Println("Blob Storage CORS configured successfully (allow all origins)")
	return nil
}

func strPtr(s string) *string { return &s }
func int32Ptr(i int32) *int32 { return &i }
