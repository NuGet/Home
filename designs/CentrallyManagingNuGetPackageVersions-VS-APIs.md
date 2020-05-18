# Centrally managing NuGet package versions - Visual Studio NuGet/Project System APIs

* Status: **In Review**
* Author(s): [Andy Zivkovic](https://github.com/zivkan)

## Related Specs

* [Centrally managing NuGet package versions](https://github.com/NuGet/Home/wiki/Centrally-managing-NuGet-package-versions)
* [Centrally managing NuGet package versions - Restore Design Spec](https://github.com/NuGet/Home/blob/dev/designs/CentrallyManagingNuGetPackageVersions-Restore.md)

## Problem Background

Within Visual Studio, only project systems read and manipulate project files, and provide APIs to other components, such as NuGet. This allows project systems to efficiently handle changes. Although CPVM's `Directory.Packages.props` file is not the project file itself (`csproj`, `vbproj`, and so on), it is an MSBuild file and is imported by the project files and therefore contributes to project evaluation.

To enable NuGet's package management functionality within Visual Studio (Package Manager UI, Package Manager Console, or NuGet's APIs to install packages), NuGet needs agreement with project systems on how APIs should behave with the new feature.

## Who are the customers

All customers managing packages on projects that are using central package version management with projects in Visual Studio IDE.

## Minimum Viable Product Goals

Note: Project System APIs, and changes to NuGet's APIs, needed for restore scenarios were done as part of the restore spec & implementation. This document focuses on being able to update packages

1. When installing a package in a centrally managed project, if the package already exists in the `Directory.Packages.props` file, only the project file is modified. The `PackageReference` element added must not have a version applied.
2. When installing a package in a centrally managed project, if the package does not already exist in the `Directory.Packages.props` file, then the package version is added to `Directory.Packages.props`, in addition to goal 1 above.
3. When updating a centrally managed package version, the `Directory.Packages.props` file is updated, and all projects that use the `Directory.Packages.props` must be restored.
  * A future optimisation could be to restore only the projects that have either a direct or transitive dependency on the updated package. Since it is not currently easy to check if a project has a transitive dependency to a package, this is out of scope for the initial version of the feature.
4. When uninstalling/removing a package from a centrally managed project, the `PackageReference` is removed from the project file, but the `PackageVersion` is kept in the `Directory.Packages.props` file.

## Later Phase Goals

5. Removing a `PackageVersion` from the `Directory.Packages.props` file is out of scope for the first version, but will be a requirement in the future.

## Non - Goals

6. This spec is scoped to Visual Studio API interaction between components. Package Manager UI changes are out of scope. Command Line Interface is out of scope.
7. `Directory.Packages.props` files that import other MSBuild files. Only update of the first `Directory.Packages.props` file found is supported. Any `PackageVersion` items defines in different files, or any nesting of `Directory.Packages.props` is unsupported with undefined behavior.

## Scenarios

The following scenarios will be enabled when the proposed design changes will be completed.

### Install a package in a project that already exists in `Directory.Packages.props`

In this scenario, there is a `Directory.Packages.props` file which specifies a `PackageVersion` for `PackageA`. There is a project `Project1`, which does not currently have a reference to `PackageA`. When the customer installs `PackageA` into `Project1`, the project's file is modified to include a `<PackageReference Include="PackageA" />`, which does not specify a version. `Directory.Packages.props` remains unchanged.

#### Before

`$(repo_root)\Directory.Packages.props`

```xml
<Project>
  <ItemGroup>
    <PackageVersion Include="PackageA" Version="1.2.3" />
  </ItemGroup>
</Project>
```

`$(repo_root)\Project1\Project1.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.1</TargetFramework>
  </PropertyGroup>

</Project>
```

#### Gesture

Customer installs `PackageA` into `Project1` using Package Manager UI.

#### After

`$(repo_root)\Directory.Packages.props`

```xml
<Project>
  <ItemGroup>
    <PackageVersion Include="PackageA" Version="1.2.3" />
  </ItemGroup>
</Project>
```

`$(repo_root)\Project1\Project1.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.1</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="PackageA" />
  </ItemGroup>

</Project>
```

### Install a package in a project that does not exist in `Directory.Packages.props`

In this scenario, there is a `Directory.Packages.props` file, but it does not have a `PackageVersion` for `PackageA`. There is a project `Project1`, which also does not currently have a reference to `PackageA`. When the customer installs `PackageA`, version `1.2.3`, into `Project1`, `Directory.Packages.props` is modified to include `<PackageVersion Include="PackageA" Version="1.2.3" />`, and the project's file is modified to include a `<PackageReference Include="PackageA" />`.

#### Before

`$(repo_root)\Directory.Packages.props`

```xml
<Project>
  <ItemGroup>
  </ItemGroup>
</Project>
```

`$(repo_root)\Project1\Project1.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.1</TargetFramework>
  </PropertyGroup>

</Project>
```

#### Gesture

Customer adds `PackageA` version `1.2.3` to `Project1` using Package Manager UI.

#### After

`$(repo_root)\Directory.Packages.props`

```xml
<Project>
  <ItemGroup>
    <PackageVersion Include="PackageA" Version="1.2.3" />
  </ItemGroup>
</Project>
```

`$(repo_root)\Project1\Project1.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.1</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="PackageA" />
  </ItemGroup>

</Project>
```

### Remove a package from a project

In this scenario, there is a `Directory.Packages.props` file which defines a version for `PackageA` and `PackageB`, and a project `Project1` has a `PackageReference` to both `PackageA` and `PackageB`. The customer uninstalls `PackageA`, and the `PackageReference` must be removed from `Project1`, leaving `PackageB`. `Directory.Packages.props` should remain unmodified, as other projects might be referencing `PackageA`.

#### Before

`$(repo_root)\Directory.Packages.props`

```xml
<Project>
  <ItemGroup>
    <PackageVersion Include="PackageA" Version="1.2.3" />
    <PackageVersion Include="PackageB" Version="4.5.6" />
  </ItemGroup>
</Project>
```

`$(repo_root)\Project1\Project1.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.1</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="PackageA" />
    <PackageReference Include="PackageB" />
  </ItemGroup>

</Project>
```

#### Gesture

The customer uninstalls `PackageA` from the Package Manager UI.

#### After

`$(repo_root)\Directory.Packages.props`

```xml
<Project>
  <ItemGroup>
    <PackageVersion Include="PackageA" Version="1.2.3" />
    <PackageVersion Include="PackageB" Version="4.5.6" />
  </ItemGroup>
</Project>
```

`$(repo_root)\Project1\Project1.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.1</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="PackageB" />
  </ItemGroup>

</Project>
```

### Update the version

In this scenario, there is a `Directory.Packages.props` file which defines a version for `PackageA`. There is a project, `Project1`, which has a `PackageReference` to `PackageA`. The customer updates `PackageA` to a different version. The `Directory.Packages.props` must be modified to contain the new version. All projects (one in this scenario) must be restored.

#### Before

`$(repo_root)\Directory.Packages.props`

```xml
<Project>
  <ItemGroup>
    <PackageVersion Include="PackageA" Version="1.2.3" />
  </ItemGroup>
</Project>
```

`$(repo_root)\Project1\Project1.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.1</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="PackageA" />
  </ItemGroup>

</Project>
```

#### Gesture

The customer updates `PackageA` to version `2.3.4` in Package Manager UI.

#### After

`$(repo_root)\Directory.Packages.props`

```xml
<Project>
  <ItemGroup>
    <PackageVersion Include="PackageA" Version="2.3.4" />
  </ItemGroup>
</Project>
```

`$(repo_root)\Project1\Project1.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.1</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="PackageA" />
  </ItemGroup>

</Project>
```

## Requirements

The requirements are defined in the [feature spec](https://github.com/NuGet/Home/wiki/Centrally-managing-NuGet-package-versions).

Note that:

* It's valid for some, not all, projects in the solution to use centrally managed package versions.
* It's valid for different projects using central package versions to use different `Directory.Packages.props` files.
* As is valid now, it's valid for some projects to use `packages.config`, while others use `PackageReference`. The `packages.config` projects cannot use centrally managed package versions, and individual `PackageReference` projects may opt in or out of central package version management.

## Solution

A new service should be created. This service will have multiple responsibilities:

* Write changes to `Directory.Packages.props` files to disk.
* Find which `Directory.Packages.props` file needs to be changed given a package install for a specific project.
* Orchestrate efficient updating and nomination of projects. In particular, when project files and `Directory.Packages.props` files need to change due to a single customer gesture, avoid multiple project nominations and multiple restores due to multiple file changes.

Proposed API.

```cs
enum PackageReferenceAction
{
  /// <summary>
  /// To catch uninitialized values, but otherwise usused and invalid.
  /// </summary>
  Unknown = 0,

  /// <summary>
  /// The change should add or update PackageReference and or PackageVersion items.
  /// </summary>
  AddOrUpdate = 1,

  /// <summary>
  /// The change should remove matching PackageReference items only, do not remove PackageVersion items.
  /// </summary>
  RemovePackageReference = 2,

  /// <summary>
  /// This change should remove both PackageReference and PackageVersion items.
  /// </summary>
  /// <remarks>
  /// Out of scope for the initial version. It has been defined to avoid needing an API change to add this in the future.
  /// </remarks>
  Remove = 3
}

class PackageReferenceChangeRequest
{
  /// <summary>
  /// The action to apply
  /// </summary>
  public PackageReferenceAction Action { get; set;}

  /// <summary>
  /// Which projects in the solution should apply this PackageReference action
  /// </summary>
  public List<string> Projects { get; set; }

  /// <summary>
  /// The package ID 
  /// </summary>
  public string PackageId { get; set; }

  /// <summary>
  /// The package version
  /// </summary>
  /// <remarks>
  /// * If the project does not use CPVM
  ///   * AddOrUpdate must set the PackageReference Version metadata to this value
  ///   * RemovePackage will ignore any value in Version
  /// * If the project uses CPVM
  ///   * AddOrUpdate must set the Version attribute in the Directory.Packages.props fie to this version. If the Directory.Packages.props file does not already contain an item for this PackageId, then it should be added.
  ///   * RemovePackage will ignore any value in Version
  /// </remarks>
  public string Version { get; set; }

  /// <summary>
  /// Additional metadata for this PackageId to set on the PackageReference item.
  /// </summary>
  /// <remarks>
  /// * AddOrUpdate must create or set metadata defined by the keys of this dictionary, with the value defined by the dictionary item's value.
  /// * AddOrUpdate must remove any metadata already defined in the PackageReference, if there is no key for that metadata in the dictionary.
  /// * RemovePackage will ignore any value in AdditionalMetadata.
  /// </remarks>
  public IDictionary<string, string> AdditionalMetadata { get; set; }
}

interface IPackageReferenceUpdateService
{
  /// <summary>
  /// Apply changes to the project(s) provided.
  /// </summary>
  Task<bool> ApplyChangesAsync(List<PackageReferenceChangeRequest> actions, CancellationToken token);
}
```

open questions:

* The convention in .NET is to add `CancellationToken` to async APIs. However, what is the expected behaviour if cancellation is requested in the middle of processing a single change request?
* Which project types will this service support? C# and VB only?  f#? c++? non-Microsoft project systems?


## References

* https://github.com/NuGet/Home/wiki/Centrally-managing-NuGet-package-versions
* https://github.com/microsoft/MSBuildSdks/tree/master/src/CentralPackageVersions

## Appendix 1 : Current project system API usage by NuGet

For SDK (CPS) projects, NuGet's relevant code is in [`src/NuGet.Clients/NuGet.PackageManagement.VisualStudio/Projects/NetCorePackageReferenceProject.cs`](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Clients/NuGet.PackageManagement.VisualStudio/Projects/NetCorePackageReferenceProject.cs). The project system APIs used are `Microsoft.VisualStudio.ProjectSystem.UnconfiguredProject`'s `GetSuggestedConfigurationprojectAsync` and `Services.PackageReference.AddAsync`.

* To [add or update a package reference](https://github.com/NuGet/NuGet.Client/blob/16be25216b699f48d5e4d0baed86a62c78acadbe/src/NuGet.Clients/NuGet.PackageManagement.VisualStudio/Projects/NetCorePackageReferenceProject.cs#L246-L338), NuGet has two code paths, depending if the package being installed is compatible with all project Target Framework Monikers (TFMs) or not. Ultimately, both code paths use `IPackageReferencesService.AddAsync(string packageIdentity, string version)` to try to add the package reference to the project, and if that fails, calls `IUnresolvedPackageReference.Metadata.SetPropertyValueAsync(string propertyName, string unevaluatedPropertyValue, IReadOnlyDictionary<string, string> dimensionalConditions = null)` to set the version. I couldn't find docs on any of these project system APIs. There is XML doc, but it doesn't say whether version is required or optional.

  * When the package is compatible with all project TFMs, `UnconfiguredProject.GetSuggestedConfiguredProjectAsync()` is called, followed by the `AddAsync` and `SetPropertyValueAsync` as described above.

  * When the package is not compatible with all project TFMs, `AddAsync` and `SetPropertyValueAsync` is called on `IConditionalPackageReferencesService` for each project TFM that is compatible with the package.

* To [remove a package reference](https://github.com/NuGet/NuGet.Client/blob/16be25216b699f48d5e4d0baed86a62c78acadbe/src/NuGet.Clients/NuGet.PackageManagement.VisualStudio/Projects/NetCorePackageReferenceProject.cs#L347-L351), NuGet calls `UnconfiguredProject.GetSuggestedConfiguredProjectAsync()` to get a `ConfiguredProject` instance, then calls `.Services.PackageReferences.RemoveAsync(string packageIdentity)`. I couldn't find public docs on these APIs.

For non-SDK style projects, NuGet's relevant code is in [`src/NuGet.Clients/NuGet.PackageManagement.VisualStudio/ProjectServices/VsManagedLanguagesProjectSystemServices.cs`](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Clients/NuGet.PackageManagement.VisualStudio/ProjectServices/VsManagedLanguagesProjectSystemServices.cs),
and the project system APIs used are  `VSLangProj150.dll`'s `VSProject4.PackageReferences`.

* To [add or update a package reference](https://github.com/NuGet/NuGet.Client/blob/16be25216b699f48d5e4d0baed86a62c78acadbe/src/NuGet.Clients/NuGet.PackageManagement.VisualStudio/ProjectServices/VsManagedLanguagesProjectSystemServices.cs#L270-L283), NuGet calls [`AsVSProject4.PackageReferences.AddOrUpdate (string bstrName, string bstrVersion, Array pbstrMetadataElements, Array pbstrMetadataValues)`](https://docs.microsoft.com/en-us/dotnet/api/vslangproj150.packagereferences.addorupdate?view=visualstudiosdk-2017). The docs for this method are empty, so don't explain expected behavior if any of the values (such as `bstrVersion`) is null.

* To [remove a package reference](https://github.com/NuGet/NuGet.Client/blob/16be25216b699f48d5e4d0baed86a62c78acadbe/src/NuGet.Clients/NuGet.PackageManagement.VisualStudio/ProjectServices/VsManagedLanguagesProjectSystemServices.cs#L285-L291), NuGet calls [`VsProject4.PackageReferences.Remove(packageName)`](https://docs.microsoft.com/en-us/dotnet/api/vslangproj150.packagereferences.remove?view=visualstudiosdk-2017). No version information is passed.
