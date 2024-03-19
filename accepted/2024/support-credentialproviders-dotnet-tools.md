# ***Support for credential providers deployed via .NET tools***
<!-- Replace `Title` with an appropriate title for your design -->

- Author Name: <https://github.com/kartheekp-ms>
- GitHub Issue: <https://github.com/NuGet/Home/issues/12567>

## Summary

## Motivation

Currently, credential providers support `*.exe` for .NET Framework and `*.dll` for .NET Core. They are typically divided into two folders under the NuGet credential provider base path. For .NET Framework, the providers are discovered by searching `credentialprovider*.exe` and executing that program. For .NET Core, they are discovered by searching `credentialprovider*.dll` and executing `dotnet <credentialprovider>.dll`. Before .NET Core 2.0, this division was necessary because .NET Core only supported platform-agnostic DLLs. However, with the latest versions of .NET, this division is no longer necessary, but it does require supporting and deploying multiple versions. This is further reinforced by the two plugin path environment variables `NUGET_NETFX_PLUGIN_PATHS` and `NUGET_NETCORE_PLUGIN_PATHS`, which need to be set for each framework version.

A deployment solution for dotnet is [.NET tools](https://learn.microsoft.com/dotnet/core/tools), which provide a seamless .NET installation and management experience for NuGet packages. Using .NET tools as a deployment mechanism has been a recurring request from users of the .NET ecosystem who need to authenticate with private repositories. The ideal workflow for repositoroes that access private NuGet feeds like Azure DevOps would be:

1. Customers have the .NET SDK installed.
2. They run `dotnet tool install -g Microsoft.CredentialProviders`.
3. They run `dotnet restore` with a private endpoint, and it 'just works' (i.e., the credential providers from step 2 are used during credential acquisition and are used to authenticate against private endpoints).

This almost works today, but only for the Windows .NET Framework. The goal is to support this cross-platform for all supported .NET runtimes.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->