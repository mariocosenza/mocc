using './main.bicep'

param firebaseServiceAccount = loadJsonContent('main.parameters.json')

param location = 'italynorth'
param environment = 'dev'

param tags = {
  project: 'MOCC'
  env: 'dev'
}

param enableAca = true
param enableFunctions = true
param enableRedis = true
param enableKeyVault = true
param enableStorage = true
param enableCosmos = true
param enableApim = true
param enableEventGrid = true
param enableNotificationHub = true
param enableAI = true
param enableSignalIR = true
param deployEventSubscription = true

param storageAccountName = 'moccstorage'
param eventGridSystemTopicName = 'moccblobeventgrid'
param backendClientId = readEnvironmentVariable('BACKEND_CLIENT_ID', '1abbe04a-3b9b-4a19-800c-cd8cbbe479f4')


param email = 'cosenzamario@proton.me'
