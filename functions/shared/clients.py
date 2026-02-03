import os
import urllib.parse
from azure.cosmos import CosmosClient
from azure.identity import get_bearer_token_provider
from openai import AzureOpenAI
from azure.storage.blob import BlobServiceClient
from shared.config_utils import get_credential, DEV_STORAGE_CONN_STR

def get_cosmos_client() -> CosmosClient:
    endpoint = os.environ["COSMOS_URL"]
    key = os.getenv("COSMOS_KEY")
    if key:
        return CosmosClient(url=endpoint, credential=key)
    return CosmosClient(url=endpoint, credential=get_credential())

def get_azure_openai_client() -> AzureOpenAI:
    endpoint = os.environ["AZURE_OPENAI_ENDPOINT"].rstrip("/")
    token_provider = get_bearer_token_provider(
        get_credential(),
        "https://cognitiveservices.azure.com/.default",
    )
    return AzureOpenAI(
        azure_endpoint=endpoint,
        azure_ad_token_provider=token_provider,
        api_version="2024-06-01"
    )

def get_blob_service_client(url: str = None) -> BlobServiceClient:
    if url:
        parsed = urllib.parse.urlparse(url)
        if "127.0.0.1" in url or "localhost" in url or "devstoreaccount1" in url:
            return BlobServiceClient.from_connection_string(DEV_STORAGE_CONN_STR)
        return BlobServiceClient(account_url=f"{parsed.scheme}://{parsed.netloc}", credential=get_credential())
    
    # Fallback to default storage account if no URL provided (or general usage)
    account_name = os.getenv("STORAGE_ACCOUNT_NAME") or "moccstorage"
    return BlobServiceClient(account_url=f"https://{account_name}.blob.core.windows.net", credential=get_credential())
