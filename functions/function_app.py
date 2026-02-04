import json
import logging
import hashlib
import urllib.parse
import azure.functions as func

from services.post_clean_service import flag_comment_as_unsafe, verify_post_comment_safety, verify_post_image_safety
from shared.config_utils import get_secret, build_sas_token, JSON_MIME
from shared.clients import get_cosmos_client
from services.notifications_service import (
    get_nh_platform,
    create_nh_install_payload,
    send_template_notification,
    send_signalr_refresh
)
from services.expiry_service import check_user_expiry
from services.recipe_service import (
    run_daily_recipe_logic,
    process_recipe_image_logic
)
from services.shopping_service import (
    analyze_receipt_document,
    save_shopping_scan_result,
    parse_label_url,
    analyze_product_label,
    update_shopping_item_details,
    delete_blob
)
import requests

ERROR_NO_URL_IN_EVENT = "No URL found in event data"

app = func.FunctionApp()

@app.timer_trigger(schedule="0 0 7 * * *", arg_name="timer", run_on_startup=False)
def daily_expiry_check(timer: func.TimerRequest) -> None:
    logging.info("Daily Expiry Check triggered")

    cosmos_client = get_cosmos_client()
    database = cosmos_client.get_database_client("mocc-db")
    users_container = database.get_container_client("Users")
    fridge_container = database.get_container_client("Inventory")

    try:
        users = list(users_container.query_items(
            query="SELECT c.id FROM c WHERE IS_DEFINED(c.id)",
            enable_cross_partition_query=True
        ))
        user_id_set = {u["id"] for u in users if u.get("id")}
        logging.info("Found %d unique users in Cosmos DB.", len(user_id_set))
    except Exception:
        logging.exception("Failed to query Users container.")
        return

    if not user_id_set:
        return

    for user_id in user_id_set:
        check_user_expiry(user_id, fridge_container)

@app.timer_trigger(schedule="0 0 1 * * *", arg_name="timer", run_on_startup=False)
def daily_recipe_generation(timer: func.TimerRequest) -> None:
    logging.info("Daily Recipe Generation triggered")

    try:
        run_daily_recipe_logic()
    except Exception:
         logging.exception("Error in daily recipe generation logic")

@app.event_grid_trigger(arg_name="event")
def generate_recipe_from_image(event: func.EventGridEvent):
    logging.info("GenerateRecipeFromImage triggered by Event Grid")
    
    data = event.get_json()
    url = data.get("url")
    if not url:
        logging.error(ERROR_NO_URL_IN_EVENT)
        return

    try:
        parsed_url = urllib.parse.urlparse(url)
        path_parts = parsed_url.path.split('/')
        
        if "recipes-input" not in path_parts or "users" not in path_parts:
            logging.warning(f"Ignored event for URL: {url} (pattern mismatch)")
            return

        users_index = path_parts.index("users")
        if len(path_parts) <= users_index + 2:
            logging.warning("URL structure invalid for extracting userId/filename")
            return
            
        user_id = path_parts[users_index + 1]
        blob_name = "/".join(path_parts[path_parts.index("recipes-input")+1:])
    except Exception:
        logging.error("Failed to parse URL")
        return

    logging.info(f"Processing image for user_id: {user_id}, blob: {blob_name}")

    process_recipe_image_logic(user_id, blob_name, parsed_url)

