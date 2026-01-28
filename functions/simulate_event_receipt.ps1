$functionUrl = "http://localhost:7071/runtime/webhooks/eventgrid?functionName=process_receipt_image"
$userId = "00"
$blobUrl = "http://127.0.0.1:10000/devstoreaccount1/uploads/receipts/$userId/scaled_receipt.jpeg"

$eventPayload = @(
    @{
        id              = [Guid]::NewGuid().ToString()
        subject         = "/blobServices/default/containers/uploads/blobs/receipts/$userId/receipt.jpg"
        data            = @{
            api                = "PutBlockList"
            clientRequestId    = [Guid]::NewGuid().ToString()
            requestId          = [Guid]::NewGuid().ToString()
            eTag               = "0x8D8"
            contentType        = "image/jpeg"
            contentLength      = 12345
            blobType           = "BlockBlob"
            url                = $blobUrl
            sequencer          = "00000000000004420000000000028963"
            storageDiagnostics = @{
                batchId = [Guid]::NewGuid().ToString()
            }
        }
        eventType       = "Microsoft.Storage.BlobCreated"
        eventTime       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.0000000Z")
        dataVersion     = ""
        metadataVersion = "1"
        topic           = "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Storage/storageAccounts/{storage-account}"
    }
)

$jsonPayload = $eventPayload | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri $functionUrl -Method Post -Body $jsonPayload -ContentType "application/json" -Headers @{ "aeg-event-type" = "Notification" }
Write-Host "Event sent to $functionUrl"
