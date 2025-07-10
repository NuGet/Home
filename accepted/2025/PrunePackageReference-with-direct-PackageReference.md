
# PrunePackageReference handling of direct PackageReference items

- Nikolche Kolev <https://github.com/nkolev92>

- [#14196: Pruning should prune and not warn for a direct reference in a multi-targeting project](https://github.com/NuGet/Home/issues/14196)

## Summary

Change the NU1510 heuristic in multi-targeting scenarios to only be raised when the package would be completely removed from the project.
This would ensure customers don't end up in a potentially more challenging to manage conditional PackageReference scenario. As of <https://github.com/NuGet/NuGet.Client/pull/6469>, this change is implemented.

This proposal explores various ideas for pruning direct package references, the technical details around and the benefits of doing the work.
The proposed handling of direct PackageReference that are within pruning range is to privatize them, by marking them with `PrivateAssets='all'` and `IncludeAssets='none'`.

## Motivation

As of .NET 10, Preview 4, `PrunePackageReference` does not prune direct PackageReference items and raises a NU1510 warning when a direct PackageReference is specified to be pruned.

In [#14196](https://github.com/NuGet/Home/issues/14196), we have an example of a project targeting netstandard2.0;net8.0 and referencing System.Text.Json 8.0.x.
The warning would lead the customer to write a condition targeting netstandard2.0 only.
If the customers decide upgrade the package while still targeting net8.0, it may lead to the netstandard2.0 version of their library not being compatible with the net8.0 version and *nothing* will warn of this potential concern that may lead to runtime errors for customers referencing this package.

To understand those potential runtime issues, let's take the following example:
Package LibX targets was built from this project, and targets net9.0 and netstandard2.0, with a conditional reference on STJ 10.0.
Package LibYDependsOnX was build against LibX and it targets net8.0.
A project uses LibYDependsOnX targeting net8.0. At this point it's consuming STJ 10.0, getting the reference through LibX.
Then the project retargets to net9.0, and now it is *not* getting a STJ 10.0 as a dependency, despite LibYDependsOnX potentially depending on it.
Note that this potential runtime issue is a general problem with packages that multi-target, where the dependencies of less specific frameworks like netstandard2.0 cannot be broader than more the specific frameworks like net9.0.  

In the same, a reconsideration of the pruning behavior for direct package references was also suggested.

## Explanation

This design builds on the previous pruning specs, [PrunePackageReference roll-out](../2025/prune-package-reference-rollout.md) and [PrunePackageReference](../2024/prune-package-reference.md).

### Scenarios for direct PackageReference items

The motivation for the pruning overall is that we'd want to reduce the overhead of customers managing components that can be managed by the runtime.
We want customers to remove unnecessary PackageReference items.
As a long as a package is specified within a project but it's not needed, it adds maintenance overhead:

- It may be accidentally updated by tooling such as dependabot
- It may appear as a direct reference in the Package Manager UI or list package or others tools that list the project dependencies.
- It is still part of auditing functionality such as NuGetAudit, deprecation etc.
- It will be listed as a dependency of packages (thus needing them to be pruned.)

Given that pruning is a per framework feature, there are a few scenarios to consider for the handling of direct package references, primarily revolving around multi-targeting:

1. Single framework
If the direct package reference is within the pruning range, we ask the customer to remove the PackageReference and reduce the management overhead.

2. Multi framework scenario
a. .NET & .NET Framework scenario

```csproj
  <PropertyGroup>
    <TargetFramework>net9.0;net472</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="System.Text.Json" Version="9.0.4" />
  </ItemGroup>
```

For .NET, the package is unnecessary, and ideally we'd want the customer to consider conditionally reference the System.Text.Json package.
Note that even in these situations, there's a theoretical way to end up with runtime issues, but it would require that a .NET Framework package references a package that references both, and then a .NET application reference this package.

b. .NET & .NET Standard scenario

```csproj
  <PropertyGroup>
    <TargetFramework>net9.0;netstandard2.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="System.Text.Json" Version="9.0.4" />
  </ItemGroup>
```

For .NET 9, the package is unnecessary, but if the customer removes the reference and then at a later point point updates the PackageReference without bumping the target framework, it may lead to a situation where the netstandard2.0 version of their package has a broader API surface area than net9.0 and potentially leading to runtime issues as talked about in the [Motivation](#motivation).

c. Multiple .NET frameworks, package specified for all frameworks.

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

### How do we tell the customers we want them to remove a PackageReference

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

### Direct PackageReference in pruning range

The primary motivation for pruning is that the audit functionality and external scanners no longer sees those package references and raise false positives.
Transitively pruned packages do not appear in the assets file as dependencies of the packages that originally referenced them.
They have effectively been selected as unnecessary during the framework selection step of dependency resolution.
The only place the id appears in the assets file is the `project` section under the `packagesToPrune`.

When the NU1510 warning is raised, we are giving the customer a clear signal that they need to remove the PackageReference.
In these scenarios, what happens to the direct package references is not very critical.

In the partial prune scenarios such as 2b and 2c, pruning directs like transitive could be beneficial in the .NET leg, helping avoid additional audit warnings.
However, due to the fact that the PackageReference is in other frameworks, the benefit is more minimal, since if the package itself had a vulnerability, the audit warning will be warranted since the customer is using it in a case where it is not being pruned.

#### Should we prune direct PackageReference similarly to transitives?

[Pruning of direct packages](#how-pruning-direct-packagereference-similarly-to-transitive-would-work) would introduce the new concept of a pruned direct package.
For transitive pruning, the end user would not see anything beyond a reduction in packages downloaded. For direct packages, the PM UI, list & why commands need to updated as well. From a cost/benefit perspective, direct pruning requires a lot of parts to be updated and there is not a big benefit in the core scenario where a package has vulnerabilities (warnings would still be raised since the package is still used).
Only 5% of .NET SDK based projects are suspected to be multi-targeted, and it would be challenging to get more specificity at this point.

#### Direct PackageReference in the pruning range are treated with `PrivateAssets=all` and `IncludeAssets=none`

If a direct PackageReference is within the pruning range, we will treat them `PrivateAssets=all` and `IncludeAssets=none`.
The direct packages are still resolved. No need to introduce special concepts for direct packages that are not resolved.

`PrivateAssets=all` means that they will not be:

- Transitive project through project - this is pretty inconsequential to the larger story, since as a transitive package, it would be pruned in the referencing project as well (assuming pruning wasn't explicitly disabled).
- Be part of the resulting package - This is beneficial in scenarios like 2a, 2b and 2c where we can't raise an NU1510 warning due to the risks of conditional PackageReference. We would effectively be removing this package for the user, without them having to apply it themselves.
Additionally, in single framework scenarios, prunable packages would be removed from the package definition completely, which is effectively NuGet applying the `NU1510` heuristic for the customer. Given that the `NU1510` warning is enabled for `.NET 10` only, this would clean-up packages targeting net9.0 and earlier of unnecessary dependencies.
- Overall, `PrivateAssets=all` means for direct PackageReference prunable packages private, for the project only.
It completely *stops* the propagation of unnecessary dependencies within packages (what the original NU1510 was aiming at, but without the gotchas that come with the customer manually trying to get the references correct).

`IncludeAssets=none` will be used to clearly indicate that the package would not be used at compile or runtime.

This has the following side-effects:

- Breaking change for the pack operation. You upgrade the .NET SDK and now your package has different dependencies without a clear indication.
The whole PrunePackageReference feature is a breaking change itself, but in the case of transitive package pruning, the benefits are no audit warnings, since the package is not used at all, so very low chances of things going wrong.
In the directs case, we'd be changing the resulting package.

A practical example would be, 2a's nuspec is:

```xml
<dependencies>
    <group targetFramework=".NETFramework4.7.2">
        <dependency id="System.Text.Json" version="9.0.4" />
    </group>
    <group targetFramework="net9.0">
    </group>
</dependencies>
```

Note that we could consider gating the `PrivateAssets=all` addition to net10.0 being the used framework, but the impact would significantly smaller. If we gate this behavior on net10.0 being used, we could consider adding a separate property as well.

- Aliases for PackageReference that will be pruned will stop working. This is *unlikely* to be a problem, since we normally wouldn't expect customers to alias platform packages.

This changes will automatically happen in *all* pruning scenarios, if pruning is enabled, you would get the behavior for both transitives & directs.

## Drawbacks

- Breaking change for the pack operation (albeit, a warranted one)
- Breaking change for aliases on direct PackageReference from the platform.

## Rationale and alternatives

- Don't change the direct PackageReference handling.
- Prune direct PackageReference similarly to transitives.

### How pruning direct PackageReference similarly to transitive would work

Direct PackageReference appear in the project file and we would need to be able to answer questions about the status of the package itself.
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

There are some unresolved questions with this approach:

- What should `dotnet list package` show for direct pruned packages? Should it show the version specified as requested?
  - It can be marked in a similar way that auto-referenced packages are marked. `> Newtonsoft.Json           (A)   [13.0.2, )   13.0.2`
- What should the GetInstalledPackages return for the pruned direct packages?
- Should we add a setting to prune direct package references?
- Validate how 3rd party components would behave with unresolved direct package references.

## Prior Art

N/A

## Unresolved Questions

- How should we handle direct packages? `PrivateAssets=all` or no action.
  - If the answer is `PrivateAssets=all`, should we gate it behind the net10.0 framework being used?
    - The impact is more minimal, but we're fully following the [Breaking Change guidelines](https://github.com/dotnet/sdk/blob/main/documentation/project-docs/breaking-change-guidelines.md#tie-potentially-impactful-changes-to-the-target-tfm).
- Do we have to apply `IncludeAssets=none` or is making prunable packages private good enough?
- Should we add a switch for opting out of the direct package pruning behavior?

## Future Possibilities

- Opt-out for the pruning behavior of direct PackageReference (pack time and restore time.)
- Visualize prunable direct packages in the PM UI Installed/Updates tabs. Note that the PM UI does not have visualization support for multi-targeting, so the heuristic here should be similar to the one for the NU1510 warning.
- Add an icon indicating a direct package would be pruned.
- Block installation of packages that would be pruned. Effectively, do not allow System.Text.Json 8.0.0 to be installed in a project targeting `net10.0` only. The heuristic could be similar to the one of NU1510, block the installation if a NU1510 is raised for the package id being installed.
- [#14126: Warning rollout for PrunePackageReference](https://github.com/NuGet/Home/issues/14126) - We may want a way to enable how this warning is surfaced for customers that do not target .NET 10.0.
- NuGet vulnerability warnings for direct PackageReference can account for the fact that a package would be pruned and provide that information. We could also choose to raise a NU1510 warning when a vulnerability is reported for that package during NuGet Audit.
- [[DCR]: ExcludeAssets="all" should exclude the package from the restore graph](https://github.com/NuGet/Home/issues/11567) covers a similar idea of removing packages from restore, like direct pruning would.
- [Make ExcludeAssets visible in Audit and nuget why](https://github.com/NuGet/Home/issues/13860)