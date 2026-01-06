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

param storageAccountName = 'moccstorage'
param eventGridSystemTopicName = 'moccblobeventgrid'


param email = 'cosenzamario@proton.me'
