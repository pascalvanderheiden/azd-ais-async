$myip = curl -4 icanhazip.com
azd env set MY_IP_ADDRESS $myip

#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1

if ($? -eq $true) {
    $myPrincipal = az ad signed-in-user show --query "id" -o tsv
    azd env set MY_USER_ID $myPrincipal
    
    # Install InteractiveMenu module
    $module = Get-Module -Name "InteractiveMenu" -ListAvailable
    if ($module) {
        Update-Module -Name "InteractiveMenu" -Force
    }
    else {
        Install-Module -Name InteractiveMenu
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

    $resourceGroupQuestion = "In which Resource Group did you deployed the Azure Integration Service Landing Zone?"
    $selectedresourceGroup = Get-InteractiveMenuChooseUserSelection -Question $resourceGroupQuestion -Answers $resourceGroupMenuItem -Options $options
    azd env set LZA_RESOURCE_GROUP_NAME $selectedresourceGroup
    $selectedLocation = $azureResourceGroups | Where-Object { $_.name -eq $selectedresourceGroup } | Select-Object -ExpandProperty location
    $env:AZURE_LOCATION = $selectedlocation
}