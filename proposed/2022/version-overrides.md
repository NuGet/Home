# Title

- [Jeff Kluge](https://github.com/jeffkl) & [Jon Douglas](https://github.com/jondouglas)
- Start Date (2022-02-07)
- [11516](https://github.com/NuGet/Home/issues/11516)
- [4426](https://github.com/NuGet/NuGet.Client/pull/4426)

## Summary

<!-- One-paragraph description of the proposal. -->
When specifying package versions in a central location, developers want the to be able to override versions for a particular project.  This is useful when a project is not directly tied to the rest of the repo and needs to use a newer version of a package.  Additionally, some projects have a need to specify an older version of a package when targeting an older version of .NET Framework.

This proposal introduces the ability to override a centrally defined package version on a `<PackageReference />` item in a well documented and supported way.

## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
When interviewing a number of developers who currently use the NuGet provided central package management feature, we found that the majority of them were frustrated with the lack of a way to override a centrally defined package version for a particular project. Many of these individuals would use the MSBuildSdks [Microsoft.Build.CentralPackageVersions](https://github.com/microsoft/msbuildsdks) as an alternative to give them the flexibility they needed in their repositories.

The concept of dependency resolution overrides exists in many ecosystems and for NuGet, we want to ensure that there is a formal way to override package versions in the case that:

- A project exists in a repository but is not part of the main set of shipping assemblies and is allowed to use newer, untested package depedencies (such as an experimental tool)
- A project that has more advanced requirements and cannot use a single version of a package dependency for all of its target frameworks

In these cases, a project can override the centrally defined package version.  However, if that project is part of a transitive graph with version conflicts, a user would still need to resolve those conflicts before restore would succeed.  The main point of this feature is to give a well documented and supported way of overriding a package version for a particular project, not to make graph resolution easier if package conflicts exist.  

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

First a user opts-in to Central Package Management with a `Directory.Packages.props` file in their directory tree.

A user would specify package versions in `Directory.Packages.props`:

```xml
<Project>
  <ItemGroup>
    <PackageVersion Include="PackageA" Version="1.0.0" />
    <PackageVersion Include="PackageB" Version="2.0.0" />
  </ItemGroup>
<Project>
```

A project would override the version with the `VersionOverride` metadata on a `<PackageReference />` item:

```xml
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

```xml
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
There could be concerns that allowing users to override package versions for a particular project could lead to version conflicts for transitive project dependencies in the same repository.  While this is true, there are legitimate cases when overriding a centrally defined version for a particular project is the only way to get the desired outcome.  Since users can and will override versions to work around this, we feel its better to give them a supported way of acheiving it.

Although there may be different approaches to the current design, this is one that has been tested in the field with many projects and the feedback has matched our expectations of doing the job to be done in question.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
The current concept that exists in the MSBuildSdks's CentralPackageVersions project has met the needs of many developers around the world who take it on as a dependency and it has been noted many times that this feature is missing in NuGet's first-class support of central package management.

Although there could be a more fleshed out design that includes complete package IDs & their respective versions similar to other ecosystems, we are working with what we know teams need today and will build upon it in the future.   Since the specifications of packages and versions are MSBuild-based, we feel its better to stick with current constructs that Microsoft developer ecosystem customers are familiar with rather than inventing a new process that could lead to confusion.

If for any reason we decide to do a similar "package override" feature where a developer can replace any package on the dependency graph with another, we will allow for different levels of control such as replacing the package ID, the package version, and perhaps other selective mutations for a package in a graph.

Users can also just specify a `<PackageVersion Update="" />` in an import or use an MSBuild property that represents a package version to override what's used in a particular project.

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

