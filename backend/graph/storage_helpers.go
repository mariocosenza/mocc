package graph

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/sas"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/service"
)

// Helper to generate SAS tokens for Blob Storage
// Supports both Account Key (Dev) and User Delegation (Prod)

func (r *Resolver) generateSAS(ctx context.Context, containerName string, blobName string, permissions sas.BlobPermissions, duration time.Duration) (string, error) {
	connStr := os.Getenv("AZURE_STORAGE_CONNECTION_STRING")

	// DEV: Use Connection String (Account Key)
	if connStr != "" {

		cred, err := azblob.NewSharedKeyCredential("devstoreaccount1", "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==")
		if err != nil {
			return "", fmt.Errorf("failed to create dev credential: %v", err)
		}

		// Use an older API version that Azurite definitely supports
		vals := sas.BlobSignatureValues{
			Protocol:      sas.ProtocolHTTPSandHTTP,
			StartTime:     time.Now().Add(-5 * time.Minute).UTC(),
			ExpiryTime:    time.Now().Add(duration).UTC(),
			Permissions:   permissions.String(),
			ContainerName: containerName,
			BlobName:      blobName,
			// Version omitted - let SDK use its default
		}

		q, err := vals.SignWithSharedKey(cred)
		if err != nil {
			fmt.Printf("SAS Sign Error: %v\n", err)
			return "", err
		}

		// Azurite URL format - use http for local dev
		sasURL := fmt.Sprintf("http://127.0.0.1:10000/devstoreaccount1/%s/%s?%s", containerName, blobName, q.Encode())
		fmt.Printf("Generated SAS URL: %s\n", sasURL)
		fmt.Printf("SAS Query Params: sv=%s, sp=%s, sig=%s...\n", q.Version(), q.Permissions(), q.Signature()[:10])
		return sasURL, nil
	}

	// PROD: Use User Delegation SAS (Managed Identity)
	start := time.Now().Add(-5 * time.Minute)
	expiry := time.Now().Add(duration)

	info := service.KeyInfo{
		Start:  toPtr(start.Format(time.RFC3339)),
		Expiry: toPtr(expiry.Format(time.RFC3339)),
	}

	udc, err := r.BlobClient.ServiceClient().GetUserDelegationCredential(ctx, info, nil)
	if err != nil {
		return "", fmt.Errorf("failed to get user delegation credential: %v", err)
	}

	vals := sas.BlobSignatureValues{
		Protocol:      sas.Protocol("https"),
		StartTime:     start,
		ExpiryTime:    expiry,
		Permissions:   permissions.String(),
		ContainerName: containerName,
		BlobName:      blobName,
	}

	q, err := vals.SignWithUserDelegation(udc)
	if err != nil {
		return "", err
	}

	// Prod URL format: https://<account>.blob.core.windows.net/<container>/<blob>?<sas>
	return fmt.Sprintf("%s%s/%s?%s", r.BlobClient.URL(), containerName, blobName, q.Encode()), nil
}

func (r *Resolver) moveBlob(ctx context.Context, containerName, srcBlobName, destBlobName string) (string, error) {
	containerClient := r.BlobClient.ServiceClient().NewContainerClient(containerName)
	srcClient := containerClient.NewBlobClient(srcBlobName)
	destClient := containerClient.NewBlobClient(destBlobName)

	// Generate SAS for source (Read) to use in CopyFromURL

	// We need a short lived SAS for the source blob.
	permissions := sas.BlobPermissions{Read: true}
	srcSASURL, err := r.generateSAS(ctx, containerName, srcBlobName, permissions, 5*time.Minute)
	if err != nil {
		return "", fmt.Errorf("failed to generate source SAS for move: %v", err)
	}

	_, err = destClient.StartCopyFromURL(ctx, srcSASURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to start copy: %v", err)
	}

	// Wait for copy to complete
	start := time.Now()
	for {
		props, err := destClient.GetProperties(ctx, nil)
		if err != nil {
			return "", fmt.Errorf("failed to get dest properties: %v", err)
		}
		if props.CopyStatus == nil || *props.CopyStatus == "success" {
			break
		}
		if *props.CopyStatus == "failed" {
			return "", fmt.Errorf("copy failed: %s", *props.CopyStatusDescription)
		}
		if time.Since(start) > 30*time.Second {
			return "", fmt.Errorf("copy timed out")
		}
		time.Sleep(100 * time.Millisecond)
	}

	// Delete source
	_, err = srcClient.Delete(ctx, nil)
	if err != nil {
		// Log warning but don't fail the operation
		fmt.Printf("Warning: failed to delete source blob: %v\n", err)
	}

	// Generate a long-lived read SAS for the destination blob (7 days)
	readPermissions := sas.BlobPermissions{Read: true}
	destSASURL, err := r.generateSAS(ctx, containerName, destBlobName, readPermissions, 7*24*time.Hour)
	if err != nil {
		// Fallback to raw URL if SAS generation fails
		fmt.Printf("Warning: failed to generate read SAS for moved blob: %v\n", err)
		return destClient.URL(), nil
	}

	fmt.Printf("Move complete. Dest URL with SAS: %s\n", destSASURL)
	return destSASURL, nil
}

func (r *Resolver) ensureContainer(ctx context.Context, containerName string) error {
	_, err := r.BlobClient.ServiceClient().NewContainerClient(containerName).Create(ctx, nil)
	if err != nil {
		// Check for ContainerAlreadyExists (409)
		if strings.Contains(err.Error(), "ContainerAlreadyExists") || strings.Contains(err.Error(), "409") {
			return nil
		}
		// IGNORE Azurite version mismatch error for local dev
		if strings.Contains(err.Error(), "InvalidHeaderValue") && strings.Contains(err.Error(), "Azurite") {
			fmt.Printf("Warning: Azurite version mismatch ignored for container creation: %v\n", err)
			return nil
		}
		return err
	}
	return nil
}
