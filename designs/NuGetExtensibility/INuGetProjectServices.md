# INuGetProjectServices

* Status: In Review
* Author(s): [Andy Zivkovic](https://github.com/zivkan)
* Issue: [1](https://github.com/NuGet/Home/issues/9577) IVsPackageInstallerServices should be async

## Problem Background

The existing IVsPackageInstallerServices service is synchronous, and is being called by several components on the UI thread, causing UI delays in Visual Studio. We are creating new async APIs that will allow us to unblock the UI thread, and use the Visual Studio Service Broker to work in Visual Studio CodeSpaces (and maybe Live Share).

See [NuGet extensibility services](NuGetExtensibilityServices.md) for more details.

## Who are the customers

Visual Studio component and extension developers.

## Goals

* Can be called on any thread (ideally background thread, but work if called on UI thread).
* Do not block caller (implement async properly, return incomplete task instead).
* Works with Visual Studio Codespaces, and hopefully Live Share.

## Non-Goals

* This will not be a 1:1 replacement for any of NuGet's existing `IVs` interfaces.

## Solution

```cs
/// <summary>Service to interact with projects in a solution</summary>
public interface INuGetProjectServices
{
    /// <Summary>Gets the list of packages installed in a project.</Summary>
    /// <param name="projectId">Project ID (GUID).</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>
    /// The list of packages in the project.
    /// </returns>
    /// <exception cref="System.ArgumentException">When projectId is not a guid.</exception>
    Task<GetInstalledPackagesResult> GetInstalledPackagesAsync(string projectId, CancellationToken cancellationToken);
}

/// <summary>Result of a call to INuGetProjectServices.GetInstalledPackagesAsync</summary>
public sealed class GetInstalledPackagesResult
{
    /// <summary>The status of the result</summary>
    public GetInstalledPackageResultStatus Status { get; }

    /// <summary>List of packages in the project</summary>
    /// <remarks>May be null if <see cref="Status"/> was not successful</remarks>
    public IReadOnlyCollection<NuGetInstalledPackage> Packages { get; }

    // To maximize the chance this class can be converted to a C#9 record type without breaking changes, constructor is not public
    internal GetInstalledPackagesResult();
}

/// <summary>The status of the result</summary>
public enum GetInstalledPackageResultStatus
{
    /// <summary>Unknown status</summary>
    /// <remarks>Probably represents a bug in the method that created the result.</remarks>
    Unknown = 0,

    /// <summary>Successful</summary>
    Successful,

    /// <summary>The project is not yet ready</summary>
    /// <remarks>This typically happens shortly after the project is loaded, but the project system has not yet informed NuGet about package references</remarks>
    ProjectNotReady,

    /// <summary>Package information could not be retrieved because the project is in an invalid state</summary>
    /// <remarks>If a project has an invalid target framework value, or a package reference has a version value, NuGet may be unable to generate basic project information, such as requested packages.</remarks>
    ProjectInvalid
}

/// <summary>Basic information about a package</summary>
public sealed class NuGetInstalledPackage
{
    /// <summary>The package id.</summary>
    public string Id { get; }

    /// <summary>The package version</summary>
    /// <remarks>
    /// If the project uses packages.config, this will be the installed package version.
    /// If the project uses PackageReference, this would ideally be the resolved package version, but may be the requested package version.
    /// </remarks>
    public string Version { get; }

    // To maximize the chance this class can be converted to a C#9 record type without breaking changes, constructor is not public
    internal NuGetInstalledPackage();
}

/// <summary>Factory to create types</summary>
/// <remarks>Trying to be forwards compatible with what C#9 records are going to be</remarks>
public static class ContractsFactory
{
    /// <summary>Create a <see cref="NuGetInstalledPackage"/></summary>
    /// <param name="id"></param>
    /// <param name="version"></param>
    /// <param name="isDirectDependency"></param>
    /// <returns></returns>
    public static NuGetInstalledPackage CreateNuGetInstalledPackage(string id, string version, bool isDirectDependency);

    /// <summary>Create a <see cref="GetInstalledPackageResultStatus"/></summary>
    /// <param name="status"></param>
    /// <param name="packages"></param>
    /// <returns></returns>
    public static GetInstalledPackagesResult CreateGetInstalledPackagesResult(GetInstalledPackageResultStatus status, IReadOnlyCollection<NuGetInstalledPackage> packages);
}
```

## Future Work

* Add direct/transitive dependency information to `NuGetInstalledPackage`.

* Other required APIs: (incomplete list)
  * InstallPackageAsync
  * UninstallPackageAsync

## Open Questions

* GetInstalledPackagesAsync
  * Should returned package version be the resolved version, or the requested range, or the lower bound of the requested range? Leaning towards requested range. It means 
    * Should we return both requested and resolved versions?  Leaning to no: most components & extensions wouldn't care, plus it doesn't make sense in `packages.config` projects. If wanted, a PackageReference (PR) specific service could be added, which allows it to provide PR specific properties.
  * Should there be options to wait for nomination, rather than returning error?
  * If `NuGetInstalledPackage.Version` is the resolved version, do we distinguish between project not nominated vs restore not complete?  What about if restore failed?
* Test Explorer uses `IVsPackageMetadata.PackagePath`, via `GetInstalledPackages`. Check if this actually works for PackageReference projects, and consider adding to `NuGetInstalledPackage`. (future work)

## Considerations

* Error handling:
  * Use common practise of using exceptions for input validation (things caller should know before calling the API), and exceptional circumstances. Do not throw exceptions for expected scenarios.


### References

[NuGet extensibility services](NuGetExtensibilityServices.md)
[IVsPackageInstallerServices should be async](https://github.com/NuGet/Home/issues/9577)
