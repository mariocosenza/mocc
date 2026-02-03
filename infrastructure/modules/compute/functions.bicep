param location string = 'westeurope'
param cosmosDbEndpoint string
param keyVaultUrl string
param openAiEndpoint string
param openAiDeployment string = 'gpt-4o-mini'
param mainStorageAccountName string = ''

@description('Allowlist of CIDRs that can access the Container App ingress.')
param allowedSourceCidrs array = [
  '4.232.0.0/17'
  '4.232.128.0/18'
  '4.232.192.0/21'
  '4.232.208.0/20'
  '4.232.224.0/19'
  '9.235.0.0/16'
  '13.105.105.144/28'
  '13.105.105.192/26'
  '13.105.107.64/27'
  '13.105.107.96/28'
  '13.105.107.128/27'
  '13.105.108.16/28'
  '13.105.108.64/26'
  '13.105.107.96/28'
  '20.20.35.0/24'
  '20.33.128.0/24'
  '20.33.221.0/24'
  '20.38.22.0/24'
  '20.95.104.0/24'
  '20.95.111.0/24'
  '20.95.123.0/24'
  '20.95.124.0/24'
  '20.143.14.0/23'
  '20.143.24.0/23'
  '20.152.8.0/23'
  '20.157.200.0/24'
  '20.157.237.0/24'
  '20.157.255.0/24'
  '20.209.80.0/23'
  '20.209.86.0/23'
  '20.209.120.0/23'
  '20.231.131.0/24'
  '40.64.147.248/29'
  '40.64.153.224/27'
  '40.64.189.128/25'
  '40.93.87.0/24'
  '40.93.88.0/24'
  '40.98.19.0/25'
  '40.101.113.0/25'
  '40.101.113.128/26'
  '40.107.163.0/24'
  '40.107.164.0/23'
  '40.120.132.0/23'
  '40.120.134.0/26'
  '40.120.134.64/28'
  '40.120.134.80/30'
  '48.212.19.0/24'
  '48.212.147.0/24'
  '48.213.19.0/24'
  '51.5.60.0/24'
  '52.101.103.0/24'
  '52.101.176.0/24'
  '52.102.185.0/24'
  '52.103.57.0/24'
  '52.103.185.0/24'
  '52.106.135.0/24'
  '52.106.189.0/24'
  '52.108.122.0/24'
  '52.108.145.0/24'
  '52.109.80.0/23'
  '52.111.193.0/24'
  '52.112.132.0/24'
  '52.123.37.0/24'
  '52.123.208.0/24'
  '52.253.216.0/23'
  '52.253.218.0/24'
  '57.150.36.0/23'
  '70.152.43.0/24'
  '72.146.0.0/16'
  '135.130.84.0/23'
  '145.190.69.0/24'
  '172.213.0.0/19'
  '172.213.64.0/18'
  '172.213.128.0/17'
]


var storageName = toLower(take('moccfnsa${uniqueString(resourceGroup().id)}', 24))
var planName = 'mocc-fn-plan'
var functionAppName = 'mocc-functions-${uniqueString(resourceGroup().id)}'
var linuxFxVersion = 'Python|3.12'


resource functionStorageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: storageName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource plan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: planName
  location: location
  kind: 'functionapp'
  sku: { name: 'Y1', tier: 'Dynamic' }
  properties: {
    reserved: true
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: '${functionAppName}-logs'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: json('0.10')
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${functionAppName}-ai'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    SamplingPercentage: 100
  }
}

var defaultRestrictions = [
  { name: 'Allow-EventGrid', priority: 100, action: 'Allow', ipAddress: 'AzureEventGrid', tag: 'ServiceTag' }
  { name: 'Allow-AzureCloud', priority: 102, action: 'Allow', ipAddress: 'AzureCloud', tag: 'ServiceTag' }
  { name: 'Allow-APIM-ItalyNorth', priority: 105, action: 'Allow', ipAddress: 'ApiManagement.ItalyNorth', tag: 'ServiceTag' }
  { name: 'Allow-APIM', priority: 110, action: 'Allow', ipAddress: 'ApiManagement', tag: 'ServiceTag' }
]

var cidrRestrictions = [for (cidr, i) in allowedSourceCidrs: {
  name: 'Allow-CIDR-${i}'
  priority: 300 + i
  action: 'Allow'
  ipAddress: cidr
  description: 'Allowed source CIDR'
}]

var denyAllRestriction = [
  { name: 'Deny-All', priority: 4096, action: 'Deny', ipAddress: '0.0.0.0/0' }
]

resource func 'Microsoft.Web/sites@2025-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      cors: {
        allowedOrigins: [
          '*'
        ]
      }
      linuxFxVersion: linuxFxVersion
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};AccountKey=${functionStorageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'python' }
        { name: 'COSMOS_URL', value: cosmosDbEndpoint }
        { name: 'AZURE_OPENAI_ENDPOINT', value: openAiEndpoint }
        { name: 'AZURE_OPENAI_DEPLOYMENT', value: openAiDeployment }
        { name: 'DOCUMENT_INTELLIGENCE_ENDPOINT', value: openAiEndpoint }
        { name: 'KEY_VAULT_URL', value: keyVaultUrl }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
        { name: 'STORAGE_ACCOUNT_NAME', value: mainStorageAccountName }
        { name: 'SIGNALR_ENDPOINT', value: 'https://moccsignalr.service.signalr.net/' }
        { name: 'SIGNALR_HUB', value: 'updates' }
        { name: 'AzureSignalRConnectionString__serviceUri', value: 'https://moccsignalr.service.signalr.net' }
        { name: 'AzureSignalRConnectionString__credential', value: 'managedidentity' }
        { name: 'EVENTGRID_TOPIC_ENDPOINT', value: 'https://moccpostcomments.italynorth-1.eventgrid.azure.net/api/events' }
      ]

      ipSecurityRestrictions: concat(defaultRestrictions, cidrRestrictions, denyAllRestriction)
    }
  }
}

output functionAppId string = func.id
output functionAppName string = func.name
output functionHost string = 'https://${func.properties.defaultHostName}'
output functionPrincipalId string = func.identity.principalId
output functionTenantId string = func.identity.tenantId
output functionStorageAccountName string = functionStorageAccount.name

#disable-next-line outputs-should-not-contain-secrets
output defaultFunctionKey string = listKeys('${func.id}/host/default', '2022-03-01').functionKeys.default

