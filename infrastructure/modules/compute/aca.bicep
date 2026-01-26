param location string
param webAppName string = 'mocc-aca'

@description('ACR name')
param acrName string = 'moccdockeregistry'

@description('Docker image repo:tag (without registry), e.g. mocc-backend:latest')
param imageRepoAndTag string = 'mocc-backend:latest'

@description('If true, deploys a public placeholder image (supports /health) so the app can be created before your private image exists.')
param usePlaceholderImage bool = true

@description('Public placeholder image that returns HTTP 200 on any path (including /health).')
param placeholderImage string = 'jmalloc/echo-server:latest'

@description('Container port exposed by the app')
param containerPort int = 8080

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

@description('vCPU cores for the container. Use string + json() to support decimals (e.g. 0.25, 0.5, 0.75).')
@allowed([
  '0.25'
  '0.5'
  '0.75'
  '1'
  '2'
])
param cpuCores string = '0.75'

@description('Memory for the container (e.g. 1Gi, 1.5Gi, 2Gi).')
param memory string = '1.5Gi'

@description('Redis URL (host:port)')
param redisUrl string

@description('Cosmos DB URL / Endpoint')
param cosmosUrl string

@description('Managed Identity Client ID (optional, used if system-assigned identity is not enough or for user-assigned)')
param managedIdentityClientId string

@description('Auth Authority URL (e.g. https://login.microsoftonline.com/common)')
#disable-next-line no-hardcoded-env-urls
param authAuthority string = 'https://login.microsoftonline.com/common'

@description('Expected Audience for JWT validation (e.g. api://mocc-backend-api)')
param expectedAudience string

@description('Required Scope for JWT validation')
param requiredScope string = 'access_as_user'

@description('Azure Storage Account Name')
param storageAccountName string = 'moccstorage'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: '${webAppName}-log'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: json('0.15')
    }
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

var acrLoginServer = acr.properties.loginServer
var mainImage = '${acrLoginServer}/${imageRepoAndTag}'
var selectedImage = usePlaceholderImage ? placeholderImage : mainImage

var acrPullRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

resource caEnv 'Microsoft.App/managedEnvironments@2025-07-01' = {
  name: '${webAppName}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource app 'Microsoft.App/containerApps@2025-07-01' = {
  name: webAppName
  location: location
  identity: {
    type: 'SystemAssigned' 
  }
  properties: {
    managedEnvironmentId: caEnv.id

    configuration: {
      activeRevisionsMode: 'Single'

      ingress: {
        external: true
        targetPort: containerPort
        transport: 'auto'
        allowInsecure: false

        ipSecurityRestrictions: [
          for (cidr, i) in allowedSourceCidrs: {
            name: 'Allow-Source-${i + 1}'
            description: 'Rule ${i + 1}: Allow inbound from ${cidr}'
            action: 'Allow'
            ipAddressRange: cidr
          }
        ]
      }

      registries: usePlaceholderImage ? [] : [
        {
          server: acrLoginServer
          identity: 'system'
        }
      ]
    }

    template: {
      containers: [
        {
          name: webAppName
          image: selectedImage
          resources: {
            cpu: json(cpuCores)
            memory: memory
          }
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/health'
                port: containerPort
              }
              initialDelaySeconds: 5
              periodSeconds: 5
              failureThreshold: 24
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: containerPort
              }
              initialDelaySeconds: 15
              periodSeconds: 30
              failureThreshold: 3
            }
          ]
          env: [
            {
              name: 'RUNNING_ON_AZURE'
              value: 'true'
            }
            {
              name: 'AZURE_STORAGE_ACCOUNT_NAME'
              value: storageAccountName
            }
            {
              name: 'AZURE_STORAGE_CONTAINER_SOCIAL'
              value: 'social'
            }
            {
              name: 'REDIS_URL'
              value: redisUrl
            }
            {
              name: 'COSMOS_URL'
              value: cosmosUrl
            }
            {
              name: 'MANAGED_IDENTITY_CLIENT_ID'
              value: managedIdentityClientId
            }
            {
              name: 'AUTH_AUTHORITY'
              value: authAuthority
            }
            {
              name: 'EXPECTED_AUDIENCE'
              value: expectedAudience
            }
            {
              name: 'REQUIRED_SCOPE'
              value: requiredScope
            }
            {
              name: 'PORT'
              value: '${containerPort}'
            }
          ]
        }
      ]

      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, app.id, acrPullRoleDefinitionId)
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output appName string = app.name
output appUrl string = 'https://${app.properties.configuration.ingress.fqdn}'
output appPrincipalId string = app.identity.principalId
output acrLoginServer string = acrLoginServer
output image string = selectedImage
