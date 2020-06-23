# Remote Authentication

* Status: ** Draft **
* Author(s): [Rob Relyea](https://github.com/rrelyea)

## Issue

TODO

## Who are the customers

Package Consumers who are using authenticated feeds.

## Requirements


## Problem Background

Several operations require authentication to a source (sometimes call feed or repository) in NuGet:

- restore
- search
- icon fetching for search
- update

Authentication techniques in NuGet.

 1. **VS Auth** - Inside VS, NuGet can demand implementers of Auth.
    - VS-AACP - VS installs Azure Artifacts Credential Provider
      - caches credentials in VS Keyring: %LocalAppData%\.IdentityService\SessionTokens.json
 1. **NuGet CLI v2 Auth** - Our xplat auth plugin technique. This allows xplat auth in all of our codepaths (nuget.exe, msbuild.exe, dotnet.exe and VS). [needs NuGet 4.8+, VS 15.8+]
    - VS installs AACP - Azure Artifacts Credential Provider
      - caches credentials in %LocalAppData%\MicrosoftCredentialProvider\SessionTokenCache.dat
 1. **NuGet.Config PAT/password in nuget.config**
    - see `dotnet nuget add source`
    - or via env vars. (explore details on how this works)
 1. **NuGet CLI v1 Auth** - NuGet.exe historically allowed an exe in the same directory that nuget.exe would communicate with. We list this for completeness, but this has been replaced entirely by v2 Auth. (v1 still works)

nk: wouldn't it be nice if CLI's and VS shared credential caches. (likely easier with new code on codespaces)

## Scenarios

### VS & Azure Artifacts
- If the dev uses the same account to auth to the codespace as they will use to get packages from azure artifacts, no additional auth is required.
- If the dev uses a 2nd account to get packages from azure artifacts, that account must be authenticated for that feed.
    - Part of that problem is we don't have an anchor for authenticated sources. Perhaps we improve the error experience, and provide an anchor in the UI, so they can figure out how to do this. Tracking issue: [nuget/home#7814](https://github.com/NuGet/Home/issues/7814)

JM: AAD - conditional access policies ... may only work on the same machine...

### dotnet.exe/nuget.exe/msbuild.exe running in VS Terminal
- msbuild.exe /restore /p:NuGetInteractive=true
  - works via codeflow today, if you ask for interactive
    - integrated windows auth doesn't work w/o interaction, unlike normal CLIs and AACP on a client. (see "could it remote..." below)
  - device flow prompts once per feed, where it should be able to use the same creds, in most cases, if same AAD Tenant. [artifacts-credprovider#195](https://github.com/microsoft/artifacts-credprovider/issues/195)
- nuget.exe
  - NuGet.exe should detect execution on codespace, and send canPrompt to plugin as false. [nuget/home#9687](https://github.com/NuGet/Home/issues/9687) 
- dotnet.exe restore --interactive
  - make install of AACP (dotnet core flavor) installable easily [client.engineering#360](https://github.com/NuGet/Client.Engineering/issues/360)
  - Longer term: should dotnet.exe be able to use full framework copy of AACP? Or should dotnet.exe copy of AACP be able to replace full framework copy.
- all
  - [nuget/home#9688](https://github.com/NuGet/Home/issues/9688) improve error experience with NUXXXX errors when auth fails, or auth fails and no cred provider is there, etc...

#### Could it remote back to client to get client auth info

#### Could it talk to VS Keychain on server?
Not a public API, so AACP doesn't currently use it. Not public due to GDPR and perhaps other reasons?

### Github Package Repository (GPR)
- Dev connects to codespace/repo that needs to use PAT from some feeds on GPR (github package repository). They already have (via non-repo based nuget.config) some PATs stored.
  - Ideally, if we have credential info on the client, can share that. note encryption can only be decrypted on that client. 

### MyGet, Artifactory 
- MyGet has a VS credential provider - https://docs.myget.org/docs/reference/credential-provider-for-visual-studio
- Artifactory doesn't mention a credential provider here: https://www.jfrog.com/confluence/display/JFROG/NuGet+Repositories


### ONPremises server azure artifacts 
- scenario viable?

### CLI cred store on client - usable?
 - what if they used CLI for auth on the client.
if nuget remoted auth request to nuget client, and nuget client asked a plugin (aacp) for normal request (uri, x, y, x) - would it run and work?
JM: likely should work.
GCM: does a proxy model...git credential manager. see that.
JM: always translates things into devops tokens...which are flexible.

### Open Questions

- does the existing principal from codespace creation get reused?

## Background

### dotnet restore and aacp
rd obj -r

dotnet nuget locals -c all

del %LocalAppData%\MicrosoftCredentialProvider\SessionTokenCache.dat

dotnet restore --interactive

:: precendence order: cached creds -> windows creds -> device flow

with cmann's PR:

:: cached creds -> windows creds -> interactive (opened in default system browser)

interactive false --> always goes to device flow.
 
### nuget restore and aacp
rd obj -r

dotnet nuget locals -c all

del %LocalAppData%\MicrosoftCredentialProvider\SessionTokenCache.dat

c:\repos\nuget.exe restore

:: precendence order: cached creds -> windows creds -> dialog prompt -> (if cancelled previous) device flow

### msbuild /r and aacp
rd obj -r

dotnet nuget locals -c all

del %LocalAppData%\MicrosoftCredentialProvider\SessionTokenCache.dat

msbuild.exe /r /p:NuGetInteractive=true

:: precendence order: cached creds -> windows creds -> (if cancelled previous) device flow

## Improvements to AACP
cmann: aacp uses ADL - old.
   vs identity team wants them to use MSAL - new, fancy, like VS 2019.
        that PR...added MSAL support. also added env var...
        if you point that cache to vs via envvar...would use vs keyring.
        (regardless, sessiontokencache would be used.)