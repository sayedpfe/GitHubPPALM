# Power Platform Deployment Guide

## Quick Start Guide

This repository provides a complete automated deployment solution for Power Platform solutions using CI/CD pipelines.

### 🚀 Getting Started

1. **Fork/Clone this repository**
2. **Update configuration files with your solution details**
3. **Set up service principal for authentication**
4. **Configure pipeline secrets/variables**
5. **Push to main branch to trigger deployment**

## 📋 Prerequisites

- **Power Platform environments**: Development, Test (optional), Production
- **GitHub repository** or **Azure DevOps project**
- **Azure AD tenant** with permissions to create service principals
- **Power Platform CLI** (for local development)

### Power Platform CLI Installation

The Power Platform CLI is required for local development and testing. Choose one of the following installation methods:

#### Method 1: Windows Installer (Recommended for Windows)

1. **Download the latest MSI installer**:
   - Go to [Power Platform CLI releases](https://aka.ms/PowerPlatformCLI)
   - Download the `.msi` file for Windows

2. **Run the installer**:
   ```powershell
   # Double-click the downloaded .msi file or run via PowerShell
   Start-Process ".\Microsoft.PowerApps.CLI.msi" -Wait
   ```

3. **Verify installation**:
   ```powershell
   pac help
   ```

#### Method 2: .NET Tool (Cross-platform)

1. **Install .NET 6.0 or later** (if not already installed):
   - Download from [dotnet.microsoft.com](https://dotnet.microsoft.com/download)

2. **Install Power Platform CLI as a global tool**:
   ```powershell
   dotnet tool install --global Microsoft.PowerApps.CLI.Tool
   ```

3. **Update to latest version** (if already installed):
   ```powershell
   dotnet tool update --global Microsoft.PowerApps.CLI.Tool
   ```

4. **Verify installation**:
   ```powershell
   pac help
   ```

#### Method 3: Winget (Windows Package Manager)

```powershell
winget install Microsoft.PowerApps.CLI
```

#### Method 4: Chocolatey

```powershell
choco install pac
```

#### Method 5: Docker (for CI/CD environments)

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:6.0
RUN dotnet tool install --global Microsoft.PowerApps.CLI.Tool
ENV PATH="${PATH}:/root/.dotnet/tools"
```

### Post-Installation Setup

1. **Authenticate with your Power Platform environment**:
   ```powershell
   # Interactive authentication
   pac auth create --url https://orgf447c64a.crm.dynamics.com/

   # Service Principal authentication (for automation)
   pac auth create --url https://yourorg.crm.dynamics.com --applicationId "your-app-id" --clientSecret "your-secret" --tenant "your-tenant-id"
   ```

2. **List available authentication profiles**:
   ```powershell
   pac auth list
   ```

3. **Switch between authentication profiles**:
   ```powershell
   pac auth select --index 1
   ```

4. **Test CLI connectivity**:
   ```powershell
   # List environments you have access to
   pac admin list

   # List solutions in current environment
   pac solution list
   ```

### Quick Setup Test

Run our provided test script to verify your local setup:

```powershell
.\scripts\test-setup.ps1
```

This script will check:
- ✅ Power Platform CLI installation
- ✅ Authentication status
- ✅ Environment connectivity
- ✅ Required PowerShell modules
- ✅ Git configuration

### Troubleshooting CLI Installation

**Issue: "pac is not recognized"**
- Solution: Restart your terminal/PowerShell after installation
- Verify PATH environment variable includes CLI location

**Issue: "Not a valid command" when running pac --version**
- Solution: Use `pac help` instead of `pac --version` for verification
- The current CLI version doesn't support --version flag

**Issue: .NET Tool installation fails**
- Solution: Ensure you have .NET 6.0+ installed
- Run: `dotnet --version` to check

**Issue: Authentication fails**
- Solution: Check your environment URL format
- Ensure you have proper permissions in the environment
- Verify tenant ID is correct

**Issue: CLI commands are slow**
- Solution: Use `--verbose` flag to see detailed logs
- Check your network connectivity
- Consider using service principal authentication for better performance

### GitHub Actions Compatibility Notes

**⚠️ Important for CI/CD Pipelines:**

- **Windows Package Manager (winget) is not available** on GitHub Actions Windows runners
- Our workflow uses the **.NET global tool method** for CLI installation, which is the most reliable approach for CI/CD
- **Avoid using winget commands** in GitHub Actions workflows
- The workflow automatically handles PATH configuration for the pac CLI

**Recommended CI/CD Installation Method:**
```yaml
- name: Setup Power Platform CLI
  uses: microsoft/powerplatform-actions/actions-install@v1
```

**Alternative: Manual Installation (if needed):**
```yaml
- name: Setup Power Platform CLI
  run: |
    # Install Power Platform CLI as a .NET global tool
    dotnet tool install --global Microsoft.PowerApps.CLI.Tool
    
    # Refresh environment variables to ensure pac is in PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
    
    # Verify installation and show help
    pac help
  shell: pwsh
```

### 🔧 Additional Tools (Optional but Recommended)

#### **Azure CLI** (for service principal management):
```powershell
# Install Azure CLI
winget install Microsoft.AzureCLI

# Or via PowerShell
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -ArgumentList '/i AzureCLI.msi /quiet' -Wait
```

#### **Git** (for version control):
```powershell
# Install Git
winget install Git.Git

# Or download from: https://git-scm.com/download/win
```

### 🛠️ Troubleshooting Installation

**Common Issues:**

1. **"pac is not recognized as a command"**
   ```powershell
   # Check if PATH is set correctly
   $env:PATH -split ';' | Where-Object { $_ -like "*PowerPlatform*" }
   
   # Manually add to PATH (temporary)
   $env:PATH += ";C:\Program Files\Microsoft Power Platform CLI"
   ```

2. **Permission denied errors**
   ```powershell
   # Run PowerShell as Administrator
   # Or use portable installation method
   ```

3. **Installation fails**
   ```powershell
   # Clear PowerShell module cache
   Remove-Module Microsoft.PowerApps.CLI -Force
   Uninstall-Module Microsoft.PowerApps.CLI -Force
   Install-Module Microsoft.PowerApps.CLI -Force
   ```

4. **Version conflicts**
   ```powershell
   # Uninstall old version first
   pac install latest
   ```

### 📝 Post-Installation Setup

Once installed, you can test the solution locally:

```powershell
# Clone this repository
git clone https://github.com/yourusername/GitHubPPALM.git
cd GitHubPPALM

# Test environment compatibility
.\scripts\check-environment-compatibility.ps1 `
  -EnvironmentUrl "https://yourdev.crm.dynamics.com" `
  -ClientId "your-app-id" `
  -ClientSecret "your-secret" `
  -TenantId "your-tenant-id"

# Test solution export
.\scripts\export-solution.ps1 `
  -EnvironmentUrl "https://yourdev.crm.dynamics.com" `
  -SolutionName "YourSolutionName" `
  -ClientId "your-app-id" `
  -ClientSecret "your-secret" `
  -TenantId "your-tenant-id"
```

## 🔧 Setup Instructions

### Step 1: Service Principal Setup

Run the service principal setup script:

```powershell
.\scripts\setup-service-principal.ps1 -TenantId "your-tenant-id"
```

This will create:
- Azure AD Application Registration
- Service Principal
- Required API permissions
- Client secret

### Step 2: Environment Configuration

Update `config/environment-settings.json` with your environment details:

```json
{
  "environments": {
    "development": {
      "environmentUrl": "https://yourdev.crm.dynamics.com",
      "environmentId": "your-dev-environment-id"
    },
    "production": {
      "environmentUrl": "https://yourprod.crm.dynamics.com", 
      "environmentId": "your-prod-environment-id"
    }
  }
}
```

### Step 3: GitHub Secrets (if using GitHub Actions)

Add these secrets to your GitHub repository:

- `POWER_PLATFORM_SP_APP_ID`: Service Principal Application ID
- `POWER_PLATFORM_SP_CLIENT_SECRET`: Service Principal Client Secret
- `POWER_PLATFORM_TENANT_ID`: Azure Tenant ID
- `DEV_ENVIRONMENT_URL`: Development environment URL
- `PROD_ENVIRONMENT_URL`: Production environment URL

#### 📝 **Step-by-Step Guide to Add GitHub Secrets**

**Method 1: Using GitHub Web Interface (Recommended)**

1. **Navigate to Your Repository**:
   - Go to [GitHub.com](https://github.com)
   - Sign in to your account
   - Navigate to your forked/cloned repository (e.g., `https://github.com/yourusername/GitHubPPALM`)

2. **Access Repository Settings**:
   - Click on the **"Settings"** tab (located in the top menu of your repository)
   - If you don't see "Settings", make sure you're the repository owner or have admin access

3. **Navigate to Secrets and Variables**:
   - In the left sidebar, scroll down to the **"Security"** section
   - Click on **"Secrets and variables"**
   - Select **"Actions"**

4. **Add Each Secret**:
   For each secret, follow these steps:
   
   - Click the **"New repository secret"** button
   - Enter the **Name** (exactly as listed above, case-sensitive)
   - Enter the **Value** (from your service principal setup output)
   - Click **"Add secret"**

   **Required Secrets to Add**:
   
   | Secret Name | Value Source | Example Value |
   |-------------|--------------|---------------|
   | `POWER_PLATFORM_SP_APP_ID` | From service principal script output | `12345678-1234-1234-1234-123456789012` |
   | `POWER_PLATFORM_SP_CLIENT_SECRET` | From service principal script output | `dJ8Q~abcdefghijklmnopqrstuvwxyz1234567890` |
   | `POWER_PLATFORM_TENANT_ID` | Your Azure tenant ID | `87654321-4321-4321-4321-210987654321` |
   | `DEV_ENVIRONMENT_URL` | Your development environment URL | `https://yourdev.crm.dynamics.com` |
   | `PROD_ENVIRONMENT_URL` | Your production environment URL | `https://yourprod.crm.dynamics.com` |

5. **Verify Secrets Are Added**:
   - You should see all 5 secrets listed in the "Repository secrets" section
   - Secret values will be hidden (showing only `•••••••••••`)
   - You can update or delete secrets using the edit/delete buttons

**Method 2: Using GitHub CLI (for Advanced Users)**

If you have GitHub CLI installed:

```powershell
# Install GitHub CLI (if not already installed)
winget install GitHub.cli

# Authenticate with GitHub
gh auth login

# Navigate to your repository directory
cd d:\CopilotExtensibility\GitHubPPALM

# Add secrets using GitHub CLI
gh secret set POWER_PLATFORM_SP_APP_ID --body "your-app-id-here"
gh secret set POWER_PLATFORM_SP_CLIENT_SECRET --body "your-client-secret-here"
gh secret set POWER_PLATFORM_TENANT_ID --body "your-tenant-id-here"
gh secret set DEV_ENVIRONMENT_URL --body "https://yourdev.crm.dynamics.com"
gh secret set PROD_ENVIRONMENT_URL --body "https://yourprod.crm.dynamics.com"

# Verify secrets were added
gh secret list
```

**Method 3: Using PowerShell with GitHub API (Alternative)**

```powershell
# Set your variables
$owner = "yourusername"
$repo = "GitHubPPALM"
$token = "your-github-personal-access-token"

# Function to add secret
function Add-GitHubSecret {
    param($secretName, $secretValue)
    
    $headers = @{
        "Authorization" = "token $token"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    # Get repository public key
    $keyResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/actions/secrets/public-key" -Headers $headers
    
    # Encrypt secret (requires Sodium.Core NuGet package)
    # This is complex - recommend using GitHub web interface instead
}
```

#### 🔍 **How to Get the Secret Values**

**From Service Principal Setup Script Output**:
When you ran `.\scripts\setup-service-principal.ps1`, it displayed these values:

```
=== SERVICE PRINCIPAL DETAILS ===
Application ID: [Copy this for POWER_PLATFORM_SP_APP_ID]
Tenant ID: [Copy this for POWER_PLATFORM_TENANT_ID]  
Client Secret: [Copy this for POWER_PLATFORM_SP_CLIENT_SECRET]
```

**Environment URLs**:
- **Development**: Your Power Platform development environment URL
- **Production**: Your Power Platform production environment URL
- Format: `https://yourorgname.crm.dynamics.com` (no trailing slash)

#### 🔧 **How to Find Your Environment URLs**

**Method 1: Power Platform Admin Center**
1. Go to [Power Platform Admin Center](https://admin.powerplatform.microsoft.com)
2. Sign in with your admin account
3. Click on **"Environments"** in the left navigation
4. Select your environment (Dev/Prod)
5. Copy the **Environment URL** from the details panel

**Method 2: Power Apps Maker Portal**
1. Go to [Power Apps](https://make.powerapps.com)
2. Select your environment from the top-right dropdown
3. Look at the URL in your browser - it will show: `https://make.powerapps.com/environments/[environment-id]/home`
4. The environment URL format is: `https://[your-org].crm[region].dynamics.com`

**Method 3: Using Power Platform CLI**
```powershell
# List all environments you have access to
pac admin list

# This will show Environment Display Name, Environment Id, and Environment Url
```

#### ⚠️ **Important Security Notes**

- **Never commit secrets to your repository code**
- **Secret values are hidden once added** - you can't view them again
- **Rotate secrets regularly** (every 90 days recommended)
- **Use environment-specific secrets** for different deployment targets
- **Only repository collaborators with appropriate permissions can add/modify secrets**

#### 🧪 **Testing Secret Configuration**

After adding secrets, test them by:

1. **Trigger the GitHub Action**:
   - Make a small change to your repository (e.g., update README.md)
   - Commit and push to the `main` branch
   - Go to the **"Actions"** tab to see if the workflow runs

2. **Check for Authentication Errors**:
   - If secrets are incorrect, you'll see authentication failures in the action logs
   - Look for error messages like "Authentication failed" or "Invalid client secret"

3. **Manual Verification**:
   ```powershell
   # Test authentication locally with the same values
   pac auth create --url $env:DEV_ENVIRONMENT_URL --applicationId $env:POWER_PLATFORM_SP_APP_ID --clientSecret $env:POWER_PLATFORM_SP_CLIENT_SECRET --tenant $env:POWER_PLATFORM_TENANT_ID
   ```

### Step 4: Update Solution Name

In `.github/workflows/power-platform-deployment.yml`, update:

```yaml
env:
  SOLUTION_NAME: 'YourActualSolutionName'  # Replace with your solution name
```

### Step 5: Grant Service Principal Permissions

Now you need to add the service principal to your Power Platform environments and grant the necessary permissions.

#### 🔧 **Detailed Guide: Adding Service Principal to Power Platform Environments**

Adding a service principal to Power Platform environments requires specific steps and permissions. Here's the complete process:

**Prerequisites:**
- You must be a **Power Platform Administrator** or **System Administrator** in the target environment
- The service principal must exist in the same Azure AD tenant as your Power Platform environment
- **Admin consent** must be granted for the service principal API permissions

#### **Method 1: Using Power Platform Admin Center (Recommended)**

1. **Grant Admin Consent First** (Critical Step):
   - Go to [Azure Portal](https://portal.azure.com)
   - Navigate to **Azure Active Directory** > **App registrations**
   - Find your app: **"PowerPlatform-DevOps-ServicePrincipal"**
   - Click on **"API permissions"**
   - Click **"Grant admin consent for [Your Organization]"**
   - Verify the status shows **"Granted for [Your Organization]"**

2. **Navigate to Power Platform Admin Center**:
   - Go to [admin.powerplatform.microsoft.com](https://admin.powerplatform.microsoft.com)
   - Sign in with an account that has **Power Platform Administrator** or **Global Administrator** privileges

3. **Select Your Development Environment**:
   - Click **"Environments"** in the left navigation
   - Find and click on your **Development** environment
   - Click **"Settings"** button at the top

4. **Navigate to Users and Permissions**:
   - In the Settings panel, expand **"Users + permissions"**
   - Click **"Users"**

5. **Add the Service Principal**:
   - Click **"+ Add user"** button
   - In the **"Add user"** dialog:
     - **Username**: Enter the **Application ID** (GUID format: `12345678-1234-1234-1234-123456789012`)
     - **First name**: Enter "DevOps"
     - **Last name**: Enter "ServicePrincipal"
     - **Email**: Enter a placeholder like `devops-sp@yourcompany.com`
   - Click **"Add"**

6. **Assign Security Roles**:
   - After adding the user, find the service principal in the users list (search by Application ID)
   - Click on the service principal user
   - Click **"Manage security roles"**
   - Select **"System Administrator"** role (required for solution deployment)
   - Optionally, also select **"Environment Maker"** role
   - Click **"Save"**

7. **Repeat for Production Environment**:
   - Go back to **Environments**
   - Select your **Production** environment
   - Repeat steps 3-6

#### **Method 2: Using PowerShell (Alternative)**

If you prefer PowerShell and have admin permissions:

```powershell
# Install required modules if not already installed
Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Force
Install-Module -Name Microsoft.PowerApps.PowerShell -Force

# Connect to Power Platform (will prompt for interactive login)
Add-PowerAppsAccount

# Get your environments
Get-AdminPowerAppEnvironment | Select-Object DisplayName, EnvironmentName

# Add service principal to development environment
$devEnvironmentId = "your-dev-environment-id"  # From the output above
$servicePrincipalObjectId = "your-service-principal-object-id"  # From setup script output

# Add the service principal as an environment admin
New-AdminPowerAppRoleAssignment -EnvironmentName $devEnvironmentId -RoleName "EnvironmentAdmin" -PrincipalType "ServicePrincipal" -PrincipalObjectId $servicePrincipalObjectId

# Repeat for production environment
$prodEnvironmentId = "your-prod-environment-id"
New-AdminPowerAppRoleAssignment -EnvironmentName $prodEnvironmentId -RoleName "EnvironmentAdmin" -PrincipalType "ServicePrincipal" -PrincipalObjectId $servicePrincipalObjectId
```

#### **🚨 Troubleshooting Common Issues**

**Issue: "User not found" or "Cannot add user"**

**Possible Causes & Solutions:**

1. **Service Principal not found in Azure AD**:
   ```powershell
   # Verify the service principal exists
   Connect-AzAccount
   Get-AzADServicePrincipal -ApplicationId "your-app-id"
   ```

2. **Admin Consent Not Granted**:
   - **Most Common Issue**: Go to Azure Portal → App registrations → Your App → API permissions
   - Click **"Grant admin consent for [Your Organization]"**
   - Wait 5-10 minutes for changes to propagate

3. **Insufficient Permissions**:
   - Ensure you're signed in as a **Power Platform Administrator**
   - Check if you have **System Administrator** role in the target environment
   - Verify you're in the correct Azure AD tenant

4. **Wrong Application ID Format**:
   - Use the **Application ID** (GUID format: `12345678-1234-1234-1234-123456789012`)
   - **Not** the Display Name (`PowerPlatform-DevOps-ServicePrincipal`)
   - **Not** the Object ID

5. **Environment Type Restrictions**:
   - **Default environments**: May have restrictions on adding service principals
   - **Trial environments**: May not support service principals
   - **Production environments**: Require additional approval in some organizations

**Issue: "Access denied" when adding user**

**Solutions:**
1. **Check Environment Permissions**:
   ```powershell
   # Verify your admin permissions
   pac admin list
   ```

2. **Use Correct Admin Portal**:
   - Use [admin.powerplatform.microsoft.com](https://admin.powerplatform.microsoft.com)
   - **Not** [make.powerapps.com](https://make.powerapps.com) (maker portal)

3. **Check Organization Settings**:
   - Some organizations restrict service principal access
   - Contact your **Global Administrator** if needed

**Issue: Service Principal added but authentication still fails**

**Solutions:**
1. **Wait for Propagation** (can take 5-15 minutes)
2. **Verify API Permissions**:
   - Go to Azure Portal → Azure Active Directory → App registrations
   - Find your app → API permissions
   - Ensure **"Dynamics CRM user_impersonation"** permission has **admin consent granted**
3. **Check Security Role Assignment**:
   - Verify the service principal has **System Administrator** role
   - In some cases, you may need **Environment Maker** role as well

#### **🔍 Verification Steps**

After adding the service principal, verify it's working:

1. **Test Authentication**:
   ```powershell
   pac auth create --url "https://yourdev.crm.dynamics.com" --applicationId "your-app-id" --clientSecret "your-secret" --tenant "your-tenant-id"
   ```

2. **List Solutions** (to verify permissions):
   ```powershell
   pac solution list
   ```

3. **Check User in Admin Center**:
   - Go back to the environment's Users list
   - Verify the service principal appears with **System Administrator** role

#### **📋 Required Information Checklist**

Before adding the service principal, ensure you have:
- ✅ **Application ID** (from service principal setup script)
- ✅ **Service Principal Object ID** (from service principal setup script)
- ✅ **Environment URLs** for Dev and Prod
- ✅ **Power Platform Administrator** access
- ✅ **Admin consent granted** for API permissions

#### **⚡ Quick Fix Script**

If you're still having issues, try this verification script:

```powershell
# Quick verification script
param(
    [string]$ApplicationId,
    [string]$TenantId,
    [string]$EnvironmentUrl
)

Write-Host "🔍 Verifying Service Principal Setup..." -ForegroundColor Cyan

# Check if service principal exists in Azure AD
try {
    Connect-AzAccount -TenantId $TenantId -ErrorAction Stop
    $sp = Get-AzADServicePrincipal -ApplicationId $ApplicationId -ErrorAction Stop
    Write-Host "✅ Service Principal found in Azure AD: $($sp.DisplayName)" -ForegroundColor Green
    Write-Host "   Object ID: $($sp.Id)" -ForegroundColor Yellow
} catch {
    Write-Host "❌ Service Principal not found in Azure AD" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test Power Platform authentication
try {
    Write-Host "🔑 Testing Power Platform authentication..." -ForegroundColor Cyan
    pac auth create --url $EnvironmentUrl --applicationId $ApplicationId --tenant $TenantId
    Write-Host "✅ Authentication successful" -ForegroundColor Green
} catch {
    Write-Host "❌ Authentication failed" -ForegroundColor Red
    Write-Host "   This indicates the service principal is not properly added to the environment" -ForegroundColor Red
}
```

**Usage:**
```powershell
.\verify-sp-setup.ps1 -ApplicationId "your-app-id" -TenantId "your-tenant-id" -EnvironmentUrl "https://yourdev.crm.dynamics.com"
```

## 🔄 Deployment Process

### Automated Deployment Flow

1. **Export** solution from Development environment
2. **Unpack** solution for version control
3. **Pack** solution as managed
4. **Run** Solution Checker for quality validation
5. **Import** managed solution to Production environment
6. **Validate** deployment success

### Manual Deployment (PowerShell)

You can also run deployments manually using the provided scripts:

```powershell
# Export solution
.\scripts\export-solution.ps1 -EnvironmentUrl "https://yourdev.crm.dynamics.com" -SolutionName "YourSolution" -ClientId "your-app-id" -ClientSecret "your-secret" -TenantId "your-tenant"

# Pack as managed
.\scripts\pack-solution.ps1 -SolutionFolder ".\out\solutions\YourSolution" -OutputPath ".\out\YourSolution_managed.zip" -Managed $true

# Import to production
.\scripts\import-solution.ps1 -EnvironmentUrl "https://yourprod.crm.dynamics.com" -SolutionPath ".\out\YourSolution_managed.zip" -ClientId "your-app-id" -ClientSecret "your-secret" -TenantId "your-tenant"

# Validate deployment
.\scripts\validate-deployment.ps1 -EnvironmentUrl "https://yourprod.crm.dynamics.com" -SolutionName "YourSolution" -ClientId "your-app-id" -ClientSecret "your-secret" -TenantId "your-tenant"
```

## 🛡️ Security Best Practices

- ✅ Store secrets in GitHub Secrets or Azure Key Vault
- ✅ Use Service Principal authentication (not user accounts)
- ✅ Grant minimum required permissions
- ✅ Rotate client secrets regularly
- ✅ Monitor deployment logs for security events
- ✅ Use managed solutions in production
- ✅ Enable audit logging in Power Platform

## 📊 Monitoring & Troubleshooting

### Deployment Logs

- GitHub Actions: Check the **Actions** tab in your repository
- Azure DevOps: View pipeline runs in **Pipelines** section

### Common Issues

1. **Authentication Failed**
   - Verify service principal credentials
   - Check API permissions are granted
   - Ensure service principal has environment access

2. **Solution Import Failed**
   - Check for missing dependencies
   - Verify solution compatibility
   - Review solution checker warnings

3. **Pipeline Permissions**
   - Verify GitHub secrets are set correctly
   - Check environment protection rules

### Debug Commands

```powershell
# Check authentication
pac auth list

# Verify environment access
pac admin list

# Check solution dependencies
pac solution check --path YourSolution.zip
```

## 🔄 Branching Strategy

- **main**: Production deployments
- **develop**: Development work
- **feature/***: Feature branches
- **hotfix/***: Production hotfixes

## 📈 Advanced Features

### Environment-Specific Configuration

The pipeline supports deploying different configurations per environment by using environment-specific parameter files.

### Solution Versioning

Solutions are automatically versioned using semantic versioning based on:
- Major: Breaking changes
- Minor: New features
- Patch: Bug fixes

### Rollback Strategy

To rollback a deployment:
1. Navigate to Power Platform Admin Center
2. Select the environment
3. Go to Solutions
4. Delete the problematic solution version
5. Previous version will remain active

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For issues and questions:
- Check the troubleshooting section above
- Review GitHub Actions logs
- Open an issue in this repository
- Consult Power Platform documentation

---

**Happy Deploying! 🚀**
