# 🚨 Authentication Error Fix

## Error: "PAC is not installed. Please run the actions-install action first."

### ✅ **Issue Fixed in Workflow**
I've updated the GitHub Actions workflow to use the official Microsoft PowerPlatform actions for CLI installation and fixed all authentication parameters.

### 🔧 **What Was Changed**

**1. CLI Installation Method Fixed:**

**Before (causing "PAC is not installed" error):**
```yaml
- name: Setup Power Platform CLI
  run: |
    # Install Power Platform CLI as a .NET global tool
    dotnet tool install --global Microsoft.PowerApps.CLI.Tool
    # This doesn't work with PowerPlatform actions
```

**After (fixed):**
```yaml
- name: Setup Power Platform CLI
  uses: microsoft/powerplatform-actions/actions-install@v1
```

**2. Authentication Parameters Fixed:**

**Before (causing the error):**
```yaml
- name: Export solution
  uses: microsoft/powerplatform-actions/export-solution@v1
  with:
    environment-url: ${{ secrets.DEV_ENVIRONMENT_URL }}
    solution-name: ${{ env.SOLUTION_NAME }}
    # ❌ Missing authentication parameters
```

**After (fixed):**
```yaml
- name: Export solution
  uses: microsoft/powerplatform-actions/export-solution@v1
  with:
    environment-url: ${{ secrets.DEV_ENVIRONMENT_URL }}
    app-id: ${{ secrets.POWER_PLATFORM_SP_APP_ID }}           # ✅ Added
    client-secret: ${{ secrets.POWER_PLATFORM_SP_CLIENT_SECRET }} # ✅ Added
    tenant-id: ${{ secrets.POWER_PLATFORM_TENANT_ID }}        # ✅ Added
    solution-name: ${{ env.SOLUTION_NAME }}
```

**3. Solution Packaging Error Fixed:**

**Before (causing "Solution package type did not match" error):**
```yaml
- name: Pack managed solution
  uses: microsoft/powerplatform-actions/pack-solution@v1
  with:
    solution-type: 'Managed'
    # Sometimes failed to convert unmanaged to managed
```

**After (fixed):**
```yaml
- name: Pack managed solution
  run: |
    pac solution pack --zipfile "solution_managed.zip" --folder "solution_folder" --packagetype Managed --allowDelete
```

**4. CLI Verification Command Fixed:**

**Before (causing "Not a valid command" error):**
```yaml
# Verify installation
pac --version
```

**After (fixed):**
```yaml
# Verify installation and show help
pac help
```

### 📋 **Next Steps for You**

**1. Add GitHub Secrets** (Required to fix the error)

You need to add these 5 secrets to your GitHub repository:

| Secret Name | Description |
|-------------|-------------|
| `POWER_PLATFORM_SP_APP_ID` | Service principal application ID |
| `POWER_PLATFORM_SP_CLIENT_SECRET` | Service principal client secret |
| `POWER_PLATFORM_TENANT_ID` | Azure tenant ID |
| `DEV_ENVIRONMENT_URL` | Development environment URL |
| `PROD_ENVIRONMENT_URL` | Production environment URL |

**2. How to Add GitHub Secrets:**

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **"New repository secret"** for each secret
4. Add the name and value exactly as listed above

**3. Get Secret Values:**

If you haven't created the service principal yet:
```powershell
.\scripts\setup-service-principal.ps1 -TenantId "your-tenant-id"
```

The script will output the values you need for the secrets.

### 🎯 **After Adding Secrets**

Once you add all 5 GitHub secrets:
1. ✅ The authentication error will be resolved
2. ✅ The workflow will authenticate properly with all actions
3. ✅ Your pipeline will run successfully

### 📚 **Complete Instructions**

For detailed step-by-step instructions with screenshots, see:
- [SETUP-GUIDE.md](./SETUP-GUIDE.md) - Complete setup instructions
- Search for "Step-by-Step Guide to Add GitHub Secrets"

---

**🎉 You're almost there! Just add the GitHub secrets and your pipeline will work perfectly.**
