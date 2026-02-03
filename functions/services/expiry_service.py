import time
import logging
from shared.clients import get_cosmos_client
from services.notifications_service import send_template_notification

def check_user_expiry(user_id: str, fridge_container):
    try:
        today_str = time.strftime("%Y-%m-%d")
        fridges = list(fridge_container.query_items(
            query="SELECT * FROM c WHERE c.id = @userId",
            parameters=[{"name": "@userId", "value": user_id}],
            enable_cross_partition_query=True,
        ))
        
        expired_items = []
        
        for fridge in fridges:
            items = fridge.get("items") or []
            for item in items:
                exp_date = item.get("expiryDate", "")
                if exp_date and exp_date.startswith(today_str):
                    expired_items.append(item.get("name", "Articolo"))
        
        if expired_items:
            msg = f"Attenzione! Hai {len(expired_items)} prodotti in scadenza oggi: {', '.join(expired_items[:3])}"
            if len(expired_items) > 3:
                msg += "..."
            send_template_notification(msg, tag=f"userId:{user_id}")
            logging.info(f"Sent expiry notification to {user_id}")
            
    except Exception:
        logging.exception(f"Failed to process expiry check for user {user_id}")
