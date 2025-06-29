# PowerApps PowerShell Module Installation for CI/CD

This directory contains enhanced scripts and workflows for installing PowerApps PowerShell modules in CI/CD environments, particularly GitHub Actions, where standard installation methods might fail.

## Problem Statement

The `Get-PowerAppsAccount` cmdlet and related PowerApps PowerShell modules often fail to install or load properly in CI/CD environments due to:

- Assembly conflicts
- Permission issues
- PowerShell Gallery connectivity problems
- Missing dependencies (NuGet, PowerShellGet)
- Trust and execution policy restrictions

## Solution

This enhanced solution provides multiple installation methods with robust fallbacks:

### 1. Enhanced Main Script (`post-deploy-agent.ps1`)

The main script now includes:
- **CI/CD environment detection** (GitHub Actions, Azure Pipelines, etc.)
- **Multiple installation methods** with fallbacks
- **Manual installation function** for direct PowerShell Gallery downloads
- **Assembly conflict resolution**
- **REST API fallbacks** when PowerShell modules fail

### 2. Dedicated Installation Script (`install-powerapps-modules.ps1`)

A standalone script that focuses solely on installing PowerApps modules:
- **4 different installation methods**
- **Environment-specific configurations**
- **Comprehensive verification**
- **Detailed logging and diagnostics**

### 3. GitHub Actions Workflows

Pre-configured workflows that demonstrate proper setup:
- **Environment preparation**
- **Module installation**
- **Verification steps**
- **Error handling**

## Files

| File | Purpose |
|------|---------|
| `post-deploy-agent.ps1` | Main deployment script with enhanced module handling |
| `install-powerapps-modules.ps1` | Dedicated module installation script |
| `.github/workflows/install-powerapps-modules.yml` | Reusable workflow for module installation |
| `.github/workflows/deploy-agent.yml` | Complete deployment workflow example |

## GitHub Actions Setup

### 1. Repository Secrets

Set up these secrets in your GitHub repository (`Settings` > `Secrets and variables` > `Actions`):

```
POWERPLATFORM_CLIENT_ID=your-service-principal-client-id
POWERPLATFORM_CLIENT_SECRET=your-service-principal-client-secret
POWERPLATFORM_TENANT_ID=your-azure-tenant-id
```

### 2. Service Principal Setup

Create a service principal with appropriate permissions:

```powershell
# Create service principal
az ad sp create-for-rbac --name "GitHubActions-PowerPlatform" --role contributor

# Assign Power Platform permissions (use Azure Portal or PowerShell)
# Required roles:
# - Power Platform Administrator (for environment access)
# - Power Apps Service Admin (for agent management)
```

### 3. Workflow Usage

#### Option A: Use the dedicated installation workflow

```yaml
- name: Install PowerApps Modules
  uses: ./.github/workflows/install-powerapps-modules.yml
```

#### Option B: Run the standalone installation script

```yaml
- name: Install PowerApps Modules
  shell: pwsh
  run: |
    .\scripts\install-powerapps-modules.ps1 -Verbose
```

#### Option C: Use the enhanced main script

```yaml
- name: Deploy Agent
  shell: pwsh
  run: |
    .\scripts\post-deploy-agent.ps1 -EnvironmentUrl "https://yourorg.crm.dynamics.com" -ClientId $env:CLIENT_ID -ClientSecret $env:CLIENT_SECRET -TenantId $env:TENANT_ID
```

## Manual Installation Methods

### Method 1: Standard Installation

```powershell
# Run the dedicated installation script
.\scripts\install-powerapps-modules.ps1
```

### Method 2: Force Reinstall

```powershell
# Force reinstall all modules
.\scripts\install-powerapps-modules.ps1 -ForceReinstall
```

### Method 3: Direct Download

```powershell
# Use direct PowerShell Gallery download
.\scripts\install-powerapps-modules.ps1 -UseDirect
```

### Method 4: Manual Commands

```powershell
# Manual installation commands
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.201" -Force -Scope CurrentUser

# Install modules
Install-Module -Name "Microsoft.PowerApps.Administration.PowerShell" -Repository PSGallery -Force -AllowClobber -Scope CurrentUser -AcceptLicense
Install-Module -Name "Microsoft.PowerApps.PowerShell" -Repository PSGallery -Force -AllowClobber -Scope CurrentUser -AcceptLicense

# Import and verify
Import-Module -Name "Microsoft.PowerApps.Administration.PowerShell" -Force
Import-Module -Name "Microsoft.PowerApps.PowerShell" -Force

# Test
Get-Command -Module "Microsoft.PowerApps.Administration.PowerShell"
Get-Command -Module "Microsoft.PowerApps.PowerShell"
```

## Troubleshooting

### Common Issues and Solutions

#### 1. "Assembly with same name is already loaded"

The enhanced script automatically handles this by:
- Detecting assembly conflicts
- Removing conflicting modules
- Forcing garbage collection
- Re-importing with different approaches

#### 2. PowerShell Gallery connectivity issues

Solutions implemented:
- Multiple installation methods (Install-Module, Install-Package)
- Direct download from PowerShell Gallery API
- NuGet provider installation
- Repository trust configuration

#### 3. CI/CD permission issues

The script automatically:
- Sets appropriate execution policies
- Trusts PowerShell Gallery
- Uses CurrentUser scope for installations
- Applies AcceptLicense for automated scenarios

#### 4. Missing cmdlets after installation

The script:
- Verifies cmdlet availability after installation
- Tests specific PowerApps cmdlets
- Provides detailed diagnostics
- Falls back to REST API methods when cmdlets fail

### Manual Verification

```powershell
# Check if modules are loaded
Get-Module -Name "*PowerApps*"

# Check available cmdlets
Get-Command -Module "Microsoft.PowerApps.Administration.PowerShell"
Get-Command -Module "Microsoft.PowerApps.PowerShell"

# Test specific cmdlets
Get-Command -Name "Get-PowerAppsAccount" -ErrorAction SilentlyContinue
Get-Command -Name "Add-PowerAppsAccount" -ErrorAction SilentlyContinue
Get-Command -Name "Get-AdminPowerAppEnvironment" -ErrorAction SilentlyContinue
```

## REST API Fallback

If PowerShell modules cannot be installed, the main script automatically falls back to REST API methods:

- **Authentication**: Direct OAuth token acquisition
- **Environment discovery**: REST API calls to Power Platform endpoints
- **Agent management**: Direct API calls for publishing, enabling, and sharing

This ensures the script works even when PowerShell modules are completely unavailable.

## Best Practices

1. **Always test module installation** before running the main deployment script
2. **Use the dedicated installation script** in CI/CD pipelines for better error handling
3. **Set up proper service principal permissions** for your Power Platform environment
4. **Monitor script output** for warnings and suggestions
5. **Keep modules updated** by running with `-ForceReinstall` periodically
6. **Use REST API fallbacks** for production deployments where reliability is critical

## Support

For issues with:
- **PowerShell modules**: Use the dedicated installation script with `-Verbose` flag
- **GitHub Actions**: Check the workflow examples and ensure secrets are properly configured
- **Service principal permissions**: Verify roles in Azure Portal and Power Platform Admin Center
- **Environment access**: Test with the `-WhatIf` parameter first
