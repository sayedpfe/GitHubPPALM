# Quick Setup Test Script
# This script helps you verify your local setup is ready for Power Platform deployment

Write-Host "🚀 Power Platform CLI Setup Verification" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green

# Function to check if a command exists
function Test-Command {
    param($CommandName)
    try {
        if (Get-Command $CommandName -ErrorAction Stop) {
            return $true
        }
    }
    catch {
        return $false
    }
}

# Check Power Platform CLI
Write-Host "`n🔍 Checking Power Platform CLI..." -ForegroundColor Cyan
if (Test-Command "pac") {
    $pacVersion = pac --version 2>&1
    Write-Host "✅ Power Platform CLI installed: $pacVersion" -ForegroundColor Green
} else {
    Write-Host "❌ Power Platform CLI not found!" -ForegroundColor Red
    Write-Host "   Install it using one of these methods:" -ForegroundColor Yellow
    Write-Host "   1. PowerShell: Install-Module -Name Microsoft.PowerApps.CLI" -ForegroundColor Gray
    Write-Host "   2. Download MSI: https://aka.ms/PowerPlatformCLI" -ForegroundColor Gray
    Write-Host "   3. Winget: winget install Microsoft.PowerPlatformCLI" -ForegroundColor Gray
    $setupErrors = $true
}

# Check Azure CLI (optional but helpful)
Write-Host "`n🔍 Checking Azure CLI..." -ForegroundColor Cyan
if (Test-Command "az") {
    $azVersion = az --version 2>&1 | Select-Object -First 1
    Write-Host "✅ Azure CLI installed: $azVersion" -ForegroundColor Green
} else {
    Write-Host "⚠️ Azure CLI not found (optional but recommended)" -ForegroundColor Yellow
    Write-Host "   Install: winget install Microsoft.AzureCLI" -ForegroundColor Gray
}

# Check Git
Write-Host "`n🔍 Checking Git..." -ForegroundColor Cyan
if (Test-Command "git") {
    $gitVersion = git --version 2>&1
    Write-Host "✅ Git installed: $gitVersion" -ForegroundColor Green
} else {
    Write-Host "⚠️ Git not found (required for version control)" -ForegroundColor Yellow
    Write-Host "   Install: winget install Git.Git" -ForegroundColor Gray
}

# Check PowerShell version
Write-Host "`n🔍 Checking PowerShell version..." -ForegroundColor Cyan
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 5) {
    Write-Host "✅ PowerShell version: $psVersion" -ForegroundColor Green
} else {
    Write-Host "⚠️ PowerShell version: $psVersion (recommended: 5.0+)" -ForegroundColor Yellow
}

# Check if running as Administrator
Write-Host "`n🔍 Checking permissions..." -ForegroundColor Cyan
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isAdmin) {
    Write-Host "✅ Running as Administrator" -ForegroundColor Green
} else {
    Write-Host "⚠️ Not running as Administrator (may be needed for some operations)" -ForegroundColor Yellow
}

# Test Power Platform CLI commands
if (Test-Command "pac") {
    Write-Host "`n🔍 Testing Power Platform CLI commands..." -ForegroundColor Cyan
    
    try {
        # Test basic commands
        $authList = pac auth list 2>&1
        Write-Host "✅ pac auth list - works" -ForegroundColor Green
        
        $helpOutput = pac --help 2>&1
        Write-Host "✅ pac --help - works" -ForegroundColor Green
        
        # Check available commands
        Write-Host "`n📋 Available pac commands:" -ForegroundColor Cyan
        Write-Host "   • pac auth - Authentication management" -ForegroundColor Gray
        Write-Host "   • pac solution - Solution operations" -ForegroundColor Gray
        Write-Host "   • pac admin - Admin operations" -ForegroundColor Gray
        Write-Host "   • pac chatbot - Agent/Chatbot operations" -ForegroundColor Gray
        
    } catch {
        Write-Host "⚠️ Power Platform CLI commands may have issues: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Check required PowerShell modules
Write-Host "`n🔍 Checking PowerShell modules..." -ForegroundColor Cyan

$requiredModules = @(
    "Microsoft.PowerApps.Administration.PowerShell",
    "Microsoft.PowerApps.PowerShell"
)

foreach ($module in $requiredModules) {
    if (Get-Module -ListAvailable -Name $module) {
        Write-Host "✅ $module - installed" -ForegroundColor Green
    } else {
        Write-Host "⚠️ $module - not installed" -ForegroundColor Yellow
        Write-Host "   Install: Install-Module -Name $module -Force" -ForegroundColor Gray
    }
}

# Test internet connectivity to required endpoints
Write-Host "`n🔍 Testing connectivity..." -ForegroundColor Cyan

$testUrls = @(
    "https://api.powerplatform.com",
    "https://login.microsoftonline.com",
    "https://github.com"
)

foreach ($url in $testUrls) {
    try {
        $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 10 -ErrorAction Stop
        Write-Host "✅ $url - accessible" -ForegroundColor Green
    } catch {
        Write-Host "❌ $url - not accessible" -ForegroundColor Red
    }
}

# Summary
Write-Host "`n📊 SETUP SUMMARY" -ForegroundColor Green
Write-Host "================" -ForegroundColor Green

if (-not $setupErrors) {
    Write-Host "✅ Your setup looks good! You're ready to test the Power Platform deployment solution." -ForegroundColor Green
    
    Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Create a service principal:" -ForegroundColor White
    Write-Host "   .\scripts\setup-service-principal.ps1 -TenantId 'your-tenant-id'" -ForegroundColor Gray
    
    Write-Host "2. Test environment compatibility:" -ForegroundColor White
    Write-Host "   .\scripts\check-environment-compatibility.ps1 -EnvironmentUrl 'your-env-url' -ClientId 'app-id' -ClientSecret 'secret' -TenantId 'tenant-id'" -ForegroundColor Gray
    
    Write-Host "3. Configure GitHub secrets and run the pipeline" -ForegroundColor White
    
} else {
    Write-Host "⚠️ Some issues found. Please address the missing components above." -ForegroundColor Yellow
}

Write-Host "`n📚 Documentation:" -ForegroundColor Cyan
Write-Host "• Setup Guide: SETUP-GUIDE.md" -ForegroundColor Gray
Write-Host "• Agent Deployment: AGENT-DEPLOYMENT-GUIDE.md" -ForegroundColor Gray
Write-Host "• Pipeline Comparison: PIPELINE-COMPARISON.md" -ForegroundColor Gray

Write-Host "`n✨ Happy deploying!" -ForegroundColor Green
