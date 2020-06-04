# Remote Authentication

* Status: ** Draft **
* Author(s): [Rob Relyea](https://github.com/rrelyea)

## Issue

TODO

## Problem Background

Several operations require authentication to a source in NuGet:

- restore
- search
- icon fetching for search
- update

There are 3 authentication techniques in NuGet.

 1. VS Auth - Inside VS, NuGet can demand implementers of Auth. Azure Artifacts ships one with VS.
 1. NuGet CLI v1 Auth - NuGet.exe historically allowed an exe in the same directory that nuget.exe would communicate with.
 1. NuGet CLI v2 Auth - In NuGet 4.8 (VS 15.8), we enabled a new xplat auth plugin technique. This allows xplat auth in all of our codepaths (nuget.exe, msbuild.exe, dotnet.exe and VS).

 When solving this problem when there is some nuget code running on the client and server, we need to decide which of those to support.

## Scenarios

- Azure Artifacts (existing) - Dev who uses a repo on client machine, connects to codespace from same machine. How easy could we make the auth experience given that they have already authenticated all those feeds on the client.
  
  - what if they used VS for auth?
  - what if they used CLI for auth?

- Azure Artifacts (fresh) - Dev connects to codespace/repo from machine which has never used that repo - thus likely hasn't authenticated to those feeds.

- GPR (existing) - Dev connects to codespace/repo that needs to use PAT from some feeds on GPR (github package repository). They already have (via non-repo based nuget.config) some PATs stored.

- GPR (fresh) - Dev connects to codespace/repo that needs to use PAT from some feeds on GPR (github package repository)

- MyGet, Artifactory - ??? - research scenarios


## Possible approaches

1. Remote v2 Auth call to client - When credentials are needed, the server calls to the client to authenticate via prompts, etc... Relies on NuGet CLI v2 Auth provider being installed on VS client side.
2. support VS auth providers too? - not sure if this parallel code base is important to support.
3. other?

### Remote v2 Auth call to client

When credentials are needed, nuget server code will remote a call to nuget client with a NuGet.Credentials.PluginCredentialRequest. The client will interact with the user, if necessary, and reply back to the server with a PluginCredentialResponse.

## Who are the customers

Package Consumers who are using authenticated feeds.

## Requirements

* 

### Open Questions

- does the existing principal from codespace creation get reused?
