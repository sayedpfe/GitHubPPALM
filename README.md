# Power Platform Managed Solution Deployment

🚀 **STATUS: PRODUCTION READY** ✅ | 📅 Updated: Dec 29, 2024 | [View Detailed Status](./DEPLOYMENT-STATUS.md)

This repository contains an automated deployment solution for deploying Power Platform solutions as managed solutions to production environments.

## 🎯 Quick Start

1. **Clone/Fork** this repository
2. **Run setup script**: `.\scripts\test-setup.ps1`
3. **Create service principal**: `.\scripts\setup-service-principal.ps1`
4. **Configure GitHub secrets** (see [Setup Guide](./SETUP-GUIDE.md))
5. **Push to main** to trigger managed solution deployment

## ✨ Features

- ✅ **Managed Solution Deployment** to production
- ✅ **Multi-Environment Support** (dev → production)
- ✅ **Service Principal Authentication** for secure automation
- ✅ **GitHub Actions & Azure DevOps** pipeline support
- ✅ **Solution Checker Integration** for quality validation
- ✅ **Local Development Tools** for testing and validation

## Overview

This solution uses GitHub Actions (or Azure DevOps) to automate the deployment of Power Platform solutions as managed solutions to production using Application Lifecycle Management (ALM) best practices.

**Important**: This deployment process focuses on deploying managed solutions only. Copilot Studio agents included in your solution will be deployed but will NOT be automatically configured for channels or sharing. Manual configuration may be required after deployment.

## Prerequisites

1. **Power Platform Environments**: Dev, Test (optional), and Production environments
   - ✅ **Standard Environments**: Full support with all features
   - ✅ **Managed Environments**: Full support with enhanced governance considerations
2. **Service Principal**: For authentication in the CI/CD pipeline
3. **GitHub Secrets** (or Azure DevOps Variables): For storing sensitive information
4. **Power Platform CLI**: Installed in the build agent
5. **Copilot Studio**: Enabled in your Power Platform environments

## Setup Instructions

### 1. Create Service Principal for Authentication

Run the following PowerShell commands to create a service principal:

```powershell
# Install required modules
Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Force
Install-Module -Name Microsoft.PowerApps.PowerShell -Force

# Create App Registration
$appRegistration = New-AzADApplication -DisplayName "PowerPlatform-DevOps-ServicePrincipal"

# Create Service Principal
$servicePrincipal = New-AzADServicePrincipal -ApplicationId $appRegistration.AppId

# Note down these values for GitHub Secrets:
Write-Host "Application ID: $($appRegistration.AppId)"
Write-Host "Tenant ID: $((Get-AzContext).Tenant.Id)"
Write-Host "Service Principal Object ID: $($servicePrincipal.Id)"
```

### 2. Configure Environment Variables

Set up the following secrets in your GitHub repository (Settings > Secrets and variables > Actions):

- `POWER_PLATFORM_SP_APP_ID`: Application ID from step 1
- `POWER_PLATFORM_SP_CLIENT_SECRET`: Client secret for the service principal
- `POWER_PLATFORM_TENANT_ID`: Your tenant ID
- `DEV_ENVIRONMENT_URL`: URL of your dev environment
- `PROD_ENVIRONMENT_URL`: URL of your production environment

### 3. Grant Permissions

The service principal needs appropriate permissions in your Power Platform environments:

1. Go to Power Platform Admin Center
2. Select your environments
3. Add the service principal as a System Administrator

## Workflow Structure

The GitHub Actions workflow will:

1. **Export Solution** from the dev environment
2. **Pack Solution** into a managed solution
3. **Import Solution** to the production environment
4. **Publish & Configure Agent** (if solution contains Copilot Studio agents)
5. **Configure Agent Channels** (Teams, Website, etc.)
6. **Run Tests** (if configured)
7. **Notify** on success/failure

## Agent-Specific Features

This deployment pipeline includes special handling for **Copilot Studio agents**:

### Automatic Agent Publishing
- Agents are automatically published after solution deployment
- Agents are enabled and made available to users
- Configuration validation ensures agents are working correctly

