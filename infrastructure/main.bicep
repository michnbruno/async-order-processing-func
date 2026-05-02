// ============================================================================
// Order Processing Demo - Azure Functions + Storage Queues
// MVP approach: Start simple, show architectural decision-making
// ============================================================================

@description('Primary Azure region for all resources')
param location string = resourceGroup().location

@description('Environment name (e.g., dev, test, prod)')
param environmentName string = 'dev'

@description('Unique token for resource naming')
param resourceToken string = toLower(uniqueString(subscription().id, resourceGroup().id))

@description('Function app runtime (.NET 8 for this demo)')
param functionAppRuntime string = 'dotnet-isolated'

@description('Function app runtime version')
param functionAppRuntimeVersion string = '8.0'

// ============================================================================
// Variables
// ============================================================================

var appName = 'func-order-${environmentName}-${resourceToken}'
var storageName = 'st${replace(resourceToken, '-', '')}'  // Storage names can't have hyphens
var planName = 'plan-order-${environmentName}-${resourceToken}'
var appInsightsName = 'appi-order-${environmentName}-${resourceToken}'
var logWorkspaceName = 'log-order-${environmentName}-${resourceToken}'
var orderQueueName = 'orders-incoming'

// Role Definition IDs (built-in Azure roles)
var storageBlobDataContributorRole = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageQueueDataContributorRole = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
var storageTableDataContributorRole = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'

// ============================================================================
// Storage Account - Stores queues, blobs, tables
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'  // Locally redundant storage (cheapest for dev/test)
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'  // For demo purposes; lock this down for production
    }
  }

  // Queue Services
  resource queueServices 'queueServices' = {
    name: 'default'
    
    // Create the order processing queue
    resource orderQueue 'queues' = {
      name: orderQueueName
      properties: {
        metadata: {
          description: 'Incoming orders to be processed'
        }
      }
    }
  }

  // Blob Services (required for Functions deployment)
  resource blobServices 'blobServices' = {
    name: 'default'
  }
}

// ============================================================================
// Log Analytics Workspace - Required for Application Insights
// ============================================================================

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logWorkspaceName
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

// ============================================================================
// Application Insights - Monitoring and telemetry
// ============================================================================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================================================
// App Service Plan - Consumption Plan (Serverless)
// ============================================================================

resource hostingPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  sku: {
    name: 'Y1'  // Consumption plan (Dynamic)
    tier: 'Dynamic'
  }
  properties: {
    reserved: false  // false = Windows; true = Linux
  }
}

// ============================================================================
// Function App - The serverless compute
// ============================================================================

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: appName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'  // Using system-assigned for simplicity
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(appName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionAppRuntime
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        // Custom app settings for our order processing
        {
          name: 'OrderQueueName'
          value: orderQueueName
        }
        {
          name: 'StorageAccountName'
          value: storageAccount.name
        }
      ]
    }
  }
}

// ============================================================================
// Role Assignments - Grant Function App access to Storage
// ============================================================================

// Storage Queue Data Contributor - Can read, write, and delete queue messages
resource queueRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionApp.id, storageAccount.id, storageQueueDataContributorRole)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataContributorRole)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Contributor - For deployment packages
resource blobRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionApp.id, storageAccount.id, storageBlobDataContributorRole)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRole)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// Outputs - Information needed for deployment and access
// ============================================================================

output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output storageAccountName string = storageAccount.name
output orderQueueName string = orderQueueName
output resourceGroupName string = resourceGroup().name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

// ============================================================================
// WHAT'S NEXT:
// 1. Deploy this Bicep file: az deployment group create --template-file main.bicep --resource-group <rg-name>
// 2. Create C# Function App project with Queue Trigger
// 3. Deploy function code to the Function App
// 4. Test by adding messages to the queue
// ============================================================================