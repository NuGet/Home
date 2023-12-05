# NuGet Package Management - Command Palette & Quick Picks in Visual Studio Code
<!-- Replace `Title` with an appropriate title for your design -->

- Jon Douglas, Allie Barry, Jean-Pierre
- GitHub Issue <!-- GitHub Issue link -->

## Summary

<!-- One-paragraph description of the proposal. -->
This proposal introduces a command palette experience including quickpick flows for NuGet package management. It covers browsing for a package and installing it, managing packages(removing, updating, etc) in existing projects & solutions, clearing caches/package folders, packaging a library, pushing it to a source, managing package sources, and opening the package manager.

## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Visual Studio Code now supports "C# Dev Kit" which is an extension that allows a .NET/C# developer to use familiar Visual Studio tooling for their purposes. This proposal brings integrated Visual Studio Code-like experiences directly into the extension to make it easier for .NET/C# developers to manage their packages and package-related tasks.

Requests for NuGet functionality are at an all time high since the general availability of C# Dev Kit. NuGet feature requests remain in the top 3 of GitHub issues on the C# Dev Kit repository. It was a popular ask at MVP Summit, Microsoft Build, and dotnetConf.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or pseudocode to show how this proposal would look. -->

#### Browse and Install a Package

A new command is listed named `NuGet: Add a package...``. When a developer selects this command, it will prompt them in a search box to provide a search term for a respective package to be found on their package sources. The results box will provide them a selectable list that also shows what package sources the package can be found on. It also includes a brief snippet of the description, an icon, and the latest version available.

#### Removing a Package

#### Updating a Package

#### Clearing package caches/folders

#### Packaging a Library

#### Pushing a package to a source

#### Managing package sources

#### Opening a Package Manager

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
