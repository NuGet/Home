# Title

- [Jeff Kluge](https://github.com/jeffkl) & [Jon Douglas](https://github.com/jondouglas)
- Start Date (2022-02-07)
- [11516](https://github.com/NuGet/Home/issues/11516)
- [4426](https://github.com/NuGet/NuGet.Client/pull/4426)

## Summary

<!-- One-paragraph description of the proposal. -->
When defining package versions in a central location, developers want the control to be able to override versions in various scenarios or even disable the ability to override versions for their product. In some cases, you may need to override a version for a particular project. With multiple definitions of the package version to be used, it can lead to undesired behaviors and make diagnosing any build errors quite difficult.

This proposal introduces the ability to override any centrally defined package version to ensure there's a single source of truth for the overridden version.

## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
When interviewing a number of developers who currently use the NuGet provided central package management feature, we found that the majority of them were frustrated with the lack of a way to override a package version. Many of these individuals would use the MSBuildSdks CentralPackageVersions as an alternative to give them the flexibility they needed in their repositories

The concept of dependency resolution overrides exists in many ecosystems and for NuGet, we want to ensure that there is a formal way to override package versions in the case that:

- There is a bug that is yet to be fixed in a transitive dependency in the project's graph such as awaiting a proper bugfix to be published and we can override with the last known good version.
- Any security vulnerability has been identified in a transitive dependency, but you're not able to upgrade the direct dependency pulling it in but rather the last good version.
- Only allowing a single copy of a given dependency in the tree to discourage version conflicts and define it in one place
- Being able to override a transitive dependency that may bring in an undesired behavior for a specific version being used with another dependency.

In these cases, rules would apply to all top-level and transitive dependencies in the sense that any override would apply anywhere in the dependency graph. This makes the override more powerful, and simplifies the implementation in the process. On the other side, this also can prose a risk in which an override may apply to packages that the user did not intend it to.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

First a user opts-in to Central Package Management with a `Directory.Packages.props` file in their directory tree.

A user would specify package versions in `Directory.Packages.props`:

```
<Project>
  <ItemGroup>
    <PackageVersion Include="PackageA" Version="1.0.0" />
    <PackageVersion Include="PackageB" Version="2.0.0" />
  </ItemGroup>
<Project>
```

A project would override the version with the `VersionOverride` metadata on a `<PackageReference />` item:

```
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net5.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="PackageA" VersionOverride="3.0.0" />
  </ItemGroup>
<Project>
```

In this case, the project's restore graph would resolve `PackageA` to version `3.0.0`. Any project that references it would also get that version and a user would be responsible for handling an unresolved conflicts.

Finally, a repo owner should be able to disable the ability for developers to override package version. This would be used for instance if someone wanted to ensure that all package versions are unified. This would be possible by setting the MSBuild property `EnablePackageVersionOverride` to `false` in a project or import like `Directory.Build.props`:

```
<Project>
  <PropertyGroup>
    <EnablePackageVersionOverride>false</EnablePackageVersionOverride>
  </PropertyGroup>
<Project>
```

When this is disabled, specifying a `VersionOverride` on a `<PackageReference />` would result in a restore error indicating that he feature is disabled.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

<!-- Why should we not do this? -->
There could be concerns regarding designing this at the version level and also at the central level rather than a more holistic approach for any package, it's version, and anywhere it may be defined in a project. Since MSBuild essentially allows users to do anything they want, we want to make overriding a package version simplistic and well documented.

Although there may be different approaches to the current design, this is one that has been tested in the field with many projects and the feedback has matched our expectations of doing the job to be done in question.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
The current concept that exists in the MSBuildSdks's CentralPackageVersions project has met the needs of many developers around the world who take it on as a dependency and it has been noted many times that this feature is missing in NuGet's first-class support of central package management.

Although there could be a more flushed out design that includes complete package IDs & their respective versions similar to other ecosystems, we are working with what we know teams need today and will build upon it in the future. 

If for any reason we decide to do a similar "package override" feature where a developer can replace any package on the dependency graph with another, we will allow for different levels of control such as replacing the package ID, the package version, and perhaps other selective mutations for a package in a graph.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

- [NPM package overrides](https://github.com/npm/rfcs/blob/main/accepted/0036-overrides.md)
- [Cargo overridding dependencies](https://doc.rust-lang.org/cargo/reference/overriding-dependencies.html)
- [Pub dependency_overrides](https://www.dartlang.org/tools/pub/dependencies#dependency-overrides)
- [MSBuildSdks CentralPackageVersions](https://github.com/microsoft/MSBuildSdks/tree/main/src/CentralPackageVersions#overriding-a-packagereference-version)

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
- There's potential to build on-top of this concept with Package Overrides instead of just Package Version Overrides.
- There is the potential to be able to specify a `<PackageVersion />` in a project instead of a `.props` file.
- There could be a MSBuild property that represents the package version and can be set in a project.
