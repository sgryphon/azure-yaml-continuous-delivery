#!/usr/bin/env pwsh

Write-Host 'Building project'

dotnet tool restore

Write-Host "Getting GitVersion"
$json = (dotnet tool run dotnet-gitversion /output json)
Write-Host $json
$v = ($json | ConvertFrom-Json)

Write-Host "Building version $($v.SemVer)+$($v.ShortSha)"

dotnet publish (Join-Path $PSScriptRoot 'azure-yaml-continuous-delivery.sln') -c Release -p:AssemblyVersion=$($v.AssemblySemVer) -p:FileVersion=$($v.AssemblySemFileVer) -p:Version=$($v.SemVer)+$($v.ShortSha) --output publish
