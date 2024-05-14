$myip = curl -4 icanhazip.com
azd env set MY_IP_ADDRESS $myip

#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1

if ($? -eq $true) {
    $myPrincipal = az ad signed-in-user show --query "id" -o tsv
    azd env set MY_USER_ID $myPrincipal
    Write-Host "Done"
    <#
    Write-Host "Updating Logic App extension to the latest..."
    $apicExtension= az extension list --query "[?name=='logicapp'].name" -o tsv  
    if (!$apicExtension) {
        Write-Host "Logic Apps extension not found... installing"
        az extension add --yes --source "https://aka.ms/logicapp-latest-py2.py3-none-any.whl"
    }
    else {
        Write-Host "Logic Apps extension found... upgrading"
        az logicapp upgrade
    }
    Write-Host "Done"
    #>
}


