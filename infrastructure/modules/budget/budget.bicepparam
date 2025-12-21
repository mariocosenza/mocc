using 'budget.bicep'


param budgetName = 'moccsubscriptionbudget'
param amount = 100
param timeGrain = 'Monthly'


param startDate = '2026-01-01'
param endDate = '2030-12-31'

param contactEmails = [
  'your-email@example.com'
  'admin@example.com'
]

param contactRoles = [
  'Owner'
  'Contributor'
]

param resourceGroupFilterValues = [] 
param meterCategoryFilterValues = []

param firstThreshold = 50
param secondThreshold = 80
