
import logging
import os
from shared.clients import get_cosmos_client
from shared.config_utils import get_credential
from azure.ai.contentsafety.models import AnalyzeTextOptions, TextCategory
from azure.ai.contentsafety import ContentSafetyClient


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
            


