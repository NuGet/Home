# Title

- [Jon Douglas](https://github.com/JonDouglas)
- Start Date (2022-05-16)
- [dotnet/designs#216](https://github.com/dotnet/designs/pull/216)

## Summary

<!-- One-paragraph description of the proposal. -->
Having packages of high quality is crucial to the .NET ecosystem. As a first step to increase awareness of the characteristics that make a package high quality, we are introducing the first iteration of an effort known as package scoring.

This proposal and initial iteration will focus on common additions to a NuGet package that benefits the entirity of the .NET developer ecosystem. For reference, majority of developers we survey and chat with talk about 5 key characteristics that they deem a high quality or "healthy" package:

A high quality or "healthy" package is one that follows the following characteristics:

- It is actively maintained. Either with recent commits or an annual update/notice that the package is up-to-date.
- It is documented. It provides enough documentation to install, get started, and has public API documentation on it's members.
- It has a way to report bugs. It provides a centralized location or repository in which issues are regularly triaged & resolved in future releases.
- It resolves security flaws quickly. It fixes known vulnerabilities & releases an unaffected release quickly.
- It is not deprecated. It is in an active state meeting all the criteria above.

This proposal introduces the first iteration of package scoring. While it derives from the original proposal [last year on this topic](https://github.com/dotnet/designs/pull/216), it provides the minimum requirements for a v1.0 of implementing this on NuGet.org.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

Package scoring will contain four unique categories to start off with. The categories are the following:

- Popularity - How popular a package is & recognized in the ecosystem.
- Quality - The completeness of a package following best practices & providing documentation.
- Maintenance - The state of maintenance for a package based on it's update cadence.
- Security - The sense of trust based on a package being free of known security vulnerabilities, license risk, and current supply chain risk.

Each category has the potential to total up to 100 points.

- Categories in which the package is **in control** can always reach the maximum amount of points.
- Categories in which the package is **not in control** will be determined by the state of the ecosystem.

EX: A package is in control of providing ample metadata to ensure the quality of the package reaches the full score. A package is not in control of how popular it may be however.

To scale package scoring for the future, each score will be comprised of an analysis of package performance and potential package/dependency issues. Each of these issues will be categorized into one of these four categories and empower the author and consumer to resolve these issues to the best of their ability and control.

#### Issues

As a means to scale package scoring to it's potential through continuous iteration, each category will have its own set of issues that a user can be aware of when browsing through the package. Keeping the same idea of **being in control** or **not in control** also applies to package issues.

For issues which can be addressed, an issue will include an empowering message regarding how one can take action to help address the issue.

EX: A package might be missing a README which a developer may not be able to easily get started with the package. They might be able to then contribute a new issue or even the inclusion of the README file to the NuGet package if it's open source.

#### Popularity

Popularity is the more unique of the other three categories which are more issue based. Popularity is calculated as how many projects depend on a package over the past 30 days. This is scored as a percentile up to 100% (most used) to 0% (least used).

Since this is not possible with current data pipelines, we will work on providing such an experience in the future and use two proxy values such as total weekly downloads and total count of packages depending on the package to be scored up to a percentile of up to 100%.

- Total Weekly Downloads
- Number of Dependents

#### Quality

Quality is the combination of:

- Follow NuGet conventions
  - Provides a valid .csproj / .nuspec
  - Provides a valid README
- Provide documentation
  - Provides an example
  - 20% or more of the public API has xml doc comments
- Platform support
  - Supports all possible modern platforms (iOS, Android, Windows, MacOS, Linux, etc)
- Pass static analysis
  - Code has no errors, warnings, lints, or formatting issues.
- Support up-to-date dependencies
  - All of the package dependencies are supported in the latest version
  - Package supports the latest stable .NET SDK

#### Maintenance

Maintenance is the simplest of them all as it pertains to whether the package has been updated in a reasonable timeframe. Packages that have not been updated in more than a year may be unmaintained and any problems with the package may go unaddressed.

- Package updated in the last year.

#### Security

Finally, Security represents the trust indicators representing the package in the current state of the supply chain risk. This includes known vulnerabilities, license risk, and any issues surrounding secure supply chain risk.

- No known security vulnerabilities (Critical, High, Moderate, Low)
-

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
