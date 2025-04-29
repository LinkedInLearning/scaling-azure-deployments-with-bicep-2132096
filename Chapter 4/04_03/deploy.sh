#!/bin/bash

# Script to deploy the multi-tier architecture using Azure Bicep

# Variables
RESOURCE_GROUP="multi-tier-app-rg"
LOCATION="eastus"
PARAMETERS_FILE="parameters.json"  # Optional parameters file

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Multi-Tier Architecture Deployment Script${NC}"
echo "====================================="

# Check if Azure CLI is installed
if ! [ -x "$(command -v az)" ]; then
  echo -e "${RED}Error: Azure CLI is not installed.${NC}" >&2
  echo "Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
  exit 1
fi

# Check Azure login status
echo "Checking Azure login status..."
az account show &> /dev/null
if [ $? -ne 0 ]; then
  echo "You are not logged into Azure. Running az login..."
  az login
fi

# Create or check resource group
echo "Checking if resource group exists..."
if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
  echo -e "${GREEN}Using existing resource group: $RESOURCE_GROUP${NC}"
else
  echo "Creating resource group: $RESOURCE_GROUP in $LOCATION"
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create resource group.${NC}"
    exit 1
  fi
  echo -e "${GREEN}Resource group created successfully.${NC}"
fi

# Validate the Bicep template
echo "Validating Bicep template..."
if [ -f "$PARAMETERS_FILE" ]; then
  az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "main.bicep" \
    --parameters "@$PARAMETERS_FILE"
else
  az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "main.bicep"
fi

if [ $? -ne 0 ]; then
  echo -e "${RED}Template validation failed.${NC}"
  exit 1
fi
echo -e "${GREEN}Template validation successful.${NC}"

# Deploy the Bicep template
echo "Starting deployment..."
if [ -f "$PARAMETERS_FILE" ]; then
  az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "main.bicep" \
    --parameters "@$PARAMETERS_FILE" \
    --name "multi-tier-deployment-$(date +%Y%m%d%H%M%S)"
else
  az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "main.bicep" \
    --name "multi-tier-deployment-$(date +%Y%m%d%H%M%S)"
fi

if [ $? -ne 0 ]; then
  echo -e "${RED}Deployment failed.${NC}"
  exit 1
fi

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo "You can view the deployment outputs in the Azure portal or use the following command:"
echo "az deployment group show --resource-group $RESOURCE_GROUP --name <deployment-name> --query properties.outputs"

# Get deployment output
echo "Fetching deployment outputs..."
LATEST_DEPLOYMENT=$(az deployment group list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
az deployment group show --resource-group "$RESOURCE_GROUP" --name "$LATEST_DEPLOYMENT" --query "properties.outputs" -o json

echo -e "${GREEN}All done!${NC}"