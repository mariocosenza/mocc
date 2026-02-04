<#
.SYNOPSIS
  Upload an Azure API Management API policy (API scope) using Az PowerShell.

.REQUIREMENTS
  - Modules: Az.Accounts, Az.ApiManagement
  - Permissions: ability to update APIM policies

.DESCRIPTION
  - Reads an APIM policy XML file
  - Replaces tokens:
      __TENANT_ID__
      __EXPECTED_AUDIENCE__
      __REQUIRED_SCOPE__
      __BACKEND_NAME__
  - Uploads policy at API scope via Set-AzApiManagementPolicy
  - Cleans up temp files
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ResourceGroupName = "moccgroup",

  [Parameter(Mandatory = $false)]
  [string]$ApimName = "moccapim",

  # IMPORTANT: ApiId must be the APIM API identifier (the name in the APIM resource path), not the display name
  [Parameter(Mandatory = $false)]
  [string]$ApiId = "mocc-api",

  [Parameter(Mandatory = $false)]
  [string]$PolicyFilePath = "$PSScriptRoot\..\modules\integration\policy.xml",

  [Parameter(Mandatory = $false)]
  [string]$RequiredScope = "access_as_user",

  [Parameter(Mandatory = $false)]
  [string]$SchemaFilePath = "$PSScriptRoot\..\..\backend\graph\schema.graphqls",

  [Parameter(Mandatory = $false)]
  [string]$BackendName = "moccbackend",

  # If not provided, defaults to: api://<ApiId>
  [Parameter(Mandatory = $false)]
  [string]$Audience = $null,

  # Optional: set subscription explicitly (recommended for automation)
  [Parameter(Mandatory = $false)]
  [string]$SubscriptionId = $null,

  [Parameter(Mandatory = $false)]
  [string]$BackendClientId = "0500bb06-dcf3-477a-8743-f2922d5b0d3e",

  [Parameter(Mandatory = $false)]
  [string]$FunctionAppName = "mocc-funcs-italynorth"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-RequiredModule {
  param([Parameter(Mandatory = $true)][string]$Name)
  if (-not (Get-Module -ListAvailable -Name $Name)) {
    throw "Required module '$Name' not found. Install it with: Install-Module $Name -Scope CurrentUser"
  }
}

function Get-AzLoginContext {
  param([string]$SubscriptionId)

  try { $ctx = Get-AzContext } catch { $ctx = $null }

  if (-not $ctx) {
    Connect-AzAccount | Out-Null
    $ctx = Get-AzContext
  }

  if ($SubscriptionId) {
    Set-AzContext -Subscription $SubscriptionId | Out-Null
    $ctx = Get-AzContext
  }

  if (-not $ctx -or -not $ctx.Tenant -or -not $ctx.Tenant.Id) {
    throw "Could not obtain Azure context (TenantId missing). Ensure Connect-AzAccount succeeded."
  }

  return $ctx
}

Write-Host "-------------------------------------"
Write-Host "Step 0: Validate inputs / prerequisites"
Write-Host "-------------------------------------"

$PolicyFilePath = Resolve-Path -Path $PolicyFilePath -ErrorAction Stop
Write-Host "Using Policy File: $PolicyFilePath"

if (-not (Test-Path -LiteralPath $PolicyFilePath)) {
  throw "Policy file not found: $PolicyFilePath"
}

$SchemaFilePath = Resolve-Path -Path $SchemaFilePath -ErrorAction Stop
Write-Host "Using Schema File: $SchemaFilePath"
if (-not (Test-Path -LiteralPath $SchemaFilePath)) {
  throw "Schema file not found: $SchemaFilePath"
}

Test-RequiredModule -Name "Az.Accounts"
Test-RequiredModule -Name "Az.ApiManagement"

Write-Host "-------------------------------------"
Write-Host "Step 1: Connect to Azure and get context"
Write-Host "-------------------------------------"

$ctx = Get-AzLoginContext -SubscriptionId $SubscriptionId
$tenantId = $ctx.Tenant.Id

if (-not $Audience) {
  $Audience = "api://mocc-backend-api"
}

Write-Host "Tenant ID:       $tenantId"
Write-Host "Subscription ID: $($ctx.Subscription.Id)"
Write-Host "Resource Group:  $ResourceGroupName"
Write-Host "APIM Name:       $ApimName"
Write-Host "API Id:          $ApiId"
Write-Host "Audience:        $Audience"
Write-Host "BackendClientId: $BackendClientId"
Write-Host "RequiredScope:   $RequiredScope"
Write-Host "BackendName:     $BackendName"

