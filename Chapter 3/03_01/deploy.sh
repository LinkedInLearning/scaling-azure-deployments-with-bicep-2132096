#!/bin/bash

# This script helps deploy your Bicep template to different environments
# Usage: ./deploy.sh <environment> <resource-group-name>
# Example: ./deploy.sh Dev rg-multienv-dev

# Check if required arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <environment> <resource-group-name>"
    echo "Where <environment> is one of: Dev, Test, Prod"
    exit 1
fi

# Set variables
ENV=$1
RG_NAME=$2
LOCATION="eastus"
DEPLOYMENT_NAME="multienv-deployment-$(date +%Y%m%d%H%M%S)"

# Set location based on environment for Prod
if [ "$ENV" = "Prod" ]; then
    LOCATION="eastus2"
fi

# Check if environment is valid
if [ "$ENV" != "Dev" ] && [ "$ENV" != "Test" ] && [ "$ENV" != "Prod" ]; then
    echo "Invalid environment. Must be one of: Dev, Test, Prod"
    exit 1
fi

# Convert environment to lowercase for file naming
ENV_LOWER=$(echo $ENV | tr '[:upper:]' '[:lower:]')
PARAM_FILE="${ENV_LOWER}.parameters.json"

# Check if parameter file exists
if [ ! -f "$PARAM_FILE" ]; then
    echo "Parameter file $PARAM_FILE not found!"
    exit 1
fi

echo "Deploying to $ENV environment using $PARAM_FILE..."

# Check if resource group exists, if not create it
az group show --name $RG_NAME > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Resource group $RG_NAME does not exist. Creating..."
    az group create --name $RG_NAME --location $LOCATION
fi

# Validate the deployment
echo "Validating deployment..."
az deployment group validate \
    --resource-group $RG_NAME \
    --template-file main.bicep \
    --parameters @$PARAM_FILE

if [ $? -ne 0 ]; then
    echo "Validation failed. Aborting deployment."
    exit 1
fi

# Deploy the Bicep template
echo "Deploying to $ENV environment..."
az deployment group create \
    --name $DEPLOYMENT_NAME \
    --resource-group $RG_NAME \
    --template-file main.bicep \
    --parameters @$PARAM_FILE

if [ $? -eq 0 ]; then
    echo "Deployment to $ENV environment completed successfully!"
    
    # Get the deployed web app URL
    WEBAPP_NAME=$(az deployment group show --resource-group $RG_NAME --name $DEPLOYMENT_NAME --query "properties.outputs.webAppName.value" -o tsv)
    echo "Web App URL: https://$WEBAPP_NAME.azurewebsites.net"
else
    echo "Deployment failed!"
fi