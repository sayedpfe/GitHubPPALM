# Configure Agent Channels and Sharing
# This script configures channels (Teams, Website) and sharing settings for Copilot Studio agents

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
    [string[]]$EnableChannels = @("Teams", "Website"),
    
    [Parameter(Mandatory=$false)]
    [string[]]$ShareWithUsers = @(),
    
    [Parameter(Mandatory=$false)]
    [string]$ShareWithGroup = "All Company"
)

Write-Host "🔧 Configuring Agent Channels and Sharing..." -ForegroundColor Green

try {
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

    # Connect to Power Platform
    Write-Host "Authenticating to Power Platform..." -ForegroundColor Cyan
    Add-PowerAppsAccount -TenantID $TenantId -ApplicationId $ClientId -ClientSecret $ClientSecret -Endpoint prod
    
    # Get environment
    $environmentName = $EnvironmentUrl.Split('/')[2].Split('.')[0]
    $environment = Get-AdminPowerAppEnvironment | Where-Object { $_.EnvironmentName -like "*$environmentName*" -or $_.DisplayName -like "*$environmentName*" }
    
    if (!$environment) {
        Write-Error "Environment not found for URL: $EnvironmentUrl"
        exit 1
    }
    
    Write-Host "Found environment: $($environment.DisplayName)" -ForegroundColor Green
    
    # Get authentication token for API calls
    $headers = @{
        'Authorization' = "Bearer $((Get-PowerAppsAccount).AccessToken)"
        'Content-Type' = 'application/json'
    }
    
    # Get agents
    $agentsUrl = "https://api.powerplatform.com/appmanagement/environments/$($environment.EnvironmentName)/chatbots"
    $agentsResponse = Invoke-RestMethod -Uri $agentsUrl -Headers $headers -Method Get
    $agents = $agentsResponse.value
    
    if ($AgentName) {
        $targetAgents = $agents | Where-Object { $_.displayName -eq $AgentName -or $_.name -eq $AgentName }
    } else {
        $targetAgents = $agents
    }
    
    foreach ($agent in $targetAgents) {
        Write-Host "`n🤖 Configuring agent: $($agent.displayName)" -ForegroundColor Green
        
        # Configure Teams Channel
        if ($EnableChannels -contains "Teams") {
            Write-Host "📞 Configuring Microsoft Teams channel..." -ForegroundColor Yellow
            
            $teamsChannelConfig = @{
                name = "teams"
                isEnabled = $true
                settings = @{
                    enableFileUploads = $true
                    enableMarkdown = $true
                }
            } | ConvertTo-Json -Depth 3
            
            $teamsUrl = "https://api.powerplatform.com/appmanagement/environments/$($environment.EnvironmentName)/chatbots/$($agent.name)/channels/teams"
            
            try {
                Invoke-RestMethod -Uri $teamsUrl -Headers $headers -Method Put -Body $teamsChannelConfig
                Write-Host "✅ Teams channel configured successfully!" -ForegroundColor Green
            } catch {
                Write-Warning "⚠️ Failed to configure Teams channel: $($_.Exception.Message)"
            }
        }
        
        # Configure Website Channel
        if ($EnableChannels -contains "Website") {
            Write-Host "🌐 Configuring Website channel..." -ForegroundColor Yellow
            
            $websiteChannelConfig = @{
                name = "website"
                isEnabled = $true
                settings = @{
                    welcomeMessage = "Hello! How can I help you today?"
                    customCss = ""
                    enableFileUploads = $true
                }
            } | ConvertTo-Json -Depth 3
            
            $websiteUrl = "https://api.powerplatform.com/appmanagement/environments/$($environment.EnvironmentName)/chatbots/$($agent.name)/channels/website"
            
            try {
                Invoke-RestMethod -Uri $websiteUrl -Headers $headers -Method Put -Body $websiteChannelConfig
                Write-Host "✅ Website channel configured successfully!" -ForegroundColor Green
                
                # Get website embed code
                $embedUrl = "https://api.powerplatform.com/appmanagement/environments/$($environment.EnvironmentName)/chatbots/$($agent.name)/channels/website/embed"
                $embedResponse = Invoke-RestMethod -Uri $embedUrl -Headers $headers -Method Get
                
                Write-Host "📋 Website Embed Code:" -ForegroundColor Cyan
                Write-Host $embedResponse.embedCode -ForegroundColor Gray
                
            } catch {
                Write-Warning "⚠️ Failed to configure Website channel: $($_.Exception.Message)"
            }
        }
        
        # Configure Sharing (Basic level - full implementation requires Microsoft Graph API)
        if ($ShareWithGroup -or $ShareWithUsers.Count -gt 0) {
            Write-Host "👥 Configuring sharing settings..." -ForegroundColor Yellow
            
            Write-Host "📝 Manual Sharing Configuration Required:" -ForegroundColor Cyan
            Write-Host "   To complete sharing setup, please:" -ForegroundColor Gray
            Write-Host "   1. Go to Power Platform Admin Center" -ForegroundColor Gray
            Write-Host "   2. Navigate to your environment > Copilot Studio" -ForegroundColor Gray
            Write-Host "   3. Select your agent: $($agent.displayName)" -ForegroundColor Gray
            Write-Host "   4. Go to Settings > Security" -ForegroundColor Gray
            
            if ($ShareWithGroup) {
                Write-Host "   5. Add group: $ShareWithGroup" -ForegroundColor Gray
            }
            
            if ($ShareWithUsers.Count -gt 0) {
                Write-Host "   6. Add users: $($ShareWithUsers -join ', ')" -ForegroundColor Gray
            }
        }
        
        # Display agent configuration summary
        Write-Host "`n📊 Agent Configuration Summary:" -ForegroundColor Cyan
        Write-Host "   Agent: $($agent.displayName)" -ForegroundColor White
        Write-Host "   Environment: $($environment.DisplayName)" -ForegroundColor White
        Write-Host "   Channels Enabled: $($EnableChannels -join ', ')" -ForegroundColor Green
        
        if ($EnableChannels -contains "Teams") {
            Write-Host "   Teams Integration: Available in Microsoft Teams app store" -ForegroundColor Cyan
        }
        
        if ($EnableChannels -contains "Website") {
            Write-Host "   Website Integration: Embed code generated above" -ForegroundColor Cyan
        }
    }
    
    Write-Host "`n✅ Agent channel configuration completed!" -ForegroundColor Green
    
} catch {
    Write-Error "❌ Error during agent channel configuration: $($_.Exception.Message)"
    exit 1
}

Write-Host "`n📚 Additional Resources:" -ForegroundColor Cyan
Write-Host "• Copilot Studio Documentation: https://docs.microsoft.com/en-us/microsoft-copilot-studio/" -ForegroundColor Gray
Write-Host "• Teams Integration Guide: https://docs.microsoft.com/en-us/microsoft-copilot-studio/publication-add-bot-to-microsoft-teams" -ForegroundColor Gray
Write-Host "• Website Integration Guide: https://docs.microsoft.com/en-us/microsoft-copilot-studio/publication-connect-bot-to-web-channels" -ForegroundColor Gray