if ($FunctionAppName) {
  Write-Host "-------------------------------------"
  Write-Host "Step 1.5: Update APIM Function Key"
  Write-Host "-------------------------------------"
  
  Write-Host "Fetching host key for Function App: $FunctionAppName ..."
  
  $funcKey = $null
  # Try Azure CLI first
  try {
      $jsonRaw = az functionapp keys list --name $FunctionAppName --resource-group $ResourceGroupName --output json 2>$null
      if ($LASTEXITCODE -eq 0 -and $jsonRaw) {
          $json = $jsonRaw | ConvertFrom-Json
          $funcKey = $json.functionKeys.default
      }
  } catch {
      Write-Warning "Azure CLI extraction failed: $_"
  }

  if (-not $funcKey) {
      Write-Host "Azure CLI failed or returned empty. Trying Az PowerShell..."
      try {
          # Added explicit ApiVersion just in case
          $keys = Invoke-AzResourceAction -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Web/sites/host/default -ResourceName "$FunctionAppName/default" -Action listKeys -ApiVersion "2022-03-01" -Force
          $funcKey = $keys.functionKeys.default
      } catch {
          Write-Error "Failed to retrieve function keys via PowerShell. Error: $_"
      }
  }

  if ($funcKey) {
    Write-Host "Updating 'function-key' Named Value in APIM..."
    $apimCtx = New-AzApiManagementContext -ResourceGroupName $ResourceGroupName -ServiceName $ApimName
    # Use Set-AzApiManagementNamedValue if it exists, otherwise New
    # Actually, New-AzApiManagementNamedValue updates if it exists? No, it throws.
    # Set-AzApiManagementNamedValue updates.
    
    try {
      $nv = Get-AzApiManagementNamedValue -Context $apimCtx -NamedValueId "function-key" -ErrorAction SilentlyContinue
      if ($nv) {
        Set-AzApiManagementNamedValue -Context $apimCtx -NamedValueId "function-key" -Value $funcKey -Secret $true | Out-Null
        Write-Host "Named Value 'function-key' updated."
      } else {
        New-AzApiManagementNamedValue -Context $apimCtx -NamedValueId "function-key" -Name "function-key" -Value $funcKey -Secret $true | Out-Null
        Write-Host "Named Value 'function-key' created."
      }
    } catch {
      Write-Warning "Failed to update function-key: $_"
    }
  } else {
    Write-Warning "Could not retrieve default function key."
  }
}

Write-Host "-------------------------------------"
Write-Host "Step 2: Prepare policy (token replacement)"
Write-Host "-------------------------------------"

$tempPolicyPath = Join-Path -Path $env:TEMP -ChildPath ("apim_policy_upload_{0}.xml" -f ([Guid]::NewGuid().ToString("N")))

$policyRaw = Get-Content -LiteralPath $PolicyFilePath -Raw

# Replace tokens safely (no backtick method-chaining)
$replacements = @{
  "__TENANT_ID__"                   = $tenantId
  "__EXPECTED_AUDIENCE__"           = $Audience
  "__EXPECTED_AUDIENCE_CLIENT_ID__" = $BackendClientId
  "__REQUIRED_SCOPE__"              = $RequiredScope
  "__BACKEND_NAME__"                = $BackendName
}

$policyPrepared = $policyRaw
foreach ($token in $replacements.Keys) {
  $policyPrepared = $policyPrepared.Replace($token, [string]$replacements[$token])
}

# Write UTF-8 without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tempPolicyPath, $policyPrepared, $utf8NoBom)

Write-Host "Prepared policy written to: $tempPolicyPath"

Write-Host "-------------------------------------"
Write-Host "Step 3: Create Revision and Upload Assets"
Write-Host "-------------------------------------"

$apimCtx = New-AzApiManagementContext -ResourceGroupName $ResourceGroupName -ServiceName $ApimName

# 3a. Create New Revision
Write-Host "Creating new API Revision..."
$revDescription = "Revision created by script at $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$revId = "rev-$(Get-Date -Format 'yyyyMMddHHmm')"
$newRevision = New-AzApiManagementApiRevision -Context $apimCtx -ApiId $ApiId -ApiRevision $revId -ApiRevisionDescription $revDescription
$revisionApiId = $newRevision.ApiId
Write-Host "Created Revision: $revisionApiId"

# 3b. Update GraphQL Schema on Revision
Write-Host "Updating GraphQL Schema on $revisionApiId..."
$schemaContent = Get-Content -LiteralPath $SchemaFilePath -Raw
# Using New-AzApiManagementApiSchema to create the schema on the new revision
New-AzApiManagementApiSchema -Context $apimCtx -ApiId $revisionApiId -SchemaId "graphql" -SchemaDocumentContentType "application/vnd.ms-azure-apim.graphql.schema" -SchemaDocument $schemaContent | Out-Null
Write-Host "Schema updated."

# 3c. Update Policy on Revision
Write-Host "Uploading Policy to $revisionApiId..."
# Create/Update policy at API scope (using the revision ID)
Set-AzApiManagementPolicy -Context $apimCtx -ApiId $revisionApiId -PolicyFilePath $tempPolicyPath | Out-Null

Write-Host "Policy uploaded successfully."

Write-Host "-------------------------------------"
Write-Host "Step 4: Cleanup"
Write-Host "-------------------------------------"

Remove-Item -LiteralPath $tempPolicyPath -Force -ErrorAction SilentlyContinue
Write-Host "Done."
