# Azure Setup Script for Django Todo App
# Run this in PowerShell with Azure CLI installed

# ============================================
# CONFIGURATION - UPDATE THESE VALUES
# ============================================

$resourceGroup = "django-todo-rg"
$location = "eastus"
$registryName = "todoregistry$(Get-Random -Maximum 10000)"  # Must be unique
$appServicePlan = "django-todo-plan"
$appName = "django-todo-app-$(Get-Random -Maximum 10000)"  # Must be unique
$servicePrincipalName = "django-todo-cicd"

# ============================================
# STEP 1: Create Resource Group
# ============================================

Write-Host "Creating Resource Group: $resourceGroup" -ForegroundColor Green
az group create `
  --name $resourceGroup `
  --location $location

# ============================================
# STEP 2: Create Container Registry
# ============================================

Write-Host "Creating Container Registry: $registryName" -ForegroundColor Green
$acrResponse = az acr create `
  --resource-group $resourceGroup `
  --name $registryName `
  --sku Basic | ConvertFrom-Json

$loginServer = $acrResponse.loginServer
Write-Host "Container Registry created: $loginServer" -ForegroundColor Cyan

# ============================================
# STEP 3: Create App Service Plan
# ============================================

Write-Host "Creating App Service Plan: $appServicePlan" -ForegroundColor Green
az appservice plan create `
  --name $appServicePlan `
  --resource-group $resourceGroup `
  --sku B1 `
  --is-linux

# ============================================
# STEP 4: Create App Service
# ============================================

Write-Host "Creating App Service: $appName" -ForegroundColor Green
$appResponse = az webapp create `
  --resource-group $resourceGroup `
  --plan $appServicePlan `
  --name $appName `
  --deployment-container-image-name-user $registryName `
  --docker-registry-server-url "https://$loginServer" | ConvertFrom-Json

$appUrl = $appResponse.defaultHostName
Write-Host "App Service created: $appUrl" -ForegroundColor Cyan

# ============================================
# STEP 5: Configure App Service → ACR Permissions
# ============================================

Write-Host "Configuring ACR permissions..." -ForegroundColor Green

# Assign managed identity to App Service
$identityResponse = az webapp identity assign `
  --resource-group $resourceGroup `
  --name $appName | ConvertFrom-Json

$principalId = $identityResponse.principalId

# Get ACR resource ID
$registryId = az acr show `
  --name $registryName `
  --query id `
  --output tsv

# Grant acrpull role
az role assignment create `
  --assignee $principalId `
  --role acrpull `
  --scope $registryId

Write-Host "ACR permissions configured" -ForegroundColor Cyan

# ============================================
# STEP 6: Set App Service Environment Variables
# ============================================

Write-Host "Setting App Service configuration..." -ForegroundColor Green
az webapp config appsettings set `
  --name $appName `
  --resource-group $resourceGroup `
  --settings `
    DOCKER_REGISTRY_SERVER_URL="https://$loginServer" `
    WEBSITES_ENABLE_APP_SERVICE_STORAGE=false `
    DOCKER_ENABLE_CI=true `
    DJANGO_SETTINGS_MODULE=todo.settings `
    ALLOWED_HOSTS="$appName.azurewebsites.net" `
    DEBUG=false `
    SECRET_KEY="$(New-Guid)"

Write-Host "Configuration applied" -ForegroundColor Cyan

# ============================================
# STEP 7: Create Service Principal for GitHub Actions
# ============================================

Write-Host "Creating Service Principal for CI/CD..." -ForegroundColor Green

$subscriptionId = az account show --query id --output tsv

$spResponse = az ad sp create-for-rbac `
  --name $servicePrincipalName `
  --role contributor `
  --scopes "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup" | ConvertFrom-Json

Write-Host "Service Principal created:" -ForegroundColor Cyan
Write-Host "appId: $($spResponse.appId)" -ForegroundColor Yellow
Write-Host "password: $($spResponse.password)" -ForegroundColor Yellow
Write-Host "tenant: $($spResponse.tenant)" -ForegroundColor Yellow

# ============================================
# STEP 8: Get Azure Publish Profile
# ============================================

Write-Host "Downloading Publish Profile..." -ForegroundColor Green
az webapp deployment list-publishing-profiles `
  --name $appName `
  --resource-group $resourceGroup `
  --output json | Out-File -FilePath "$PSScriptRoot\publish-profile.json"

Write-Host "Publish profile saved to publish-profile.json" -ForegroundColor Cyan

# ============================================
# SUMMARY
# ============================================

Write-Host "`n========== SETUP COMPLETE ==========" -ForegroundColor Green
Write-Host "`nAzure Resources Created:" -ForegroundColor Green
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Registry: $loginServer"
Write-Host "  App Service: https://$appUrl"
Write-Host "  App Name: $appName"

Write-Host "`nGitHub Secrets to Create:" -ForegroundColor Green
Write-Host "  REGISTRY_LOGIN_SERVER: $loginServer"
Write-Host "  REGISTRY_USERNAME: $registryName"
Write-Host "  REGISTRY_PASSWORD: (get from ACR access key)"
Write-Host "  AZURE_CREDENTIALS: (JSON from service principal)"
Write-Host "  AZURE_PUBLISH_PROFILE: (content of publish-profile.json)"
Write-Host "  RESOURCE_GROUP: $resourceGroup"
Write-Host "  APP_NAME: $appName"

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Copy service principal credentials to GitHub Secrets"
Write-Host "2. Get ACR login credentials:"
Write-Host "   az acr credential show --name $registryName"
Write-Host "3. Create .github/workflows/deploy.yml workflow file"
Write-Host "4. Push code to trigger CI/CD pipeline"

Write-Host "`nCleanup command (if needed):" -ForegroundColor Yellow
Write-Host "az group delete --name $resourceGroup --yes"
