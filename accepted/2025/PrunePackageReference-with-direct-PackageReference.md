
# PrunePackageReference handling of direct PackageReference items

- Nikolche Kolev <https://github.com/nkolev92>

- [#14196: Pruning should prune and not warn for a direct reference in a multi-targeting project](https://github.com/NuGet/Home/issues/14196)

## Summary

<!-- One-paragraph description of the proposal. -->

## Motivation

As of .NET 10, Preview 4, `PrunePackageReference` does not prune direct PackageReference items and raises a NU1510 warning when a direct PackageReference is specified to be pruned.

In [#14196](https://github.com/NuGet/Home/issues/14196), we have an example of a project targeting netstandard2.0;net8.0 and referencing System.Text.Json 8.0.x.
The warning would lead the customer to write a condition targeting netstandard2.0 only.
If the customers decide upgrade the package while still targeting net8.0, it may lead to the netstandard2.0 version of their library not being compatible with the net8.0 version and *nothing* will warn of this potential concern that may lead to runtime errors for customers referencing this package.

In the same, a reconsideration of the pruning behavior for direct package references was also suggested. 

## Explanation

### Functional explanation

#### Scenarios for direct PackageReference items

The motivation behind NU1510 is removing unnecessary PackageReference items.
As a long as a package is specified within a project but it's not needed, it adds maintenance overhead:

- It may be accidentally updated by tooling such as dependabot
- It may appear as a direct reference in the Package Manager UI or list package or others tools that list the project dependencies.

Given that pruning is a per framework feature, there a few scenarios to consider for the handling of direct package references, primarily revolving around multi-targeting:

1. Single framework
If the direct package reference is within the pruning range, we would like for the customer to remove the PackageReference and reduce the overhead.

1. Multi framework scenario
a. .NET & .NET Framework scenario

```csproj
  <PropertyGroup>
    <TargetFramework>net9.0;net472</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="System.Text.Json" Version="9.0.4" />
  </ItemGroup>
```

For .NET, the package is unnecessary, and ideally we'd want the customer to consider conditionally referencing the System.Text.Json reference.

b. .NET & .NET Standard scenario

```csproj
  <PropertyGroup>
    <TargetFramework>net9.0;netstandard2.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="System.Text.Json" Version="9.0.4" />
  </ItemGroup>
```

For .NET, the package is unnecessary, but if the customer removes the reference and then at a later point point updates the PackageReference without bumping the target framework, it may lead to a situation where the netstandard2.0 version of their package has a broader API surface area than net9.0 and potentially leading to runtime issues.

c. Multiple .NET frameworks, package specified for all frameworks 

```csproj
  <PropertyGroup>
    <TargetFramework>net8.0;net9.0;net10.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Condition="'$(TargetFramework)' == 'net10.0'" Include="System.IO.Pipelines" Version="10.0.0-preview.3.25171.5" />
    <PackageReference Condition="'$(TargetFramework)' == 'net9.0'" Include="System.IO.Pipelines" Version="9.0.2" />
    <PackageReference Condition="'$(TargetFramework)' == 'net8.0'" Include="System.IO.Pipelines" Version="8.0.0" />
  </ItemGroup>
```

In this situation, System.IO.Pipelines was added to the framework in .NET 9, so the .NET 10 and .NET 9 references are not necessary.
There is a chance the customer may end up reference a System.IO.Pipelines version higher than the one available in the other frameworks, similarly to 2b.
It is a lot less likely given that they're carefully targeting the latest version within the matching releases, but risky nonetheless.

d. Multiple .NET frameworks, package is not specified in for frameworks

```csproj
  <PropertyGroup>
    <TargetFramework>net8.0;net9.0;net10.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Condition="'$(TargetFramework)' == 'net10.0'" Include="System.IO.Pipelines" Version="10.0.0-preview.3.25171.5" />
    <PackageReference Condition="'$(TargetFramework)' == 'net9.0'" Include="System.IO.Pipelines" Version="9.0.2" />
  </ItemGroup>
```

In this situation, System.IO.Pipelines was added to the framework in .NET 9, so the .NET 10 and .NET 9 references are not necessary.
Given that the package is unnecessary in *every* framework it's been added in, we'd want the customer to remove both conditional PackageReference items.

#### When will NU1510 be raised

Tying NU1510 to .NET 10 - In order to minimize disruption that would be caused by raising NU1510 for existing projects, as per the [Breaking Change guidelines](https://github.com/dotnet/sdk/blob/main/documentation/project-docs/breaking-change-guidelines.md#tie-potentially-impactful-changes-to-the-target-tfm) NU1510 will only be raised for projects targeting net10, requiring an explicit customer action to get this diagnostic.

For multi-targeted projects, the warning will be raised if at least one of the frameworks is .NET 10.
We will raise an NU1510 when the PackageReference can be completely removed from the project file.
In other words, when a package would be pruned for every target framework it is specified in, raise NU1510.

Referring back to the [scenarios](#scenarios-for-direct-packagereference-items) listed above:

| Scenario | NU1510 | Notes |
|----------|--------|-------|
| 1 | Yes | |
| 2a | No | The warning may be beneficial, but keeping it for simplicity |
| 2b | No | Eventual runtime failure risks |
| 2c | No | Eventual runtime failure risks |
| 2d | Yes | Removal of the PR leads to the package being completely gone from the project. |

#### Should we prune direct package references

The benefits of pruning are that external scanners and audit functionality no longer sees those package references raising false positives.

Direct are ideally are minimal and what users first update when they transitive vulnerabilties.
Tooling such as dependabot depends on the packages found in the project file.
The NuGet Package Manager UI surfaces all the direct dependencies in the UI as well, and shows an `Update` count for direct packages that are out of date.
Components in Visual Studio depend on NuGet's [GetInstalledPackagesAsync](https://learn.microsoft.com/en-us/nuget/visual-studio-extensibility/nuget-api-in-visual-studio#inugetprojectservice-interface) API for looking up packages as well for deciding whether to install certain packages.
Finally dotnet list package is the CLI equivalent of the package manager UI.

Currently, direct packages are always available should a restore succeed.
With a pruned reference, the package is explicitly not available, but not in an error state.
In addition, a pruned package should not be audit for vulnerabilities, but ideally is audited for deprecations.

For the components mentioned above, we need to define their behavior for pruned packages.

| Component | Pruned direct PackageReference behavior | Notes |
|-----------|-----------------------------------------|-------|
| Package Manager UI (Installed tab) | Show | The customer needs to see that they've specified the PackageReference and should be able to remove that package |
| Package Manager UI (Updates) | Show | An update to the package may lead to it not being pruned anymore, and the customer needs to be able to make that decision. |
| dotnet list package | Show | Similar as Package Manager UI, installed tab |
| dotnet list package --outdated | Show | A customer needs to be able to update, as an update may make a package not pruned anymore |
| Solution Explorer | Show | The package needs to indicate why it was not "resolved". The solution explorer currently adds a warning icon next to unresolved packages (ie, not found in the project.assets.json file) |
| GetInstalledPackagesAsync | Show | Depends on the scenario, they may be trying to achieve similar behavior to what the PM UI and list package commands provide. TODO: The installed packages *always* has a resolved version, what should that version be listed as? The same version? If so, should NuGet ensure the package version is resolvable? |

When the NU1510 warning is raised, we are giving the customer a clear signal that they need to remove the PackageReference.
In these scenarios, whether we prune direct package references is not very critical.

In the partial prune scenarios such as 2b and 2c, pruning could be beneficial in the .NET leg, helping avoid additional audit warnings.
However, due to the fact that the PackageReference is in other frameworks, the benefit is likewise partial, since if the package itself had a vulnerability, the audit warning will be warranted since the customer is using it in a case where it is not being pruned.

The following is a list of pros and cons of pruning direct references.
| Pros | Cons |
|------|------|

TODO NK

TODO NK - Indicate in the assets file that a package has been pruned.

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

## Prior Art

N/A

## Unresolved Questions

- Should we add a setting to prune direct package references

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

- [#14126: Warning rollout for PrunePackageReference](https://github.com/NuGet/Home/issues/14126) - We may want a way to enable how this warning is surfaced for customers that do not target .NET 10.0.
