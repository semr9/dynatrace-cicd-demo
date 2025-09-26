# Azure Login Guide for VM Deployment

## Option 1: Direct Login (Recommended)

### Step 1: Login to Azure on VM
```bash
# SSH to your VM
ssh azureuser@172.171.207.142

# Navigate to project directory
cd ~/dynatrace-cicd-demo

# Login to Azure (this will open a browser)
az login
```

### Step 2: Verify Login
```bash
# Check current account
az account show

# List available subscriptions
az account list --output table
```

### Step 3: Set Subscription (if needed)
```bash
# Set the correct subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

## Option 2: Service Principal (Alternative)

If you prefer using a service principal:

### Step 1: Create Service Principal
```bash
# On your local machine with Azure CLI
az ad sp create-for-rbac --name "dynatrace-cicd-sp" --role contributor --scopes /subscriptions/YOUR_SUBSCRIPTION_ID
```

### Step 2: Login with Service Principal
```bash
# On the VM
az login --service-principal --username APP_ID --password PASSWORD --tenant TENANT_ID
```

## Option 3: Use Azure Cloud Shell

### Step 1: Open Azure Cloud Shell
- Go to https://portal.azure.com
- Click on the Cloud Shell icon (>) in the top bar
- Choose Bash

### Step 2: Clone Repository
```bash
git clone https://github.com/semr9/dynatrace-cicd-demo.git
cd dynatrace-cicd-demo
```

### Step 3: Run Deployment
```bash
./scripts/azure-quick-deploy.sh
```

## Next Steps After Login

Once logged in, you can proceed with deployment:

```bash
# Check prerequisites
./scripts/azure-setup.sh

# Run deployment
./scripts/azure-quick-deploy.sh
```

## Troubleshooting

### If login fails:
1. Check internet connectivity on VM
2. Verify Azure CLI version: `az --version`
3. Try device code login: `az login --use-device-code`

### If subscription issues:
1. List subscriptions: `az account list`
2. Set correct subscription: `az account set --subscription "ID"`
3. Verify access: `az account show`
