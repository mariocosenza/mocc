import os
import logging
import requests
import json
from typing import Dict
from shared.config_utils import get_credential, get_secret, build_sas_token, JSON_MIME

def send_signalr_refresh(user_id: str) -> None:
    hub_name = os.getenv("SIGNALR_HUB", "updates")
    endpoint = os.getenv("SIGNALR_ENDPOINT", "https://moccsignalr.service.signalr.net").rstrip("/")
    
    url = f"{endpoint}/api/v1/hubs/{hub_name}/users/{user_id}"
    
    try:
        credential = get_credential()
        token = credential.get_token("https://signalr.azure.com/.default").token
        
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": JSON_MIME
        }
        
        payload = {
            "target": "newRecipe", 
            "arguments": [{"type": "refresh", "message": "Nuovi dati disponibili"}]
        }
        
        resp = requests.post(url, headers=headers, json=payload, timeout=5)
        
        if resp.status_code not in (200, 202):
            logging.error(f"SignalR send failed: {resp.status_code} {resp.text}")
        else:
            logging.info(f"Sent SignalR refresh to user {user_id}")
            
    except Exception:
        logging.exception(f"Failed to send SignalR refresh to user {user_id}")

def send_template_notification(message: str, tag: str = None) -> None:
    try:
        namespace = get_secret("notifHub-namespace")
        hub_name = get_secret("notifHub-name")
        sas_policy_name = get_secret("notifHub-sas-policy-name")
        sas_key_value = get_secret("notifHub-sas-primary")

        resource_uri = f"https://{namespace}.servicebus.windows.net/{hub_name}"
        sas = build_sas_token(resource_uri, sas_policy_name, sas_key_value, ttl_seconds=300)

        url = f"{resource_uri}/messages/?api-version=2015-01"
        headers = {
            "Authorization": sas,
            "Content-Type": f"{JSON_MIME};charset=utf-8",
            "ServiceBusNotification-Format": "template",
        }
        
        if tag:
            headers["ServiceBusNotification-Tags"] = tag

        payload = {"message": message}

        logging.info(f"Sending notification: tag={tag}")
        resp = requests.post(url, headers=headers, json=payload, timeout=10)
        
        if resp.status_code not in (200, 201):
            raise RuntimeError(f"Notification Hubs send failed: {resp.status_code} {resp.text}")
    except Exception:
        logging.exception("Failed to send template notification")
        # Don't re-raise, as this is usually best-effort

def get_nh_platform(platform: str) -> str:
    if not platform:
        return "fcmV1"
    platform_lower = platform.lower()
    if platform_lower in ["android", "fcm", "gcm", "fcmv1"]:
        return "fcmV1"
    elif platform_lower in ["ios", "apns"]:
        return "apns"
    return platform

def create_nh_install_payload(installation_id: str, nh_platform: str, handle: str, user_id: str) -> Dict:
    if nh_platform == "fcmV1":
        template_body = json.dumps({
            "message": {
                "notification": {
                    "title": "MOCC",
                    "body": "$(message)"
                }
            }
        })
    else:
        template_body = json.dumps({
            "aps": {
                "alert": {
                    "title": "MOCC",
                    "body": "$(message)"
                }
            }
        })

    return {
        "installationId": installation_id,
        "platform": nh_platform,
        "pushChannel": handle,
        "tags": [f"userId:{user_id}"],
        "templates": {
            "genericTemplate": {
                "body": template_body
            }
        }
    }