@app.route(route="register_device", auth_level=func.AuthLevel.ANONYMOUS, methods=["POST"])
def register_device(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("RegisterDevice triggered via APIM")
    
    try:
        req_body = req.get_json()
        variables = req_body.get("variables", {})
        
        handle = variables.get("handle") or req_body.get("handle")
        platform = variables.get("platform") or req_body.get("platform")
        
        user_id = req.headers.get("x-user-id")
        
        if not user_id:
             user_id = req_body.get("userId")

    except ValueError:
        return func.HttpResponse("Invalid JSON", status_code=400)

    if not user_id or not handle:
        logging.warning("Missing userId or handle")
        return func.HttpResponse("Missing userId or handle", status_code=400)

    nh_platform = get_nh_platform(platform)

    installation_id = req_body.get("installationId") or variables.get("installationId")
    if not installation_id:
        installation_id = hashlib.sha256(handle.encode('utf-8')).hexdigest()

    try:
        namespace = get_secret("notifHub-namespace")
        hub_name = get_secret("notifHub-name")
        sas_policy_name = get_secret("notifHub-sas-policy-name")
        sas_key_value = get_secret("notifHub-sas-primary")

        resource_uri = f"https://{namespace}.servicebus.windows.net/{hub_name}"
        sas_token = build_sas_token(resource_uri, sas_policy_name, sas_key_value, ttl_seconds=300)

        url = f"{resource_uri}/installations/{installation_id}?api-version=2023-10-01-preview"
        
        payload = create_nh_install_payload(installation_id, nh_platform, handle, user_id)

        headers = {
            "Authorization": sas_token,
            "Content-Type": JSON_MIME,
            "x-ms-version": "2023-10-01-preview"
        }

        logging.info(
            "Registering device with Notification Hub: platform=%s",
            nh_platform
        )
        resp = requests.put(url, headers=headers, json=payload, timeout=10)
        
        if resp.status_code not in (200, 201):
            logging.error("NH Registration failed with status code: %s", resp.status_code)
            return func.HttpResponse(f"Registration failed: {resp.text}", status_code=500)

        logging.info(f"Registered device for user {user_id} with ID {installation_id}")
        
        try:
           send_template_notification("MOCC ti aiuterà a realizzare i tuoi pasti", tag=f"userId:{user_id}")
        except Exception:
           logging.exception("Failed to send promo notification")

        return func.HttpResponse(
            json.dumps({"data": {"registerDevice": True}}),
            mimetype=JSON_MIME,
            status_code=200
        )

    except Exception:
        logging.exception("RegisterDevice exception")
        return func.HttpResponse(
            json.dumps({"errors": [{"message": "Internal server error"}]}),
            mimetype=JSON_MIME,
            status_code=500
        )

@app.route(route="negotiate", auth_level=func.AuthLevel.ANONYMOUS, methods=["POST"])
@app.generic_input_binding(
    arg_name="connectionInfo",
    type="signalRConnectionInfo",
    hubName="updates",
    connectionStringSetting="AzureSignalRConnectionString",
    userId="{headers.x-user-id}"
)
def generate_url(req: func.HttpRequest, connectionInfo: str) -> func.HttpResponse:
    logging.info("Negotiate triggered via APIM (Native Binding with Identity)")

    if not req.headers.get("x-user-id"):
        return func.HttpResponse("Unauthorized: Missing x-user-id header", status_code=401)

    return func.HttpResponse(
        body=connectionInfo,
        status_code=200,
        mimetype="application/json"
    )
    
@app.event_grid_trigger(arg_name="event")
def process_new_comment(event: func.EventGridEvent):
    logging.info("ProcessNewComment triggered")
    try:
        data = event.get_json()
        
        if data is None:
            logging.error("Event data is None")
            return

        post_id = data.get("postId")
        comment_text = data.get("commentText")
        comment_id = data.get("commentId")

        if not post_id or not comment_text:
            logging.warning("Missing required fields in event data")
            return
        
        if not verify_post_comment_safety(comment_text):
            logging.info("Comment flagged as unsafe, not processing further")
            flag_comment_as_unsafe(post_id, comment_id)
            
    except Exception:
        logging.exception("Failed to process new comment event")


@app.event_grid_trigger(arg_name="event")
def process_receipt_image(event: func.EventGridEvent):
    logging.info("ProcessReceiptImage triggered")

    data = event.get_json()
    url = data.get("url")
    if not url:
        logging.error("No URL found in event data")
        return

    try:
        parsed_url = urllib.parse.urlparse(url)
        path_parts = parsed_url.path.split('/')
        if "receipts" not in path_parts:
            logging.warning(f"Ignored: not a receipt path {url}")
            return

        idx = path_parts.index("receipts")
        if len(path_parts) <= idx + 2:
             logging.warning("Invalid path structure")
             return
        
        user_id = path_parts[idx + 1]
        
    except Exception:
        logging.error("Failed to parse URL")
        return

    logging.info(f"Processing receipt for user: {user_id}")

    try:
        items, store_name, total = analyze_receipt_document(url)
        if items is None:
            return
            
        save_shopping_scan_result(user_id, items, store_name, total, url)
        send_signalr_refresh(user_id)
        
    except Exception:
        logging.exception("Process receipt failed")

@app.event_grid_trigger(arg_name="event")
def process_product_label(event: func.EventGridEvent):
    logging.info("ProcessProductLabel triggered")

    data = event.get_json()
    url = data.get("url")
    if not url:
        logging.error("No URL found")
        return

    parsed = parse_label_url(url)
    if not parsed:
        return
    user_id, history_id, item_id, blob_name = parsed

    logging.info(f"Processing label: user={user_id}, history={history_id}, item={item_id}")

    try:
        data_map = analyze_product_label(url, blob_name)
        if data_map:
            update_shopping_item_details(history_id, item_id, user_id, data_map)
            send_signalr_refresh(user_id)
        
    except Exception:
        logging.exception("Process product label failed")
    finally:
        delete_blob("uploads", blob_name)



@app.event_grid_trigger(arg_name="event")
def filter_social_image(event: func.EventGridEvent):
    logging.info("FilterSocialImage triggered")
    data = event.get_json()
    url = data.get("url")
    if not url:
        logging.error(ERROR_NO_URL_IN_EVENT)
        return
    if not verify_post_image_safety(image_url=url):
        logging.info("Image flagged as unsafe, deleted from storage")