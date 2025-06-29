# Manual PowerApps PowerShell Module Installation Script
# This script provides multiple methods to install PowerApps PowerShell modules
# Especially useful for CI/CD environments and when standard installation methods fail

param(
    [Parameter(Mandatory=$false)]
    [switch]$ForceReinstall,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseDirect,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

# Set verbose preference
if ($Verbose) {
    $VerbosePreference = "Continue"
}

Write-Host "🔧 PowerApps PowerShell Module Installation Script" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Required modules
$requiredModules = @(
    "Microsoft.PowerApps.Administration.PowerShell",
    "Microsoft.PowerApps.PowerShell"
)

# CI/CD Environment Detection
$isCICD = $env:CI -eq "true" -or $env:GITHUB_ACTIONS -eq "true" -or $env:AZURE_PIPELINES -eq "true" -or $env:TF_BUILD -eq "true"
$isGitHubActions = $env:GITHUB_ACTIONS -eq "true"

Write-Host "Environment Detection:" -ForegroundColor Yellow
Write-Host "  CI/CD Environment: $isCICD" -ForegroundColor Gray
Write-Host "  GitHub Actions: $isGitHubActions" -ForegroundColor Gray
Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "  OS: $($PSVersionTable.OS)" -ForegroundColor Gray

# Setup PowerShell environment for installation
function Initialize-PowerShellEnvironment {
    Write-Host "`n🔧 Initializing PowerShell environment..." -ForegroundColor Cyan
    
    try {
        # Set execution policy for current user
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Execution policy set" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Could not set execution policy: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    try {
        # Trust PowerShell Gallery
        $psRepo = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
        if (-not $psRepo -or $psRepo.InstallationPolicy -ne "Trusted") {
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction Stop
            Write-Host "✅ PowerShell Gallery trusted" -ForegroundColor Green
        } else {
            Write-Host "✅ PowerShell Gallery already trusted" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️ Could not trust PowerShell Gallery: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    try {
        # Install/Update NuGet provider
        $nugetProvider = Get-PackageProvider -Name "NuGet" -ErrorAction SilentlyContinue
        if (-not $nugetProvider -or $nugetProvider.Version -lt "2.8.5.201") {
            Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.201" -Force -Scope CurrentUser -ErrorAction Stop
            Write-Host "✅ NuGet provider installed/updated" -ForegroundColor Green
        } else {
            Write-Host "✅ NuGet provider already up to date" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️ Could not install NuGet provider: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    try {
        # Ensure PowerShellGet is up to date
        $psGet = Get-Module -ListAvailable -Name PowerShellGet | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $psGet -or $psGet.Version -lt "2.0.0") {
            Install-Module -Name PowerShellGet -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
            Write-Host "✅ PowerShellGet installed/updated" -ForegroundColor Green
        } else {
            Write-Host "✅ PowerShellGet already up to date (Version: $($psGet.Version))" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️ Could not update PowerShellGet: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Install module using multiple methods
function Install-PowerAppsModuleRobust {
    param(
        [string]$ModuleName
    )
    
    Write-Host "`n📦 Installing $ModuleName..." -ForegroundColor Cyan
    
    # Check if already installed and functional
    if (-not $ForceReinstall) {
        $existingModule = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue
        if ($existingModule) {
            try {
                Import-Module -Name $ModuleName -Force -ErrorAction Stop
                Write-Host "✅ $ModuleName already installed and imported (Version: $($existingModule.Version))" -ForegroundColor Green
                return $true
            } catch {
                Write-Host "⚠️ Existing module has issues, will reinstall" -ForegroundColor Yellow
            }
        }
    }
    
    # Method 1: Standard Install-Module
    Write-Host "  🔄 Method 1: Standard Install-Module..." -ForegroundColor Gray
    try {
        $params = @{
            Name = $ModuleName
            Repository = "PSGallery"
            Force = $true
            AllowClobber = $true
            Scope = "CurrentUser"
            ErrorAction = "Stop"
        }
        
        # Add AcceptLicense for CI/CD environments
        if ($isCICD) {
            $params.Add("AcceptLicense", $true)
        }
        
        Install-Module @params
        Import-Module -Name $ModuleName -Force -ErrorAction Stop
        Write-Host "  ✅ Method 1 successful" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  ❌ Method 1 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Method 2: Install-Package
    Write-Host "  🔄 Method 2: Install-Package..." -ForegroundColor Gray
    try {
        Install-Package -Name $ModuleName -Source "PowerShellGallery" -Force -Scope CurrentUser -ErrorAction Stop
        Import-Module -Name $ModuleName -Force -ErrorAction Stop
        Write-Host "  ✅ Method 2 successful" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  ❌ Method 2 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Method 3: Direct download from PowerShell Gallery
    if ($UseDirect) {
        Write-Host "  🔄 Method 3: Direct download..." -ForegroundColor Gray
        try {
            $downloadPath = "$env:TEMP\PowerAppsModules"
            if (-not (Test-Path $downloadPath)) {
                New-Item -Path $downloadPath -ItemType Directory -Force | Out-Null
            }
            
            # Get latest version info from PowerShell Gallery API
            $galleryUrl = "https://www.powershellgallery.com/api/v2/Packages?`$filter=Id%20eq%20'$ModuleName'&`$orderby=Published%20desc&`$top=1"
            $moduleInfo = Invoke-RestMethod -Uri $galleryUrl -ErrorAction Stop
            
            if ($moduleInfo.entry) {
                $downloadUrl = $moduleInfo.entry.content.src
                $version = $moduleInfo.entry.properties.Version
                $fileName = "$ModuleName.$version.nupkg"
                $filePath = Join-Path $downloadPath $fileName
                
                Write-Host "    ⬇️ Downloading $ModuleName version $version..." -ForegroundColor Gray
                Invoke-WebRequest -Uri $downloadUrl -OutFile $filePath -ErrorAction Stop
                
                # Extract the package
                $extractPath = Join-Path $downloadPath "$ModuleName.$version"
                if (Test-Path $extractPath) {
                    Remove-Item -Path $extractPath -Recurse -Force
                }
                
                # Rename .nupkg to .zip and extract
                $zipPath = $filePath -replace "\.nupkg$", ".zip"
                Rename-Item -Path $filePath -NewName $zipPath -Force
                Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
                
                # Find and import the module
                $moduleFiles = Get-ChildItem -Path $extractPath -Recurse -Filter "*.psd1" 
                $mainModuleFile = $moduleFiles | Where-Object { $_.Name -eq "$ModuleName.psd1" } | Select-Object -First 1
                
                if (-not $mainModuleFile) {
                    $mainModuleFile = $moduleFiles | Select-Object -First 1
                }
                
                if ($mainModuleFile) {
                    Import-Module -Name $mainModuleFile.FullName -Force -Global -ErrorAction Stop
                    Write-Host "  ✅ Method 3 successful" -ForegroundColor Green
                    return $true
                } else {
                    throw "Could not find module manifest file"
                }
            } else {
                throw "Could not find module in PowerShell Gallery"
            }
        } catch {
            Write-Host "  ❌ Method 3 failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Method 4: Force reinstall with skip publisher check
    Write-Host "  🔄 Method 4: Force reinstall with skip publisher check..." -ForegroundColor Gray
    try {
        # Remove any existing version
        $existingModules = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue
        foreach ($existingModule in $existingModules) {
            try {
                Uninstall-Module -Name $ModuleName -RequiredVersion $existingModule.Version -Force -ErrorAction SilentlyContinue
            } catch {
                # Ignore uninstall errors
            }
        }
        
        Install-Module -Name $ModuleName -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck -AcceptLicense -ErrorAction Stop
        Import-Module -Name $ModuleName -Force -ErrorAction Stop
        Write-Host "  ✅ Method 4 successful" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  ❌ Method 4 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "  ❌ All installation methods failed for $ModuleName" -ForegroundColor Red
    return $false
}

# Verify module functionality
function Test-PowerAppsModule {
    param(
        [string]$ModuleName
    )
    
    Write-Host "`n🔍 Testing $ModuleName functionality..." -ForegroundColor Cyan
    
    try {
        $module = Get-Module -Name $ModuleName -ErrorAction Stop
        Write-Host "✅ Module loaded: $($module.Name) v$($module.Version)" -ForegroundColor Green
        
        # Test specific cmdlets
        $testCmdlets = switch ($ModuleName) {
            "Microsoft.PowerApps.Administration.PowerShell" { 
                @("Get-AdminPowerAppEnvironment", "Add-PowerAppsAccount", "Get-AdminPowerApp") 
            }
            "Microsoft.PowerApps.PowerShell" { 
                @("Get-PowerAppsAccount", "Get-PowerApp") 
            }
        }
        
        $cmdletCount = 0
        foreach ($cmdlet in $testCmdlets) {
            if (Get-Command -Name $cmdlet -ErrorAction SilentlyContinue) {
                Write-Host "  ✅ Cmdlet available: $cmdlet" -ForegroundColor Green
                $cmdletCount++
            } else {
                Write-Host "  ❌ Cmdlet missing: $cmdlet" -ForegroundColor Red
            }
        }
        
        if ($cmdletCount -eq $testCmdlets.Count) {
            Write-Host "✅ All cmdlets verified for $ModuleName" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ Some cmdlets missing for $ModuleName" -ForegroundColor Yellow
            return $false
        }
        
    } catch {
        Write-Host "❌ Module test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
try {
    Write-Host "`n🚀 Starting PowerApps module installation..." -ForegroundColor Green
    
    # Initialize environment
    Initialize-PowerShellEnvironment
    
    # Install modules
    $installationResults = @{}
    foreach ($module in $requiredModules) {
        $result = Install-PowerAppsModuleRobust -ModuleName $module
        $installationResults[$module] = $result
    }
    
    # Test modules
    $testResults = @{}
    foreach ($module in $requiredModules) {
        if ($installationResults[$module]) {
            $testResult = Test-PowerAppsModule -ModuleName $module
            $testResults[$module] = $testResult
        } else {
            $testResults[$module] = $false
        }
    }
    
    # Summary
    Write-Host "`n📊 Installation Summary:" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    
    $successCount = 0
    foreach ($module in $requiredModules) {
        $installed = $installationResults[$module]
        $tested = $testResults[$module]
        
        if ($installed -and $tested) {
            Write-Host "✅ $module - Installed and Verified" -ForegroundColor Green
            $successCount++
        } elseif ($installed -and -not $tested) {
            Write-Host "⚠️ $module - Installed but some cmdlets missing" -ForegroundColor Yellow
        } else {
            Write-Host "❌ $module - Installation failed" -ForegroundColor Red
        }
    }
    
    if ($successCount -eq $requiredModules.Count) {
        Write-Host "`n🎉 All PowerApps modules successfully installed and verified!" -ForegroundColor Green
        Write-Host "You can now use PowerApps PowerShell cmdlets in your scripts." -ForegroundColor Green
    } elseif ($successCount -gt 0) {
        Write-Host "`n⚠️ Some modules installed successfully, others may need manual intervention." -ForegroundColor Yellow
        Write-Host "Check the summary above and consider using REST API fallbacks for missing modules." -ForegroundColor Yellow
    } else {
        Write-Host "`n❌ No modules were successfully installed." -ForegroundColor Red
        Write-Host "Consider using REST API authentication instead of PowerShell cmdlets." -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "`n❌ Fatal error during installation: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Red
    exit 1
}
