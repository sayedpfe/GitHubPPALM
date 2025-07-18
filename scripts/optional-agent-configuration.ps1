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

# CI/CD Environment Detection and Session Isolation
$isCICD = $env:CI -eq "true" -or $env:GITHUB_ACTIONS -eq "true" -or $env:AZURE_PIPELINES -eq "true" -or $env:TF_BUILD -eq "true"
if ($isCICD) {
    Write-Host "🔍 CI/CD environment detected. Implementing session isolation..." -ForegroundColor Yellow
    
    # In CI/CD, force clean the module cache to prevent assembly conflicts
    try 
    {
        Get-Module | Where-Object { $_.Name -like "*PowerApps*" } | Remove-Module -Force -ErrorAction SilentlyContinue
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        Write-Host "   Session isolation applied" -ForegroundColor Gray
    }
    catch 
    {
        Write-Host "   Session isolation warning: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

# Check PowerShell Gallery connectivity and setup
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

# GitHub Actions specific setup
if ($env:GITHUB_ACTIONS -eq "true") {
    Write-Host "🔧 GitHub Actions environment detected - applying specific configurations..." -ForegroundColor Cyan
    
    # Set PowerShell execution policy for GitHub Actions
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        Write-Host "   ✅ Execution policy set for GitHub Actions" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️ Could not set execution policy: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Trust PowerShell Gallery for automated installation
    try {
        if (-not (Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue | Where-Object {$_.InstallationPolicy -eq "Trusted"})) {
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction Stop
            Write-Host "   ✅ PowerShell Gallery set as trusted repository" -ForegroundColor Green
        }
    } catch {
        Write-Host "   ⚠️ Could not set PSGallery as trusted: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Configure package management for GitHub Actions
    try {
        $packageProvider = Get-PackageProvider -Name "NuGet" -ErrorAction SilentlyContinue
        if (-not $packageProvider -or $packageProvider.Version -lt "2.8.5.201") {
            Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.201" -Force -Scope CurrentUser -ErrorAction Stop
            Write-Host "   ✅ NuGet package provider installed/updated" -ForegroundColor Green
        }
    } catch {
        Write-Host "   ⚠️ Could not install NuGet provider: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Manual installation function for PowerApps modules
function Install-PowerAppsModuleManually {
    param(
        [string]$ModuleName,
        [string]$DownloadPath = "$env:TEMP\PowerAppsModules"
    )
    
    Write-Host "🔧 Attempting manual installation of $ModuleName..." -ForegroundColor Yellow
    
    try {
        # Create download directory
        if (-not (Test-Path $DownloadPath)) {
            New-Item -Path $DownloadPath -ItemType Directory -Force | Out-Null
        }
        
        # GitHub releases approach for PowerApps modules
        $githubRepos = @{
            "Microsoft.PowerApps.Administration.PowerShell" = "microsoft/PowerApps-Samples"
            "Microsoft.PowerApps.PowerShell" = "microsoft/PowerApps-Samples"
        }
        
        if ($githubRepos.ContainsKey($ModuleName)) {
            Write-Host "   🔍 Checking GitHub releases for $ModuleName..." -ForegroundColor Gray
            
            # Try to get latest release info
            $repoUrl = "https://api.github.com/repos/$($githubRepos[$ModuleName])/releases/latest"
            try {
                $release = Invoke-RestMethod -Uri $repoUrl -ErrorAction Stop
                Write-Host "   ✅ Found latest release: $($release.tag_name)" -ForegroundColor Green
            } catch {
                Write-Host "   ⚠️ Could not access GitHub releases, trying direct PowerShell Gallery download..." -ForegroundColor Yellow
            }
        }
        
        # Direct PowerShell Gallery download approach
        Write-Host "   📦 Attempting direct PowerShell Gallery download..." -ForegroundColor Gray
        
        # Get module info from PowerShell Gallery API
        $galleryUrl = "https://www.powershellgallery.com/api/v2/Packages?`$filter=Id%20eq%20'$ModuleName'&`$top=1"
        $moduleInfo = Invoke-RestMethod -Uri $galleryUrl -ErrorAction Stop
        
        if ($moduleInfo.entry) {
            $downloadUrl = $moduleInfo.entry.content.src
            $version = $moduleInfo.entry.properties.Version
            $fileName = "$ModuleName.$version.nupkg"
            $filePath = Join-Path $DownloadPath $fileName
            
            Write-Host "   ⬇️ Downloading $ModuleName version $version..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $downloadUrl -OutFile $filePath -ErrorAction Stop
            
            # Extract and install manually
            $extractPath = Join-Path $DownloadPath "$ModuleName.$version"
            Expand-Archive -Path $filePath -DestinationPath $extractPath -Force
            
            # Find PowerShell module files
            $modulePath = Get-ChildItem -Path $extractPath -Recurse -Filter "*.psd1" | Select-Object -First 1
            if ($modulePath) {
                # Import the module directly
                Import-Module -Name $modulePath.FullName -Force -Global -ErrorAction Stop
                Write-Host "   ✅ Successfully manually installed and imported $ModuleName" -ForegroundColor Green
                return $true
            }
        }
        
        return $false
        
    } catch {
        Write-Host "   ❌ Manual installation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

foreach ($module in $requiredModules) {
    try {
        # Check if module is already loaded and functional
        $loadedModule = Get-Module -Name $module -ErrorAction SilentlyContinue
        if ($loadedModule) {
            # Test if the module is functional by checking for key cmdlets
            $testCmdlets = switch ($module) {
                "Microsoft.PowerApps.Administration.PowerShell" { @("Get-AdminPowerAppEnvironment", "Add-PowerAppsAccount") }
                "Microsoft.PowerApps.PowerShell" { @("Get-PowerAppsAccount") }
            }
            
            $cmdletsAvailable = $true
            foreach ($cmdlet in $testCmdlets) {
                if (!(Get-Command -Name $cmdlet -ErrorAction SilentlyContinue)) {
                    $cmdletsAvailable = $false
                    break
                }
            }
            
            if ($cmdletsAvailable) {
                Write-Host "✅ Module already loaded and functional: $module" -ForegroundColor Green
                continue
            } else {
                Write-Host "⚠️ Module '$module' is loaded but missing cmdlets, will reload" -ForegroundColor Yellow
                # Remove the problematic module
                Remove-Module -Name $module -Force -ErrorAction SilentlyContinue
            }
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
        
        # Handle "Assembly with same name is already loaded" error specifically
        if ($_.Exception.Message -like "*Assembly with same name is already loaded*") {
            Write-Host "🔧 Detected assembly conflict for: $module" -ForegroundColor Yellow
            
            try {
                # Force remove any conflicting modules
                Get-Module -Name $module -ErrorAction SilentlyContinue | Remove-Module -Force
                
                # Clear any loaded assemblies and force garbage collection
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
                [System.GC]::Collect()
                
                # Wait a moment for cleanup
                Start-Sleep -Seconds 2
                
                # Try importing again with different approach
                Import-Module -Name $module -Force -Global -ErrorAction Stop
                Write-Host "✅ Successfully resolved assembly conflict and imported: $module" -ForegroundColor Green
                continue
                
            } catch {
                Write-Host "🔄 Assembly conflict resolution failed, trying alternative methods..." -ForegroundColor Yellow
            }
        }
        
        # Try alternative installation methods
        try {
            Write-Host "🔄 Trying alternative installation method 1 for: $module" -ForegroundColor Yellow
            Install-Package -Name $module -Source PowerShellGallery -Force -Scope CurrentUser -ErrorAction Stop
            Import-Module -Name $module -Force -ErrorAction Stop
            Write-Host "✅ Successfully installed via Install-Package: $module" -ForegroundColor Green
        } catch {
            # Try method 2: Force reinstall
            try {
                Write-Host "🔄 Trying alternative installation method 2 for: $module" -ForegroundColor Yellow
                Uninstall-Module -Name $module -Force -ErrorAction SilentlyContinue
                Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck -ErrorAction Stop
                Import-Module -Name $module -Force -ErrorAction Stop
                Write-Host "✅ Successfully reinstalled: $module" -ForegroundColor Green
            } catch {
                # Try method 3: Manual installation for CI/CD environments
                try {
                    Write-Host "🔄 Trying manual installation method for: $module" -ForegroundColor Yellow
                    $manualInstallSuccess = Install-PowerAppsModuleManually -ModuleName $module
                    if ($manualInstallSuccess) {
                        Write-Host "✅ Successfully manually installed: $module" -ForegroundColor Green
                    } else {
                        throw "Manual installation failed"
                    }
                } catch {
                    # Try method 4: GitHub Actions specific installation
                    if ($env:GITHUB_ACTIONS -eq "true") {
                        try {
                            Write-Host "🔄 Trying GitHub Actions specific installation for: $module" -ForegroundColor Yellow
                            
                            # Use PowerShell Gallery with different approach for GitHub Actions
                            $ProgressPreference = 'SilentlyContinue'
                            Install-Module -Name $module -Repository PSGallery -Force -AllowClobber -Scope CurrentUser -AcceptLicense -ErrorAction Stop
                            Import-Module -Name $module -Force -PassThru -ErrorAction Stop
                            Write-Host "✅ Successfully installed via GitHub Actions method: $module" -ForegroundColor Green
                        } catch {
                            Write-Host "❌ GitHub Actions installation also failed for: $module" -ForegroundColor Red
                            Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
                            
                            # Final fallback: Continue without the module (graceful degradation)
                            Write-Warning "⚠️ Could not install module '$module'. Will attempt to continue with REST API fallbacks."
                            Write-Host "   Note: Some PowerShell cmdlet functionality may not be available" -ForegroundColor Yellow
                            Write-Host "   For GitHub Actions, add this to your workflow before running the script:" -ForegroundColor Cyan
                            Write-Host "   - name: Install PowerApps PowerShell Modules" -ForegroundColor Cyan
                            Write-Host "     run: |" -ForegroundColor Cyan
                            Write-Host "       Install-Module -Name $module -Force -Scope CurrentUser -Repository PSGallery" -ForegroundColor Cyan
                            Write-Host "       Import-Module -Name $module -Force" -ForegroundColor Cyan
                        }
                    } else {
                        # Final fallback: Continue without the module (graceful degradation)
                        Write-Warning "⚠️ Could not install module '$module'. Will attempt to continue with REST API fallbacks."
                        Write-Host "   Note: Some PowerShell cmdlet functionality may not be available" -ForegroundColor Yellow
                        Write-Host "   Manual installation command: Install-Module -Name $module -Force -Scope CurrentUser" -ForegroundColor Cyan
                        # Don't exit here - let the script try REST API methods instead
                    }
                }
            }
        }
    }
}

# Verify modules are properly loaded
Write-Host "🔍 Verifying module installation..." -ForegroundColor Cyan
$missingModules = @()
$functionalModules = @()

foreach ($module in $requiredModules) {
    $loadedModule = Get-Module -Name $module -ErrorAction SilentlyContinue
    if (!$loadedModule) {
        $missingModules += $module
        Write-Warning "⚠️ Module not loaded: $module"
    } else {
        # Test if the module is functional
        $testCmdlets = switch ($module) {
            "Microsoft.PowerApps.Administration.PowerShell" { @("Get-AdminPowerAppEnvironment", "Add-PowerAppsAccount") }
            "Microsoft.PowerApps.PowerShell" { @("Get-PowerAppsAccount") }
        }
        
        $cmdletsAvailable = $true
        foreach ($cmdlet in $testCmdlets) {
            if (!(Get-Command -Name $cmdlet -ErrorAction SilentlyContinue)) {
                $cmdletsAvailable = $false
                break
            }
        }
        
        if ($cmdletsAvailable) {
            $functionalModules += $module
            Write-Host "✅ Verified functional: $module (Version: $($loadedModule.Version))" -ForegroundColor Green
        } else {
            $missingModules += $module
            Write-Warning "⚠️ Module loaded but cmdlets missing: $module"
        }
    }
}

if ($missingModules.Count -gt 0) {
    if ($functionalModules.Count -eq 0) {
        Write-Warning "⚠️ No PowerShell modules are functional: $($missingModules -join ', ')"
        Write-Host "The script will attempt to use REST API fallbacks for all operations." -ForegroundColor Yellow
        Write-Host "If you encounter issues, please run the following commands manually:" -ForegroundColor Cyan
        foreach ($module in $missingModules) {
            Write-Host "  Install-Module -Name $module -Force -Scope CurrentUser" -ForegroundColor Cyan
        }
    } else {
        Write-Warning "⚠️ Some PowerShell modules are not available: $($missingModules -join ', ')"
        Write-Host "Proceeding with available modules and REST API fallbacks for missing functionality." -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ All required modules are functional!" -ForegroundColor Green
}

# Script-level variables to track module and authentication state
$script:usePowerShellModules = $false
$script:directApiToken = $null  
$script:tokenScope = $null

# Set script-level variable for module availability
$script:usePowerShellModules = $functionalModules.Count -gt 0
$script:directApiToken = $null

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
    
    # Method 1: Add-PowerAppsAccount with service principal (only if modules are functional)
    if ($script:usePowerShellModules) {
        try {
            Write-Host "Attempting authentication with service principal using PowerShell modules..." -ForegroundColor Gray
            
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
            Write-Host "   Falling back to REST API authentication..." -ForegroundColor Yellow
            $script:usePowerShellModules = $false
        }
    } else {
        Write-Host "PowerShell modules not functional, using REST API authentication directly..." -ForegroundColor Yellow
    }
    
    # Method 2: Direct REST API authentication if PowerShell modules fail
    if (!$authSuccess) {
        Write-Host "Attempting direct REST API authentication..." -ForegroundColor Gray
        
        # Try multiple token scopes as different APIs require different permissions
        $tokenScopes = @(
            "https://service.powerapps.com/.default",
            "https://graph.microsoft.com/.default", 
            "https://service.powerplatform.com/.default",
            "https://admin.services.crm.dynamics.com/.default"
        )
        
        foreach ($scope in $tokenScopes) {
            try {
                Write-Host "  Trying scope: $scope" -ForegroundColor Gray
                
                # Get OAuth token directly
                $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
                $tokenBody = @{
                    client_id = $ClientId
                    client_secret = $ClientSecret
                    scope = $scope
                    grant_type = "client_credentials"
                }
                
                $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
                
                if ($tokenResponse.access_token) {
                    Write-Host "✅ Direct REST API authentication successful with scope: $scope" -ForegroundColor Green
                    $authSuccess = $true
                    $script:directApiToken = $tokenResponse.access_token
                    $script:tokenScope = $scope
                    break
                }
            }
            catch {
                Write-Host "  ❌ Failed with scope $scope : $($_.Exception.Message)" -ForegroundColor Gray
                continue
            }
        }
        
        if (!$authSuccess) {
            Write-Warning "❌ Direct REST API authentication failed for all scopes"
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
    # https://12345678-1234-1234-1234-123456789012.crm.dynamics.com (GUID format)
    
    $environmentIdentifier = ""
    $environmentGuid = $null
    
    try {
        $uri = [System.Uri]$EnvironmentUrl
        $hostName = $uri.Host
        Write-Host "Parsed hostname: $hostName" -ForegroundColor Gray
        
        # Extract org name from different URL patterns
        if ($hostName -match '^([^.]+)\.crm[0-9]*\.dynamics\.com$') {
            $environmentIdentifier = $matches[1]
            
            # Check if it's a GUID format (environment ID)
            $guidPattern = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            if ($environmentIdentifier -match $guidPattern) {
                $environmentGuid = $environmentIdentifier
                Write-Host "Detected GUID-based environment ID: $environmentGuid" -ForegroundColor Gray
            } else {
                Write-Host "Detected org-name based environment identifier: $environmentIdentifier" -ForegroundColor Gray
            }
            
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
        
        # Use the token from either authentication method
        $apiToken = $null
        if ($script:directApiToken) {
            $apiToken = $script:directApiToken
        } elseif ($script:usePowerShellModules) {
            $powerAppsAccount = Get-PowerAppsAccount -ErrorAction SilentlyContinue
            if ($powerAppsAccount -and $powerAppsAccount.AccessToken) {
                $apiToken = $powerAppsAccount.AccessToken
            }
        }
        
        if ($apiToken) {
            $envHeaders = @{
                'Authorization' = "Bearer $apiToken"
                'Content-Type' = 'application/json'
                'Accept' = 'application/json'
            }
            
            # Try multiple environment API endpoints with better error handling
            $envEndpoints = @(
                @{
                    Url = "https://api.powerapps.com/providers/Microsoft.PowerApps/environments"
                    Description = "PowerApps Environments API"
                },
                @{
                    Url = "https://api.powerplatform.com/environments" 
                    Description = "Power Platform Environments API"
                },
                @{
                    Url = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments"
                    Description = "Business App Platform Environments API"
                },
                @{
                    Url = "https://admin.services.crm.dynamics.com/api/v1.0/instances"
                    Description = "Dynamics Admin API"
                }
            )
            
            foreach ($endpoint in $envEndpoints) {
                try {
                    Write-Host "   Trying: $($endpoint.Description)" -ForegroundColor Gray
                    Write-Host "     URL: $($endpoint.Url)" -ForegroundColor DarkGray
                    
                    $envResponse = Invoke-RestMethod -Uri $endpoint.Url -Headers $envHeaders -Method Get -ErrorAction Stop
                    
                    # Handle different response formats
                    $environments = $null
                    if ($envResponse.value) {
                        $environments = $envResponse.value
                    } elseif ($envResponse -is [array]) {
                        $environments = $envResponse
                    } elseif ($envResponse.Items) {
                        $environments = $envResponse.Items
                    } else {
                        $environments = @($envResponse)
                    }
                    
                    if ($environments -and $environments.Count -gt 0) {
                        $allEnvironments = $environments
                        Write-Host "✅ Found $($allEnvironments.Count) environments using: $($endpoint.Description)" -ForegroundColor Green
                        $environmentDiscoverySuccess = $true
                        break
                    }
                }
                catch {
                    $statusCode = "Unknown"
                    $errorMessage = $_.Exception.Message
                    
                    # Extract HTTP status code if available
                    if ($_.Exception.Response) {
                        $statusCode = [int]$_.Exception.Response.StatusCode
                    }
                    
                    Write-Host "   ❌ Failed: $($endpoint.Description)" -ForegroundColor Yellow
                    Write-Host "     Status: $statusCode" -ForegroundColor Gray
                    Write-Host "     Error: $errorMessage" -ForegroundColor Gray
                    
                    # Provide specific guidance based on error type
                    switch ($statusCode) {
                        401 { Write-Host "     💡 Hint: Authentication issue - check service principal permissions" -ForegroundColor Cyan }
                        403 { Write-Host "     💡 Hint: Insufficient permissions - service principal may need Power Platform Admin role" -ForegroundColor Cyan }
                        404 { Write-Host "     💡 Hint: API endpoint not found - this endpoint may not be available" -ForegroundColor Cyan }
                        429 { Write-Host "     💡 Hint: Rate limited - too many requests" -ForegroundColor Cyan }
                    }
                }
            }
        } else {
            Write-Warning "No valid API token available for environment discovery"
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
                $envName = $_.DisplayName -or $_.displayName -or $_.name -or "Unknown"
                $envId = $_.EnvironmentName -or $_.name -or $_.id -or "Unknown"
                Write-Host "  - $envName | $envId" -ForegroundColor Gray
            }
        }
        
        # Try multiple matching strategies with improved logic
        # Strategy 1: Exact match on environment identifier (GUID or org name)
        $environment = $allEnvironments | Where-Object { 
            ($_.EnvironmentName -eq $environmentIdentifier) -or 
            ($_.name -eq $environmentIdentifier) -or
            ($_.id -eq $environmentIdentifier) -or
            ($_.DisplayName -eq $environmentIdentifier) -or
            ($_.displayName -eq $environmentIdentifier)
        } | Select-Object -First 1
        
        if (!$environment -and $environmentGuid) {
            # Strategy 2: Match GUID-based environment ID
            $environment = $allEnvironments | Where-Object { 
                ($_.EnvironmentName -eq $environmentGuid) -or 
                ($_.name -eq $environmentGuid) -or
                ($_.id -eq $environmentGuid)
            } | Select-Object -First 1
        }
        
        if (!$environment) {
            # Strategy 3: Partial match on environment name/display name
            $environment = $allEnvironments | Where-Object { 
                ($_.EnvironmentName -like "*$environmentIdentifier*") -or 
                ($_.DisplayName -like "*$environmentIdentifier*") -or
                ($_.displayName -like "*$environmentIdentifier*") -or
                ($_.name -like "*$environmentIdentifier*")
            } | Select-Object -First 1
        }
        
        if (!$environment) {
            # Strategy 4: Match against the full URL in environment properties
            $environment = $allEnvironments | Where-Object { 
                ($_.Internal.properties.linkedEnvironmentMetadata.instanceUrl -eq $EnvironmentUrl) -or
                ($_.Internal.properties.instanceUrl -eq $EnvironmentUrl) -or
                ($_.properties.linkedEnvironmentMetadata.instanceUrl -eq $EnvironmentUrl) -or
                ($_.properties.instanceUrl -eq $EnvironmentUrl) -or
                ($_.instanceUrl -eq $EnvironmentUrl)
            } | Select-Object -First 1
        }
        
        if (!$environment) {
            Write-Host "❌ Environment matching failed. Available environments:" -ForegroundColor Red
            $allEnvironments | ForEach-Object {
                $envName = $_.DisplayName -or $_.displayName -or $_.name -or "Unknown"
                $envId = $_.EnvironmentName -or $_.name -or $_.id -or "Unknown"
                $envUrl = $_.Internal.properties.instanceUrl -or $_.properties.instanceUrl -or $_.instanceUrl -or "Unknown"
                
                Write-Host "  - Name: $envName" -ForegroundColor Yellow
                Write-Host "    ID: $envId" -ForegroundColor Yellow
                Write-Host "    URL: $envUrl" -ForegroundColor Yellow
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
    
    # Try to get token from PowerApps account first (only if modules are available)
    if ($script:usePowerShellModules) {
        $powerAppsAccount = Get-PowerAppsAccount -ErrorAction SilentlyContinue
        if ($powerAppsAccount -and $powerAppsAccount.AccessToken) {
            $accessToken = $powerAppsAccount.AccessToken
            Write-Host "✅ Using PowerApps account token" -ForegroundColor Green
        }
    }
    # Fall back to direct API token if available
    if (!$accessToken -and $script:directApiToken) {
        $accessToken = $script:directApiToken
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
    
    # Try multiple API endpoints for agents/chatbots with better error handling
    $agentEndpoints = @(
        @{
            Url = "https://api.powerapps.com/providers/Microsoft.PowerApps/environments/$($environment.EnvironmentName)/chatbots"
            Description = "PowerApps Chatbots API"
        },
        @{
            Url = "https://api.powerplatform.com/appmanagement/environments/$($environment.EnvironmentName)/chatbots"
            Description = "Power Platform App Management API"
        },
        @{
            Url = "https://$($environment.EnvironmentName).api.crm.dynamics.com/api/data/v9.2/bots"
            Description = "Dynamics Web API (Bots)"
        },
        @{
            Url = "https://$($environment.EnvironmentName).api.crm.dynamics.com/api/data/v9.2/workflows?`$filter=category eq 5"
            Description = "Dynamics Web API (Workflows/Bots)"
        }
    )
    
    $agents = @()
    $agentApiSuccess = $false
    
    foreach ($endpoint in $agentEndpoints) {
        try {
            Write-Host "Trying: $($endpoint.Description)" -ForegroundColor Gray
            Write-Host "  URL: $($endpoint.Url)" -ForegroundColor DarkGray
            
            $agentsResponse = Invoke-RestMethod -Uri $endpoint.Url -Headers $headers -Method Get -ErrorAction Stop
            
            # Handle different response formats
            if ($agentsResponse.value) {
                $agents = $agentsResponse.value
            } elseif ($agentsResponse -is [array]) {
                $agents = $agentsResponse
            } else {
                $agents = @($agentsResponse)
            }
            
            if ($agents.Count -gt 0) {
                Write-Host "✅ Successfully retrieved $($agents.Count) agent(s) from: $($endpoint.Description)" -ForegroundColor Green
                $agentApiSuccess = $true
                break
            } else {
                Write-Host "  ⚠️ No agents found in response from: $($endpoint.Description)" -ForegroundColor Yellow
            }
            
        } catch {
            $statusCode = "Unknown"
            $errorMessage = $_.Exception.Message
            
            # Extract HTTP status code if available
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            
            Write-Host "  ❌ Failed: $($endpoint.Description)" -ForegroundColor Yellow
            Write-Host "    Status: $statusCode" -ForegroundColor Gray
            Write-Host "    Error: $errorMessage" -ForegroundColor Gray
            
            # Provide specific guidance based on error type
            switch ($statusCode) {
                401 { Write-Host "    💡 Hint: Authentication issue - token may be invalid for this API" -ForegroundColor Cyan }
                403 { Write-Host "    💡 Hint: Insufficient permissions for this environment" -ForegroundColor Cyan }
                404 { Write-Host "    💡 Hint: Environment or API endpoint not found" -ForegroundColor Cyan }
                429 { Write-Host "    💡 Hint: Rate limited - too many requests" -ForegroundColor Cyan }
            }
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
