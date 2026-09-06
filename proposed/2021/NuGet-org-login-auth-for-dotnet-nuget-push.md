# NuGet.org login authentication workflow for `dotnet nuget push`

- Author: Christopher Gill (https://github.com/chgill-MSFT)
- Start Date: 2021-03-1
- GitHub Issue: https://github.com/NuGet/Home/issues/10657
- GitHub PR: N/A

## Summary

Currently there are 3 ways to push NuGet packages to NuGet.org:
* [Manual upload on NuGet.org](https://www.nuget.org/packages/manage/upload)
* `donet nuget push` with a valid API key
* `nuget push` with a valid API key

I propose creating a workflow to push to NuGet.org via the `dotnet nuget push` command by NuGet.org account login in the CLI or the browser.

## Motivation 

1. API keys can be a pain to use in many circumstances, especially for beginners. To securely upload a package to NuGet.org via the CLI you need to:
   1. Create a package.
   2. Login to NuGet.org using MSA.
   3. Create an API key with the correct permissions/scope. Beginners will be presented with potentially overwhelming options and technical terms like expiration time, scope, unlist, and glob pattern. This is complicated enough, we have an entire [doc on how to do it securely](https://docs.microsoft.com/en-us/nuget/nuget-org/scoped-api-keys).
   4. Either store the API key securely. Beginners will need to do research on how to do this or may insecurely store the API key in plaintext. The best way to do this in Windows is with `nuget setapikey`, which currently has no support on MacOS or Linux.
   5. Push the package using the very long `dotnet nuget push <package id> --api-key <api key> --source https://api.nuget.org/v3/index.json` command, which is unlikely to figure out without copying from docs.
2. Alleviate pain for authors who are frustrated by expiring API keys.
3. Reduce risk of simple mistakes with API keys that lead to security vulnerabilities such as accidental leaks to a public repo or storing the API in plaintext to avoid hassle.
4. Provide workaround for [lack of `nuget setapikey` equivalent for MacOS and Linux.](https://github.com/NuGet/Home/issues/6437)
   
The ideal workflow for a beginner to push a package should be:
1. Create a package
2. Execute `dotnet nuget push` which prompts me to log in at some URL.
3. Follow the URL and log in using MSA.
4. Execute `dotnet nuget push` and it *magically works.*

No need to learn how to securely create an API key, store the API key securely, or worry about leaks and expirations.

We believe this feature will help convert a dotnet CLI users in a NuGet package author.
### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->


### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

Users who want to avoid the hassle of API keys have the option to [manually upload a package to NuGet.org](https://www.nuget.org/packages/manage/upload). So one could argue this is unnecessary.

We believe this will still be an improvement for many customers prefer using the dotnet CLI for most of their workflow and also reduces the need to manually navigate to NuGet.org, go to the Upload tab, and search your file system for the target package. This feature is more efficient and delivers a *delightful* package push experience.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevent to this proposal? -->

### NPM

### Pub

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
