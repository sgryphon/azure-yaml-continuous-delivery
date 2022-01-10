#!/usr/bin/env pwsh

[CmdletBinding()]
param (
    [string]$Environment,
    [string]$Location,
    [string]$OrgId
)

$appName = 'pipelinedemo'

$rgName = "rg-$appName-$Environment-001".ToLowerInvariant()
$aspName = "asp-$appName-$Environment".ToLowerInvariant()
$wappName = "$appName-$OrgId-$Environment".ToLowerInvariant()

$rg = az group show --name $rgName | ConvertFrom-Json
$rgTags = $rg.tags | Get-Member -MemberType NoteProperty | ForEach-Object { "$($_.Name)=$($rg.tags.$($_.Name))" }

Write-Verbose "Creating web app $wappName"

az webapp create -n $wappName -p $aspName -g $rgName --tags $rgTags
