# Azure YAML Continuous Delivery 

Example of continuous delivery (deployment to multiple environments) using Azure YAML pipelines

### Requirements

The example repository is in GitHub, but it is run from Azure DevOps. You will also need an Azure account to deploy to.

* Dotnet 6.0 LTS
* Azure subscription, to deploy to
* Azure CLI, to create cloud resources
* Powershell, for running scripts

## Start with an application

Create a GitHub repo, like this one.

Add `.gitignore`, `.gitattributes`, and `.editorconfig` files, document important things in ReadMe.md, and maybe add an open source licence.

Create a `src` directory, then create a new **dotnet** solution, a sample web app (with proxy port 44301), and add the web app to the solution.

```powershell
mkdir src
dotnet new sln
dotnet new react --output src/Demo.WebApp --ProxyPort 44301
dotnet sln add src/Demo.WebApp
```

Check it works by running the web API in one PowerShell terminal:

```powershell
dotnet run --project src/Demo.WebApp --environment Development --urls 'http://*:8002'
```

And then also running the front end proxy in a second PowerShell terminal (pointing at the API):

```powershell
$env:ASPNETCORE_URLS = 'http://localhost:8002'
npm run start --prefix src/Demo.WebApp/ClientApp
```

Check the front end proxy with a browser, e.g. `https://localhost:44301/`, and make sure to go to the Fetch data page to ensure the connection to the API is working.

**NOTE:** If you have trouble with HTTPS, or do not have certificates set up, then see the section at the end of this file for HTTPS Developer Certificates.

### HTTPS for the web API (on Ubuntu)

**TODO:** Using HTTPS for the API had issues working on Ubuntu, where the proxied request would time out, and eventually report a JS stack trace referencing `builtin exit frame: getPeerCertificate` and `FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed - JavaScript heap out of memory`

Web API:

```powershell
dotnet run --project src/Demo.WebApp --environment Development --urls 'https://*:44302'
```

Front end:

```powershell
$env:ASPNETCORE_URLS = 'https://localhost:44302'
npm run start --prefix src/Demo.WebApp/ClientApp
```

This may be the Node server not trusting the developer certificate. A similar issue happens if you just run the API server, and use it to trigger automatic launching of the front end proxy.


## Semantic versioning

For automated deployment you need a way to track which version is being deployed. For example, you can use GitVersion, which has built in support for semantic versioning.

```powershell
dotnet new tool-manifest
dotnet tool install GitVersion.Tool
```

To see the version run `dotnet gitversion`. You can use different configurations, e.g. to use Mainline versioning and use the ShortSha for AssemblyInformationVersion, use the following `GitVersion.yml`:

```yaml
assembly-versioning-scheme: MajorMinor
assembly-informational-format: '{SemVer}+{ShortSha}'
mode: Mainline
branches: {}
ignore:
  sha: []
```

To test local build and publish, you can also create a basic `build.ps1` script that generates the current version number and then tests, builds and publishes the project (however this project has no tests).

```powershell
#!/usr/bin/env pwsh

dotnet tool restore
$json = (dotnet tool run dotnet-gitversion /output json)
$v = ($json | ConvertFrom-Json)
dotnet publish (Join-Path $PSScriptRoot 'azure-yaml-continuous-delivery.sln') -c Release -p:AssemblyVersion=$($v.AssemblySemVer) -p:FileVersion=$($v.AssemblySemFileVer) -p:Version=$($v.SemVer)+$($v.ShortSha) --output publish
```


## Infrastructure as code

There are a lot of alternatives for deploying websites, such as deploying containers, pushing to a Git repository that is automatically deployed, or using deployment slots for quick changes between Staging and Production. There are also many different ways to create Azure infrastructure as code -- Bicep, ARM templates, Azure PowerShell, and Azure CLI. These examples use Azure CLI.

To run the script locally you first log in to Azure CLI.

```powershell
az login
az account set --subscription <subscription id>
```

