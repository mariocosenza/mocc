using 'budget.bicep'


param budgetName = 'moccsubscriptionbudget'
param amount = 50
param timeGrain = 'Monthly'


param startDate = '2026-01-01'
param endDate = '2030-12-31'

param contactEmails = [
  'cosenzamario@proton.me'
  'm.cosenza11@studenti.unisa.it'
]

param contactRoles = [
  'Owner'
  'Contributor'
]

param resourceGroupFilterValues = [] 
param meterCategoryFilterValues = []

param firstThreshold = 30
param secondThreshold = 40
