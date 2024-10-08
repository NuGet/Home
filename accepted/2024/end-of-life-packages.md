# End-of-life (EOL) packages and package lifecycle
<!-- Replace `Title` with an appropriate title for your design -->

- [Jon Douglas](https://github.com/jondouglas) <!-- GitHub username link -->
- [#9638](https://github.com/NuGet/NuGetGallery/issues/9638), [#9837](https://github.com/NuGet/NuGetGallery/issues/9837) <!-- GitHub Issue link -->

## Summary

<!-- One-paragraph description of the proposal. -->
Today, there exists two major package status mechanisms for understanding if a package is [vulnerable](https://learn.microsoft.com/en-us/nuget/concepts/auditing-packages) and/or [deprecated](https://learn.microsoft.com/en-us/nuget/nuget-org/deprecate-packages).

Recently, the NuGet team has shipped functionality allowing package authors to include markdown READMEs to contain a hodgepodge of information relating to the package such as installation instructions, getting started examples, contributing tips, and less often seen is how the package is supported through an official or unofficial support policy.

To make these package statuses clearer to package consumers and authors, this proposal introduces a new concept to indicate when a package has reached the end of its intended life.

The reason being is that the current package statuses mean specific things today and how they are perceived such as:

- Vulnerable - Indicates the package has a known security vulnerability registered in an official CVE database.
- Deprecated - Indicates the package is deprecated, meaning that people should consider migrating off of the package for a common reason such as it is **legacy, included critical bugs, or any other reason** the maintainer wants to disclose. These packages are no longer recommended to use but may still receive updates.

Introducing a concept of **"end of life"** will make it clear to package authors that these packages are not intended to be used any further as they are no longer supported, will not receive critical updates, and feedback will not be considered. This would be a new definition including:

- End of life (EOL) - Indicates the package is no longer maintained, supported, or updated by its authors.

| Status      | Definition                              | Updates Available | User Guidance                          | Risk     |
|-------------|-----------------------------------------|-------------------|----------------------------------------|----------|
| EOL         | No longer maintained or supported       | No                | Migrate to alternatives                | High     |
| Vulnerable  | Contains known security vulnerabilities | Possibly          | Update or find secure alternatives     | High     |
| Deprecated  | Not recommended for use                 | Possibly          | Transition to newer packages           | Moderate |

## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->

There are two primary motivations in doing this work. The first being a direct answer to the "am I supported?" question. This is especially prevalent in the .NET ecosystem due to many first-party package providers have robust support policies that require a developer to understand with a decoder ring and too much time on their hands. It should be explictly simple to know you're supported in your current solution so long as your packages do not report EOL.

The second primary motivation is security. Being on unsupported packages that are EOL is a high risk as there will be no security updates and may render your application vulnerable. A typical lifecycle of an end of life package may accrue known vulnerabilities over the years as they are discovered which may add additional risk for developer teams to sincerely consider prompt remediation.

The expected outcome would be developers having a clear package status for knowing if a package in their package graph is "supported" or not through its status being EOL. EOL packages tend to be very difficult for engineering teams to build in the first place to provide security updates and typically aren't serviced do to the difficulty.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
This functionality will follow the footsteps of the existing deprecation and vulnerability functionality. It will be closest to the deprecation experience today, but will include a way for a package owner to mark a package and its many versions at anytime "EOL". There will be no reason nor custom message to provide to users. However, there will be an suggested alternate package to use to encourage a direct action from the developer.

When a package is marked EOL, a few things will happen:

- The package at restore time will appear with a new warning letting any consumers know the package is EOL.
- The package on NuGet.org and throughout browsing experiences will show a label or affordance mentioning its EOL status.
- The package on NuGet.org API can be queried for the EOL package status for any tooling to build upon this.
- The dotnet CLI will have a list command to show all EOL packages.

A new visual icon will be used to encourage a user to "stop" using an EOL package. A stop sign or a crossed circle concept should suffice(i.e. `StatusStopped`), highlighting the need for immediate action.

Given that this can be either an extension of the existing deprecation functionality or its own standalone functionality, the only major con of extending today is adding more reasons and status which can dilute the intention of a package's lifecycle such as:

Package created -> package deprecated -> package end of life

A standalone feature also allows for more tailored experiences in the future without being constrained to the existing deprecation framework. As needs evolve for end of life, features can be easily adapted and extended.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

<!-- Why should we not do this? -->
It could be argued that it really isn't the package manager's job to designate whether or not a package is supported by the current maintainer. Rather that it is the responsibility of the maintainer to be in close contact with their community to help them understand how their products are supported, such as NuGet packages.

Of course one of the major drawbacks will be having a clear differentiation of each of these package statuses. There is a clear need to provide this, and perhaps this could be a good precedent to provide for package maintainers in an end-to-end fashion of a package's life.

On the telemetry side, packages that are EOL but still are used heavily may be an indicator of lacking an alternative and may need further investigation.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
Having a central place for marking a package end of life can be a huge quality of life upgrade, especially in the current climate we live in where NuGet can now provide warnings at restore time for vulnerabilities, [deprecations in the future](https://github.com/NuGet/Home/issues/13266), and potentially this.

The current alternatives exist today and are utilized. Many packages provide their support policies through package READMEs or as resources on their project's website. They use the deprecation feature with various reasons to communicate with their users regarding the package's current status.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

There exists many ecosystems with deprecation concepts, but to my knowledge and research I have not found one that includes this EOL concept.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->
- Is this a unique enough experience to consider being a standalone package status?
- Is end of life (EOL) the proper terminology?

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
- Integration with security tools to automatically flag EOL packages in dependency graphs.
- Enhanced UI features on NuGet.org and in development tools to better highlight EOL packages.
- Tools to suggest or automate migration from EOL packages to supported alternatives.
- Future enhancements to manage package lifecycle stages, including pre-release, stable, deprecated, and EOL.
- Enable community-driven support for EOL packages where maintainers have abandoned projects but the community wishes to continue support.