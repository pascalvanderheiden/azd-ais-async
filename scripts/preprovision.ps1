$myip = curl -4 icanhazip.com
azd env set MY_IP_ADDRESS $myip

#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1

if ($? -eq $true) {
    $myPrincipal = az ad signed-in-user show --query "id" -o tsv
    azd env set MY_USER_ID $myPrincipal

    # Install needed extensions
    #Write-Host "Updating az extensions to the latest..."
    #$azExtension = az extension list --query "[?name=='appservice-kube'].name" -o tsv  
    #if (!$azExtension) {
    #    az extension add --name appservice-kube
    #}
    #else {
    #    az extension update --name appservice-kube
    #}

    # Install InteractiveMenu module
    $module = Get-Module -Name "InteractiveMenu" -ListAvailable
    if ($module) {
        Update-Module -Name "InteractiveMenu" -Force
    }
    else {
        Set-PSRepository PSGallery -InstallationPolicy Trusted
        Install-Module -Name InteractiveMenu -Confirm:$False -Force
    }

    Import-Module InteractiveMenu

    $options = @{
        MenuInfoColor = [ConsoleColor]::DarkYellow
        QuestionColor = [ConsoleColor]::Magenta
        HelpColor = [ConsoleColor]::Cyan
        ErrorColor = [ConsoleColor]::DarkRed
        HighlightColor = [ConsoleColor]::DarkGreen
        OptionSeparator = "`n"
    }

    ###################
    ## Select Azure Integration Services Landing Zone Resource Group
    ###################

    $resourceGroupMenuItem = @()
    $azureResourceGroups = (az group list --output json --only-show-errors) | ConvertFrom-Json
    foreach ($azureResourceGroup in $azureResourceGroups){
        $resourceGroupMenuItem += Get-InteractiveChooseMenuOption `
            -Value $azureResourceGroup.name `
            -Label $azureResourceGroup.name `
            -Info $azureResourceGroup.location
    }

    $resourceGroupQuestion = "In which Resource Group did you deploy the Azure Integration Service Landing Zone?"
    $selectedresourceGroup = Get-InteractiveMenuChooseUserSelection -Question $resourceGroupQuestion -Answers $resourceGroupMenuItem -Options $options
    azd env set LZA_RESOURCE_GROUP_NAME $selectedresourceGroup
    # Overwrite the default location with the location of the Landing Zone resource group
    $selectedLocation = $azureResourceGroups | Where-Object { $_.name -eq $selectedresourceGroup } | Select-Object -ExpandProperty location
    azd env set AZURE_LOCATION $selectedLocation

    Write-Host "One sec...fetching resources in the resource group $selectedresourceGroup... and selecting if there is only 1."

    ###################
    ## Select Service Bus Namespace
    ###################
    
    $serviceBusNamespaceMenuItem = @()
    $serviceBusNamespaces = (az servicebus namespace list --resource-group $selectedresourceGroup --output json --only-show-errors) | ConvertFrom-Json
    
    if ($serviceBusNamespaces.Count -eq 1) {
        Write-Host "Service Bus Namespace found. Selecting $($serviceBusNamespaces[0].name)."
        $selectedServiceBusNamespace = $serviceBusNamespaces[0].name
    } else {
        foreach ($serviceBusNamespace in $serviceBusNamespaces){
            $serviceBusNamespaceMenuItem += Get-InteractiveChooseMenuOption `
                -Value $serviceBusNamespace.name `
                -Label $serviceBusNamespace.name `
                -Info $serviceBusNamespace.name
        }
    
        $serviceBusNamespaceQuestion = "Select the Service Bus Namespace to use?"
        $selectedServiceBusNamespace = Get-InteractiveMenuChooseUserSelection -Question $serviceBusNamespaceQuestion -Answers $serviceBusNamespaceMenuItem -Options $options
    }
    
    azd env set LZA_SERVICE_BUS_NAMESPACE_NAME $selectedServiceBusNamespace
    
    ###################
    ## Select Storage Account
    ###################
    
    $storageAccountMenuItem = @() | Out-Null
    $storageAccounts = (az storage account list --resource-group $selectedresourceGroup --output json --only-show-errors) | ConvertFrom-Json
    
    if ($storageAccounts.Count -eq 1) {
        Write-Host "Storage Account found. Selecting $($storageAccounts[0].name)."
        $selectedStorageAccount = $storageAccounts[0].name
    } else {
        foreach ($storageAccount in $storageAccounts){
            $storageAccountMenuItem += Get-InteractiveChooseMenuOption `
                -Value $storageAccount.name `
                -Label $storageAccount.name `
                -Info $storageAccount.name
        }
    
        $storageAccountQuestion = "Select the Storage Account to use?"
        $selectedStorageAccount = Get-InteractiveMenuChooseUserSelection -Question $storageAccountQuestion -Answers $storageAccountMenuItem -Options $options
    }
    
    azd env set LZA_STORAGE_ACCOUNT_NAME $selectedStorageAccount

    ###################
    ## Select Key Vault
    ###################
    
    $keyVaultMenuItem = @()
    $keyVaults = (az keyvault list --resource-group $selectedresourceGroup --output json --only-show-errors) | ConvertFrom-Json
    
    if ($keyVaults.Count -eq 1) {
        Write-Host "Key Vault found. Selecting $($keyVaults[0].name)."
        $selectedKeyVault = $keyVaults[0].name
    } else {
        foreach ($keyVault in $keyVaults){
            $keyVaultMenuItem += Get-InteractiveChooseMenuOption `
                -Value $keyVault.name `
                -Label $keyVault.name `
                -Info $keyVault.name
        }
    
        $keyVaultQuestion = "Select the Key Vault to use?"
        $selectedKeyVault = Get-InteractiveMenuChooseUserSelection -Question $keyVaultQuestion -Answers $keyVaultMenuItem -Options $options
    }
    
    azd env set LZA_KEY_VAULT_NAME $selectedKeyVault

    ###################
    ## Select App Service Plan
    ###################
    
    $appServicePlanMenuItem = @()
    $appServicePlans = (az appservice plan list --resource-group $selectedresourceGroup --output json --only-show-errors 2>$null) | ConvertFrom-Json
    
    if ($appServicePlans.Count -eq 1) {
        Write-Host "App Service Plan found. Selecting $($appServicePlans[0].name)."
        $selectedAppServicePlan = $appServicePlans[0].name
    } else {
        foreach ($appServicePlan in $appServicePlans){
            $appServicePlanMenuItem += Get-InteractiveChooseMenuOption `
                -Value $appServicePlan.name `
                -Label $appServicePlan.name `
                -Info $appServicePlan.name
        }
    
        $appServicePlanQuestion = "Select the App Service Plan to use?"
        $selectedAppServicePlan = Get-InteractiveMenuChooseUserSelection -Question $appServicePlanQuestion -Answers $appServicePlanMenuItem -Options $options
    }
    
    azd env set LZA_APP_SERVICE_PLAN_NAME $selectedAppServicePlan

    # Determine the tier to set the ASEv3 deployment boolean
    $selectedAppServicePlanTier = (az appservice plan show --name $selectedAppServicePlan --resource-group $selectedresourceGroup --query "sku.tier" --output tsv)
    if ($selectedAppServicePlanTier -eq "Isolated") {
        azd env set LZA_ASEV3_DEPLOYMENT $true
    } else {
        azd env set LZA_ASEV3_DEPLOYMENT $false
    }

    ###################
    ## Select API Management Instance
    ###################
    
    $apiManagementMenuItem = @()
    $apiManagements = (az apim list --resource-group $selectedresourceGroup --output json --only-show-errors) | ConvertFrom-Json
    
    if ($apiManagements.Count -eq 1) {
        Write-Host "API Management Instance found. Selecting $($apiManagements[0].name)."
        $selectedApiManagement = $apiManagements[0].name
    } else {
        foreach ($apiManagement in $apiManagements){
            $apiManagementMenuItem += Get-InteractiveChooseMenuOption `
                -Value $apiManagement.name `
                -Label $apiManagement.name `
                -Info $apiManagement.name
        }
    
        $apiManagementQuestion = "Select the API Management Instance to use?"
        $selectedApiManagement = Get-InteractiveMenuChooseUserSelection -Question $apiManagementQuestion -Answers $apiManagementMenuItem -Options $options
    }
    
    azd env set LZA_API_MANAGEMENT_NAME $selectedApiManagement

    ###################
    ## Select Application Insights Instance
    ###################
    
    $appInsightsMenuItem = @()
    $appInsights = (az monitor app-insights component show --resource-group $selectedresourceGroup --output json --only-show-errors) | ConvertFrom-Json
    
    if ($appInsights.Count -eq 1) {
        Write-Host "Application Insights Instance found. Selecting $($appInsights[0].name)."
        $selectedAppInsights = $appInsights[0].name
    } else {
        foreach ($appInsight in $appInsights){
            $appInsightsMenuItem += Get-InteractiveChooseMenuOption `
                -Value $appInsight.name `
                -Label $appInsight.name `
                -Info $appInsight.name
        }
    
        $appInsightsQuestion = "Select the Application Insights Instance to use?"
        $selectedAppInsights = Get-InteractiveMenuChooseUserSelection -Question $appInsightsQuestion -Answers $appInsightsMenuItem -Options $options
    }
    
    azd env set LZA_APP_INSIGHTS_NAME $selectedAppInsights

    ###################
    ## Select the VNet
    ###################

    $vnetMenuItem = @()
    $vnets = (az network vnet list --resource-group $selectedresourceGroup --output json --only-show-errors) | ConvertFrom-Json

    if ($vnets.Count -eq 1) {
        Write-Host "VNet found. Selecting $($vnets[0].name)."
        $selectedVNet = $vnets[0].name
    } else {
        foreach ($vnet in $vnets){
            $vnetMenuItem += Get-InteractiveChooseMenuOption `
                -Value $vnet.name `
                -Label $vnet.name `
                -Info $vnet.name
        }

        $vnetQuestion = "Select the VNet to use?"
        $selectedVNet = Get-InteractiveMenuChooseUserSelection -Question $vnetQuestion -Answers $vnetMenuItem -Options $options
    }

    azd env set LZA_VNET_NAME $selectedVNet

    ###################
    ## For non-ASEv3 deployments, select the outbound subnet
    ###################

    if ($selectedAppServicePlanTier -ne "Isolated") {
        azd env set DEPLOY_TO_ASE $false
        ###################
        ## Select the Subnet for outbound traffic of the Logic App
        ###################

        $subnetMenuItem = @()
        $subnets = (az network vnet subnet list --resource-group $selectedresourceGroup --vnet-name $selectedVNet --output json --only-show-errors) | ConvertFrom-Json
        foreach ($subnet in $subnets){
            $subnetMenuItem += Get-InteractiveChooseMenuOption `
                -Value $subnet.name `
                -Label $subnet.name `
                -Info $subnet.name
        }

        $subnetQuestion = "Select the Subnet for outbound traffic of the Logic App?"
        $selectedSubnet = Get-InteractiveMenuChooseUserSelection -Question $subnetQuestion -Answers $subnetMenuItem -Options $options
        azd env set LZA_LA_SUBNET_NAME $selectedSubnet
    }
    else {
        azd env set DEPLOY_TO_ASE $true
    }

    ###################
    ## Select the Subnet for Private Endpoints
    ###################

    $peSubnetMenuItem = @()
    $peSubnets = (az network vnet subnet list --resource-group $selectedresourceGroup --vnet-name $selectedVNet --output json --only-show-errors) | ConvertFrom-Json
    foreach ($peSubnet in $peSubnets){
        $peSubnetMenuItem += Get-InteractiveChooseMenuOption `
            -Value $peSubnet.name `
            -Label $peSubnet.name `
            -Info $peSubnet.name
    }

    $peSubnetQuestion = "Select the Subnet for Private Endpoints?"
    $selectedPESubnet = Get-InteractiveMenuChooseUserSelection -Question $peSubnetQuestion -Answers $peSubnetMenuItem -Options $options
    azd env set LZA_PE_SUBNET_NAME $selectedPESubnet
}