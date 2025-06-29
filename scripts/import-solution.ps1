# Import Power Platform Managed Solution
# This script imports a managed solution to a Power Platform environment

param(
    [Parameter(Mandatory=$true)]
    [string]$EnvironmentUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$SolutionPath,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$false)]
    [bool]$PublishChanges = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$OverwriteUnmanagedCustomizations = $false,
    
    [Parameter(Mandatory=$false)]
    [bool]$SkipProductUpdateDependencies = $false,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxAsyncWaitTime = 60
)

# Validate solution file exists
if (!(Test-Path $SolutionPath)) {
    Write-Error "Solution file not found: $SolutionPath"
    exit 1
}

# Install Power Platform CLI if not available
if (!(Get-Command "pac" -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Power Platform CLI..." -ForegroundColor Yellow
    # Download and install PAC CLI
    $pacUrl = "https://aka.ms/PowerPlatformCLI"
    Write-Host "Please install Power Platform CLI from: $pacUrl" -ForegroundColor Red
    exit 1
}

try {
    Write-Host "Authenticating to Power Platform..." -ForegroundColor Green
    
    # Create authentication profile
    pac auth create --name "ImportAuth" --kind "ServicePrincipal" --url $EnvironmentUrl --applicationId $ClientId --clientSecret $ClientSecret --tenant $TenantId
    
    # Select the authentication profile
    pac auth select --name "ImportAuth"
    
    Write-Host "Importing solution from: $SolutionPath" -ForegroundColor Green
    
    # Build import command
    $importCommand = "pac solution import --path `"$SolutionPath`" --async --max-async-wait-time $MaxAsyncWaitTime"
    
    if ($PublishChanges) {
        $importCommand += " --publish-changes"
        Write-Host "Will publish changes after import..." -ForegroundColor Yellow
    }
    
    if ($OverwriteUnmanagedCustomizations) {
        $importCommand += " --force-overwrite"
        Write-Host "Will overwrite unmanaged customizations..." -ForegroundColor Yellow
    }
    
    if ($SkipProductUpdateDependencies) {
        $importCommand += " --skip-dependency-check"
        Write-Host "Will skip product update dependencies..." -ForegroundColor Yellow
    }
    
    Write-Host "Importing managed solution to production environment..." -ForegroundColor Yellow
    
    Write-Host "Executing import command..." -ForegroundColor Cyan
    Write-Host $importCommand -ForegroundColor Gray
    
    # Execute import command
    $startTime = Get-Date
    Invoke-Expression $importCommand
    
    if ($LASTEXITCODE -eq 0) {
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-Host "Solution imported successfully!" -ForegroundColor Green
        Write-Host "Import duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Cyan
        Write-Host "Import completed at: $(Get-Date)" -ForegroundColor Cyan
        
        # Get solution info
        $solutionFile = Get-Item $SolutionPath
        Write-Host "Imported file: $($solutionFile.Name)" -ForegroundColor Cyan
        Write-Host "File size: $([math]::Round($solutionFile.Length / 1MB, 2)) MB" -ForegroundColor Cyan
        
        # Run post-import validation
        Write-Host "Running post-import validation..." -ForegroundColor Yellow
        pac solution list
        
    } else {
        Write-Error "Solution import failed with exit code: $LASTEXITCODE"
        
        # Try to get more detailed error information
        Write-Host "Checking for import errors..." -ForegroundColor Yellow
        pac solution list
        
        exit 1
    }
}
catch {
    Write-Error "Error during solution import: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Red
    exit 1
}
finally {
    # Clean up authentication profile
    try {
        pac auth delete --name "ImportAuth"
        Write-Host "Cleaned up authentication profile" -ForegroundColor Gray
    }
    catch {
        Write-Warning "Could not clean up authentication profile"
    }
}
