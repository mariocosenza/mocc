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
  [string]$PolicyFilePath = "..\modules\integration\policy.xml",

  [Parameter(Mandatory = $false)]
  [string]$RequiredScope = "access_as_user",

  [Parameter(Mandatory = $false)]
  [string]$BackendName = "moccbackend",

  # If not provided, defaults to: api://<ApiId>
  [Parameter(Mandatory = $false)]
  [string]$Audience = $null,

  # Optional: set subscription explicitly (recommended for automation)
  [Parameter(Mandatory = $false)]
  [string]$SubscriptionId = $null
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

if (-not (Test-Path -LiteralPath $PolicyFilePath)) {
  throw "Policy file not found: $PolicyFilePath"
}

Test-RequiredModule -Name "Az.Accounts"
Test-RequiredModule -Name "Az.ApiManagement"

Write-Host "-------------------------------------"
Write-Host "Step 1: Connect to Azure and get context"
Write-Host "-------------------------------------"

$ctx = Get-AzLoginContext -SubscriptionId $SubscriptionId
$tenantId = $ctx.Tenant.Id

if (-not $Audience) {
  $Audience = "api://$ApiId"
}

Write-Host "Tenant ID:       $tenantId"
Write-Host "Subscription ID: $($ctx.Subscription.Id)"
Write-Host "Resource Group:  $ResourceGroupName"
Write-Host "APIM Name:       $ApimName"
Write-Host "API Id:          $ApiId"
Write-Host "Audience:        $Audience"
Write-Host "RequiredScope:   $RequiredScope"
Write-Host "BackendName:     $BackendName"

Write-Host "-------------------------------------"
Write-Host "Step 2: Prepare policy (token replacement)"
Write-Host "-------------------------------------"

$tempPolicyPath = Join-Path -Path $env:TEMP -ChildPath ("apim_policy_upload_{0}.xml" -f ([Guid]::NewGuid().ToString("N")))

$policyRaw = Get-Content -LiteralPath $PolicyFilePath -Raw

# Replace tokens safely (no backtick method-chaining)
$replacements = @{
  "__TENANT_ID__"         = $tenantId
  "__EXPECTED_AUDIENCE__" = $Audience
  "__REQUIRED_SCOPE__"    = $RequiredScope
  "__BACKEND_NAME__"      = $BackendName
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
Write-Host "Step 3: Upload policy to APIM (API scope)"
Write-Host "-------------------------------------"

$apimCtx = New-AzApiManagementContext -ResourceGroupName $ResourceGroupName -ServiceName $ApimName

# Create/Update policy at API scope
Set-AzApiManagementPolicy -Context $apimCtx -ApiId $ApiId -PolicyFilePath $tempPolicyPath | Out-Null

Write-Host "Policy uploaded successfully."

Write-Host "-------------------------------------"
Write-Host "Step 4: Cleanup"
Write-Host "-------------------------------------"

Remove-Item -LiteralPath $tempPolicyPath -Force -ErrorAction SilentlyContinue
Write-Host "Done."
