param location string
param webAppName string = 'mocc-aca'

@description('ACR name')
param acrName string = 'moccdockeregistry'

@description('Docker image repo:tag (without registry), e.g. mocc-backend:latest')
param imageRepoAndTag string = 'mocc-backend:latest'

@description('If true, deploys a public placeholder image (supports /health) so the app can be created before your private image exists.')
param usePlaceholderImage bool = true

@description('Public placeholder image that returns HTTP 200 on any path (including /health).')
param placeholderImage string = 'phpdockerio/health-check-mock:latest'

@description('Container port exposed by the app')
param containerPort int = 80

@description('Allowlist of CIDRs that can access the Container App ingress.')
param allowedSourceCidrs array = [
  '4.232.48.104/30'
  '4.232.106.88/30'
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

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
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
              failureThreshold: 3
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: containerPort
              }
              initialDelaySeconds: 10
              periodSeconds: 30
              failureThreshold: 3
            }
          ]
          env: [
            {
              name: 'RUNNING_ON_AZURE'
              value: 'true'
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