Create a script (or several) to deploy the needed infrastructure. Create all the required infrastructure via scripts, so that it can be automatically deployed to each environment using the pipeline.

```powershell
#!/usr/bin/env pwsh

[CmdletBinding()]
param (
    [string]$Environment = $ENV:DEPLOY_ENVIRONMENT ?? 'Dev',
    [string]$Location = $ENV:DEPLOY_LOCATION ?? 'australiaeast',
    [string]$OrgId = $ENV:DEPLOY_ORGID ?? "0x$((az account show --query id --output tsv).Substring(0,4))"
)

$appName = 'pipelinedemo'

$rgName = "rg-$appName-$Environment-001".ToLowerInvariant()
$laName = "la-$appName-$Environment".ToLowerInvariant()
$appiName = "appi-$appName-$Environment".ToLowerInvariant()
$aspName = "asp-$appName-$Environment".ToLowerInvariant()
$wappName = "$appName-$OrgId-$Environment".ToLowerInvariant()

$TagDictionary = @{ WorkloadName = 'demowebapp'; DataClassification = 'Non-business'; Criticality = 'Low'; `
  BusinessUnit = 'Demo'; ApplicationName = $appName; Env = $Environment }
$tags = $TagDictionary.Keys | ForEach-Object { $key = $_; "$key=$($TagDictionary[$key])" }

az group create -g $rgName -l $location --tags $tags
az monitor log-analytics workspace create --workspace-name $laName `
  --resource-group $rgName -l $rg.location --tags $tags
az monitor app-insights component create --app $appiName --workspace $laName `
  -g $rgName -l $rg.location --tags $tags
az appservice plan create -n $aspName --sku $sku --number-of-workers $numberOfWorkers `
  -g $rgName -l $rg.location --tags $tags
az webapp create -n $wappName -p $aspName -g $rgName --tags $tags
```

TODO: Set app settings for web app with app insights connection string (will override config)

TODO: Set web app logs, errors, etc to go to app insights


This script can be run locally, to create personal development infrastructure in your own Azure subscription, and the same scripts run for pipeline deployment. Sometimes you might want to have a separate project, repository, or pipeline for deploying infrastructure, particularly if it is managed with a different cadence.

Infrastructure deployment may consist of a single resource group with a few resources, or a much more complex configuration. For local deployment it can also be useful to provide a remove script to clean up for individual developers.

### Naming conventions and unique names

Follow the standard naming conventions from Azure Cloud Adoption Framework, https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming

However you also need to use an organisation or subscription identifier in global names to make them unique. For example if there are multiple developers that will deploy a web app, suffix the app name with the first four characters of their subscripition ID to make unique web addresses.

Scripts should also follow standard tagging conventions from  Azure Cloud Adoption Framework, https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging

### Deployment parameters

There are potentially a lot of different deployment parameters that you want to change, and you may not know all of them in advance.

This makes it hard to have a specific set of parameters to the deployment scripts (and such a solution would not be generic).

Each script, or part of a script, should be independent and manage it's own parameters. This could mean a generic context dictionary is passed in, however this already exists in the form of environment variables. Each script can read relevant environment variables, falling back to an appropriate default.

Another solution could be to have a configuration file, e.g. JSON, that is updated or replaced for each environment and accessible to all scripts. This also has the benefit of documenting what parameters exist to be set.

### Shared infrastructure

Sometimes there may be shared infrastructure, e.g. a web app may be deployed to an existing app service plan, or an app insights instance may connect to an existing log analytics workspace. Any virtual network configuration is probably shared infrastructure.

This may mean there is a separate project and pipeline for the shared infrastructure (in a separate resource group), but still allowing the project to manage the specific resources as part of their build. For local deployments this may mean additional scripts are needed to also create this shared infrastructure.

## Pipeline skeleton

First, create a basic `azure-pipelines.yml`, with a single build Stage, and Job with a single Step that echos a hello message; commit it, and push it to your GitHub repository.

