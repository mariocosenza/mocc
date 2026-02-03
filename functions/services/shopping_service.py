import os
import urllib.parse
import logging
import base64
import json
import uuid
import azure.core.exceptions
from typing import Dict, List, Optional, Tuple
from datetime import datetime, timezone
from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.ai.documentintelligence.models import AnalyzeResult
from azure.storage.blob import BlobServiceClient
from shared.config_utils import get_credential, DEV_STORAGE_CONN_STR
from shared.clients import get_cosmos_client, get_azure_openai_client, get_blob_service_client

def analyze_receipt_document(url: str):
    try:
        doc_client = _get_doc_client()
        if not doc_client:
            return None, None, None

        b64 = _download_blob_as_base64(url)
        poller = doc_client.begin_analyze_document("prebuilt-receipt", body={"base64Source": b64})
        result: AnalyzeResult = poller.result()
        
        logging.info(f"Document Intelligence completed: {poller.status()}")
        
        return _extract_receipt_data(result)

    except Exception:
        logging.exception("Document Intelligence analysis failed")
        return None, None, None

def _get_doc_client():
    doc_endpoint = os.getenv("DOCUMENT_INTELLIGENCE_ENDPOINT") or os.getenv("AZURE_OPENAI_ENDPOINT")
    
    if not doc_endpoint:
        logging.error("Missing DOCUMENT_INTELLIGENCE_ENDPOINT")
        return None

    # Prefer Managed Identity (RBAC) via get_credential()
    return DocumentIntelligenceClient(endpoint=doc_endpoint, credential=get_credential())

def _download_blob_as_base64(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    path_parts = [p for p in parsed.path.split('/') if p]
    
    if "127.0.0.1" in url or "localhost" in url or "devstoreaccount1" in url:
        blob_svc = BlobServiceClient.from_connection_string(DEV_STORAGE_CONN_STR)
        container = path_parts[1]
        blob_name = "/".join(path_parts[2:])
    else:
        storage_account = os.getenv("STORAGE_ACCOUNT_NAME") or "moccstorage"
        blob_svc = BlobServiceClient(
            account_url=f"https://{storage_account}.blob.core.windows.net",
            credential=get_credential()
        )
        container = path_parts[0]
        blob_name = "/".join(path_parts[1:])
    
    blob_client = blob_svc.get_blob_client(container=container, blob=blob_name)
    data = blob_client.download_blob().readall()
    return base64.b64encode(data).decode('utf-8')

def _extract_receipt_data(result: AnalyzeResult):
    store_name = "Unknown Store"
    total = 0.0
    items = []

    if not result.documents:
        logging.warning("No documents found in analysis result")
        return items, store_name, total

    doc = result.documents[0]
    if "MerchantName" in doc.fields:
        store_name = doc.fields["MerchantName"].value_string
    if "Total" in doc.fields:
        total = _get_financial_value(doc.fields["Total"])
    
    if "Items" in doc.fields:
        for item_field in doc.fields["Items"].value_array:
            items.append(_parse_receipt_item(item_field.value_object))

    return items, store_name, total

def _get_financial_value(field):
    if field.value_currency:
        return field.value_currency.amount
    return field.value_number if field.value_number else 0.0

def _parse_receipt_item(item_obj):
    name = "Unknown Item"
    price = 0.0
    qty = 1
    
    if "Description" in item_obj:
        name = item_obj["Description"].value_string
    if "TotalPrice" in item_obj:
        price = _get_financial_value(item_obj["TotalPrice"])
    if "Quantity" in item_obj:
        f = item_obj["Quantity"]
        qty = int(f.value_number if f.value_number else 1)
        
    return {
        "id": str(uuid.uuid4()),
        "name": name,
        "price": price,
        "quantity": float(qty),
        "unit": "PZ",
        "confidence": 0.9,
        "category": None,
        "brand": None,
        "expiryDate": None,
        "expiryType": "BEST_BEFORE"
    }

def save_shopping_scan_result(user_id: str, items: List[Dict], store_name: str, total: float, url: str):
    calculated_total = sum((i.get("price") or 0) * (i.get("quantity") or 1) for i in items)
    if total == 0 and calculated_total > 0:
        total = calculated_total

    try:
        cosmos_client = get_cosmos_client()
        database = cosmos_client.get_database_client("mocc-db")
        container = database.get_container_client("History") 
        
        history_id = str(uuid.uuid4())
        entry = {
            "id": history_id,
            "authorId": user_id,
            "date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "storeName": store_name,
            "totalAmount": total,
            "currency": "EUR",
            "isImported": False,
            "itemsSnapshot": items,
            "receiptImageUrl": url,
            "status": "IN_STAGING"
        }
        
        container.upsert_item(entry)
        logging.info(f"Created ShoppingHistory {history_id} (Staging) for user {user_id}")
        
    except Exception:
        logging.exception("Failed to save ShoppingHistory scan result")

def parse_label_url(url: str):
    try:
        parsed_url = urllib.parse.urlparse(url)
        path_parts = parsed_url.path.split('/')
        if "product-labels" not in path_parts:
            logging.warning(f"Ignored: not a product-label path {url}")
            return None

        return _extract_label_info(path_parts, url)
    except Exception:
        logging.error(f"Failed to parse URL: {url}")
        return None

def _extract_label_info(path_parts, url):
    idx = path_parts.index("product-labels")
    if len(path_parts) <= idx + 3:
            logging.warning(f"Invalid path structure: {url}")
            return None
    
    user_id = path_parts[idx + 1]
    history_id = path_parts[idx + 2]
    item_id = path_parts[idx + 3]
    blob_name = "/".join(path_parts[idx:])
    
    return user_id, history_id, item_id, blob_name

def analyze_product_label(url: str, blob_name: str) -> Optional[Dict]:
    try:
        blob_svc = get_blob_service_client(url)
        container = "uploads"
        blob_client = blob_svc.get_blob_client(container=container, blob=blob_name)
        
        data = blob_client.download_blob().readall()
        b64 = base64.b64encode(data).decode('utf-8')

        openai_client = get_azure_openai_client()
        deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4o-mini")

        prompt = (
            "Analizza questa etichetta di prodotto. Estrai: "
            "1. Nome prodotto (es. 'Pasta di Grano Duro') "
            "2. Marca (es. 'Barilla') "
            "3. Quantità totale (es. 500g, 1L). Se incerto, stima o lascia vuoto. "
            "Restituisci JSON: { \"name\": \"...\", \"brand\": \"...\", \"quantity\": \"500g\", \"category\": \"...\" }"
        )

        response = openai_client.chat.completions.create(
            model=deployment,
            messages=[
                {"role": "system", "content": "Sei un assistente per l'inventario."},
                {"role": "user", "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}}
                ]}
            ],
            max_tokens=300,
            temperature=0.3,
        )

        content = response.choices[0].message.content.strip()
        if content.startswith("```json"): content = content[7:]
        if content.startswith("```"): content = content[3:]
        if content.endswith("```"): content = content[:-3]
        
        result = json.loads(content.strip())
        return result

    except azure.core.exceptions.ResourceNotFoundError:
        logging.error(f"Blob not found for analysis: {blob_name}.")
        return None
    except Exception:
        logging.exception("Label analysis failed")
        return None

