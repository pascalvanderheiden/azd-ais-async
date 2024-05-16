#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1
if ($? -eq $true) {
    # Get environment variables
    $azdenv = azd env get-values --output json | ConvertFrom-Json

    Write-Host "Starting deployment..."
    <# Deploy Logic Apps Workflows via Zip Deployment, AZD now supports this feature
    # Compress the Logic App workflows
    $workflowFilePathSource = "workflow\*"
    $workflowZipDeployFileName = "workflow\zipdeploy\$($azdenv.AZURE_ENV_NAME)-wf.zip"
    if (Compress-Archive -Path $workflowFilePathSource -DestinationPath $workflowZipDeployFileName) {
        Write-Host "Zip deployment created succesfully"
    }
    else
    {
        Write-Host "Zip deployment failed"
        exit 1
    }

    # Create a deployment
    Write-Host "Starting Logic Apps Workflow deployment..."
    if (!$azdenv.RESOURCE_GROUP_NAME -Or !$azdenv.LOGIC_APPS_NAME) {
        Write-Host "Logic Apps Workflow Deployment skipped, target info is missing."
        exit 1
    }
    else 
    {
        if (az logicapp deployment source config-zip --name $azdenv.LOGIC_APPS_NAME --resource-group $azdenv.RESOURCE_GROUP_NAME --subscription $azdenv.AZURE_SUBSCRIPTION_ID --src $workflowZipDeployFileName) {
            Write-Host "Logic Apps deployment succesfully"
            #>
            # Update SAS key in APIM named value
            Write-Host "Retrieving Logic Apps SAS Key..."
            $url = "https://management.azure.com/subscriptions/$($azdenv.AZURE_SUBSCRIPTION_ID)/resourceGroups/$($azdenv.RESOURCE_GROUP_NAME)/providers/Microsoft.Web/sites/$($azdenv.LOGIC_APPS_NAME)/hostruntime/runtime/webhooks/workflow/api/management/workflows/$($azdenv.LA_ORCHESTRATION_CUSTOMER_WF_NAME)/triggers/$($azdenv.LA_ORCHESTRATION_CUSTOMER_WF_TRIGGER)/listCallbackUrl?api-version=2018-11-01"
            $response = az rest --method post --uri $url
            if ($response) {
                Write-Host "Retrieved successfully"
                $json = $response | ConvertFrom-Json
                $apiVersion = ($json.queries | Where-Object {'api-version'}).'api-version'
                $sp = ($json.queries | Where-Object sp).sp
                $sv = ($json.queries | Where-Object sv).sv
                $sig = ($json.queries | Where-Object sig).sig
                if (
                    (az apim nv update --service-name $azdenv.LZA_API_MANAGEMENT_NAME -g $azdenv.LZA_RESOURCE_GROUP_NAME --named-value-id $azdenv.LA_ORCHESTRATION_CUSTOMER_WF_SIG_NV --value $sig --secret true) -and
                    (az apim nv update --service-name $azdenv.LZA_API_MANAGEMENT_NAME -g $azdenv.LZA_RESOURCE_GROUP_NAME --named-value-id $azdenv.LA_ORCHESTRATION_CUSTOMER_WF_SP_NV --value $sp --secret false) -and
                    (az apim nv update --service-name $azdenv.LZA_API_MANAGEMENT_NAME -g $azdenv.LZA_RESOURCE_GROUP_NAME --named-value-id $azdenv.LA_ORCHESTRATION_CUSTOMER_WF_SV_NV --value $sv --secret false) -and
                    (az apim nv update --service-name $azdenv.LZA_API_MANAGEMENT_NAME -g $azdenv.LZA_RESOURCE_GROUP_NAME --named-value-id $azdenv.LA_ORCHESTRATION_CUSTOMER_WF_API_VERSION_NV --value $apiVersion --secret false)
                ) {
                    Write-Host "Successfully updated API Management Named Values"
                }
                else
                {
                    Write-Host "Failed to update API Management Named Values"
                    exit 1
                }
            } 
            else 
            {
                Write-Host "Failed to retrieve SAS key"
                exit 1
            }
        <#}
        else
        {
            Write-Host "Logic Apps deployment failed"
            exit 1
        }
    }
    #>
    Write-Host "Deployment finished"
}