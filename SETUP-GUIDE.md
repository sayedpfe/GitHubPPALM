# Power Platform Deployment Guide

## Quick Start Guide

This repository provides a complete automated deployment solution for Power Platform solutions using CI/CD pipelines.

### 🚀 Getting Started

1. **Fork/Clone this repository**
2. **Update configuration files with your solution details**
3. **Set up service principal for authentication**
4. **Configure pipeline secrets/variables**
5. **Push to main branch to trigger deployment**

## 📋 Prerequisites

- **Power Platform environments**: Development, Test (optional), Production
- **GitHub repository** or **Azure DevOps project**
- **Azure AD tenant** with permissions to create service principals
- **Power Platform CLI** (for local development)

## 🔧 Setup Instructions

### Step 1: Service Principal Setup

Run the service principal setup script:

```powershell
.\scripts\setup-service-principal.ps1 -TenantId "your-tenant-id"
```

This will create:
- Azure AD Application Registration
- Service Principal
- Required API permissions
- Client secret

### Step 2: Environment Configuration

Update `config/environment-settings.json` with your environment details:

```json
{
  "environments": {
    "development": {
      "environmentUrl": "https://yourdev.crm.dynamics.com",
      "environmentId": "your-dev-environment-id"
    },
    "production": {
      "environmentUrl": "https://yourprod.crm.dynamics.com", 
      "environmentId": "your-prod-environment-id"
    }
  }
}
```

### Step 3: GitHub Secrets (if using GitHub Actions)

Add these secrets to your GitHub repository:

- `POWER_PLATFORM_SP_APP_ID`: Service Principal Application ID
- `POWER_PLATFORM_SP_CLIENT_SECRET`: Service Principal Client Secret
- `POWER_PLATFORM_TENANT_ID`: Azure Tenant ID
- `DEV_ENVIRONMENT_URL`: Development environment URL
- `PROD_ENVIRONMENT_URL`: Production environment URL

### Step 4: Update Solution Name

In `.github/workflows/power-platform-deployment.yml`, update:

```yaml
env:
  SOLUTION_NAME: 'YourActualSolutionName'  # Replace with your solution name
```

### Step 5: Grant Service Principal Permissions

1. Go to **Power Platform Admin Center**
2. Select each environment (Dev, Test, Prod)
3. Go to **Settings** > **Users + permissions** > **Users**
4. Click **Add user**
5. Enter the Service Principal Application ID
6. Assign **System Administrator** role

## 🔄 Deployment Process

### Automated Deployment Flow

1. **Export** solution from Development environment
2. **Unpack** solution for version control
3. **Pack** solution as managed
4. **Run** Solution Checker for quality validation
5. **Import** managed solution to Production environment
6. **Validate** deployment success

### Manual Deployment (PowerShell)

You can also run deployments manually using the provided scripts:

```powershell
# Export solution
.\scripts\export-solution.ps1 -EnvironmentUrl "https://yourdev.crm.dynamics.com" -SolutionName "YourSolution" -ClientId "your-app-id" -ClientSecret "your-secret" -TenantId "your-tenant"

# Pack as managed
.\scripts\pack-solution.ps1 -SolutionFolder ".\out\solutions\YourSolution" -OutputPath ".\out\YourSolution_managed.zip" -Managed $true

# Import to production
.\scripts\import-solution.ps1 -EnvironmentUrl "https://yourprod.crm.dynamics.com" -SolutionPath ".\out\YourSolution_managed.zip" -ClientId "your-app-id" -ClientSecret "your-secret" -TenantId "your-tenant"

# Validate deployment
.\scripts\validate-deployment.ps1 -EnvironmentUrl "https://yourprod.crm.dynamics.com" -SolutionName "YourSolution" -ClientId "your-app-id" -ClientSecret "your-secret" -TenantId "your-tenant"
```

## 🛡️ Security Best Practices

- ✅ Store secrets in GitHub Secrets or Azure Key Vault
- ✅ Use Service Principal authentication (not user accounts)
- ✅ Grant minimum required permissions
- ✅ Rotate client secrets regularly
- ✅ Monitor deployment logs for security events
- ✅ Use managed solutions in production
- ✅ Enable audit logging in Power Platform

## 📊 Monitoring & Troubleshooting

### Deployment Logs

- GitHub Actions: Check the **Actions** tab in your repository
- Azure DevOps: View pipeline runs in **Pipelines** section

### Common Issues

1. **Authentication Failed**
   - Verify service principal credentials
   - Check API permissions are granted
   - Ensure service principal has environment access

2. **Solution Import Failed**
   - Check for missing dependencies
   - Verify solution compatibility
   - Review solution checker warnings

3. **Pipeline Permissions**
   - Verify GitHub secrets are set correctly
   - Check environment protection rules

### Debug Commands

```powershell
# Check authentication
pac auth list

# Verify environment access
pac admin list

# Check solution dependencies
pac solution check --path YourSolution.zip
```

## 🔄 Branching Strategy

- **main**: Production deployments
- **develop**: Development work
- **feature/***: Feature branches
- **hotfix/***: Production hotfixes

## 📈 Advanced Features

### Environment-Specific Configuration

The pipeline supports deploying different configurations per environment by using environment-specific parameter files.

### Solution Versioning

Solutions are automatically versioned using semantic versioning based on:
- Major: Breaking changes
- Minor: New features
- Patch: Bug fixes

### Rollback Strategy

To rollback a deployment:
1. Navigate to Power Platform Admin Center
2. Select the environment
3. Go to Solutions
4. Delete the problematic solution version
5. Previous version will remain active

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For issues and questions:
- Check the troubleshooting section above
- Review GitHub Actions logs
- Open an issue in this repository
- Consult Power Platform documentation

---

**Happy Deploying! 🚀**
