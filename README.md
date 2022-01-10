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

```sh
mkdir src
dotnet new sln
dotnet new react --output src/Demo.WebApp --ProxyPort 44301
dotnet sln add src/Demo.WebApp
```

Check it works by running the web API in one PowerShell terminal:

```pwsh
dotnet run --project src/Demo.WebApp --environment Development --urls 'http://*:8002'
```

And then also running the front end proxy in a second PowerShell terminal (pointing at the API):

```pwsh
$env:ASPNETCORE_URLS = 'http://localhost:8002'
npm run start --prefix src/Demo.WebApp/ClientApp
```

Check the front end proxy with a browser, e.g. `https://localhost:44301/`, and make sure to go to the Fetch data page to ensure the connection to the API is working.

**NOTE:** If you have trouble with HTTPS, or do not have certificates set up, then see the section at the end of this file for HTTPS Developer Certificates.

### HTTPS for the web API (on Ubuntu)

**TODO:** Using HTTPS for the API had issues working on Ubuntu, where the proxied request would time out, and eventually report a JS stack trace referencing `builtin exit frame: getPeerCertificate` and `FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed - JavaScript heap out of memory`

Web API:

```pwsh
dotnet run --project src/Demo.WebApp --environment Development --urls 'https://*:44302'
```

Front end:

```pwsh
$env:ASPNETCORE_URLS = 'https://localhost:44302'
npm run start --prefix src/Demo.WebApp/ClientApp
```

This may be the Node server not trusting the developer certificate. A similar issue happens if you just run the API server, and use it to trigger automatic launching of the front end proxy.


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
