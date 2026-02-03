import os
import urllib.parse
import hmac
import hashlib
import base64
import time
from typing import Dict, Optional
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

_credential: Optional[DefaultAzureCredential] = None
_kv_client: Optional[SecretClient] = None
_secret_cache: Dict[str, str] = {}

JSON_MIME = "application/json"
DEV_STORAGE_CONN_STR = "UseDevelopmentStorage=true"

def get_credential() -> DefaultAzureCredential:
    global _credential
    if _credential is None:
        _credential = DefaultAzureCredential(exclude_shared_token_cache_credential=True)
    return _credential

def get_kv_client() -> SecretClient:
    global _kv_client
    if _kv_client is None:
        kv_url = os.environ["KEY_VAULT_URL"].rstrip("/")
        _kv_client = SecretClient(vault_url=kv_url, credential=get_credential())
    return _kv_client

def get_secret(secret_name: str) -> str:
    if secret_name in _secret_cache:
        return _secret_cache[secret_name]

    val = get_kv_client().get_secret(secret_name).value
    if not val:
        raise ValueError(f"Key Vault secret '{secret_name}' is empty or missing.")
    _secret_cache[secret_name] = val
    return val

def build_sas_token(resource_uri: str, key_name: str, key_value: str, ttl_seconds: int = 300) -> str:
    expiry = str(int(time.time() + ttl_seconds))
    encoded_uri = urllib.parse.quote(resource_uri.lower(), safe="")

    to_sign = (encoded_uri + "\n" + expiry).encode("utf-8")
    sig = hmac.new(key_value.encode("utf-8"), to_sign, hashlib.sha256).digest()
    encoded_signature = urllib.parse.quote(base64.b64encode(sig), safe="")

    return f"SharedAccessSignature sr={encoded_uri}&sig={encoded_signature}&se={expiry}&skn={key_name}"
