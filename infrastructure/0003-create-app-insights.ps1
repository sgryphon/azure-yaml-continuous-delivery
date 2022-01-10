#!/usr/bin/env pwsh

[CmdletBinding()]
param (
    [string]$Environment,
    [string]$Location,
    [string]$OrgId
)

$appName = 'pipelinedemo'

$rgName = "rg-$appName-$Environment-001".ToLowerInvariant()
$laName = "la-$appName-$Environment".ToLowerInvariant()
$appiName = "appi-$appName-$Environment".ToLowerInvariant()

$rg = az group show --name $rgName | ConvertFrom-Json
$rgTags = $rg.tags | Get-Member -MemberType NoteProperty | ForEach-Object { "$($_.Name)=$($rg.tags.$($_.Name))" }

Write-Verbose "Creating app insights $appiName (may take a while)"
az extension add -n application-insights

$appi = az monitor app-insights component create --app $appiName --workspace $laName `
  -g $rgName -l $rg.location --tags $rgTags | ConvertFrom-Json

# copy the key into another variable, to ensure the property is dereferenced when passing to
# the az command line
$appiKey = $appi.instrumentationKey
$appiConnectionString = $appi.connectionString

Write-Verbose "Client App Instrumentation Key: $appiKey"
Write-Verbose "Client App Connection String: $appiConnectionString"
