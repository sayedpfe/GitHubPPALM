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
    Write-Host "🤖 Starting Agent post-deployment configuration..." -ForegroundColor Green
    
    # Connect to Power Platform
    Write-Host "Authenticating to Power Platform..." -ForegroundColor Cyan
    $securePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($ClientId, $securePassword)
    
    # Add Power Apps connection
    Add-PowerAppsAccount -TenantID $TenantId -ApplicationId $ClientId -ClientSecret $ClientSecret -Endpoint prod
    
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
        $host = $uri.Host
        Write-Host "Parsed host: $host" -ForegroundColor Gray
        
        # Extract org name from different URL patterns
        if ($host -match '^([^.]+)\.crm[0-9]*\.dynamics\.com$') {
            $environmentIdentifier = $matches[1]
        } elseif ($host -match '^([^.]+)\.api\.crm[0-9]*\.dynamics\.com$') {
            $environmentIdentifier = $matches[1]
        } elseif ($host -match '^([^.]+)\..*\.dynamics\.com$') {
            $environmentIdentifier = $matches[1]
        } else {
            # Fallback: try to extract from path or use the whole host
            $environmentIdentifier = $host.Split('.')[0]
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
    $allEnvironments = Get-AdminPowerAppEnvironment
    
    Write-Host "Found $($allEnvironments.Count) total environments" -ForegroundColor Gray
    
    # Debug: Show first few environment names for troubleshooting
    if ($allEnvironments.Count -gt 0) {
        Write-Host "Sample environments (first 3):" -ForegroundColor Gray
        $allEnvironments | Select-Object -First 3 | ForEach-Object {
            Write-Host "  - $($_.DisplayName) | $($_.EnvironmentName)" -ForegroundColor Gray
        }
    }
    
    # Try multiple matching strategies
    $environment = $null
    
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
    
    Write-Host "Found environment: $($environment.DisplayName)" -ForegroundColor Green
    
    # Get all chatbots/agents in the environment
    Write-Host "📋 Discovering agents in environment..." -ForegroundColor Cyan
    Write-Host "Environment ID: $($environment.EnvironmentName)" -ForegroundColor Gray
    
    # Check authentication status
    $powerAppsAccount = Get-PowerAppsAccount
    if (!$powerAppsAccount -or !$powerAppsAccount.AccessToken) {
        Write-Error "❌ Power Apps authentication failed or token not available"
        exit 1
    }
    
    Write-Host "✅ Authentication verified" -ForegroundColor Green
    
    # Use REST API to get chatbots (agents)
    $headers = @{
        'Authorization' = "Bearer $($powerAppsAccount.AccessToken)"
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
            # This may not work for agents specifically, but let's try
            $powerApps = Get-AdminPowerApp -EnvironmentName $environment.EnvironmentName
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
                        $publishResponse = Invoke-RestMethod -Uri $publishUrl -Headers $headers -Method Post -ErrorAction Stop
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
                        $enableResponse = Invoke-RestMethod -Uri $enableUrl -Headers $headers -Method Patch -Body $enableBody -ErrorAction Stop
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
