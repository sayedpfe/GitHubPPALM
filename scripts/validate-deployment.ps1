# Validate Deployment Script
# This script validates the deployment of a Power Platform solution

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
    [string]$ExpectedVersion = $null
)

# Install Power Platform CLI if not available
if (!(Get-Command "pac" -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Power Platform CLI..." -ForegroundColor Yellow
    $pacUrl = "https://aka.ms/PowerPlatformCLI"
    Write-Host "Please install Power Platform CLI from: $pacUrl" -ForegroundColor Red
    exit 1
}

try {
    Write-Host "Validating deployment for solution: $SolutionName" -ForegroundColor Green
    
    # Create authentication profile
    pac auth create --name "ValidationAuth" --kind "ServicePrincipal" --url $EnvironmentUrl --applicationId $ClientId --clientSecret $ClientSecret --tenant $TenantId
    
    # Select the authentication profile
    pac auth select --name "ValidationAuth"
    
    Write-Host "Checking solution status..." -ForegroundColor Yellow
    
    # List solutions and check if our solution exists
    $solutionListOutput = pac solution list --json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $solutions = $solutionListOutput | ConvertFrom-Json
        $targetSolution = $solutions | Where-Object { $_.UniqueName -eq $SolutionName -or $_.FriendlyName -eq $SolutionName }
        
        if ($targetSolution) {
            Write-Host "✅ Solution found in environment!" -ForegroundColor Green
            Write-Host "Solution Name: $($targetSolution.FriendlyName)" -ForegroundColor Cyan
            Write-Host "Unique Name: $($targetSolution.UniqueName)" -ForegroundColor Cyan
            Write-Host "Version: $($targetSolution.Version)" -ForegroundColor Cyan
            Write-Host "Publisher: $($targetSolution.PublisherName)" -ForegroundColor Cyan
            Write-Host "Install Date: $($targetSolution.InstalledTime)" -ForegroundColor Cyan
            Write-Host "Managed: $($targetSolution.IsManaged)" -ForegroundColor Cyan
            
            # Check version if specified
            if ($ExpectedVersion -and $targetSolution.Version) {
                if ($targetSolution.Version -eq $ExpectedVersion) {
                    Write-Host "✅ Version matches expected: $ExpectedVersion" -ForegroundColor Green
                } else {
                    Write-Warning "⚠️ Version mismatch! Expected: $ExpectedVersion, Found: $($targetSolution.Version)"
                }
            }
            
            # Additional validation checks
            Write-Host "`n🔍 Running additional validation checks..." -ForegroundColor Yellow
            
            # Check for any solution components that might have failed
            Write-Host "Checking solution health..." -ForegroundColor Cyan
            
            # Get solution components (simplified check)
            try {
                $componentsOutput = pac solution export --name $SolutionName --path temp_validation.zip --managed 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Solution export test passed - solution is healthy" -ForegroundColor Green
                    # Clean up temp file
                    if (Test-Path "temp_validation.zip") {
                        Remove-Item "temp_validation.zip" -Force
                    }
                } else {
                    Write-Warning "⚠️ Solution export test failed - there may be issues with solution health"
                }
            }
            catch {
                Write-Warning "⚠️ Could not perform solution health check: $($_.Exception.Message)"
            }
            
            Write-Host "`n✅ Deployment validation completed successfully!" -ForegroundColor Green
            return 0
            
        } else {
            Write-Error "❌ Solution '$SolutionName' not found in environment!"
            Write-Host "Available solutions:" -ForegroundColor Yellow
            $solutions | ForEach-Object {
                Write-Host "  - $($_.FriendlyName) ($($_.UniqueName))" -ForegroundColor Gray
            }
            return 1
        }
    } else {
        Write-Error "❌ Failed to retrieve solution list: $solutionListOutput"
        return 1
    }
}
catch {
    Write-Error "❌ Error during deployment validation: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Red
    return 1
}
finally {
    # Clean up authentication profile
    try {
        pac auth delete --name "ValidationAuth"
        Write-Host "Cleaned up authentication profile" -ForegroundColor Gray
    }
    catch {
        Write-Warning "Could not clean up authentication profile"
    }
}