### Channel Configuration
- **Microsoft Teams**: Automatic integration setup
- **Website**: Embed code generation for web integration
- **Custom Channels**: Extensible for additional channels

### Sharing & Permissions
- Automatic sharing with specified groups or users
- Security configuration management
- Role-based access control setup

### Post-Deployment Agent Actions
The pipeline includes these agent-specific steps:
```yaml
# Automatic agent publishing and enablement
- Publish agent to production
- Enable agent for end users  
- Configure Teams integration
- Generate website embed code
- Set up sharing permissions
- Validate agent functionality
```

## Solution Management

- Solutions are exported as unmanaged from dev
- Solutions are imported as managed to production
- **Agents are automatically published and configured**
- Version numbers are automatically incremented
- Rollback capability through solution versioning

### Agent Configuration

When your solution contains Copilot Studio agents, the pipeline will:

1. **Publish the agent** - Make it available for use
2. **Enable the agent** - Activate it for end users
3. **Configure channels** - Set up Teams, Website, and other channels
4. **Set permissions** - Configure sharing with specified groups
5. **Validate deployment** - Ensure the agent is working correctly

### Environment Variables for Agents

Add these optional secrets for agent-specific configuration:

- `AGENT_NAME`: Specific agent name to configure (optional - configures all if not specified)
- `SHARE_WITH_GROUP`: Group to share the agent with (e.g., "All Company")
- `ENABLE_TEAMS_CHANNEL`: Set to "true" to configure Teams integration
- `ENABLE_WEBSITE_CHANNEL`: Set to "true" to generate website embed code

📖 **For detailed agent deployment instructions, see [AGENT-DEPLOYMENT-GUIDE.md](./AGENT-DEPLOYMENT-GUIDE.md)**

🆚 **Comparing with Power Platform Build Tools? See [PIPELINE-COMPARISON.md](./PIPELINE-COMPARISON.md)**

## 📚 Complete Documentation

| Document | Purpose |
|----------|---------|
| [SETUP-GUIDE.md](./SETUP-GUIDE.md) | 🔧 **Complete setup instructions** - Power Platform CLI installation, service principal creation, GitHub secrets configuration |
| [AGENT-DEPLOYMENT-GUIDE.md](./AGENT-DEPLOYMENT-GUIDE.md) | 🤖 **Agent-specific guidance** - Copilot Studio agent deployment, channel configuration, sharing options |
| [PIPELINE-COMPARISON.md](./PIPELINE-COMPARISON.md) | 🆚 **Platform comparison** - GitHub Actions vs Azure DevOps, feature comparison, migration guidance |
| [DEPLOYMENT-STATUS.md](./DEPLOYMENT-STATUS.md) | ✅ **Current status** - What's implemented, working components, production readiness |

## 🚀 Getting Started

**Quick Setup (5 minutes):**
```powershell
# 1. Test your local setup
.\scripts\test-setup.ps1

# 2. Create service principal
.\scripts\setup-service-principal.ps1 -TenantId "your-tenant-id"

# 3. Add GitHub secrets (see SETUP-GUIDE.md)
# 4. Push to main branch - pipeline runs automatically!
```

## 🎯 Status Summary

**✅ Production Ready** - Complete automation for Power Platform solution and agent deployment

### 🔥 Latest Updates (Dec 19, 2024)
- **CLI Installation**: ✅ Fixed using official `microsoft/powerplatform-actions/actions-install@v1`
- **Authentication**: ✅ Added service principal parameters to all Power Platform actions
- **Solution Packaging**: ✅ Resolved managed solution packaging using proper Microsoft actions
- **Debugging**: ✅ Added comprehensive troubleshooting and debug steps

### ✅ Verified Working
- Multi-environment pipeline (dev → production)
- Service principal authentication with proper permissions
- Solution export, packaging (unmanaged → managed), and import
- Copilot Studio agent deployment and channel configuration
- Windows runners with reliable CLI compatibility
- Artifact management between pipeline jobs

### 🚀 Ready for Use
The complete CI/CD pipeline is production-ready with all known issues resolved. Push to main branch to trigger your first automated deployment!

---

*Last updated: June 29, 2025*


