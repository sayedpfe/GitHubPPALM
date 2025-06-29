# Test script for module installation
param(
    [switch]$TestOnly
)

Write-Host "🧪 Testing PowerShell module installation..." -ForegroundColor Cyan

# Set TLS to 1.2 for PowerShell Gallery
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$requiredModules = @(
    "Microsoft.PowerApps.Administration.PowerShell",
    "Microsoft.PowerApps.PowerShell"
)

foreach ($module in $requiredModules) {
    Write-Host "`n📦 Testing module: $module" -ForegroundColor Yellow
    
    # Check if already loaded
    $loadedModule = Get-Module -Name $module -ErrorAction SilentlyContinue
    if ($loadedModule) {
        Write-Host "✅ Already loaded: $module (Version: $($loadedModule.Version))" -ForegroundColor Green
        continue
    }
    
    # Check if available
    $availableModule = Get-Module -ListAvailable -Name $module -ErrorAction SilentlyContinue
    if ($availableModule) {
        Write-Host "📥 Available but not loaded: $module (Version: $($availableModule.Version))" -ForegroundColor Yellow
        
        if (!$TestOnly) {
            try {
                Import-Module -Name $module -Force -ErrorAction Stop
                Write-Host "✅ Successfully imported: $module" -ForegroundColor Green
            } catch {
                Write-Host "❌ Failed to import: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "❌ Not available: $module" -ForegroundColor Red
        
        if (!$TestOnly) {
            Write-Host "📥 Attempting to install: $module" -ForegroundColor Yellow
            try {
                Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser -Repository PSGallery -ErrorAction Stop
                Write-Host "✅ Successfully installed: $module" -ForegroundColor Green
                
                Import-Module -Name $module -Force -ErrorAction Stop
                Write-Host "✅ Successfully imported: $module" -ForegroundColor Green
            } catch {
                Write-Host "❌ Failed to install/import: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`n🔍 Final verification:" -ForegroundColor Cyan
foreach ($module in $requiredModules) {
    $loadedModule = Get-Module -Name $module -ErrorAction SilentlyContinue
    if ($loadedModule) {
        Write-Host "✅ $module is loaded (Version: $($loadedModule.Version))" -ForegroundColor Green
    } else {
        Write-Host "❌ $module is NOT loaded" -ForegroundColor Red
    }
}

Write-Host "`n🧪 Module test completed!" -ForegroundColor Cyan
