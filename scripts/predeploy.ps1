#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1

if ($? -eq $true) {
    # Get environment variables
    $azdenv = azd env get-values --output json | ConvertFrom-Json

    Write-Host "Starting pre deployment script..."

    # Update storage account access for Logic Apps deployment
    if (az storage account update --allow-blob-public-access true --name $azdenv.LZA_STORAGE_ACCOUNT_NAME --resource-group $azdenv.LZA_RESOURCE_GROUP_NAME)
    {
        Write-Host "Storage account access updated pre deployment"
    }
    else
    {
        Write-Host "Failed to update storage account access"
        exit 1
    }

    Write-Host "Deployment script finished"
}