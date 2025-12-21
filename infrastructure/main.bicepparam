using './main.bicep'

param location = 'italynorth'
param environment = 'dev'

param tags = {
  project: 'MOCC'
  env: 'dev'
}

param enableAppService = true
param enableFunctions = true
param enableRedis = true
param enableKeyVault = true
param enableStorage = true
param enableCosmos = false
param enableApim = true
param enableEventGrid = true
param enableNotificationHub = false
param enableAI = false

param storageAccountName = 'moccstorage'
param eventGridSystemTopicName = 'moccblobeventgrid'


param email = 'cosenzamario@proton.me'
