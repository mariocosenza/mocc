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
  '4.232.28.0/28'
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
            description: 'Allow inbound from ${cidr}'
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
