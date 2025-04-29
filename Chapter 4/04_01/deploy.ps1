# deploy.ps1 - Script to deploy the large-scale Bicep solution

# Parameters
param(
    [string]$BaseName = "largedepl",
    [int]$StorageAccountCount = 500,
    [int]$BatchSize = 20,
    [string]$SubscriptionId = "",
    [array]$Regions = @("eastus", "westus")
)

# Set the context to the target subscription
if ($SubscriptionId) {
    Write-Host "Setting subscription context to $SubscriptionId"
    Set-AzContext -SubscriptionId $SubscriptionId
}
else {
    $context = Get-AzContext
    $SubscriptionId = $context.Subscription.Id
    Write-Host "Using current subscription: $SubscriptionId"
}

# Create timestamp for deployment identification
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$deploymentName = "$BaseName-$timestamp"

Write-Host "Starting large-scale deployment: $deploymentName"
Write-Host "Parameters:"
Write-Host "  Base Name: $BaseName"
Write-Host "  Storage Account Count: $StorageAccountCount"
Write-Host "  Batch Size: $BatchSize"
Write-Host "  Regions: $($Regions -join ', ')"

# Deploy the main Bicep template at subscription scope
Write-Host "Deploying main Bicep template..."
New-AzSubscriptionDeployment `
    -Name $deploymentName `
    -Location $Regions[0] `
    -TemplateFile "./main.bicep" `
    -BaseName $BaseName `
    -StorageAccountCount $StorageAccountCount `
    -BatchSize $BatchSize `
    -DeploymentRegions $Regions `
    -Verbose

Write-Host "Main deployment complete"

# Check deployment status
$deployment = Get-AzSubscriptionDeployment -Name $deploymentName
Write-Host "Deployment status: $($deployment.ProvisioningState)"

# Output resource groups created
Write-Host "Resource groups created:"
foreach ($region in $Regions) {
    $rgName = "$BaseName-$region-rg"
    Write-Host "  - $rgName"
}
Write-Host "  - $BaseName-global-rg"

Write-Host "Deployment complete!"