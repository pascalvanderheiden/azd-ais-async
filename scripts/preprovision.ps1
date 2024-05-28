$myip = curl -4 icanhazip.com
azd env set MY_IP_ADDRESS $myip

#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1

if ($? -eq $true) {
    $myPrincipal = az ad signed-in-user show --query "id" -o tsv
    azd env set MY_USER_ID $myPrincipal

    # Get the values from the environment
    $azdenv = azd env get-values --output json | ConvertFrom-Json

    # Define the path to the InteractiveMenu module
    $currentDir = Get-Location 
    $modulePath = "${currentDir}\scripts\InteractiveMenu\InteractiveMenu.psd1"

    # Check if the module exists
    if (Test-Path $modulePath) {
        # Remove the old module if it's already loaded
        if (Get-Module -Name InteractiveMenu) {
            Remove-Module -Name InteractiveMenu
        }

        # Import the InteractiveMenu module from the local directory
        Import-Module $modulePath
    } else {
        Write-Host "The module $modulePath does not exist."
    }

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
    if ([String]::IsNullOrEmpty($azdenv.LZA_RESOURCE_GROUP_NAME) -or -not (Test-Path env:LZA_RESOURCE_GROUP_NAME)) {
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
        Write-Host "Overwriting location with resource Group location. Selecting $selectedLocation."
        azd env set AZURE_LOCATION $selectedLocation
    } else {
        $selectedresourceGroup = $azdenv.LZA_RESOURCE_GROUP_NAME
    }
    Write-Host "One sec...fetching resources in the resource group $selectedresourceGroup... and selecting if there is only 1 or when already chosen."

    ###################
    ## Select Service Bus Namespace
    ###################
    if ([String]::IsNullOrEmpty($azdenv.LZA_SERVICE_BUS_NAMESPACE_NAME) -or -not (Test-Path env:LZA_SERVICE_BUS_NAMESPACE_NAME)) {
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
    }
    else {
        Write-Host "Service Bus Namespace already selected: $($azdenv.LZA_SERVICE_BUS_NAMESPACE_NAME)"
    }

    ###################
    ## Select Storage Account
    ###################
    if ([String]::IsNullOrEmpty($azdenv.LZA_STORAGE_ACCOUNT_NAME) -or -not (Test-Path env:LZA_STORAGE_ACCOUNT_NAME)) {
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
    }
    else {
        Write-Host "Storage Account already selected: $($azdenv.LZA_STORAGE_ACCOUNT_NAME)"
    }

    ###################
    ## Select Key Vault
    ###################
    if ([String]::IsNullOrEmpty($azdenv.LZA_KEY_VAULT_NAME) -or -not (Test-Path env:LZA_KEY_VAULT_NAME)) {
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
    }
    else {
        Write-Host "Key Vault already selected: $($azdenv.LZA_KEY_VAULT_NAME)"
    }

    ###################
    ## Select App Service Plan
    ###################
    if ([String]::IsNullOrEmpty($azdenv.LZA_APP_SERVICE_PLAN_NAME) -or -not (Test-Path env:LZA_APP_SERVICE_PLAN_NAME)) {
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
    }
    else {
        Write-Host "App Service Plan already selected: $($azdenv.LZA_APP_SERVICE_PLAN_NAME)"
    }

    # Determine the tier to set the ASEv3 deployment boolean
    if ([String]::IsNullOrEmpty($azdenv.LZA_ASEV3_DEPLOYMENT) -or -not (Test-Path env:LZA_ASEV3_DEPLOYMENT)) {
        $selectedAppServicePlanTier = (az appservice plan show --name $selectedAppServicePlan --resource-group $selectedresourceGroup --query "sku.tier" --output tsv)
        if ($selectedAppServicePlanTier -eq "Isolated") {
            Write-Host "App Service Plan tier is $selectedAppServicePlanTier. Deploying to ASEv3."
            azd env set LZA_ASEV3_DEPLOYMENT $true
        } else {
            Write-Host "App Service Plan tier is $selectedAppServicePlanTier. Not deploying to ASEv3."
            azd env set LZA_ASEV3_DEPLOYMENT $false
        }
    }
    else {
        Write-Host "ASEv3 deployment already selected: $($azdenv.LZA_ASEV3_DEPLOYMENT)"
    }

    ###################
    ## Select API Management Instance
    ###################
    if ([String]::IsNullOrEmpty($azdenv.LZA_API_MANAGEMENT_NAME) -or -not (Test-Path env:LZA_API_MANAGEMENT_NAME)) {
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
    }
    else {
        Write-Host "API Management Instance already selected: $($azdenv.LZA_API_MANAGEMENT_NAME)"
    }

    ###################
    ## Select Application Insights Instance
    ###################
    if ([String]::IsNullOrEmpty($azdenv.LZA_APP_INSIGHTS_NAME) -or -not (Test-Path env:LZA_APP_INSIGHTS_NAME)) {
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
    }
    else {
        Write-Host "Application Insights Instance already selected: $($azdenv.LZA_APP_INSIGHTS_NAME)"
    }

    ###################
    ## Select the VNet
    ###################
    if ([String]::IsNullOrEmpty($azdenv.LZA_VNET_NAME) -or -not (Test-Path env:LZA_VNET_NAME)) {
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
    }
    else {
        Write-Host "VNet already selected: $($azdenv.LZA_VNET_NAME)"
    }

    ###################
    ## For non-ASEv3 deployments, select the outbound subnet
    ###################

    if ($selectedAppServicePlanTier -ne "Isolated") {

        ###################
        ## Select the Subnet for outbound traffic of the Logic App
        ###################
        if ([String]::IsNullOrEmpty($azdenv.LZA_LA_SUBNET_NAME) -or -not (Test-Path env:LZA_LA_SUBNET_NAME)) {
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
            Write-Host "Subnet for outbound traffic of the Logic App already selected: $($azdenv.LZA_LA_SUBNET_NAME)"
        }
    }

    ###################
    ## Select the Subnet for Private Endpoints
    ###################
    if ([String]::IsNullOrEmpty($azdenv.LZA_PE_SUBNET_NAME) -or -not (Test-Path env:LZA_PE_SUBNET_NAME)) {
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
    else {
        Write-Host "Subnet for Private Endpoints already selected: $($azdenv.LZA_PE_SUBNET_NAME)"
    }
}