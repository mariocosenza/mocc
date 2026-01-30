$functionName = "process_product_label"
$endpoint = "http://localhost:7071/runtime/webhooks/EventGrid?functionName=$functionName"

$eventPayload = @(
    @{
        id              = [Guid]::NewGuid().ToString()
        subject         = "/blobServices/default/containers/uploads/blobs/product-labels/label.jpg"
        data            = @{
            api                = "PutBlob"
            clientRequestId    = [Guid]::NewGuid().ToString()
            requestId          = [Guid]::NewGuid().ToString()
            eTag               = "0x8D8C0XXXXX"
            contentType        = "application/json"
            contentLength      = 524288
            blobType           = "BlockBlob"
            url                = "http://127.0.0.1:10000/devstoreaccount1/uploads/label.jpg"
            sequencer          = "00000000000004420000000000028963"
            storageDiagnostics = @{
                batchId = [Guid]::NewGuid().ToString()
            }
        }
        eventType       = "Microsoft.Storage.BlobCreated"
        dataVersion     = ""
        metadataVersion = "1"
        eventTime       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ")
        topic           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/moccgroup/providers/Microsoft.Storage/storageAccounts/moccstorage"
    }
)

$json = $eventPayload | ConvertTo-Json -Depth 10
Write-Host "Sending event to $endpoint"
Invoke-RestMethod -Uri $endpoint -Method Post -Body $json -ContentType "application/json" -Headers @{ "aeg-event-type" = "Notification" }
Write-Host "Event sent."
