# Setup Service Principal for Power Platform DevOps
# This script creates a service principal and configures it for Power Platform ALM operations

param(
    [Parameter(Mandatory=$true)]
    [string]$DisplayName = "PowerPlatform-DevOps-ServicePrincipal",
    
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$false)]
    [switch]$GrantAdminConsent
)

# Check if required modules are installed
$requiredModules = @(
    "Microsoft.PowerApps.Administration.PowerShell",
    "Microsoft.PowerApps.PowerShell", 
    "Az.Accounts",
    "Az.Resources"
)

foreach ($module in $requiredModules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing module: $module" -ForegroundColor Yellow
        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
    }
}

# Connect to Azure
Write-Host "Connecting to Azure..." -ForegroundColor Green
Connect-AzAccount -TenantId $TenantId

# Create App Registration
Write-Host "Creating App Registration..." -ForegroundColor Green
$appRegistration = New-AzADApplication -DisplayName $DisplayName

# Create Service Principal
Write-Host "Creating Service Principal..." -ForegroundColor Green
$servicePrincipal = New-AzADServicePrincipal -ApplicationId $appRegistration.AppId

# Create Client Secret
Write-Host "Creating Client Secret..." -ForegroundColor Green
$clientSecret = New-AzADAppCredential -ApplicationId $appRegistration.AppId -DisplayName "DevOps Secret"

# Required API permissions for Power Platform
$requiredResourceAccess = @(
    @{
        ResourceAppId = "00000007-0000-0000-c000-000000000000" # Dynamics CRM
        ResourceAccess = @(
            @{
                Id = "78ce3f0f-a1ce-49c2-8cde-64b5c0896db4" # user_impersonation
                Type = "Scope"
            }
        )
    }
)

# Update App Registration with required permissions
Write-Host "Configuring API Permissions..." -ForegroundColor Green
Update-AzADApplication -ApplicationId $appRegistration.AppId -RequiredResourceAccess $requiredResourceAccess

# Output important values
Write-Host "`n=== SERVICE PRINCIPAL DETAILS ===" -ForegroundColor Cyan
Write-Host "Application ID: $($appRegistration.AppId)" -ForegroundColor White
Write-Host "Tenant ID: $TenantId" -ForegroundColor White
Write-Host "Service Principal Object ID: $($servicePrincipal.Id)" -ForegroundColor White
Write-Host "Client Secret: $($clientSecret.SecretText)" -ForegroundColor White
Write-Host "Client Secret ID: $($clientSecret.KeyId)" -ForegroundColor White

Write-Host "`n=== NEXT STEPS ===" -ForegroundColor Cyan
Write-Host "1. Add the following secrets to your GitHub repository:" -ForegroundColor Yellow
Write-Host "   - POWER_PLATFORM_SP_APP_ID: $($appRegistration.AppId)"
Write-Host "   - POWER_PLATFORM_SP_CLIENT_SECRET: $($clientSecret.SecretText)"
Write-Host "   - POWER_PLATFORM_TENANT_ID: $TenantId"

Write-Host "`n2. Grant admin consent for the API permissions in Azure Portal:" -ForegroundColor Yellow
Write-Host "   - Navigate to Azure Portal > Azure Active Directory > App registrations"
Write-Host "   - Find your app: $DisplayName"
Write-Host "   - Go to API permissions and click 'Grant admin consent'"

Write-Host "`n3. Add the service principal to your Power Platform environments:" -ForegroundColor Yellow
Write-Host "   - Go to Power Platform Admin Center"
Write-Host "   - Select each environment (Dev, Test, Prod)"
Write-Host "   - Add user: $($appRegistration.AppId)"
Write-Host "   - Assign System Administrator role"

if ($GrantAdminConsent) {
    Write-Host "`nGranting admin consent..." -ForegroundColor Green
    # Note: This requires Global Admin privileges
    try {
        # This would require additional Azure AD admin permissions
        Write-Warning "Admin consent granting requires Global Admin privileges. Please grant manually in Azure Portal."
    }
    catch {
        Write-Warning "Failed to grant admin consent automatically. Please grant manually in Azure Portal."
    }
}

Write-Host "`nService Principal setup completed!" -ForegroundColor Green
