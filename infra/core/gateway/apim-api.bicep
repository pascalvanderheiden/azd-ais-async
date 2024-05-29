param name string
param displayName string
param apimName string
param apimLoggerName string = 'appinsights-logger'
param path string
param policy string = ''
param definition string
param logicAppsName string
param logicAppsDefaultHostname string
param logicAppsId string
@description('The named values that need to be defined prior to the policy being uploaded')
param namedValues array = []

@description('The number of bytes of the request/response body to record for diagnostic purposes')
param logBytes int = 8192

var logSettings = {
  headers: [ 'Content-type', 'User-agent' ]
  body: { bytes: logBytes }
}

resource apimService 'Microsoft.ApiManagement/service@2022-08-01' existing = {
  name: apimName
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2022-08-01' existing = if (!empty(apimLoggerName)) {
  name: apimLoggerName
  parent: apimService
}

resource restApi 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  name: name
  parent: apimService
  properties: {
    displayName: displayName
    path: path
    protocols: [ 'https' ]
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'api-key'
    }
    type: 'http'
    format: 'openapi'
    value: definition
  }
}

resource logicAppBackend 'Microsoft.ApiManagement/service/backends@2022-08-01' = {
  name: logicAppsName
  parent: apimService
  properties: {
    description: logicAppsName
    url: 'https://${logicAppsDefaultHostname}/api'
    resourceId: uri(environment().resourceManager, logicAppsId)
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

resource apimNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = [for nv in namedValues: {
  name: nv.key
  parent: apimService
  properties: {
    displayName: nv.key
    secret: contains(nv, 'secret') ? nv.secret : false
    value: nv.value
  }
}]

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2022-08-01' = {
  name: 'policy'
  parent: restApi
  properties: {
    format: 'rawxml'
    value: policy
  }
  dependsOn: [
    apimNamedValue
  ]
}

resource diagnosticsPolicy 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = if (!empty(apimLoggerName)) {
  name: 'applicationinsights'
  parent: restApi
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: apimLogger.id
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: logSettings
      response: logSettings
    }
    backend: {
      request: logSettings
      response: logSettings
    }
  }
}

output serviceUrl string = '${apimService.properties.gatewayUrl}/${path}'
