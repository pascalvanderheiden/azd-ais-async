param name string
param tags object = {}
param lzaResourceGroup string
param lzaVnetName string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' existing = {
  name: lzaVnetName
  scope: resourceGroup('${lzaResourceGroup}')
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: name
  location: 'global'
  tags: union(tags, { 'azd-service-name': name })
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'privateDnsZoneLink'
  parent: privateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetwork.id
    }
    registrationEnabled: false
  }
}

output privateDnsZoneName string = privateDnsZone.name