def update_shopping_item_details(history_id: str, item_id: str, user_id: str, data: Dict):
    try:
        cosmos_client = get_cosmos_client()
        database = cosmos_client.get_database_client("mocc-db")
        container = database.get_container_client("History")

        entry = container.read_item(item=history_id, partition_key=user_id)
        items = entry.get("itemsSnapshot", [])
        
        updated = False
        for i in items:
            if i.get("id") == item_id:
                if data.get("name"): 
                    name_part = data["name"]
                    brand_part = data.get("brand", "")
                    qty_part = data.get("quantity", "")
                    
                    parts = [brand_part, name_part, qty_part]
                    full_name = " ".join([p for p in parts if p]).strip()
                    
                    if full_name:
                        i["name"] = full_name
                        
                    if data.get("brand"):
                        i["brand"] = data["brand"]
                    if data.get("category"):
                        i["category"] = data["category"]
                        
                i["confidence"] = 0.95
                updated = True
                break
        
        if updated:
            entry["itemsSnapshot"] = items
            container.upsert_item(entry)
            logging.info(f"Updated ShoppingItem {item_id} in History {history_id}")

    except Exception:
        logging.exception("Failed to update shopping history in Cosmos")

def delete_blob(container_name, blob_name):
    try:
        credential = get_credential()
        account_name = os.getenv("STORAGE_ACCOUNT_NAME") or "moccstorage"
        blob_svc = BlobServiceClient(account_url=f"https://{account_name}.blob.core.windows.net", credential=credential)
             
        container = blob_svc.get_container_client(container_name)
        container.delete_blob(blob_name)
        logging.info(f"Deleted blob {blob_name}")
    except azure.core.exceptions.ResourceNotFoundError:
        logging.warning(f"Blob {blob_name} not found during deletion (already deleted?)")
    except Exception:
        logging.exception("Failed to delete blob")
