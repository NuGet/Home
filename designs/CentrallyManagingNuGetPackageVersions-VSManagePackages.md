# Centrally managing NuGet package versions - Managing packages in Visual Studio Spec

* Status: **In Review**
* Author(s): [Andy Zivkovic](https://github.com/zivkan)

## Related Specs

* [Centrally managing NuGet package versions](https://github.com/NuGet/Home/wiki/Centrally-managing-NuGet-package-versions)
* [Centrally managing NuGet package versions - Restore Design Spec](https://github.com/NuGet/Home/blob/dev/designs/CentrallyManagingNuGetPackageVersions-Restore.md)

## Problem Background

To date, NuGet does not modify any MSBuild files (projects files, or files imported by the projects) either directly or though MSBuild APIs. Instead, NuGet uses APIs provided by the various project systems when projects need to be modified as a result of installing, updating or removing packages. In practise, NuGet has only indirectly caused project files to be modified.

With centrally managed package versions, there will be a single file, `Directory.Packages.props`, which is intended to be shared across multiple projects. There are multiple design decisions about which Visual Studio component will have the responsibility for writing changes to the file, and how the updated values will flow throughout Visual Studio. 

## Who are the customers

All customers managing packages on projects that are using central package version management with projects in Visual Studio IDE.

## Goals

1. When installing a package in a centrally managed project, if the package already exists in the `Directory.Packages.props` file, only the project file is modified. The `PackageReference` element added must not have a version applied.
2. When installing a package in a centrally managed project, if the package does not already exist in the `Directory.Packages.props` file, then the package version is added to `Directory.Packages.props`, in addition to goal 1 above.
3. When updating a centrally managed package version, the `Directory.Packages.props` file is updated, and all projects that use the package are restored with the new package version.
4. When uninstalling/removing a package from a centrally managed project, the `PackageReference` is removed from the project file, but the `PackageVersion` is kept in the `Directory.Packages.props` file.

## Non - Goals

a. This spec is scoped to Visual Studio API interaction between components. Package Manager UI changes are out of scope. Command Line Interface is out of scope.
b. Removing a `PackageVersion` from the `Directory.Packages.props` file is out of scope for the first version, but may be in scope in the future.

## Scenarios

The following scenarios will be enabled when the proposed design changes will be completed.

1. Installing a package in a project with Package Manager UI or Package Manager Console.
2. Installing a package from a quick action when editing a source file.
3. Removing a package from a project with Package Manager UI or Package Manager Console.
4. Updating the version of a package for all projects using that `Directory.Packages.props` file.

## Requirements

The requirements are defined in the [feature spec](https://github.com/NuGet/Home/wiki/Centrally-managing-NuGet-package-versions).

Note that:

* It's valid for some, not all, projects in the solution to use centrally managed package versions.
* It's valid for different projects using central package versions to use different `Directory.Packages.props` files.
* As is valid now, it's valid for some projects to use `packages.config`, while others use `PackageReference`. The `packages.config` projects cannot use centrally managed package versions, and individual `PackageReference` projects may opt in or out of central package version management.

## Solution

### Installing a package in a project

Currently NuGet calls project system APIs to add a PackageReference to the project for the given package id and version. However, when the project uses centrally managed versions, the project file must not add the version on the `PackageReference` element.

There are two categories of solutions.

* API ignorant of centrally managed package versions

Project system APIs would not be changed, but the implementation would need to be aware of how to detect if the feature is enabled, and know when to add a version to the `PackageReference` and when not to, and when to modify the `Directory.Packages.props` and when not not.

There would also be a potential issue when a single user gesture causes a package to be installed into multiple projects, particularly when the `Directory.Packages.props` file does not already contain a `PackageVersion` for the package. If NuGet calls APIs to modify all the projects in parallel, there might be a race condition with trying to update `Directory.Packages.props`.

* API aware of centrally managed package versions

Presumably this would mean there's a separate API to add a `PackageVersion` to the `Directory.Packages.props` file. But since this file is shared across multiple projects, would the API be independent from the projects, or should NuGet pick one project and call the API on that project?

Should new APIs be added to the project systems considering the version attribute must not be written? Or NuGet could call the API with a null version. Or NuGet passes the version and the project system must know if the project uses centrally managed package versions or not.

### Removing a package from a project

Currently NuGet calls APIs on the project system to remove the `PackageReference` for that package given a package id. The current API is sufficient and the same behavior should continue. The `Directory.Packages.props` file should not be modified to remove the `PackageVersion`, as other projects may still be using it.

### Change the version of a package in `Directory.Packages.props`

This will affect, at minimum, all the loaded projects in the solution that have a `PackageReference` to the package whose version is changed. For SDK-style projects, it appears this should work already, by watching the file for changes and then sending NuGet a project nomination with the new information. Currently non-SDK style projects need to be unloaded and reloaded to take into account changes to imported MSBuild files.

Given this single user gesture will often affect multiple projects, should the API to modify the `Directory.Packages.props` file be on a project system interface, or a new interface that's decoupled from individual projects?

Once the file is modified, should NuGet notify projects that it's changed, or should they detect it themselves?

In particular, given that SDK style projects currently use file watchers to detect changes to imported files and automatically reload, but non-SDK style projects do not and continue to use outdated information until the project is reloaded, how can we avoid a bad user experience when a customer uses Package Manager UI/Console to change package versions?

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
