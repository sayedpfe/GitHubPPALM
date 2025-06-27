# Export Power Platform Solution
# This script exports a solution from a Power Platform environment

param(
    [Parameter(Mandatory=$true)]
    [string]$EnvironmentUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$SolutionName,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\out\exported\",
    
    [Parameter(Mandatory=$false)]
    [bool]$Managed = $false
)

# Ensure output directory exists
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force
    Write-Host "Created output directory: $OutputPath" -ForegroundColor Green
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
    pac auth create --name "DevOpsAuth" --kind "ServicePrincipal" --url $EnvironmentUrl --applicationId $ClientId --clientSecret $ClientSecret --tenant $TenantId
    
    # Select the authentication profile
    pac auth select --name "DevOpsAuth"
    
    Write-Host "Exporting solution: $SolutionName" -ForegroundColor Green
    
    # Export solution
    $exportCommand = "pac solution export --name `"$SolutionName`" --path `"$OutputPath$SolutionName.zip`""
    
    if ($Managed) {
        $exportCommand += " --managed"
        Write-Host "Exporting as managed solution..." -ForegroundColor Yellow
    } else {
        Write-Host "Exporting as unmanaged solution..." -ForegroundColor Yellow
    }
    
    # Execute export command
    Invoke-Expression $exportCommand
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Solution exported successfully to: $OutputPath$SolutionName.zip" -ForegroundColor Green
        
        # Get file info
        $exportedFile = Get-Item "$OutputPath$SolutionName.zip"
        Write-Host "File size: $([math]::Round($exportedFile.Length / 1MB, 2)) MB" -ForegroundColor Cyan
        Write-Host "Export completed at: $(Get-Date)" -ForegroundColor Cyan
    } else {
        Write-Error "Solution export failed with exit code: $LASTEXITCODE"
        exit 1
    }
}
catch {
    Write-Error "Error during solution export: $($_.Exception.Message)"
    exit 1
}
finally {
    # Clean up authentication profile
    try {
        pac auth delete --name "DevOpsAuth"
        Write-Host "Cleaned up authentication profile" -ForegroundColor Gray
    }
    catch {
        Write-Warning "Could not clean up authentication profile"
    }
}
