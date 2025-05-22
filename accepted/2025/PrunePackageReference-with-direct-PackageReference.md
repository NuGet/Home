
# PrunePackageReference handling of direct PackageReference items

- Nikolche Kolev <https://github.com/nkolev92>

- [#14196: Pruning should prune and not warn for a direct reference in a multi-targeting project](https://github.com/NuGet/Home/issues/14196)

## Summary

Change the NU1510 heuristic in multi-targeting scenarios to only be raised when the package would be completely removed from the project.
This would ensure customers don't end up a potentially more challenging to manage conditional PackageReference scenario.

Also, this proposal explores the idea of pruning direct package references, the technical details around and the benefits of doing the work.

## Motivation

As of .NET 10, Preview 4, `PrunePackageReference` does not prune direct PackageReference items and raises a NU1510 warning when a direct PackageReference is specified to be pruned.

In [#14196](https://github.com/NuGet/Home/issues/14196), we have an example of a project targeting netstandard2.0;net8.0 and referencing System.Text.Json 8.0.x.
The warning would lead the customer to write a condition targeting netstandard2.0 only.
If the customers decide upgrade the package while still targeting net8.0, it may lead to the netstandard2.0 version of their library not being compatible with the net8.0 version and *nothing* will warn of this potential concern that may lead to runtime errors for customers referencing this package.

In the same, a reconsideration of the pruning behavior for direct package references was also suggested.

## Explanation

### Functional explanation

This design builds on the previous pruning specs, [PrunePackageReference roll-out](../2025/prune-package-reference-rollout.md) and [PrunePackageReference](../2024/prune-package-reference.md).

#### Scenarios for direct PackageReference items

The motivation for the pruning overall is that we'd want to reduce the overhead of customers managing components that can be managed by the runtime.
We want customers to remove unnecessary PackageReference items.
As a long as a package is specified within a project but it's not needed, it adds maintenance overhead:

- It may be accidentally updated by tooling such as dependabot
- It may appear as a direct reference in the Package Manager UI or list package or others tools that list the project dependencies.
- The package might become vulnerable in the future, causing NuGetAudit warnings that could be avoided by letting the SDK use the target's reference assemblies (update the runtime to fix the vulnerability)

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

#### How do we tell the customers we want them to remove a PackageReference

We raise a NU1510 warning.

For multi-targeted projects, the warning will be raised if at least one of the frameworks is .NET 10.
We will raise an NU1510 when the PackageReference can be completely removed from the project file.
In other words, when a package would be pruned for every target framework it is specified in, raise NU1510.

In order to provide continuity, and minimize disruption that would be caused by raising NU1510 for existing projects, as per the [Breaking Change guidelines](https://github.com/dotnet/sdk/blob/main/documentation/project-docs/breaking-change-guidelines.md#tie-potentially-impactful-changes-to-the-target-tfm) NU1510 will only be raised for projects targeting net10, requiring an explicit customer action to get this diagnostic.

Referring back to the [scenarios](#scenarios-for-direct-packagereference-items) listed above:

| Scenario | NU1510 | Notes |
|----------|--------|-------|
| 1 | Yes | |
| 2a | No | The warning may be beneficial, but complex heuristic would be harder to reason about. |
| 2b | No | Eventual runtime failure risks |
| 2c | No | Eventual runtime failure risks |
| 2d | Yes | Removal of the PR leads to the package being completely gone from the project. |

#### Pruning direct PackageReference items

The primary motivation for pruning is that the audit functionality and external scanners no longer sees those package references and raise false positives.
Transitively pruned packages do not appear in the assets file as dependencies of the packages that originally referenced them.
They have effectively been selected as unnecessary during the framework selection step of dependency resolution.
The only place the id appears in the assets file is the `project` section under the `packagesToPrune`.

Direct PackageReference appear in the project file and we would need to be able to answer questions about the statu of the package itself.
To allow components to reason about the direct dependencies, the list of pruned packages will be represented in a new section as well.
Similar to transitively pruned packages, direct  dependencies that were pruned *will not* appear in the targets section and  affect build in any way.

```json
"prunedPackages" : {
        "net9.0": {
          "System.Text.Json": "[9.0.0, )"
        }
}
```

Direct packages tend to be minimal and what users first update when they have transitive vulnerabilties.
Tooling such as dependabot depends on the packages found in the project file.
The NuGet Package Manager UI surfaces all the direct dependencies in the UI as well, and shows an `Update` count for direct packages that are out of date.
Components in Visual Studio depend on NuGet's [GetInstalledPackagesAsync](https://learn.microsoft.com/en-us/nuget/visual-studio-extensibility/nuget-api-in-visual-studio#inugetprojectservice-interface) API for looking up packages as well for deciding whether to install certain packages.
Finally dotnet list package is the CLI equivalent of the package manager UI.

Currently, direct packages are always available should a restore succeed.
With a pruned reference, the package is explicitly not available, but not in an error state.
In addition, a pruned package should not be audited for vulnerabilities, but ideally is audited for deprecations.

For the components mentioned above, we need to define their behavior for pruned packages.

| Component | Pruned direct PackageReference behavior | Notes |
|-----------|-----------------------------------------|-------|
| Package Manager UI (Installed tab) | Show | The customer needs to see that they've specified the PackageReference and should be able to remove that package. Only the requested version will be used for any logic, that means requested/resolved are expected to the same. |
| Package Manager UI (Updates) | Show | An update to the package may lead to it not being pruned anymore, and the customer needs to be able to make that decision. Only the requested version will be used for any logic, that means requested/resolved are expected to the same. |
| dotnet list package | Show | Similar as Package Manager UI, installed tab. The list package has a requested/resolved column. The resolved column should match the requested, as well as an additional indicator similar to auto-referenced. |
| dotnet list package --outdated | Show | A customer needs to be able to update, as an update may make a package not pruned anymore. The resolved column should match the requested, as well as an additional indicator similar to auto-referenced. |
| dotnet nuget why | Show | Similar reasoning as list package. |
| Solution Explorer | Show | The package needs to indicate why it was not "resolved". The solution explorer currently adds a warning icon next to unresolved packages (ie, not found in the project.assets.json file). We should change the indicator to something different. |
| GetInstalledPackagesAsync | Show | Depends on the scenario, they may be trying to achieve similar behavior to what the PM UI and list package commands provide. The [NuGetInstalledPackage](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Clients/NuGet.VisualStudio.Contracts/NuGetInstalledPackage.cs) type from the INuGetProjectService (that test explorer and roslyn use), will have the following changes: `Version` => null, the documentation will be updated to say the package is in either an error case or pruned, InstallPath => null, similarly if the package does not exist, the installation path does not exist. |

Given that pruning is an offline operation, ie NuGet does not talk to the sources for pruned packages, we never validate that the requested package exists and the specified version may be incorrect. This is likely to not be of too much consequence, since it's only really possible with hand-editing, and the impact of it is minimal since the package is not used anyways.

### Should we prune direct PackageReference

When the NU1510 warning is raised, we are giving the customer a clear signal that they need to remove the PackageReference.
In these scenarios, whether we prune direct package references is not very critical.

In the partial prune scenarios such as 2b and 2c, pruning could be beneficial in the .NET leg, helping avoid additional audit warnings.
However, due to the fact that the PackageReference is in other frameworks, the benefit is probably more minimal, since if the package itself had a vulnerability, the audit warning will be warranted since the customer is using it in a case where it is not being pruned.
There are a few things that pruning of direct packages introduces:

- The new concept of a pruned direct package. For transitive pruning, the end user would not see anything beyond a reduction in packages downloaded. For direct packages, the PM UI, list & why commands.

The biggest drawback is cost. Direct pruning requires a lot of parts to be updated and the benefit is minimal. Only 5% of .NET SDK based projects are suspected to be multi-targeted and data analysis would suggest only 1-2% of projects could ever fall into this scenario and all of that disregards the per framework considerations.

## Drawbacks

- Additional UX concepts for both 1st and 3rd party tooling that manage packages.
- Cost of direct PackageReference pruning vs the potential benefit since customers in affected scenarios with a vulnerable package would either get a NU1510 or get a legit audit warning.

## Rationale and alternatives

- Update the NU1510 heuristic only. Retain the current behavior for pruning.
- Instead of removing the direct PackageReference from the graph completely, treat it as `IncludeAssets="none"`. This would allow get us benefits from Component Governance, in a more cost-effective way. `NuGetAudit` would also need to be updated to stop auditing unused packages, similarly to how Component Governance approaches the problem. [Make ExcludeAssets visible in Audit and nuget why](https://github.com/NuGet/Home/issues/13860)

## Prior Art

N/A

## Unresolved Questions

- Should we prune direct packages? If the answer is yes, the following unresolved questions apply:
  - What should `dotnet list package` show for direct pruned packages? Should it show the version specified as requested?
  - What should the GetInstalledPackages return for the pruned direct packages?
  - Should we add a setting to prune direct package references?
  - Validate how 3rd party components would behave with unresolved direct package references.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

- If we prune direct packages:
  - Visualize pruned packages in the PM UI Installed/Updates tabs. Note that the PM UI does not have visualization support for multi-targeting, so the heuristic here should be similar to the one for the NU1510 warning.
  - Change the warning icon for a missing direct package reference to something that accounts for the pruned packages.
- Block installation of packages that would be pruned. Effectively, do not allow System.Text.Json 8.0.0 to be installed in a project targeting `net10.0` only. The heuristic could be similar to the one of NU1510, block the installation if a NU1510 is raised for the package id being installed.
- [#14126: Warning rollout for PrunePackageReference](https://github.com/NuGet/Home/issues/14126) - We may want a way to enable how this warning is surfaced for customers that do not target .NET 10.0.
- NuGet vulnerability warnings for direct PackageReference can account for the fact that a package would be pruned and provide that information. We could also choose to raise a NU1510 warning when a vulnerability is reported for that package during NuGet Audit.
- [[DCR]: ExcludeAssets="all" should exclude the package from the restore graph](https://github.com/NuGet/Home/issues/11567) covers a similar idea of removing packages from restore, like direct pruning would. Treating pruned packages with `IncludeAssets="none"` followed by excluding this package from all auditing may yield similar results.
