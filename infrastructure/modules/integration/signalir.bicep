param location string = 'italynorth'
param name string = 'moccsignalr'
param serviceMode string = 'Serverless'
param skuName string = 'Free_F1'
param tier string = 'Free'
param capacity int = 1


resource signalIR 'Microsoft.SignalRService/SignalR@2024-10-01-preview' = {
  name: name
  location: location
  sku: {
    name: skuName
    tier: tier
    capacity: capacity
  }
  properties: {
    features: [
      {
        flag: 'ServiceMode'
        value: serviceMode
      }
      {
        flag: 'EnableConnectivityLogs'
        value: 'true'
      }
    ]
    cors: {
      allowedOrigins: [
        '*'
      ]
    }
    tls: {
      clientCertEnabled: false
    }
  }

}


output signalIRName string = signalIR.name
output signalIRHostName string = signalIR.properties.hostName
output signalIRID string = signalIR.id
