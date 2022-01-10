#!/usr/bin/env pwsh

[CmdletBinding()]
param (
    [string]$Environment,
    [string]$Location,
    [string]$OrgId
)

$appName = 'pipelinedemo'

$rgName = "rg-$appName-$Environment-001".ToLowerInvariant()

$TagDictionary = @{ WorkloadName = 'demowebapp'; DataClassification = 'Non-business'; Criticality = 'Low'; `
  BusinessUnit = 'Demo'; ApplicationName = $appName; Env = $Environment }

Write-Verbose "Creating resource group $rgName in location $Location"

$tags = $TagDictionary.Keys | ForEach-Object { $key = $_; "$key=$($TagDictionary[$key])" }
az group create -g $rgName -l $location --tags $tags
