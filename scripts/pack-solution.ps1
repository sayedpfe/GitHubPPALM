# Pack Solution Script
# This script packs an unpacked solution into a solution file

param(
    [Parameter(Mandatory=$true)]
    [string]$SolutionFolder,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false)]
    [bool]$Managed = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$SolutionName
)

# Validate source folder exists
if (!(Test-Path $SolutionFolder)) {
    Write-Error "Solution folder not found: $SolutionFolder"
    exit 1
}

# Ensure output directory exists
$outputDir = Split-Path $OutputPath -Parent
if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force
    Write-Host "Created output directory: $outputDir" -ForegroundColor Green
}

# Install Power Platform CLI if not available
if (!(Get-Command "pac" -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Power Platform CLI..." -ForegroundColor Yellow
    $pacUrl = "https://aka.ms/PowerPlatformCLI"
    Write-Host "Please install Power Platform CLI from: $pacUrl" -ForegroundColor Red
    exit 1
}

try {
    Write-Host "Packing solution from: $SolutionFolder" -ForegroundColor Green
    
    # Build pack command
    $packCommand = "pac solution pack --folder `"$SolutionFolder`" --zipfile `"$OutputPath`""
    
    if ($Managed) {
        $packCommand += " --packagetype Managed"
        Write-Host "Packing as managed solution..." -ForegroundColor Yellow
    } else {
        $packCommand += " --packagetype Unmanaged"
        Write-Host "Packing as unmanaged solution..." -ForegroundColor Yellow
    }
    
    Write-Host "Executing pack command..." -ForegroundColor Cyan
    Write-Host $packCommand -ForegroundColor Gray
    
    # Execute pack command
    $startTime = Get-Date
    Invoke-Expression $packCommand
    
    if ($LASTEXITCODE -eq 0) {
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-Host "Solution packed successfully!" -ForegroundColor Green
        Write-Host "Pack duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Cyan
        Write-Host "Output file: $OutputPath" -ForegroundColor Cyan
        
        # Get file info
        if (Test-Path $OutputPath) {
            $packedFile = Get-Item $OutputPath
            Write-Host "File size: $([math]::Round($packedFile.Length / 1MB, 2)) MB" -ForegroundColor Cyan
        }
        
    } else {
        Write-Error "Solution packing failed with exit code: $LASTEXITCODE"
        exit 1
    }
}
catch {
    Write-Error "Error during solution packing: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Red
    exit 1
}
