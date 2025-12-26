# --- Configuration ---
RESOURCE_GROUP="moccgroup"
APIM_NAME="moccapim"
API_ID="mocc-graphql-api"
POLICY_FILE_PATH="../modules/integration/policy.xml"

# --- Dynamic Values ---
# 1. Get Tenant ID automatically from the logged-in Azure account
echo "Fetching Tenant ID from current Azure session..."
TENANT_ID=$(az account show --query tenantId -o tsv)

if [ -z "$TENANT_ID" ]; then
    echo "Error: Could not fetch Tenant ID. Please run 'az login' first."
    exit 1
fi
echo "Using Tenant ID: $TENANT_ID"

# 2. Hardcoded or Retrieved variables
# Adjust these if you need to fetch them dynamically as well
AUDIENCE="api://mocc-graphql-api"  # Example: usually the App ID URI
REQUIRED_SCOPE="access_as_user"
BACKEND_NAME="moccbackend"

echo "-------------------------------------"
echo "Step 1: Reading Policy Template"
echo "-------------------------------------"

if [ ! -f "$POLICY_FILE_PATH" ]; then
    echo "Error: Policy file not found at $POLICY_FILE_PATH"
    exit 1
fi

POLICY_CONTENT=$(cat "$POLICY_FILE_PATH")

echo "-------------------------------------"
echo "Step 2: Replacing Tokens"
echo "-------------------------------------"

# Replace tokens
POLICY_CONTENT=${POLICY_CONTENT//__TENANT_ID__/$TENANT_ID}
POLICY_CONTENT=${POLICY_CONTENT//__EXPECTED_AUDIENCE__/$AUDIENCE}
POLICY_CONTENT=${POLICY_CONTENT//__REQUIRED_SCOPE__/$REQUIRED_SCOPE}
POLICY_CONTENT=${POLICY_CONTENT//__BACKEND_NAME__/$BACKEND_NAME}

echo "Policy prepared."

echo "-------------------------------------"
echo "Step 3: Uploading Policy to Azure"
echo "-------------------------------------"

az apim api policy update \
    --resource-group "$RESOURCE_GROUP" \
    --service-name "$APIM_NAME" \
    --api-id "$API_ID" \
    --value "$POLICY_CONTENT" \
    --format "xml"

echo "Policy successfully updated for Tenant: $TENANT_ID"