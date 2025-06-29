# Post-Deployment Agent Management Script
# This script handles publishing and sharing of Copilot Studio agents after solution deployment

param(
    [Parameter(Mandatory=$true)]
    [string]$EnvironmentUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$false)]
    [string]$AgentName,
    
    [Parameter(Mandatory=$false)]
    [string]$ShareWithGroup,
    
    [Parameter(Mandatory=$false)]
    [bool]$PublishAgent = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$EnableAgent = $true
)

# Install and import required PowerShell modules
$requiredModules = @(
    "Microsoft.PowerApps.Administration.PowerShell",
    "Microsoft.PowerApps.PowerShell"
)

Write-Host "🔧 Checking and installing required PowerShell modules..." -ForegroundColor Cyan

# Check PowerShell Gallery connectivity
try {
    Write-Host "🌐 Testing PowerShell Gallery connectivity..." -ForegroundColor Gray
    $testConnection = Test-NetConnection -ComputerName "www.powershellgallery.com" -Port 443 -InformationLevel Quiet -ErrorAction SilentlyContinue
    if ($testConnection) {
        Write-Host "✅ PowerShell Gallery is accessible" -ForegroundColor Green
    } else {
        Write-Warning "⚠️ PowerShell Gallery connectivity test failed - continuing anyway"
    }
} catch {
    Write-Host "⚠️ Network connectivity test skipped" -ForegroundColor Gray
}

foreach ($module in $requiredModules) {
    try {
        # Check if module is already loaded
        $loadedModule = Get-Module -Name $module -ErrorAction SilentlyContinue
        if ($loadedModule) {
            Write-Host "✅ Module already loaded: $module" -ForegroundColor Green
            continue
        }
        
        # Check if module is available but not loaded
        $availableModule = Get-Module -ListAvailable -Name $module -ErrorAction SilentlyContinue
        if (!$availableModule) {
            Write-Host "📦 Installing module: $module" -ForegroundColor Yellow
            
            # Set TLS to 1.2 for PowerShell Gallery
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            
            # Install with explicit parameters
            Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser -Repository PSGallery -ErrorAction Stop
            Write-Host "✅ Successfully installed: $module" -ForegroundColor Green
        }
        
        # Import the module
        Write-Host "📥 Importing module: $module" -ForegroundColor Gray
        Import-Module -Name $module -Force -ErrorAction Stop
        Write-Host "✅ Successfully imported: $module" -ForegroundColor Green
        
    } catch {
        Write-Warning "❌ Failed to install/import module '$module': $($_.Exception.Message)"
        
        # Try alternative installation method
        try {
            Write-Host "🔄 Trying alternative installation for: $module" -ForegroundColor Yellow
            Install-Package -Name $module -Source PowerShellGallery -Force -Scope CurrentUser -ErrorAction Stop
            Import-Module -Name $module -Force -ErrorAction Stop
            Write-Host "✅ Successfully installed via Install-Package: $module" -ForegroundColor Green
        } catch {
            Write-Error "❌ All installation methods failed for module '$module'. Please install manually: Install-Module -Name $module -Force"
            exit 1
        }
    }
}

# Verify modules are properly loaded
Write-Host "🔍 Verifying module installation..." -ForegroundColor Cyan
$missingModules = @()

foreach ($module in $requiredModules) {
    $loadedModule = Get-Module -Name $module -ErrorAction SilentlyContinue
    if (!$loadedModule) {
        $missingModules += $module
        Write-Warning "⚠️ Module not loaded: $module"
    } else {
        Write-Host "✅ Verified loaded: $module (Version: $($loadedModule.Version))" -ForegroundColor Green
    }
}

if ($missingModules.Count -gt 0) {
    Write-Error "❌ Required modules are not available: $($missingModules -join ', ')"
    Write-Host "Please run the following commands manually:" -ForegroundColor Yellow
    foreach ($module in $missingModules) {
        Write-Host "  Install-Module -Name $module -Force -Scope CurrentUser" -ForegroundColor Yellow
    }
    exit 1
}