```yaml
trigger:
- main

stages:
  - stage: BuildStage
    displayName: Build
    jobs:
    - job: Build
      pool:
        name: Azure Pipelines
        vmImage: 'ubuntu-latest'
      steps:
      - bash: echo Hello YAML build
```

## Add the pipeline in Azure DevOps

In Azure DevOps, create a new project. You can use Git for source control and Agile as the process template, although these won't be used. The example project is Public, but you normally an organisation would use Private projects.

From the left hand menu, select Pipelines > Pipelines, and then Create Pipeline.

For 'Where is your code?', select GitHub, then sign in (you may need to also complete any two-factor authentication). You will then need to authorise "Azure Pipelines (OAuth)".

Azure DevOps will show a list of your GitHub repositories, and you can select the one you have created the pipeline in. This will direct you back to github where you then need to approve & install "Azure Pipelines". You can install in All repositories if desired (or just the ones you are using).

It should then come back to Azure DevOps with "Review your pipeline YAML", and show you the basic `azure-pipelines.yml` from your project. You can click 'Run' for an initial run of your new pipeline.

Once set up, Azure DevOps will monitor the specified trigger for changes.

**Troubleshooting**

When I first authorised "Azure Pipelines", it sent me to a sign up screen for a new Azure DevOps organisation, and would not let me select an existing one.

I cancelled, reloaded the Azure DevOps project, and went through the Create Pipeline steps a second time, and it worked.

## Add environment gates

Under Pipelines > Environments create your environments, e.g.

* Integration - Where merged branches are continuous integrated and deployed.
* Test - Where builds are manually released to for testing.
* Production - Where live systems run.

Open the Test environment and in the "..." menu select Approvals and Checks, then select Approval. For approvers, add "[your project]\Contributors" (or the appropriate group), and click Create.

This will add a gate before any stages linked to the Test environment will be run.

Add a similar approval to the Production environment.

## Add build job

### Create the build steps template

You can template at the step, job, or stage level. This example uses template steps, which are then easy to reuse, e.g. across different jobs.

Create a `pipeline/build-steps.yml` file, and put in the steps needed to build, test, publish, and package your application. These are all the steps that are independent of environments and that you want to do once for each build.

If there are some steps (like push to a repository or feed) that you only want to do for branches that you are deploying, then you can add a `IsDeploymentBranch` parameter to the step template, and then calculate and pass in the value, e.g. based on the branch name (maybe `main` and `release/*`).

Note that parameters are resolved at compile time, so you can only use pre-defined variables such as the branch name, and no runtime variables, and have to reference them with template syntax `${{ parameters.Xxxx }}`.

Template syntax is used during pre-processing and can be used to generate the structure of the file or insert literals (or calculated literals) into the pipeline file.

It cannot access any runtime information, but note that once the template has been included, variables in the main pipeline are available at runtime in the included template using the normal macro syntax, e.g. `$(MyVariable)`

```yaml
parameters:
  - name: IsDeploymentBranch
    type: boolean

steps:
- checkout: self
  fetchDepth: 0

- task: DotNetCoreCLI@2
  displayName: Run dotnet tool restore
  inputs:
    command: custom
    custom: tool
    arguments: restore

- task: DotNetCoreCLI@2
  displayName: Run GitVersion dotnet tool
  inputs:
    command: custom
    custom: gitversion
    arguments: /output buildserver

- task: DotNetCoreCLI@2
  displayName: Run dotnet publish
  condition: succeeded()
  inputs:
    command: publish
    publishWebProjects: true
    projects: '*.sln'
    arguments: '-c Release -p:AssemblyVersion=$(GitVersion.AssemblySemVer) -p:FileVersion=$(GitVersion.AssemblySemFileVer) -p:Version=$(GitVersion.SemVer)+$(GitVersion.ShortSha) -o $(Build.ArtifactStagingDirectory)'
    zipAfterPublish: false
    modifyOutputPath: false

- task: PublishPipelineArtifact@1
  displayName: 'Publish app artifact'
  condition: and(succeeded(), ${{ parameters.IsDeploymentBranch }})
  inputs:
    targetPath: '$(Build.ArtifactStagingDirectory)'
    artifactName: PublishedBuild
```

