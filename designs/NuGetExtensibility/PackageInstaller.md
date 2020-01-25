
# IVsAsyncPackageInstaller

* Status: **In Review**
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)
* Issue: [8896](https://github.com/NuGet/Home/issues/8896)
* Type: Feature

## Problem Background

The IVsPackageInstaller and IVsPackageInstaller2 are extensibility interfaces defined in the NuGet.VisualStudio assembly.
All methods in these interfaces are synchronous and marked as ComImport for embedding purposes.

We need asynchronous alternatives that provide better performance.
To provide these interfaces we will use the guideline set in [NuGet extensibility services](NuGetExtensilityServices.md).

## Who are the customers

* Extension authors
* Visual Studio components like Roslyn.

## Requirements

* Asynchronous and performant installer service
* Ability to invoke these through RPC. These days there are components that are running out of devenv.exe

## Goals

* Define an asynchronous IVsAsyncInstallerService
* Migrate the relevant methods available in IVsPackageInstaller and IVsPackageInstaller2 account for the current state of the eco-system/directions. 

## Non-Goals

* Making them service free-threaded (yet).

## Solution

The new contracts will ship as part of the NuGet.VisualStudio.Contracts assembly. That assembly is versioned similarly to all other NuGet APIs.

These APIs were mostly written at a time where packages.config was the only package management option. With PackageReference some of the requirements and overall guidance have changed. We will analyze each of the methods in the current API and decide whether to migrate them or not.

The general approach for these APIs is incrementalism. We can iterate on these APIs and provide what the customers need.
Given this, we will consider every single API and decide whether we port it!

```cs
void InstallPackage(string source, Project project, string packageId, Version version, bool ignoreDependencies);
```

Verdict: Cut
Reason: We only declare simple types in our interfaces. 

```cs
void InstallPackage(string source, Project project, string packageId, string version, bool ignoreDependencies);
```

Verdict: Keep but modify. 
Reason: Project cannot be part of the API, we will use a unique identifier instead. At this point, the ignore dependencies boolean seems like something we wouldn't in our APIs. It's not respected in PackageReference anyways. 

```cs
void InstallPackage(IPackageRepository repository, Project project, string packageId, string version, bool ignoreDependencies, bool skipAssemblyReferences);
```

Verdict: Cut
Reason: This method is already disabled on the newest version of Visual Studio. The IPackageRepository is not used anymore. 

```cs
void InstallPackagesFromRegistryRepository(string keyName, bool isPreUnzipped, bool skipAssemblyReferences, Project project, IDictionary<string, string> packageVersions);
```

Verdict: Cut
Reason: This is not a very common scenario.

```cs
void InstallPackagesFromRegistryRepository(string keyName, bool isPreUnzipped, bool skipAssemblyReferences, bool ignoreDependencies, Project project, IDictionary<string, string> packageVersions);
```

Verdict: Cut
Reason: This is not a very common scenario.

```cs
void InstallPackagesFromVSExtensionRepository(string extensionId, bool isPreUnzipped, bool skipAssemblyReferences, Project project, IDictionary<string, string> packageVersions);
```

Verdict: Cut for now.
Reason: The packages from VS extension scenario does not have enough clarity. We can reconsider a variant of this API at a later point.

```cs
void InstallPackagesFromVSExtensionRepository(string extensionId, bool isPreUnzipped, bool skipAssemblyReferences, bool ignoreDependencies, Project project, IDictionary<string, string> packageVersions);
```

Verdict: Cut for now.
Reason: The packages from VS extension scenario does not have enough clarity. We can reconsider a variant of this API at a later point.

```cs
void InstallLatestPackage(string source, Project project, string packageId, bool includePrerelease, bool ignoreDependencies);
```

Verdict: Keep but modify.
Reason: Project cannot be part of the API, we will use a unique identifier instead. At this point, the ignore dependencies boolean seems like something we wouldn't want to allow in our APIs. It's not respected in PackageReference anyways.

### Proposed API

```cs
namespace NuGet.VisualStudio.Contracts
{
    public interface INuGetPackageInstaller
    {

        Task InstallPackageAsync(
            string source,
            string projectUniqueName,
            string packageId,
            string version,
            CancellationToken cancellationToken);

        Task InstallLatestPackageAsync(
            string source,
            string projectUniqueName,
            string packageId,
            bool includePrerelease,
            CancellationToken cancellationToken);
```

## Considerations

* Can we combine IVsPackageInstaller and IVsPackageUninstaller into the same service.

* Can we combine the 2 methods into one? After all the InstallLatestPackageAsync method was added to add a includePrerelease switch.

### Why aren't these services free-threaded

As part of the install path of packages, NuGet itself does not require the UI thread, but it's dependencies do.
The challenges are detailed below. We will engage the shareholders to reduce our UI thread dependencies, but at this point, we're not there yet.
The reality is that while these APIs will still have certain UI thread dependencies, we will reduce the number of UI delays when invoked in async code path.

#### packages.config install scripts

In packages.config, at install/uninstall time, certain scripts might be executed.
Certain packages access the DTE at install/uninstallation time. Even if NuGet & the dependencies at package installation time could become free-threaded, as long as the install/uninstall scripts are executed, this scenario cannot be free threaded.

#### packages.config installation scenarios

In the packages.config install scenarios NuGet is the component that writes to the project files themselves.
Some of the APIs frequently used there are: Project, VCProject, IVsHierarchy, ProjectItems.

#### Csproj PackageReference scenarios

In PackageReference, the dependencies are defined in the csproj. A list interactions with components that have UI thread requirements.

* Microsoft.VisualStudio.Shell.Interop.IVsBuildPropertyStorage - To read the properties such as TargetFrameworkVersion, RestoreProjectStyle etc. 
* VSLangProj.References & VSLangProj150.VSProject4.References (Reference6) for reading the ProjectReferences
* VSLangProj150.VSProject4.PackageReferences to write/read PackageReferences

#### CPS PackageReference scenarios

The CPS PackageReference scenarios are the ones build on top of the CPS project system (in reality all of the PackageReference functionality is implemented in the dotnet project system).
In CPS based PackageReference, NuGet receives nominations with the details for everything that NuGet needs to know about a project (almost).
When installing packages, NuGet uses Microsoft.VisualStudio.ProjectSystem.UnconfiguredProject, Microsoft.VisualStudio.ProjectSystem.UnconfiguredProjectServices, Microsoft.VisualStudio.ProjectSystem.References.IConditionalPackageReferencesService & Microsoft.VisualStudio.ProjectSystem.ConfiguredProject.

#### Challenges beyond the package action scenario

All the above discusses NuGet with the project/solution fully loaded. In the initialization code paths, NuGet needs to access IVsSolution to get solution path to initialize the config settings.  NuGet also depends on SolutionEvents to receive all project change events, but I do not foresee these being a problem in this specific scenario.
During the project load scenarios NuGet also uses the IVsHierarchy to check for project system capabilities (check for CPS). Similarly, this shouldn't be an issue.

### Additional considerations

* Certain of the roslyn scenarios are synchronous in their nature, so someone will need to block eventually. Providing an asynchronous service in general is a good direction as far as NuGet goes.

### Open Questions

* How can we address the roslyn scenario?
  * What happens when our service is free threaded?
  * Should we create separate APIs that are free threaded?
* In RPC scenarios, we need to use a project identifier to declare the intention. NuGet uses the ProjectUniqueName throughout its code to achieve this. Analyze whether this is satisfactory.
