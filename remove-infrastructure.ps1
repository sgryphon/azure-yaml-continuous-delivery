#!/usr/bin/env pwsh

[CmdletBinding()]
param (
    ## Deployment environment, e.g. Prod, Dev, QA, Stage, Test.
    [string]$Environment = $ENV:DEPLOY_ENVIRONMENT ?? 'Dev',
    ## The Azure region where the resource is deployed.
    [string]$Location = $ENV:DEPLOY_LOCATION ?? 'australiaeast',
    ## Identifier for the organisation (or subscription) to make global names unique.
    [string]$OrgId = $ENV:DEPLOY_ORGID ?? "0x$((Get-AzContext).Subscription.Id.Substring(0,4))"
)

$ErrorActionPreference="Stop"

$SubscriptionId = $(az account show --query id --output tsv)
Write-Verbose "Removing from context subscription ID $SubscriptionId"

$appName = 'pipelinedemo'

$rgName = "rg-$appName-$Environment-001".ToLowerInvariant()
$laName = "la-$appName-$Environment".ToLowerInvariant()

az monitor log-analytics workspace delete --force true --resource-group $rgName --workspace-name $laName
az group delete --name $rgName
