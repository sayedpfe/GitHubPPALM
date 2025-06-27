# Environment Compatibility Check Script
# This script checks if your Power Platform environment is ready for agent deployment

param(
    [Parameter(Mandatory=$true)]
    [string]$EnvironmentUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantId
)

Write-Host "🔍 Power Platform Environment Compatibility Check" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# Install required PowerShell modules
$requiredModules = @(
    "Microsoft.PowerApps.Administration.PowerShell",
    "Microsoft.PowerApps.PowerShell"
)

foreach ($module in $requiredModules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing module: $module" -ForegroundColor Yellow
        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
    }
}

try {
    # Connect to Power Platform
    Write-Host "`n🔐 Authenticating to Power Platform..." -ForegroundColor Cyan
    Add-PowerAppsAccount -TenantID $TenantId -ApplicationId $ClientId -ClientSecret $ClientSecret -Endpoint prod
    
    # Get environment details
    $environmentName = $EnvironmentUrl.Split('/')[2].Split('.')[0]
    $environment = Get-AdminPowerAppEnvironment | Where-Object { $_.EnvironmentName -like "*$environmentName*" -or $_.DisplayName -like "*$environmentName*" }
    
    if (!$environment) {
        Write-Error "❌ Environment not found for URL: $EnvironmentUrl"
        exit 1
    }
    
    Write-Host "✅ Found environment: $($environment.DisplayName)" -ForegroundColor Green
    
    # Check environment type
    Write-Host "`n📋 Environment Information:" -ForegroundColor Cyan
    Write-Host "   Name: $($environment.DisplayName)" -ForegroundColor White
    Write-Host "   Type: $($environment.EnvironmentType)" -ForegroundColor White
    Write-Host "   Region: $($environment.Location.Name)" -ForegroundColor White
    Write-Host "   State: $($environment.States.Management.Id)" -ForegroundColor White
    
    # Determine if it's a managed environment
    $isManaged = $environment.GovernanceConfiguration.ProtectionLevel -eq "Standard" -or 
                 $environment.Internal.Properties.governanceConfiguration.protectionLevel -eq "Standard"
    
    if ($isManaged) {
        Write-Host "   Environment Type: 🛡️ MANAGED ENVIRONMENT" -ForegroundColor Yellow
        Write-Host "   Protection Level: Enhanced" -ForegroundColor Yellow
    } else {
        Write-Host "   Environment Type: 📂 STANDARD ENVIRONMENT" -ForegroundColor Green
        Write-Host "   Protection Level: Basic" -ForegroundColor Green
    }
    
    # Check service principal permissions
    Write-Host "`n🔑 Checking Service Principal Permissions..." -ForegroundColor Cyan
    
    try {
        $roleAssignments = Get-AdminPowerAppRoleAssignment -EnvironmentName $environment.EnvironmentName -PrincipalObjectId $ClientId
        
        if ($roleAssignments) {
            Write-Host "✅ Service Principal has environment access" -ForegroundColor Green
            foreach ($role in $roleAssignments) {
                Write-Host "   Role: $($role.RoleDisplayName)" -ForegroundColor White
            }
        } else {
            Write-Warning "⚠️ Service Principal may not have environment access"
            Write-Host "   Please add the service principal to the environment with Environment Maker role" -ForegroundColor Yellow
        }
    } catch {
        Write-Warning "⚠️ Could not check service principal permissions: $($_.Exception.Message)"
    }
    
    # Check DLP policies (for managed environments)
    if ($isManaged) {
        Write-Host "`n🛡️ Checking DLP Policies (Managed Environment)..." -ForegroundColor Cyan
        
        try {
            $dlpPolicies = Get-AdminDlpPolicy -EnvironmentName $environment.EnvironmentName
            
            if ($dlpPolicies) {
                Write-Host "📋 Found $($dlpPolicies.Count) DLP policy(ies)" -ForegroundColor Yellow
                
                foreach ($policy in $dlpPolicies) {
                    Write-Host "   Policy: $($policy.DisplayName)" -ForegroundColor White
                    Write-Host "   Type: $($policy.Type)" -ForegroundColor Gray
                }
                
                Write-Host "`n⚠️ Important for Managed Environments:" -ForegroundColor Yellow
                Write-Host "   • Ensure Teams connector is in Business/Non-Business group" -ForegroundColor Gray
                Write-Host "   • Verify HTTP connector permissions for website integration" -ForegroundColor Gray
                Write-Host "   • Check Power Platform connector is allowed" -ForegroundColor Gray
                
            } else {
                Write-Host "✅ No DLP policies found" -ForegroundColor Green
            }
        } catch {
            Write-Warning "⚠️ Could not check DLP policies: $($_.Exception.Message)"
        }
    }
    
    # Check Copilot Studio availability
    Write-Host "`n🤖 Checking Copilot Studio Availability..." -ForegroundColor Cyan
    
    try {
        # Try to list chatbots to verify Copilot Studio is available
        $headers = @{
            'Authorization' = "Bearer $((Get-PowerAppsAccount).AccessToken)"
            'Content-Type' = 'application/json'
        }
        
        $agentsUrl = "https://api.powerplatform.com/appmanagement/environments/$($environment.EnvironmentName)/chatbots"
        $agentsResponse = Invoke-RestMethod -Uri $agentsUrl -Headers $headers -Method Get
        
        Write-Host "✅ Copilot Studio is available" -ForegroundColor Green
        Write-Host "   Found $($agentsResponse.value.Count) existing agent(s)" -ForegroundColor White
        
        if ($agentsResponse.value.Count -gt 0) {
            Write-Host "   Existing agents:" -ForegroundColor Cyan
            foreach ($agent in $agentsResponse.value) {
                Write-Host "   • $($agent.displayName)" -ForegroundColor Gray
            }
        }
        
    } catch {
        Write-Warning "⚠️ Could not verify Copilot Studio availability: $($_.Exception.Message)"
        Write-Host "   This might indicate Copilot Studio is not enabled in this environment" -ForegroundColor Yellow
    }
    
    # Check required APIs and connectors
    Write-Host "`n🔌 Checking Required Connectors..." -ForegroundColor Cyan
    
    $requiredConnectors = @(
        @{ Name = "Microsoft Teams"; Id = "teams"; Purpose = "Teams integration" },
        @{ Name = "HTTP"; Id = "http"; Purpose = "Website integration" },
        @{ Name = "Power Platform"; Id = "powerplatform"; Purpose = "Agent management" }
    )
    
    foreach ($connector in $requiredConnectors) {
        Write-Host "   $($connector.Name): $($connector.Purpose)" -ForegroundColor White
    }
    
    if ($isManaged) {
        Write-Host "   ⚠️ For managed environments, verify these connectors are properly classified in DLP policies" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ Standard environment - connectors should be available by default" -ForegroundColor Green
    }
    
    # Summary and recommendations
    Write-Host "`n📊 COMPATIBILITY SUMMARY" -ForegroundColor Green
    Write-Host "========================" -ForegroundColor Green
    
    Write-Host "✅ Environment found and accessible" -ForegroundColor Green
    Write-Host "✅ Authentication successful" -ForegroundColor Green
    
    if ($isManaged) {
        Write-Host "🛡️ Managed Environment detected" -ForegroundColor Yellow
        Write-Host "`n📝 Managed Environment Checklist:" -ForegroundColor Cyan
        Write-Host "   □ Review DLP policies for required connectors" -ForegroundColor White
        Write-Host "   □ Ensure service principal has sufficient permissions" -ForegroundColor White
        Write-Host "   □ Configure environment security groups if needed" -ForegroundColor White
        Write-Host "   □ Set up approval processes if required" -ForegroundColor White
    } else {
        Write-Host "📂 Standard Environment - Ready for deployment!" -ForegroundColor Green
    }
    
    Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Deploy your Power Platform solution with the agent" -ForegroundColor White
    Write-Host "   2. Run the automated deployment pipeline" -ForegroundColor White
    Write-Host "   3. Monitor the agent publishing and configuration" -ForegroundColor White
    
} catch {
    Write-Error "❌ Error during environment check: $($_.Exception.Message)"
    exit 1
}

Write-Host "`n✅ Environment compatibility check completed!" -ForegroundColor Green
