package logic

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/sas"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/service"
)

func (l *Logic) SetupBlobCORS(ctx context.Context) error {
	logger := l.GetLogger()

	serviceProps, err := l.BlobClient.ServiceClient().GetProperties(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to get blob service properties: %w", err)
	}

	corsRules := []*service.CORSRule{
		{
			AllowedOrigins:  toPtr("*"),
			AllowedMethods:  toPtr("GET,POST,PUT,OPTIONS"),
			AllowedHeaders:  toPtr("*"),
			ExposedHeaders:  toPtr("*"),
			MaxAgeInSeconds: toPtr(int32(3600)),
		},
	}
	serviceProps.CORS = corsRules

	_, err = l.BlobClient.ServiceClient().SetProperties(ctx, &service.SetPropertiesOptions{
		CORS: corsRules,
	})

	if err != nil {
		return fmt.Errorf("failed to set blob service properties: %w", err)
	}

	logger.Println("Successfully set Blob Storage CORS rules.")
	return nil
}

func (l *Logic) CreateSAS(ctx context.Context, containerName string, blobName string, permissions sas.BlobPermissions, duration time.Duration) (string, error) {
	connStr := os.Getenv("AZURE_STORAGE_CONNECTION_STRING")

	if connStr != "" {
		cred, err := azblob.NewSharedKeyCredential("devstoreaccount1", "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==")
		if err != nil {
			return "", fmt.Errorf("failed to create dev credential: %v", err)
		}

		vals := sas.BlobSignatureValues{
			Protocol:      sas.ProtocolHTTPSandHTTP,
			StartTime:     time.Now().Add(-5 * time.Minute).UTC(),
			ExpiryTime:    time.Now().Add(duration).UTC(),
			Permissions:   permissions.String(),
			ContainerName: containerName,
			BlobName:      blobName,
		}

		q, err := vals.SignWithSharedKey(cred)
		if err != nil {
			return "", err
		}

		sasURL := fmt.Sprintf("http://127.0.0.1:10000/devstoreaccount1/%s/%s?%s", containerName, blobName, q.Encode())
		return sasURL, nil
	}

	start := time.Now().Add(-5 * time.Minute)
	expiry := time.Now().Add(duration)

	info := service.KeyInfo{
		Start:  toPtr(start.Format(time.RFC3339)),
		Expiry: toPtr(expiry.Format(time.RFC3339)),
	}

	udc, err := l.BlobClient.ServiceClient().GetUserDelegationCredential(ctx, info, nil)
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

	return fmt.Sprintf("%s%s/%s?%s", l.BlobClient.URL(), containerName, blobName, q.Encode()), nil
}

func (l *Logic) RelocateBlob(ctx context.Context, containerName, srcBlobName, destBlobName string) (string, error) {
	containerClient := l.BlobClient.ServiceClient().NewContainerClient(containerName)
	srcClient := containerClient.NewBlobClient(srcBlobName)
	destClient := containerClient.NewBlobClient(destBlobName)

	permissions := sas.BlobPermissions{Read: true}
	srcSASURL, err := l.CreateSAS(ctx, containerName, srcBlobName, permissions, 5*time.Minute)
	if err != nil {
		return "", fmt.Errorf("failed to generate source SAS for move: %v", err)
	}

	_, err = destClient.StartCopyFromURL(ctx, srcSASURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to start copy: %v", err)
	}

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

	_, err = srcClient.Delete(ctx, nil)
	if err != nil {
		log.Printf("Warning: failed to delete source blob: %v", err)
	}

	readPermissions := sas.BlobPermissions{Read: true}
	destSASURL, err := l.CreateSAS(ctx, containerName, destBlobName, readPermissions, 7*24*time.Hour)
	if err != nil {
		return destClient.URL(), nil
	}

	return destSASURL, nil
}

func (l *Logic) CreateContainerIfNotExists(ctx context.Context, containerName string) error {
	_, err := l.BlobClient.ServiceClient().NewContainerClient(containerName).Create(ctx, nil)
	if err != nil {
		if strings.Contains(err.Error(), "ContainerAlreadyExists") || strings.Contains(err.Error(), "409") {
			return nil
		}
		if strings.Contains(err.Error(), "InvalidHeaderValue") && strings.Contains(err.Error(), "Azurite") {
			return nil
		}
		return err
	}
	return nil
}

func (l *Logic) ForwardToAzureFunction(ctx context.Context, url string, payload interface{}) error {
	jsonBody, _ := json.Marshal(payload)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("function returned status %d: %s", resp.StatusCode, string(bodyBytes))
	}
	return nil
}

func (l *Logic) DeleteBlob(ctx context.Context, blobUrl string) error {
	if blobUrl == "" {
		return nil
	}
	u, err := url.Parse(blobUrl)
	if err != nil {
		return fmt.Errorf("failed to parse blob URL: %v", err)
	}

	path := strings.TrimPrefix(u.Path, "/")
	parts := strings.SplitN(path, "/", 2)
	if len(parts) < 2 {
		return fmt.Errorf("invalid blob URL path: %s", u.Path)
	}
	containerName := parts[0]
	blobName := parts[1]

	containerClient := l.BlobClient.ServiceClient().NewContainerClient(containerName)
	blobClient := containerClient.NewBlobClient(blobName)

	_, err = blobClient.Delete(ctx, nil)
	if err != nil {
		if strings.Contains(err.Error(), "BlobNotFound") || strings.Contains(err.Error(), "404") {
			return nil
		}
		return fmt.Errorf("failed to delete blob %s/%s: %v", containerName, blobName, err)
	}
	l.Logger.Printf("Successfully deleted blob: %s/%s", containerName, blobName)
	return nil
}

func toPtr[T any](v T) *T {
	return &v
}
