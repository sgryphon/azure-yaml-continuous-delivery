#!/usr/bin/env pwsh

[CmdletBinding()]
param (
    [string]$Environment,
    [string]$Location,
    [string]$OrgId
)

$sku = $ENV:DEPLOY_SKU ?? 'FREE'
$numberOfWorkers = $ENV:DEPLOY_NUMBER_OF_WORKERS ?? '1'

$appName = 'pipelinedemo'

$rgName = "rg-$appName-$Environment-001".ToLowerInvariant()
$aspName = "asp-$appName-$Environment".ToLowerInvariant()

$rg = az group show --name $rgName | ConvertFrom-Json
$rgTags = $rg.tags | Get-Member -MemberType NoteProperty | ForEach-Object { "$($_.Name)=$($rg.tags.$($_.Name))" }

Write-Verbose "Creating app service plan $aspName ($sku)"

az appservice plan create -n $aspName --sku $sku --number-of-workers $numberOfWorkers `
  -g $rgName -l $rg.location --tags $rgTags