### Reference the build steps template in the main pipeline

While you could put the build steps directly into the main pipeline file (as you are only running them once), it is better to keep the two files structured at separate abstraction levels:

* Main pipeline: high level stages and jobs.
* Child template files: low level build steps and deployment steps.

Keeping the two abstractions separate is easier to understand than mixing abstraction levels in the main file (build steps and deployment jobs).

```yaml
trigger:
- main

variables:
  IsDeploymentBranch: ${{ eq(variables['Build.SourceBranch'], 'refs/heads/main') }}

stages:
  - stage: BuildStage
    displayName: Build
    jobs:
    - job: BuildJob
      displayName: Build
      pool:
        name: Azure Pipelines
        vmImage: 'ubuntu-latest'
      steps:
      - template: 'pipelines/build-steps.yml'
        parameters:
          IsDeploymentBranch: ${{ variables.IsDeploymentBranch }}
```

## Add deployment jobs

TODO:

### Create the deployment steps template

Create a `pipeline/deploy-steps.yml` file for the deployment steps. This should have parameters for all the key values that differ by environment, e.g. the environment name, maybe prefix of suffixes for values, or similar settings.

Parameters are pre-processor values that are used to compile the pipeline, so can even change the structure.

Secrets, and secret management, needs some specific considerations.

```yaml
parameters:
  - name: EnvironmentName
    type: string

steps:
# Note: artifacts are downloaded automatically for deployment jobs, there's no need for explict download tasks

- script: |
    echo # Deployment #
    echo Environment name: $(Environment.Name) / $(parameters.EnvironmentName)
    echo Build number '$(Build.BuildNumber)'
  displayName: "Report deployment"
```


### Reference the deployment steps template in the main pipeline

In the main pipeline file, create the variables for each environment, and then the stages and deployment jobs. Link the stages to the environments created earlier.

Add a reference to the deployment steps template for each job, with the corresponding variables. (You could put the environment values directly into the template parameters, but I find them easier to organise and manage as variables.)

```yaml
trigger:
- main

variables:
  IsDeploymentBranch: ${{ eq(variables['Build.SourceBranch'], 'refs/heads/main') }}
  # Integration variables
  Integration_EnvironmentName: 'Integration'
  # Test variables
  Test_EnvironmentName: 'Test'
  # Production variables
  Production_EnvironmentName: 'Production'

stages:
  - stage: BuildStage
    ...

  - stage: IntegrationStage
    displayName: Integration
    condition: and(succeeded(), eq(variables.IsDeploymentBranch, 'true'))
    dependsOn: BuildStage
    jobs:
    - deployment: IntegrationDeployment
      displayName: Deploy Integration
      environment: Integration
      pool:
        name: Azure Pipelines
        vmImage: 'ubuntu-latest'
      strategy:
        runOnce:
          deploy:
            steps:
            - template: 'pipelines/deploy-steps.yml'
              parameters:
                EnvironmentName: $(Integration_EnvironmentName)

  - stage: TestStage
    displayName: Test
    condition: succeeded()
    dependsOn: IntegrationStage
    jobs:
    - deployment: TestDeployment
      displayName: Deploy Test
      environment: Test
      pool:
        name: Azure Pipelines
        vmImage: 'ubuntu-latest'
      strategy:
        runOnce:
          deploy:
            steps:
            - template: 'pipelines/deploy-steps.yml'
              parameters:
                EnvironmentName: $(Test_EnvironmentName)
  ...
```

Repeat for the Production environment as well.

## Secret management

