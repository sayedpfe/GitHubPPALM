# Agent Deployment Guide

## 🤖 Copilot Studio Agent Deployment

This guide covers the automated deployment and configuration of Copilot Studio agents as part of your Power Platform solution.

## Overview

When your Power Platform solution contains Copilot Studio agents, the deployment pipeline automatically:

1. **Deploys the solution** containing your agent
2. **Publishes the agent** to make it available
3. **Enables the agent** for end users
4. **Configures channels** (Teams, Website, etc.)
5. **Sets up sharing** with specified groups/users
6. **Validates deployment** to ensure everything works

## 🔧 Configuration

### Required Secrets

Make sure these GitHub secrets are configured:

```
POWER_PLATFORM_SP_APP_ID
POWER_PLATFORM_SP_CLIENT_SECRET  
POWER_PLATFORM_TENANT_ID
DEV_ENVIRONMENT_URL
PROD_ENVIRONMENT_URL
```

### Optional Variables (for agent-specific features)

Set these as GitHub repository variables (Settings > Secrets and variables > Actions > Variables tab):

```
AGENT_NAME=YourSpecificAgentName          # Optional: target specific agent
ENABLE_TEAMS_CHANNEL=true                 # Enable Teams integration
ENABLE_WEBSITE_CHANNEL=true               # Enable website embedding
SHARE_WITH_GROUP=All Company               # Group to share with
```

## 📋 Agent Configuration Settings

Update `config/environment-settings.json` with your agent preferences:

```json
{
  "agentSettings": {
    "autoPublishAfterDeployment": true,
    "autoEnableAfterDeployment": true,
    "shareWithGroups": [
      "All Company",
      "IT Support Team"
    ],
    "agentNames": [
      "Customer Support Bot",
      "HR Assistant"
    ],
    "enableAnalytics": true,
    "configureChannels": [
      "Teams",
      "Website"
    ]
  }
}
```

## 🚀 Manual Agent Operations

### Publish Agent Manually

```powershell
.\scripts\post-deploy-agent.ps1 `
  -EnvironmentUrl "https://yourprod.crm.dynamics.com" `
  -ClientId "your-app-id" `
  -ClientSecret "your-secret" `
  -TenantId "your-tenant" `
  -AgentName "Your Agent Name" `
  -PublishAgent $true `
  -EnableAgent $true
```

### Configure Channels Manually

```powershell
.\scripts\configure-agent-channels.ps1 `
  -EnvironmentUrl "https://yourprod.crm.dynamics.com" `
  -ClientId "your-app-id" `
  -ClientSecret "your-secret" `
  -TenantId "your-tenant" `
  -AgentName "Your Agent Name" `
  -EnableChannels @("Teams", "Website") `
  -ShareWithGroup "All Company"
```

## 📱 Channel Integration

### Microsoft Teams Integration

When Teams channel is enabled, the pipeline will:
- Configure the agent for Teams
- Enable file uploads and markdown support
- Make the agent available in the Teams app store for your organization

**Manual Setup Required:**
1. Go to Teams Admin Center
2. Navigate to Teams apps > Manage apps
3. Find your agent and approve for organization use

### Website Integration

When Website channel is enabled, the pipeline will:
- Generate embed code for your website
- Configure welcome messages
- Enable file upload capabilities

**Embed Code Example:**
```html
<iframe src="https://web.powerva.microsoft.com/environments/YOUR_ENV/bots/YOUR_BOT/webchat"
        style="width: 100%; height: 600px; border: none;"></iframe>
```

## 🔒 Security & Permissions

### Service Principal Permissions

Your service principal needs these permissions:
- **Power Platform**: Environment Maker role
- **Azure AD**: Application permissions for chatbot management
- **Copilot Studio**: Bot Framework permissions

### Agent Sharing

Agents can be shared with:
- **Specific users**: Individual email addresses
- **Security groups**: Azure AD security groups
- **Everyone**: All users in the organization

## 📊 Monitoring & Validation

### Post-Deployment Validation

The pipeline validates:
- ✅ Agent exists in target environment
- ✅ Agent is published successfully
- ✅ Agent is enabled for users
- ✅ Channels are configured correctly
- ✅ Sharing permissions are set

### Monitoring Agent Usage

After deployment, monitor your agent through:
- **Copilot Studio Analytics**: Built-in analytics dashboard
- **Power Platform Admin Center**: Environment-level monitoring
- **Teams Admin Center**: Teams-specific usage (if Teams enabled)

## 🔄 Troubleshooting

### Common Issues

**Agent Not Publishing:**
- Check service principal permissions
- Verify agent exists in solution
- Review deployment logs for errors

**Teams Integration Not Working:**
- Ensure Teams channel is enabled in configuration
- Check Teams admin center for approval status
- Verify service principal has Teams permissions

**Website Embed Not Working:**
- Check if website channel is configured
- Verify embed code is properly implemented
- Test in incognito/private browser mode

### Debug Commands

```powershell
# List all agents in environment
pac chatbot list

# Check agent status
pac chatbot show --name "Your Agent Name"

# Test agent connectivity
pac chatbot test --name "Your Agent Name"
```

## 📚 Additional Resources

- [Copilot Studio Documentation](https://docs.microsoft.com/en-us/microsoft-copilot-studio/)
- [Teams Integration Guide](https://docs.microsoft.com/en-us/microsoft-copilot-studio/publication-add-bot-to-microsoft-teams)
- [Website Integration Guide](https://docs.microsoft.com/en-us/microsoft-copilot-studio/publication-connect-bot-to-web-channels)
- [Power Platform ALM Guide](https://docs.microsoft.com/en-us/power-platform/alm/)

## 🆘 Support

If you encounter issues with agent deployment:

1. **Check the pipeline logs** in GitHub Actions
2. **Review agent status** in Copilot Studio
3. **Validate permissions** in Power Platform Admin Center
4. **Test manually** using the provided scripts
5. **Open an issue** in this repository with detailed logs

---

**Happy Agent Deploying! 🤖🚀**
