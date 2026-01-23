$userId = "" # Replace with your actual User ID from the database or logs
$filename = "" # Replace with the filename you uploaded
$blobUrl = "http://127.0.0.1:10000/devstoreaccount1/recipes-input/users/$userId/$filename"
# If using real Azure Storage:
# $blobUrl = "https://YOUR_ACCOUNT.blob.core.windows.net/recipes-input/users/$userId/$filename"

$eventPayload = @(
    @{
        id = [Guid]::NewGuid().ToString()
        subject = "/blobServices/default/containers/recipes-input/blobs/users/$userId/$filename"
        eventType = "Microsoft.Storage.BlobCreated"
        eventTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.0000000Z")
        data = @{
            api = "PutBlob"
            clientRequestId = [Guid]::NewGuid().ToString()
            requestId = [Guid]::NewGuid().ToString()
            eTag = "0x8D8..."
            contentType = "image/jpeg"
            contentLength = 524288
            blobType = "BlockBlob"
            url = $blobUrl
            sequencer = "00000000000004420000000000028963"
            storageDiagnostics = @{
                batchId = "b68529f3-68cd-4744-baa4-3c0498ec19f0"
            }
        }
        dataVersion = ""
        metadataVersion = "1"
    }
)

$jsonEntry = $eventPayload | ConvertTo-Json -Depth 10
$headers = @{
    "aeg-event-type" = "Notification"
}

Write-Host "Sending event to local function..."
Invoke-RestMethod -Uri "http://localhost:7071/runtime/webhooks/EventGrid?functionName=generate_recipe_from_image" -Method Post -Body $jsonEntry -ContentType "application/json" -Headers $headers