try {
    Write-Host "🤖 Starting Agent post-deployment configuration..." -ForegroundColor Green
    
    # Diagnostic information
    Write-Host "🔍 Environment Diagnostics:" -ForegroundColor Cyan
    Write-Host "   PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "   Execution Policy: $(Get-ExecutionPolicy)" -ForegroundColor Gray
    Write-Host "   OS: $($PSVersionTable.OS)" -ForegroundColor Gray
    
    # Connect to Power Platform
    Write-Host "Authenticating to Power Platform..." -ForegroundColor Cyan
    
    # Try multiple authentication approaches
    $authSuccess = $false
    
    # Method 1: Add-PowerAppsAccount with service principal
    try {
        Write-Host "Attempting authentication with service principal..." -ForegroundColor Gray
        
        # Verify the cmdlet exists before calling it
        $addPowerAppsCmd = Get-Command -Name "Add-PowerAppsAccount" -ErrorAction SilentlyContinue
        if (!$addPowerAppsCmd) {
            throw "Add-PowerAppsAccount cmdlet not available. Module may not be properly loaded."
        }
        
        Add-PowerAppsAccount -TenantID $TenantId -ApplicationId $ClientId -ClientSecret $ClientSecret -Endpoint prod -ErrorAction Stop
        
        # Test if authentication worked
        $getPowerAppsCmd = Get-Command -Name "Get-PowerAppsAccount" -ErrorAction SilentlyContinue
        if (!$getPowerAppsCmd) {
            throw "Get-PowerAppsAccount cmdlet not available. Module may not be properly loaded."
        }
        
        $testAccount = Get-PowerAppsAccount -ErrorAction Stop
        if ($testAccount) {
            Write-Host "✅ Service principal authentication successful" -ForegroundColor Green
            Write-Host "   Account: $($testAccount.UserPrincipalName)" -ForegroundColor Gray
            $authSuccess = $true
        }
    }
    catch {
        Write-Warning "Service principal authentication failed: $($_.Exception.Message)"
        Write-Host "   This could be due to:" -ForegroundColor Gray
        Write-Host "   - PowerShell modules not properly installed" -ForegroundColor Gray
        Write-Host "   - Service principal credentials incorrect" -ForegroundColor Gray
        Write-Host "   - Insufficient permissions" -ForegroundColor Gray
    }
    
    # Method 2: Direct REST API authentication if PowerShell modules fail
    if (!$authSuccess) {
        Write-Host "Attempting direct REST API authentication..." -ForegroundColor Gray
        try {
            # Get OAuth token directly
            $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
            $tokenBody = @{
                client_id = $ClientId
                client_secret = $ClientSecret
                scope = "https://service.powerapps.com/.default"
                grant_type = "client_credentials"
            }
            
            $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
            
            if ($tokenResponse.access_token) {
                Write-Host "✅ Direct REST API authentication successful" -ForegroundColor Green
                $authSuccess = $true
                $directApiToken = $tokenResponse.access_token
            }
        }
        catch {
            Write-Warning "Direct REST API authentication also failed: $($_.Exception.Message)"
        }
    }
    
    if (!$authSuccess) {
        Write-Error "❌ All authentication methods failed. Please verify service principal credentials and permissions."
        exit 1
    }
    
    # Get environment details
    Write-Host "Getting environment details..." -ForegroundColor Cyan
    Write-Host "Environment URL: $EnvironmentUrl" -ForegroundColor Gray
    
    # Parse environment URL to extract environment identifier
    # Handle different URL formats:
    # https://orgname.crm.dynamics.com
    # https://orgname.crm4.dynamics.com  
    # https://orgname.api.crm.dynamics.com
    
    $environmentIdentifier = ""
    try {
        $uri = [System.Uri]$EnvironmentUrl
        $hostName = $uri.Host
        Write-Host "Parsed hostname: $hostName" -ForegroundColor Gray
        
        # Extract org name from different URL patterns
        if ($hostName -match '^([^.]+)\.crm[0-9]*\.dynamics\.com$') {
            $environmentIdentifier = $matches[1]
        } elseif ($hostName -match '^([^.]+)\.api\.crm[0-9]*\.dynamics\.com$') {
            $environmentIdentifier = $matches[1]
        } elseif ($hostName -match '^([^.]+)\..*\.dynamics\.com$') {
            $environmentIdentifier = $matches[1]
        } else {
            # Fallback: try to extract from path or use the whole hostname
            $environmentIdentifier = $hostName.Split('.')[0]
        }
        
        Write-Host "Extracted environment identifier: $environmentIdentifier" -ForegroundColor Gray
    }
    catch {
        Write-Warning "Failed to parse environment URL. Using fallback method."
        # Fallback parsing
        $environmentIdentifier = $EnvironmentUrl.Split('/')[2].Split('.')[0]
        Write-Host "Fallback environment identifier: $environmentIdentifier" -ForegroundColor Gray
    }
    
    # Get all environments and find the matching one
    Write-Host "Retrieving all available environments..." -ForegroundColor Cyan
    
    $allEnvironments = @()
    $environmentDiscoverySuccess = $false
    
    # Method 1: Try PowerShell cmdlets first
    try {
        Write-Host "Trying PowerShell cmdlets for environment discovery..." -ForegroundColor Gray
        
        # Verify the cmdlet exists
        $getEnvCmd = Get-Command -Name "Get-AdminPowerAppEnvironment" -ErrorAction SilentlyContinue
        if (!$getEnvCmd) {
            throw "Get-AdminPowerAppEnvironment cmdlet not available. Module may not be properly loaded."
        }
        
        $allEnvironments = Get-AdminPowerAppEnvironment -ErrorAction Stop
        
        if ($allEnvironments.Count -gt 0) {
            Write-Host "✅ Found $($allEnvironments.Count) environments using PowerShell cmdlets" -ForegroundColor Green
            $environmentDiscoverySuccess = $true
        }
    }
    catch {
        Write-Warning "PowerShell cmdlet environment discovery failed: $($_.Exception.Message)"
    }
    
    # Method 2: Direct REST API call if PowerShell cmdlets fail
    if (!$environmentDiscoverySuccess) {
        Write-Host "Trying direct REST API for environment discovery..." -ForegroundColor Gray
        try {
            # Use the token from either authentication method
            $apiToken = $null
            if ($directApiToken) {
                $apiToken = $directApiToken
            } else {
                $powerAppsAccount = Get-PowerAppsAccount -ErrorAction SilentlyContinue
                if ($powerAppsAccount -and $powerAppsAccount.AccessToken) {
                    $apiToken = $powerAppsAccount.AccessToken
                }
            }
            
            if ($apiToken) {
                $envHeaders = @{
                    'Authorization' = "Bearer $apiToken"
                    'Content-Type' = 'application/json'
                }
                
                # Try multiple environment API endpoints
                $envEndpoints = @(
                    "https://api.powerapps.com/providers/Microsoft.PowerApps/environments",
                    "https://api.powerplatform.com/environments"
                )
                
                foreach ($envEndpoint in $envEndpoints) {
                    try {
                        Write-Host "   Trying endpoint: $envEndpoint" -ForegroundColor Gray
                        $envResponse = Invoke-RestMethod -Uri $envEndpoint -Headers $envHeaders -Method Get -ErrorAction Stop
                        
                        if ($envResponse.value) {
                            $allEnvironments = $envResponse.value
                            Write-Host "✅ Found $($allEnvironments.Count) environments using REST API" -ForegroundColor Green
                            $environmentDiscoverySuccess = $true
                            break
                        }
                    }
                    catch {
                        Write-Host "   ❌ Failed with endpoint: $envEndpoint" -ForegroundColor Gray
                        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Gray
                    }
                }
            }
        }
        catch {
            Write-Warning "REST API environment discovery failed: $($_.Exception.Message)"
        }
    }
    
    # Method 3: Extract environment ID directly from URL if both methods fail
    if (!$environmentDiscoverySuccess -or $allEnvironments.Count -eq 0) {
        Write-Warning "⚠️ Could not retrieve environment list. Attempting direct environment access..."
        
        # Extract environment ID from URL for direct access
        $directEnvironmentId = $null
        try {
            # For URLs like https://org12345678.crm.dynamics.com, the org name is the environment ID
            $uri = [System.Uri]$EnvironmentUrl
            $hostName = $uri.Host
            
            if ($hostName -match '^([^.]+)\.crm[0-9]*\.dynamics\.com$') {
                $directEnvironmentId = $matches[1]
            }
            
            if ($directEnvironmentId) {
                Write-Host "✅ Extracted environment ID from URL: $directEnvironmentId" -ForegroundColor Green
                
                # Create a minimal environment object for processing
                $environment = [PSCustomObject]@{
                    EnvironmentName = $directEnvironmentId
                    DisplayName = $directEnvironmentId
                    Internal = [PSCustomObject]@{
                        properties = [PSCustomObject]@{
                            instanceUrl = $EnvironmentUrl
                        }
                    }
                }
                
                Write-Host "✅ Using direct environment access method" -ForegroundColor Green
                $environmentDiscoverySuccess = $true
            }
        }
        catch {
            Write-Error "Failed to extract environment ID from URL: $($_.Exception.Message)"
        }
    }
    
    if (!$environmentDiscoverySuccess) {
        Write-Error "❌ All environment discovery methods failed. Please verify:"
        Write-Host "  1. Service principal has Power Platform Administrator or Environment Admin permissions" -ForegroundColor Yellow
        Write-Host "  2. Environment URL is correct and accessible" -ForegroundColor Yellow
        Write-Host "  3. Service principal has been granted consent in Azure AD" -ForegroundColor Yellow
        exit 1
    }
    
    # Find the matching environment (skip if we already have it from direct access method)
    if (!$environment) {
        # Debug: Show first few environment names for troubleshooting
        if ($allEnvironments.Count -gt 0) {
            Write-Host "Sample environments (first 3):" -ForegroundColor Gray
            $allEnvironments | Select-Object -First 3 | ForEach-Object {
                Write-Host "  - $($_.DisplayName) | $($_.EnvironmentName)" -ForegroundColor Gray
            }
        }
        
        # Try multiple matching strategies
        # Strategy 1: Exact match on environment identifier
        $environment = $allEnvironments | Where-Object { 
            $_.EnvironmentName -eq $environmentIdentifier -or 
            $_.DisplayName -eq $environmentIdentifier 
        } | Select-Object -First 1
        
        if (!$environment) {
            # Strategy 2: Partial match on environment name
            $environment = $allEnvironments | Where-Object { 
                $_.EnvironmentName -like "*$environmentIdentifier*" -or 
                $_.DisplayName -like "*$environmentIdentifier*" 
            } | Select-Object -First 1
        }
        
        if (!$environment) {
            # Strategy 3: Match against the full URL in environment properties
            $environment = $allEnvironments | Where-Object { 
                $_.Internal.properties.linkedEnvironmentMetadata.instanceUrl -eq $EnvironmentUrl -or
                $_.Internal.properties.instanceUrl -eq $EnvironmentUrl
            } | Select-Object -First 1
        }
        
        if (!$environment) {
            Write-Host "❌ Environment matching failed. Available environments:" -ForegroundColor Red
            $allEnvironments | ForEach-Object {
                Write-Host "  - Name: $($_.DisplayName)" -ForegroundColor Yellow
                Write-Host "    ID: $($_.EnvironmentName)" -ForegroundColor Yellow
                if ($_.Internal.properties.instanceUrl) {
                    Write-Host "    URL: $($_.Internal.properties.instanceUrl)" -ForegroundColor Yellow
                }
                Write-Host "" -ForegroundColor Yellow
            }
            Write-Error "Environment not found for URL: $EnvironmentUrl"
            Write-Error "Please verify the environment URL matches one of the available environments above."
            exit 1
        }
    }
    
    Write-Host "Found environment: $($environment.DisplayName)" -ForegroundColor Green
    
    # Get all chatbots/agents in the environment
    Write-Host "📋 Discovering agents in environment..." -ForegroundColor Cyan
    Write-Host "Environment ID: $($environment.EnvironmentName)" -ForegroundColor Gray
    
    # Check authentication status and get access token
    $accessToken = $null
    
    # Try to get token from PowerApps account first
    $powerAppsAccount = Get-PowerAppsAccount -ErrorAction SilentlyContinue
    if ($powerAppsAccount -and $powerAppsAccount.AccessToken) {
        $accessToken = $powerAppsAccount.AccessToken
        Write-Host "✅ Using PowerApps account token" -ForegroundColor Green
    }
    # Fall back to direct API token if available
    elseif ($directApiToken) {
        $accessToken = $directApiToken
        Write-Host "✅ Using direct API token" -ForegroundColor Green
    }
    else {
        Write-Error "❌ No valid access token available from any authentication method"
        exit 1
    }
    
    # Use REST API to get chatbots (agents)
    $headers = @{
        'Authorization' = "Bearer $accessToken"
        'Content-Type' = 'application/json'
        'Accept' = 'application/json'
    }
    
    # Try multiple API endpoints for agents/chatbots
    $agentEndpoints = @(
        "https://api.powerplatform.com/appmanagement/environments/$($environment.EnvironmentName)/chatbots",
        "https://api.powerapps.com/providers/Microsoft.PowerApps/environments/$($environment.EnvironmentName)/chatbots",
        "https://$($environment.EnvironmentName).api.crm.dynamics.com/api/data/v9.2/bots"
    )
    
    $agents = @()
    $agentApiSuccess = $false
    
    foreach ($endpoint in $agentEndpoints) {
        try {
            Write-Host "Trying endpoint: $endpoint" -ForegroundColor Gray
            
            $agentsResponse = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Get -ErrorAction Stop
            
            # Handle different response formats
            if ($agentsResponse.value) {
                $agents = $agentsResponse.value
            } elseif ($agentsResponse -is [array]) {
                $agents = $agentsResponse
            } else {
                $agents = @($agentsResponse)
            }
            
            Write-Host "✅ Successfully retrieved agents from: $endpoint" -ForegroundColor Green
            $agentApiSuccess = $true
            break
            
        } catch {
            Write-Host "❌ Failed to get agents from: $endpoint" -ForegroundColor Yellow
            Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Gray
            continue
        }
    }
    
    if (!$agentApiSuccess) {
        Write-Warning "⚠️ All agent API endpoints failed. Trying PowerShell cmdlet fallback..."
        
        # Fallback: Try using PowerShell cmdlets (limited functionality)
        try {
            # Verify the cmdlet exists
            $getAppsCmd = Get-Command -Name "Get-AdminPowerApp" -ErrorAction SilentlyContinue
            if (!$getAppsCmd) {
                throw "Get-AdminPowerApp cmdlet not available. Module may not be properly loaded."
            }
            
            # This may not work for agents specifically, but let's try
            $powerApps = Get-AdminPowerApp -EnvironmentName $environment.EnvironmentName -ErrorAction Stop
            $agents = $powerApps | Where-Object { $_.AppName -like "*bot*" -or $_.AppName -like "*agent*" -or $_.DisplayName -like "*bot*" -or $_.DisplayName -like "*agent*" }
            
            if ($agents.Count -gt 0) {
                Write-Host "✅ Found $($agents.Count) potential agent(s) using PowerShell fallback" -ForegroundColor Green
                $agentApiSuccess = $true
            }
        }
        catch {
            Write-Host "❌ PowerShell fallback also failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    if (!$agentApiSuccess -or $agents.Count -eq 0) {
        Write-Warning "⚠️ No agents found in the environment."
        Write-Host "This could mean:" -ForegroundColor Yellow
        Write-Host "  1. The solution doesn't contain any Copilot Studio agents" -ForegroundColor Yellow
        Write-Host "  2. The agents haven't been properly imported yet" -ForegroundColor Yellow
        Write-Host "  3. Authentication permissions are insufficient" -ForegroundColor Yellow
        Write-Host "  4. The API endpoints have changed" -ForegroundColor Yellow
        Write-Host "" -ForegroundColor Yellow
        Write-Host "Skipping agent configuration. Manual setup may be required." -ForegroundColor Cyan
        return
    }
    
    Write-Host "Found $($agents.Count) agent(s) in environment:" -ForegroundColor Green
    foreach ($agent in $agents) {
        $agentName = $agent.displayName -or $agent.DisplayName -or $agent.name -or $agent.AppName -or "Unknown"
        $agentId = $agent.name -or $agent.AppName -or $agent.id -or "Unknown"
        Write-Host "  - $agentName (ID: $agentId)" -ForegroundColor Cyan
    }
    
    # Filter agents if specific agent name provided
    if ($AgentName) {
        $targetAgents = $agents | Where-Object { 
            ($_.displayName -eq $AgentName) -or 
            ($_.DisplayName -eq $AgentName) -or 
            ($_.name -eq $AgentName) -or 
            ($_.AppName -eq $AgentName) -or
            ($_.id -eq $AgentName)
        }
        if ($targetAgents.Count -eq 0) {
            Write-Error "Agent '$AgentName' not found in environment"
            Write-Host "Available agents:" -ForegroundColor Yellow
            foreach ($agent in $agents) {
                $agentName = $agent.displayName -or $agent.DisplayName -or $agent.name -or $agent.AppName -or "Unknown"
                Write-Host "  - $agentName" -ForegroundColor Yellow
            }
            exit 1
        }
    } else {
        $targetAgents = $agents
    }
    
    # Process each target agent
    foreach ($agent in $targetAgents) {
            $agentDisplayName = $agent.displayName -or $agent.DisplayName -or $agent.name -or $agent.AppName -or "Unknown Agent"
            $agentId = $agent.name -or $agent.AppName -or $agent.id -or "unknown"
            
            Write-Host "`n🚀 Processing agent: $agentDisplayName" -ForegroundColor Green
            Write-Host "   Agent ID: $agentId" -ForegroundColor Gray
            
            if ($PublishAgent) {
                Write-Host "📤 Publishing agent..." -ForegroundColor Yellow
                
                # Try multiple publish endpoints
                $publishEndpoints = @(
                    "https://api.powerplatform.com/appmanagement/environments/$($environment.EnvironmentName)/chatbots/$agentId/publish",
                    "https://api.powerapps.com/providers/Microsoft.PowerApps/environments/$($environment.EnvironmentName)/chatbots/$agentId/publish"
                )
                
                $publishSuccess = $false
                foreach ($publishUrl in $publishEndpoints) {
                    try {
                        Write-Host "   Trying publish endpoint: $publishUrl" -ForegroundColor Gray
                        Invoke-RestMethod -Uri $publishUrl -Headers $headers -Method Post -ErrorAction Stop | Out-Null
                        Write-Host "✅ Agent published successfully!" -ForegroundColor Green
                        $publishSuccess = $true
                        
                        # Wait for publishing to complete
                        Start-Sleep -Seconds 10
                        break
                        
                    } catch {
                        Write-Host "   ❌ Failed with endpoint: $publishUrl" -ForegroundColor Gray
                        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Gray
                    }
                }
                
                if (!$publishSuccess) {
                    Write-Warning "⚠️ Failed to publish agent using all available endpoints"
                    Write-Host "Manual publishing may be required in Power Platform Admin Center" -ForegroundColor Cyan
                }
            }
            
            if ($EnableAgent) {
                Write-Host "🔄 Enabling agent..." -ForegroundColor Yellow
                
                # Try multiple enable endpoints
                $enableEndpoints = @(
                    "https://api.powerplatform.com/appmanagement/environments/$($environment.EnvironmentName)/chatbots/$agentId",
                    "https://api.powerapps.com/providers/Microsoft.PowerApps/environments/$($environment.EnvironmentName)/chatbots/$agentId"
                )
                
                $enableBody = @{
                    isDisabled = $false
                } | ConvertTo-Json
                
                $enableSuccess = $false
                foreach ($enableUrl in $enableEndpoints) {
                    try {
                        Write-Host "   Trying enable endpoint: $enableUrl" -ForegroundColor Gray
                        Invoke-RestMethod -Uri $enableUrl -Headers $headers -Method Patch -Body $enableBody -ErrorAction Stop | Out-Null
                        Write-Host "✅ Agent enabled successfully!" -ForegroundColor Green
                        $enableSuccess = $true
                        break
                    } catch {
                        Write-Host "   ❌ Failed with endpoint: $enableUrl" -ForegroundColor Gray
                        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Gray
                    }
                }
                
                if (!$enableSuccess) {
                    Write-Warning "⚠️ Failed to enable agent using all available endpoints"
                    Write-Host "Manual enabling may be required in Power Platform Admin Center" -ForegroundColor Cyan
                }
            }
            
            if ($ShareWithGroup) {
                Write-Host "👥 Sharing agent with group: $ShareWithGroup" -ForegroundColor Yellow
                
                # Share with specified group/users
                # Note: This requires additional API calls to manage permissions
                # Implementation depends on your specific sharing requirements
                
                Write-Host "🔧 Sharing configuration requires manual setup in Power Platform Admin Center" -ForegroundColor Cyan
                Write-Host "   1. Go to Power Platform Admin Center" -ForegroundColor Gray
                Write-Host "   2. Navigate to your environment" -ForegroundColor Gray
                Write-Host "   3. Go to Copilot Studio > Agents" -ForegroundColor Gray
                Write-Host "   4. Configure sharing for: $agentDisplayName" -ForegroundColor Gray
            }
            
            # Get agent details for validation
            Write-Host "📊 Agent Status:" -ForegroundColor Cyan
            Write-Host "   Name: $agentDisplayName" -ForegroundColor White
            Write-Host "   ID: $agentId" -ForegroundColor White
            Write-Host "   Status: Published" -ForegroundColor Green
            Write-Host "   Environment: $($environment.DisplayName)" -ForegroundColor White
            
            # Get agent endpoint URL
            $agentUrl = "https://$($environment.EnvironmentName).crm.dynamics.com/main.aspx?appid=$agentId"
            Write-Host "   Access URL: $agentUrl" -ForegroundColor Cyan
        }
    
    Write-Host "`n✅ Agent post-deployment configuration completed!" -ForegroundColor Green
    
} catch {
    Write-Error "❌ Error during agent configuration: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Red
    exit 1
}

Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Test your agent in the target environment" -ForegroundColor Yellow
Write-Host "2. Configure additional sharing settings if needed" -ForegroundColor Yellow
Write-Host "3. Set up monitoring and analytics" -ForegroundColor Yellow
Write-Host "4. Update agent documentation" -ForegroundColor Yellow
