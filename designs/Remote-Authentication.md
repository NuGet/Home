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
    - AAMCP - VS installs Azure Artifacts MEF Credential Provider
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

### Azure Artifacts (existing) 
- Dev who uses a repo on client machine, connects to codespace from same machine. We should make the auth experience simple, given that they have already authenticated all those feeds on the client.
  - AA's MEF Credential Provider (AAMCP) should support this today. If this isn't working, needs debugging.
  
### Azure Artifacts (fresh)
- Dev connects to codespace/repo from machine which has never used that repo - thus likely hasn't authenticated to those feeds.
  - AAMCP on codespace should ask VS identity for creds, which will proxy to client, and ask AAMCP on client. Which should use in the following order: VS KeyChain stored creds -> Windows Auth/etc... -> Prompt
    - note prompt won't work in this scenario. it won't prompt on client today, but will display "stale" state if you look really hard.
    - part of that problem is we don't have an anchor for authenticated sources. Perhaps we improve the error experience, and provide an anchor in the UI, so they can figure out how to do this.

JM: AAD - conditional access policies ... may only work on the same machine...

### GPR (existing)
- Dev connects to codespace/repo that needs to use PAT from some feeds on GPR (github package repository). They already have (via non-repo based nuget.config) some PATs stored.
  - Ideally, if we have credential info on the client, can share that 

### GPR (fresh)
- Dev connects to codespace/repo that needs to use PAT from some feeds on GPR (github package repository)

### MyGet, Artifactory 
- research scenarios

### dotnet.exe running in VS Terminal
- how can it work via VS keychain, or aacp .dat
nk: nuget server -> talks to nuget's own v2 plugin...which could talk straight to VS on server.

### dotnet.exe running in VS terminal ... w/ no VS
   - how does that work?

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