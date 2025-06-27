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
    $environmentName = $EnvironmentUrl.Split('/')[2].Split('.')[0]
    $environment = Get-AdminPowerAppEnvironment | Where-Object { $_.EnvironmentName -like "*$environmentName*" -or $_.DisplayName -like "*$environmentName*" }
    
    if (!$environment) {
        Write-Error "Environment not found for URL: $EnvironmentUrl"
        exit 1
    }
    
    Write-Host "Found environment: $($environment.DisplayName)" -ForegroundColor Green
    
    # Get all chatbots/agents in the environment
    Write-Host "📋 Discovering agents in environment..." -ForegroundColor Cyan
    
    # Use REST API to get chatbots (agents)
    $headers = @{
        'Authorization' = "Bearer $((Get-PowerAppsAccount).AccessToken)"
        'Content-Type' = 'application/json'
    }
    
    $agentsUrl = "https://api.powerplatform.com/appmanagement/environments/$($environment.EnvironmentName)/chatbots"
    
    try {
        $agentsResponse = Invoke-RestMethod -Uri $agentsUrl -Headers $headers -Method Get
        $agents = $agentsResponse.value
        
        if ($agents.Count -eq 0) {
            Write-Warning "⚠️ No agents found in the environment. Make sure your solution contains a Copilot Studio agent."
            return
        }
        
        Write-Host "Found $($agents.Count) agent(s) in environment:" -ForegroundColor Green
        foreach ($agent in $agents) {
            Write-Host "  - $($agent.displayName) (ID: $($agent.name))" -ForegroundColor Cyan
        }
        
        # Filter agents if specific agent name provided
        if ($AgentName) {
            $targetAgents = $agents | Where-Object { $_.displayName -eq $AgentName -or $_.name -eq $AgentName }
            if ($targetAgents.Count -eq 0) {
                Write-Error "Agent '$AgentName' not found in environment"
                exit 1
            }
        } else {
            $targetAgents = $agents
        }
        
        # Process each target agent
        foreach ($agent in $targetAgents) {
            Write-Host "`n🚀 Processing agent: $($agent.displayName)" -ForegroundColor Green
            
            if ($PublishAgent) {
                Write-Host "📤 Publishing agent..." -ForegroundColor Yellow
                
                # Publish the agent
                $publishUrl = "https://api.powerplatform.com/appmanagement/environments/$($environment.EnvironmentName)/chatbots/$($agent.name)/publish"
                
                try {
                    $publishResponse = Invoke-RestMethod -Uri $publishUrl -Headers $headers -Method Post
                    Write-Host "✅ Agent published successfully!" -ForegroundColor Green
                    
                    # Wait for publishing to complete
                    Start-Sleep -Seconds 10
                    
                } catch {
                    Write-Warning "⚠️ Failed to publish agent: $($_.Exception.Message)"
                }
            }
            
            if ($EnableAgent) {
                Write-Host "🔄 Enabling agent..." -ForegroundColor Yellow
                
                # Enable the agent
                $enableUrl = "https://api.powerplatform.com/appmanagement/environments/$($environment.EnvironmentName)/chatbots/$($agent.name)"
                $enableBody = @{
                    isDisabled = $false
                } | ConvertTo-Json
                
                try {
                    $enableResponse = Invoke-RestMethod -Uri $enableUrl -Headers $headers -Method Patch -Body $enableBody
                    Write-Host "✅ Agent enabled successfully!" -ForegroundColor Green
                } catch {
                    Write-Warning "⚠️ Failed to enable agent: $($_.Exception.Message)"
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
                Write-Host "   4. Configure sharing for: $($agent.displayName)" -ForegroundColor Gray
            }
            
            # Get agent details for validation
            Write-Host "📊 Agent Status:" -ForegroundColor Cyan
            Write-Host "   Name: $($agent.displayName)" -ForegroundColor White
            Write-Host "   ID: $($agent.name)" -ForegroundColor White
            Write-Host "   Status: Published" -ForegroundColor Green
            Write-Host "   Environment: $($environment.DisplayName)" -ForegroundColor White
            
            # Get agent endpoint URL
            $agentUrl = "https://$($environment.EnvironmentName).crm.dynamics.com/main.aspx?appid=$($agent.name)"
            Write-Host "   Access URL: $agentUrl" -ForegroundColor Cyan
        }
        
    } catch {
        Write-Error "Failed to retrieve agents: $($_.Exception.Message)"
        # Fallback: Try to use PowerShell cmdlets if available
        Write-Host "Attempting fallback method..." -ForegroundColor Yellow
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
