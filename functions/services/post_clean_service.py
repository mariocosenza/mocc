
import base64
import logging
import os
from shared.clients import get_blob_service_client, get_cosmos_client
from shared.config_utils import get_credential
from azure.ai.contentsafety.models import AnalyzeTextOptions, TextCategory, AnalyzeImageOptions, ImageData, ImageCategory
from azure.ai.contentsafety import ContentSafetyClient

from urllib.parse import urlparse, unquote

def parse_blob_url_social(image_url: str, expected_container: str | None = None) -> tuple[str, str, str]:
    u = urlparse(image_url)
    if not u.scheme or not u.netloc:
        raise ValueError("Invalid image_url (missing scheme/host)")

    path = u.path.lstrip("/")
    parts = path.split("/", 1)
    if len(parts) < 2:
        raise ValueError(f"Invalid blob url path: {u.path}")

    container = parts[0]
    blob_name = unquote(parts[1])

    if expected_container and container != expected_container:
        raise ValueError(f"Unexpected container '{container}', expected '{expected_container}'")

    account_url = f"{u.scheme}://{u.netloc}"
    return account_url, container, blob_name


def verify_post_comment_safety(comment_text: str) -> bool:
    endpoint = os.environ["AZURE_OPENAI_ENDPOINT"]
    credential = get_credential()
    client = ContentSafetyClient(endpoint=endpoint, credential=credential)

    try:
        result = client.analyze_text(
            AnalyzeTextOptions(
                text=comment_text,
                categories=[
                    TextCategory.HATE,
                    TextCategory.SELF_HARM,
                    TextCategory.SEXUAL,
                    TextCategory.VIOLENCE,
                ],
            )
        )
    except Exception as e:
        logging.error("Content Safety analyze_text failed", exc_info=e)
        raise RuntimeError(f"Content Safety analyze_text failed: {e.message}") from e

    sev: dict[str, int] = {c.category: int(c.severity or 0) for c in result.categories_analysis}
    
    if any(severity >= 4 for severity in sev.values()):
        logging.warning(f"Comment flagged by Content Safety: {sev}")
        return False
    return True 

def verify_post_image_safety(image_url: str) -> bool:
    endpoint = os.environ["AZURE_OPENAI_ENDPOINT"]
    credential = get_credential()
    client = ContentSafetyClient(endpoint=endpoint, credential=credential)
    _, container_name, blob_name = parse_blob_url_social(image_url, expected_container="social")

    try:
        blob_svc = get_blob_service_client(url=image_url)
        blob_client = blob_svc.get_blob_client(container=container_name, blob=blob_name)
        data = blob_client.download_blob().readall()
        
        request = AnalyzeImageOptions(
            image=ImageData(content=data),
            categories=[
                ImageCategory.HATE,
                ImageCategory.SELF_HARM,
                ImageCategory.SEXUAL,
                ImageCategory.VIOLENCE,
            ]
        )
        result = client.analyze_image(request)
        
    except Exception as e:
        logging.error("Content Safety analyze_image failed", exc_info=e)
        raise RuntimeError(f"Content Safety analyze_image failed: {e}") from e

    sev: dict[str, int] = {c.category: int(c.severity or 0) for c in result.categories_analysis}
    
    if any(severity >= 4 for severity in sev.values()):
        logging.warning(f"Image flagged by Content Safety: {sev}")
        blob_client.delete_blob()
        return False
    return True

def flag_comment_as_unsafe(post_id: str, comment_id: str) -> None:
    logging.info(f"Flagging comment {comment_id} in post {post_id} as unsafe")
    try:
        cosmos_client = get_cosmos_client()
        database = cosmos_client.get_database_client("mocc-db")
        container = database.get_container_client("Social")
        
        item = container.read_item(item=post_id, partition_key="post")
        comments = item.get("comments", [])
        
        target_index = -1
        for i, comment in enumerate(comments):
            if comment.get("id") == comment_id:
                target_index = i
                break
        
        if target_index == -1:
            logging.warning(f"Comment {comment_id} not found in post {post_id}")
            return

        container.patch_item(
            item=post_id,
            partition_key="post",
            patch_operations=[
                {
                    "op": "set",
                    "path": f"/comments/{target_index}/removed",
                    "value": True
                },
                {
                    "op": "set",
                    "path": f"/comments/{target_index}/text",
                    "value": "Removed"
                }
            ]
        )
        logging.info("Comment flagged successfully via Patch")
        
    except Exception:
        logging.exception("Failed to flag comment as unsafe")
        raise
            