### Configuring pipeline parameters

TODO:

## Additional considerations

### Pull request builds

TODO:

### More complex builds

TODO:

### Testing pipeline changes

TODO:

### Converting from DevOps Releases

TODO:


## Next steps

TODO:


## Note on dotnet 6 default react ports

A random port (HTTPS by default) is used for the front end proxy, usually in the 44xxx range, and inserted into `ClientApp/.env.development`, and also into the SpaProxyServerUrl property in `<appname>.csproj`.

This can be set by passing an explicit value for `--ProxyPort` to the dotnet create command, which will update both locations, e.g. `dotnet new react --output src/Demo.WebApp --ProxyPort 44301`

Random ports are also used for the API in the default Kestrel profile in `Properties/launchSettings.json` for applicationUrl, setting both HTTPS port (in the 7xxx range) and HTTP port (in the 5xxx range).

Random ports are also used for the API `iisSettings` for the alternate IIS Express profile for HTTPS (in the 443xx) range and HTTP (in the 3xxxx range).

When passing the API settings to the front end app, they are handled in `ClientApp/src/setupProxy.js`, which uses the environment variable `ASPNETCORE_HTTPS_PORT` if set, otherwise the first value in `ASPNETCORE_URLS`, otherwise defaulting to the IIS HTTP value (in the 3xxxx range).

The `ASPNETCORE_URLS` environment variable is the same setting used by Kestrel, although Kestrel may use wild card values instead of specific addresses.


## HTTPS Developer Certificates

### Windows and macOS

See: https://docs.microsoft.com/en-us/aspnet/core/security/enforcing-ssl?view=aspnetcore-5.0&tabs=visual-studio#trust-the-aspnet-core-https-development-certificate-on-windows-and-macos

The certificate is automatically installed. To trust the certificate:

```
dotnet dev-certs https --trust
```

### Ubuntu

See: https://docs.microsoft.com/en-us/aspnet/core/security/enforcing-ssl?view=aspnetcore-5.0&tabs=visual-studio#ubuntu-trust-the-certificate-for-service-to-service-communication

Create the HTTPS developer certificate for the current user personal certificate store (if not already initialised). 

```
dotnet dev-certs https
```

You can check the certificate exists for the current user; the file name is the SHA1 thumbprint. (If you want to clear out previous certificates use `dotnet dev-certs https --clean`, which will delete the file.)

```
ls ~/.dotnet/corefx/cryptography/x509stores/my
```

#### Trust the certificate for server communication

You need to have OpenSSL installed (check with `openssl version`).

Install the certificate. You need to use the `-E` flag with `sudo` when exporting the file, so that it exports the file for the current user (otherwise it will export the file for root, which will be different).

```
sudo -E dotnet dev-certs https -ep /usr/local/share/ca-certificates/aspnet/https.crt --format PEM
sudo update-ca-certificates
```

You can check the file exists, and then use open SSL to verify it has the same SHA1 thumbprint.

```
ls /usr/local/share/ca-certificates/aspnet
openssl x509 -noout -fingerprint -sha1 -inform pem -in /usr/local/share/ca-certificates/aspnet/https.crt
```

If the thumbprints do not match, you may have install the root (sudo user) certificate. You can check it at `sudo ls -la /root/.dotnet/corefx/cryptography/x509stores/my`.

#### Trust in Chrome

```
sudo apt-get install -y libnss3-tools
certutil -d sql:$HOME/.pki/nssdb -A -t "P,," -n localhost -i /usr/local/share/ca-certificates/aspnet/https.crt
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n localhost -i /usr/local/share/ca-certificates/aspnet/https.crt
```

#### Trust in Firefox:

```
cat <<EOF | sudo tee /usr/lib/firefox/distribution/policies.json
{
    "policies": {
        "Certificates": {
            "Install": [
                "/usr/local/share/ca-certificates/aspnet/https.crt"
            ]
        }
    }
}
EOF
```
