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

$rg = az group show --name $rgName | ConvertFrom-Json
$rgTags = $rg.tags | Get-Member -MemberType NoteProperty | ForEach-Object { "$($_.Name)=$($rg.tags.$($_.Name))" }

Write-Verbose "Creating log analytics workspace $laName"

az monitor log-analytics workspace create --workspace-name $laName `
  --resource-group $rgName -l $rg.location --tags $rgTags
