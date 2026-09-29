# Include Metadata with IntelliCode Suggested Packages
<!-- Replace `Title` with an appropriate title for your design -->

- Donnie Goodson ([donnie-msft](https://github.com/donnie-msft))
- GitHub Issue: https://github.com/NuGet/Home/issues/10714

## Summary

<!-- One-paragraph description of the proposal. -->

Packages coming from [NuGet IntelliCode Package Suggestions](https://devblogs.microsoft.com/nuget/intellicode-package-suggestions-for-nuget-in-visual-studio/#:~:text=IntelliCode%20Package%20Suggestions%20use%20a,Netflix%20recommendations%20for%20NuGet%20packages.) (aka, "recommender") are not sourced directly from a package source, and therefore will not contain metadata such as Known Owners or Download Count.
In order to include this metadata, the NuGet Package Manager (PM UI) can search for each recommended package while loading search results by re-querying each recommended package, or a change can be made to the implementation of the recommender.

## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->

Missing recommended package metadata means customers cannot see Known Owner or Download Count for the first 5 packages shown in the PM UI Browse Tab from nuget.org. When those packages are shown in the regular search results, they will have this metadata which can cause confusion for customers.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

#### Option 1: Package Recommender Service

The Package Recommender is currently shipped as a VS Extension (VSIX) in Visual Studio.
In order to provide up-to-data metadata for a package, a service would allow clients, such as PM UI, to query for recommended packages. The service can append the package metadata along with each package it recommends.

#### Option 2: Explicitly Search for each recommended package.

When the PM UI receives recommended search results, it can call Search for each of those packages. 
An attempt to re-query each of the 5 recommended packages brought up concerns of performance in the PM UI. See pull request: https://github.com/NuGet/NuGet.Client/pull/4049.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

## Prior Art

1. An attempt to re-query each of the 5 recommended packages brought up concerns of performance in the PM UI. See pull request: https://github.com/NuGet/NuGet.Client/pull/4049.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
