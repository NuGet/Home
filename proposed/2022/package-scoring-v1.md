# Package Scoring v1

- [Jon Douglas](https://github.com/JonDouglas)
- Start Date (2022-05-16)
- [dotnet/designs#216](https://github.com/dotnet/designs/pull/216)

## Summary

<!-- One-paragraph description of the proposal. -->
Having packages of high quality is crucial to the .NET ecosystem. As a first step to increase awareness of the characteristics that make a package high quality, we are proposing the first iteration of an effort known as package scoring.

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

Anyone browsing a package on NuGet.org should be able to quickly evaluate the security and health of any NuGet package. By bringing package scoring to NuGet, we provide benefits of helping deter software supply chain attacks before they happen and gives consumers and package maintainers comprehensive protection by addressing any potential issues with their package(s) before they become a problem. This provides a pro-active approach towards security rather than a reactive one in which we assume that open source code and really any code may be in fact malicious. With helpful scoring indicators, package scoring helps you audit and make the best trust decisions for taking on new dependencies.

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

**Issue Examples:**

- Invalid .nuspec / .csproj
- Missing dependency
- Missing README
- No example
- Not enough public API documentation
- Bad semver
- Not v1+
- No website
- No repository
- Unmaintained
- No bug tracker
- Has CVE (Critical, High, etc)
- Deprecated license
- Missing license
- Non SPDX license
- Unsafe copyright
- Deprecated
- Empty package
- Malware
- etc

#### Popularity

Popularity is the more unique of the other three categories which are more issue based. Popularity is calculated as how many projects depend on a package over the past 30 days. This is scored as a percentile up to 100% (most used) to 0% (least used).

Since this is not possible with current data pipelines, we will work on providing such an experience in the future and use two proxy values such as total weekly downloads and total count of packages depending on the package to be scored up to a percentile of up to 100%.

- Total Weekly Downloads
- Number of Dependents

Total Score - 100

#### Quality

Quality is the combination of:

- Follow NuGet conventions
  - Provides a valid .csproj / .nuspec
  - Provides a valid README
- Provide documentation
  - Provides an example
  - 20% or more of the public API has xml doc comments
- Platform support
  - Supports all possible modern platforms i.e. [.NET 5+/.NET Standard](https://docs.microsoft.com/en-us/dotnet/standard/net-standard?tabs=net-standard-1-0#net-5-and-net-standard) (iOS, Android, Windows, MacOS, Linux, etc)
- Pass static analysis
  - Code has no errors, warnings, lints, or formatting issues.
- Support up-to-date dependencies
  - All of the package dependencies are supported in the latest version
  - Package supports the latest stable .NET SDK

Each of these issues would be associated an arbitrary amount of points to make a total of 100. This definition of quality is debatable and thus we will create a minimal set of quality practices.

Total Score - 100

#### Maintenance

Maintenance is the simplest of them all as it pertains to whether the package has been updated in a reasonable timeframe. Packages that have not been updated in more than a year may be unmaintained and any problems with the package may go unaddressed.

- Package updated in the last year.

The score may also be shown as a decayed value over the year approaching the year mark where it goes stale.

Total Score - 100

#### Security

Finally, Security represents the trust indicators representing the package in the current state of the supply chain risk. This includes known vulnerabilities, license risk, and any issues surrounding secure supply chain risk.

- No known security vulnerabilities (Critical, High, Moderate, Low) in top-level or transitive dependencies.
- Specifies a valid license (SPDX, embedded)
- Not deprecated.

An emphasis would be placed on known security vulnerabilities and license restriction.

Total Score - 100

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

<!-- Why should we not do this? -->
- This is a novel area and hasn't been done from the security perspective by any major package ecosystem. There are working groups trying to solve this problem today.
- This can paint packages in an unfair light for issues they may not be able to actually control but perceived that they can.
- This can be gamified to a certain degree.
- This is one model of package issues and scores. There are other models such as all-up scorecards based on best practices.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

As mentioned in the [original spec](https://github.com/dotnet/designs/pull/216), there is a significant value add to user needs from regular surveys with regards to:

- It's hard to tell if a package is of high quality and actively maintained. (5.27 Score)
- It has insufficient package documentation (i.e. Readme, changelog, examples, API reference). (4.81 Score)
- It is hard to tell if a package is secure. (4.61 Score)

In addition in recent surveys of 2022, we have seen other themes pop up as well such as:

- Clear metrics that help me evaluate package quality (3rd most popular averaging 16/100 points spent on this area)
- Special badges for key ecosystem projects, trusted packages that significantly contribute to the .NET ecosystem  (4th most popular averaging 14/100 points spent on this area)

We then asked how people install a package with the following emphasis in order.

1. Package solves my problem.
2. Package has enough downloads.
3. Package is open source.
4. Package has high quality documentation.
5. Package is maintained by a notable author or organization.
6. Package has been updated recently and is updated regularly.
7. Package has few dependencies.
8. Package is mentioned in blog posts and platforms like StackOverflow.
9. Package is code signed by the author.
10. Manual code inspection of the package’srepository.
11. Package has a blue checkmark icon.
12. Approval bycomponent governance team or other stakeholder.

Finally, we know the dissatisfaction of browsing for packages to be the following in order of priority:

1. Evaluating the overall quality of a package.
2. Evaluating if I can trust a package or publisher.
3. Discovering new packages.
4. Evaluating if I can legally use a package.
5. Finding necessary package documentation.

With all this said, we believe there is significant impact in doing this work for the security and evolution of the .NET ecosystem.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

- https://socket.dev/
- https://npms.io/
- https://deps.dev/
- https://pub.dev/
- https://www.npmjs.com/

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->
- What happened to the community score?
  - At this time, it would require a significant amount of work to add GitHub/GitLab/BitBucket and other git providers being supported for a community score. Thus the focus is on the package for these first iterations. In the future this can be revisited with the evolution of security for OSS repositories.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
- The .NET ecosystem can use exposed score APIs & metadata to create new tooling & experiences with.
- [Package Validation](https://docs.microsoft.com/en-us/dotnet/fundamentals/package-validation/overview) can be added to a future issue check.
- [Reproducible Builds](https://github.com/dotnet/reproducible-builds) can be added to a future issue check.
- [OSSF Scorecard](https://github.com/ossf/scorecard) can be added to a future issue check.
- Score distributions on different issues will vary with implementation and weighing. We will not get this right the first or second time. We will need to iterate constantly to find values that make sense.
- Scoring can be iterated and improved in future versions as we learn more about the overall health of the .NET ecosystem.
