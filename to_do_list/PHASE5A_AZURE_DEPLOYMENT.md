# Phase 5A: Azure Manual Deployment - Complete Guide

**Date:** January 16, 2026  
**Status:** ✅ COMPLETE  
**Duration:** ~3 hours (including troubleshooting)  
**App URL:** https://django-todo-app-7470.azurewebsites.net

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Azure Login](#step-1-azure-login)
4. [Create Resource Group](#step-2-create-resource-group)
5. [Create Container Registry](#step-3-create-container-registry)
6. [Create App Service Plan](#step-4-create-app-service-plan)
7. [Create App Service](#step-5-create-app-service)
8. [Configure Permissions](#step-6-configure-permissions)
9. [Build and Push Image](#step-7-build-and-push-docker-image)
10. [Configure App Service](#step-8-configure-app-service-container)
11. [Troubleshooting Journey](#troubleshooting-journey-all-errors-encountered)
12. [Final Working Configuration](#final-working-configuration)
13. [What's Next - Part B](#whats-next---phase-5b-github-cicd)

---

## Overview

### What We're Building

```
Local Code (Windows)
    ↓ az acr build
Azure Container Registry (ACR)
    ↓ Stores Docker image
Azure App Service
    ↓ Pulls and runs container
Public Internet
    → https://django-todo-app-7470.azurewebsites.net
```

### Azure Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | django-todo-rg | Container for all resources |
| Container Registry | todoregistry166 | Stores Docker images |
| App Service Plan | django-todo-plan | Compute power (B1 tier) |
| App Service | django-todo-app-7470 | Runs the container |

---

## Prerequisites

### Install Azure CLI

```powershell
# Windows - Using Chocolatey
choco install azure-cli

# Or download installer from:
# https://aka.ms/installazurecliwindows

# Verify installation
az --version
# Output: azure-cli 2.x.x
```

---

## Step 1: Azure Login

```powershell
az login
```

### ❌ ERROR: Browser doesn't open or timeout

**Symptom:**
```
A web browser has been opened... Please authenticate...
[Timeout waiting for response]
```

**Solution - Use Device Code Flow:**
```powershell
az login --use-device-code
```

**Output:**
```
To sign in, use a web browser to open the page https://microsoft.com/devicelogin 
and enter the code XXXXXXXX to authenticate.
```

1. Open the URL in any browser
2. Enter the code shown
3. Login with your Microsoft/Azure account
4. Return to terminal - should show subscription info

### ✅ SUCCESS Output:
```json
[
  {
    "cloudName": "AzureCloud",
    "id": "a3e2aa81-6c58-42ff-a34d-39924ab8e0c1",
    "isDefault": true,
    "name": "Azure subscription 1",
    "state": "Enabled",
    "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  }
]
```

---

## Step 2: Create Resource Group

```powershell
az group create --name django-todo-rg --location eastus
```

### ✅ SUCCESS Output:
```json
{
  "id": "/subscriptions/.../resourceGroups/django-todo-rg",
  "location": "eastus",
  "name": "django-todo-rg",
  "properties": {
    "provisioningState": "Succeeded"
  }
}
```

---

## Step 3: Create Container Registry

```powershell
az acr create --resource-group django-todo-rg --name todoregistry166 --sku Basic
```

**Note:** Registry name must be:
- Globally unique
- Lowercase letters and numbers only
- 5-50 characters

### ✅ SUCCESS Output:
```json
{
  "adminUserEnabled": false,
  "loginServer": "todoregistry166.azurecr.io",
  "name": "todoregistry166",
  "sku": {
    "name": "Basic",
    "tier": "Basic"
  }
}
```

---

## Step 4: Create App Service Plan

```powershell
az appservice plan create `
  --name django-todo-plan `
  --resource-group django-todo-rg `
  --sku B1 `
  --is-linux
```

### ✅ SUCCESS Output:
```json
{
  "name": "django-todo-plan",
  "sku": {
    "name": "B1",
    "tier": "Basic"
  },
  "kind": "linux"
}
```

---

## Step 5: Create App Service

### ❌ ERROR 1: Invalid Parameters

**Failed Command:**
```powershell
az webapp create `
  --name django-todo-app `
  --resource-group django-todo-rg `
  --plan django-todo-plan `
  --deployment-container-image-name-user todoregistry166.azurecr.io/django-todo:latest
```

**Error:**
```
az webapp create: error: unrecognized arguments: --deployment-container-image-name-user
```

**✅ SOLUTION - Use correct parameter:**
```powershell
az webapp create `
  --name django-todo-app-7470 `
  --resource-group django-todo-rg `
  --plan django-todo-plan `
  --container-image-name todoregistry166.azurecr.io/django-todo:latest
```

### ❌ ERROR 2: PowerShell Pipe Character

**Failed Command:**
```powershell
az webapp create ... --runtime 'PYTHON|3.11'
```

**Error:**
```
'3.11' is not recognized as the name of a cmdlet
```

**✅ SOLUTION - Don't use runtime with container apps:**
Container-based apps don't need `--runtime`. The runtime is in the Docker image.

### ✅ SUCCESS Output:
```json
{
  "name": "django-todo-app-7470",
  "defaultHostName": "django-todo-app-7470.azurewebsites.net",
  "state": "Running"
}
```

---

## Step 6: Configure Permissions

### 6.1 Enable Managed Identity

```powershell
az webapp identity assign `
  --name django-todo-app-7470 `
  --resource-group django-todo-rg
```

**Output - Save the principalId:**
```json
{
  "principalId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "type": "SystemAssigned"
}
```

### 6.2 Get Registry ID

```powershell
az acr show --name todoregistry166 --query id --output tsv
```

**Output:**
```
/subscriptions/.../providers/Microsoft.ContainerRegistry/registries/todoregistry166
```

### 6.3 Grant Pull Permission

```powershell
az role assignment create `
  --assignee <principalId-from-step-6.1> `
  --scope <registry-id-from-step-6.2> `
  --role AcrPull
```

### 6.4 Enable Admin Access (for ACR credentials)

### ❌ ERROR: Credentials Not Available

**Failed Command:**
```powershell
az acr credential show --name todoregistry166
```

**Error:**
```
Admin user is disabled. Run 'az acr update --admin-enabled true'
```

**✅ SOLUTION:**
```powershell
az acr update --name todoregistry166 --admin-enabled true
```

**Now get credentials:**
```powershell
az acr credential show --name todoregistry166
```

**Output:**
```json
{
  "username": "todoregistry166",
  "passwords": [
    {
      "name": "password",
      "value": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    }
  ]
}
```

---

## Step 7: Build and Push Docker Image

### 7.1 Create Dockerfile.azure

See [Final Working Configuration](#final-working-configuration) for the complete file.

### 7.2 Build in Azure

```powershell
az acr build --registry todoregistry166 --image django-todo:latest --file Dockerfile.azure .
```

### ❌ ERROR 1: Image Name Typo

**Failed Command:**
```powershell
az acr build --image {django-todo}:{lastest} ...
```

**Error:** Build failed - invalid image name

**✅ SOLUTION:** Remove curly braces, fix typo:
```powershell
az acr build --image django-todo:latest ...
```

### ❌ ERROR 2: Gunicorn Permission Denied

**Error in logs:**
```
/usr/local/bin/python3.12: can't open file '/root/.local/bin/gunicorn': [Errno 13] Permission denied
```

**Cause:** Using `pip install --user` in Dockerfile installs to user directory, which is inaccessible.

**✅ SOLUTION:** Remove `--user` flag from pip install:
```dockerfile
# WRONG:
RUN pip install --no-cache-dir --user -r requirements.txt

# CORRECT:
RUN pip install --no-cache-dir -r requirements.txt
```

### ✅ SUCCESS Output:
```
Successfully built xxxxxxxx
Successfully tagged todoregistry166.azurecr.io/django-todo:latest
Successfully pushed image: todoregistry166.azurecr.io/django-todo:latest
Run ID: ca9 was successful after 48s
```

---

## Step 8: Configure App Service Container

### 8.1 Set Container Configuration

```powershell
az webapp config container set `
  --name django-todo-app-7470 `
  --resource-group django-todo-rg `
  --container-image-name todoregistry166.azurecr.io/django-todo:latest `
  --container-registry-url https://todoregistry166.azurecr.io `
  --container-registry-user todoregistry166 `
  --container-registry-password 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
```

### ❌ ERROR: Deprecated Parameter Warning

**Warning:**
```
WARNING: Argument '--docker-registry-server-password' has been deprecated
```

**Note:** Azure CLI updated parameter names. Use `--container-*` instead of `--docker-*`:
- `--container-registry-url` (not `--docker-registry-server-url`)
- `--container-registry-user` (not `--docker-registry-server-user`)
- `--container-registry-password` (not `--docker-registry-server-password`)

### 8.2 Restart App Service

```powershell
az webapp restart --name django-todo-app-7470 --resource-group django-todo-rg
```

---

## Troubleshooting Journey: All Errors Encountered

### Error Timeline

| # | Error | Cause | Solution |
|---|-------|-------|----------|
| 1 | `az login` timeout | Browser not opening | Use `az login --use-device-code` |
| 2 | Script invalid parameters | Wrong CLI parameter names | Use `--container-image-name` |
| 3 | `'3.11' is not recognized` | PowerShell pipe character issue | Don't use `--runtime` with containers |
| 4 | Admin user disabled | ACR admin not enabled | Run `az acr update --admin-enabled true` |
| 5 | Deprecated docker-* params | Azure CLI updated | Use `--container-*` parameters |
| 6 | Image name typo | `{django-todo}:{lastest}` | Use `django-todo:latest` |
| 7 | Gunicorn permission denied | `pip install --user` | Remove `--user` flag |
| 8 | `no such table: tasks_task` | Migrations not run | Add `start.sh` with migrations |
| 9 | CSRF verification failed | Azure domain not trusted | Add `CSRF_TRUSTED_ORIGINS` |
| 10 | CSS not loading | No static file server | Add WhiteNoise middleware |

### Detailed Error Solutions

#### Error 8: Database Migrations Not Running

**Symptom:**
```
OperationalError: no such table: tasks_task
```

**Root Cause:** Container starts Gunicorn directly without running migrations.

**✅ SOLUTION - Create start.sh:**
```bash
#!/bin/bash
set -e

echo "Running database migrations..."
python manage.py migrate --noinput

echo "Starting Gunicorn..."
exec gunicorn \
    --bind 0.0.0.0:8000 \
    --workers 4 \
    --worker-class sync \
    --timeout 60 \
    --access-logfile - \
    --error-logfile - \
    todo.wsgi:application
```

**Update Dockerfile.azure:**
```dockerfile
RUN chmod +x start.sh
CMD ["./start.sh"]
```

#### Error 9: CSRF Verification Failed

**Symptom:**
```
Forbidden (403)
CSRF verification failed. Request aborted.
Origin checking failed - https://django-todo-app-7470.azurewebsites.net does not match any trusted origins.
```

**Root Cause:** Django doesn't trust the Azure domain for CSRF protection.

**✅ SOLUTION - Update settings.py:**
```python
CSRF_TRUSTED_ORIGINS = [
    'https://django-todo-app-7470.azurewebsites.net',
    'https://*.azurewebsites.net',
]
```

#### Error 10: CSS Not Loading

**Symptom:** Page loads but unstyled (no CSS applied)

**Root Cause:** Gunicorn doesn't serve static files. Django's development server does, but it's not for production.

**✅ SOLUTION - Add WhiteNoise:**

**requirements.txt:**
```
whitenoise==6.6.0
```

**settings.py - Add middleware after SecurityMiddleware:**
```python
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',  # ADD THIS
    ...
]

# Add at end of file:
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'
```

---

## Final Working Configuration

### Dockerfile.azure
```dockerfile
# Multi-stage build for production on Azure
# Stage 1: Builder
FROM python:3.12-slim as builder

WORKDIR /app

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.12-slim

WORKDIR /app

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder stage
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY . .

# Make startup script executable and collect static files
RUN chmod +x start.sh && python manage.py collectstatic --noinput || true

# Expose port 8000
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/ || exit 1

# Run migrations and start Gunicorn
CMD ["./start.sh"]
```

### start.sh
```bash
#!/bin/bash
set -e

echo "Running database migrations..."
python manage.py migrate --noinput

echo "Starting Gunicorn..."
exec gunicorn \
    --bind 0.0.0.0:8000 \
    --workers 4 \
    --worker-class sync \
    --timeout 60 \
    --access-logfile - \
    --error-logfile - \
    todo.wsgi:application
```

### requirements.txt
```
asgiref==3.8.1
Django==5.2
dj-database-url==2.1.0
django-restframework==0.0.1
sqlparse==0.5.3
tzdata==2025.2
gunicorn==21.2.0
psycopg2-binary==2.9.9
whitenoise==6.6.0
```

### settings.py (Key Changes)
```python
ALLOWED_HOSTS = ['*']

CSRF_TRUSTED_ORIGINS = [
    'https://django-todo-app-7470.azurewebsites.net',
    'https://*.azurewebsites.net',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',  # For static files
    ...
]

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_DIRS = [
    BASE_DIR / 'static',
]
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'
```

---

## Azure Resources Summary

| Resource | Value |
|----------|-------|
| **Resource Group** | django-todo-rg |
| **Container Registry** | todoregistry166.azurecr.io |
| **ACR Username** | todoregistry166 |
| **ACR Password** | xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx |
| **App Service Plan** | django-todo-plan (B1) |
| **App Service** | django-todo-app-7470 |
| **App URL** | https://django-todo-app-7470.azurewebsites.net |
| **Location** | East US |

---

## Quick Commands Reference

### Deploy New Changes
```powershell
# 1. Build and push to ACR
az acr build --registry todoregistry166 --image django-todo:latest --file Dockerfile.azure .

# 2. Restart to pull new image
az webapp restart --name django-todo-app-7470 --resource-group django-todo-rg
```

### View Logs
```powershell
az webapp log tail --name django-todo-app-7470 --resource-group django-todo-rg
```

### Check App Status
```powershell
az webapp show --name django-todo-app-7470 --resource-group django-todo-rg --query state
```
