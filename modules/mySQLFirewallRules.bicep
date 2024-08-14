param serverName string
param ip object

resource firewallRules 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2021-12-01-preview' = {
  name: '${serverName}/${ip.name}'
  properties: {
    startIpAddress: ip.startIPAddress
    endIpAddress: ip.endIPAddress
  }
}
