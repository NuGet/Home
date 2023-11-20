# INuGetProjectServices

* Status: In Review
* Author(s): [Andy Zivkovic](https://github.com/zivkan)
* Issue: [9577](https://github.com/NuGet/Home/issues/9577) IVsPackageInstallerServices should be async

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
/// <remarks>This interface should not be implemented. New methods may be added over time.</remarks>
public interface INuGetProjectService
{
    /// <Summary>Gets the list of packages installed in a project.</Summary>
    /// <param name="projectId">Project ID (GUID).</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The list of packages in the project.</returns>
    Task<InstalledPackagesResult> GetInstalledPackagesAsync(Guid projectId, CancellationToken cancellationToken);
}

/// <summary>Result of a call to <see cref="INuGetProjectService.GetInstalledPackagesAsync"/></summary>
/// <remarks>To create an instance, use <see cref="NuGetContractsFactory.CreateInstalledPackagesResult"/>.</remarks>
public sealed class InstalledPackagesResult
{
    /// <summary>The status of the result</summary>
    public InstalledPackageResultStatus Status { get; }

    /// <summary>List of packages in the project</summary>
    /// <remarks>May be null if <see cref="Status"/> was not successful</remarks>
    public IReadOnlyCollection<NuGetInstalledPackage> Packages { get; }

    // This class will hopefully use C# record types when that language feature becomes available, so make the constructor not-public, to prevent breaking change when records come out.
    internal InstalledPackagesResult(InstalledPackageResultStatus status, IReadOnlyCollection<NuGetInstalledPackage> packages);
}

/// <summary>The status of a <see cref="InstalledPackagesResult"/> result</summary>
public enum InstalledPackageResultStatus
{
    /// <summary>Unknown status</summary>
    /// <remarks>Probably represents a bug in the method that created the result.</remarks>
    Unknown = 0,

    /// <summary>Successful</summary>
    Successful,

    /// <summary>The project is not yet ready</summary>
    /// <remarks>There are several scenarios where this might happen:
    /// If the project was recently loaded, NuGet might not have been notified by the project system yet.
    /// Restore might not have completed yet.
    /// The requested project is not in the solution or is not loaded.
    /// </remarks>
    ProjectNotReady,

    /// <summary>Package information could not be retrieved because the project is in an invalid state</summary>
    /// <remarks>If a project has an invalid target framework value, or a package reference has a version value, NuGet may be unable to generate basic project information, such as requested packages.</remarks>
    ProjectInvalid
}

/// <summary>Information about an installed package</summary>
/// <remarks>To create an instance, use <see cref="NuGetContractsFactory.CreateNuGetInstalledPackage"/>.</remarks>
public sealed class NuGetInstalledPackage
{
    /// <summary>The package id.</summary>
    public string Id { get; }

    /// <summary>The project's requested package range for the package.</summary>
    /// <remarks>
    /// If the project uses packages.config, this will be same as the installed package version.
    /// If the project uses PackageReference, this is the version string in the project file, which may not match the resolved package version, and may not be single version string.
    /// </remarks>
    public string RequestedRange { get; }

    /// <summary>The installed package version</summary>
    /// <remarks>
    /// If the project uses packages.config, this will be the same as requested range.
    /// If the project uses PackageReference, this will be the resolved version.
    /// </remarks>
    public string Version { get; }

    /// <summary>Path to the extracted package</summary>
    /// <remarks>
    /// When Visual Studio is connected to a Codespaces or Live Share environment, the path will be for the remote envionrment, not local.
    /// This may be null if the package was not restored successfully.
    /// </remarks>
    public string InstallPath { get; }

    // This class will hopefully use C# record types when that language feature becomes available, so make the constructor not-public, to prevent breaking change when records come out.
    internal NuGetInstalledPackage(string id, string requestedRange, string version, string installPath);
}

/// <summary>Factory to create contract types</summary>
/// <remarks>Trying to be forwards compatible with what C#9 records are going to be</remarks>
public static class NuGetContractsFactory
{
    /// <summary>Create a <see cref="NuGetInstalledPackage"/></summary>
    /// <param name="id">Package Id</param>
    /// <param name="requestedRange">The requested range</param>
    /// <param name="version">The installed version</param>
    /// <param name="installPath">The package install path</param>
    /// <returns><see cref="NuGetInstalledPackage"/></returns>
    public static NuGetInstalledPackage CreateNuGetInstalledPackage(string id, string requestedRange, string version, string installPath);

    /// <summary>Create a <see cref="InstalledPackageResultStatus"/></summary>
    /// <param name="status"><see cref="InstalledPackageResultStatus"/></param>
    /// <param name="packages">Read-only collection of <see cref="NuGetInstalledPackage"/></param>
    /// <returns><see cref="InstalledPackagesResult"/></returns>
    public static InstalledPackagesResult CreateGetInstalledPackagesResult(InstalledPackageResultStatus status, IReadOnlyCollection<NuGetInstalledPackage> packages);
}
```

## Future Work

* Other required APIs: (incomplete list)
  * InstallPackageAsync
  * UninstallPackageAsync

## Considerations

* Use `System.Guid` for project identifiers
  * Projects can be renamed or moved, and this has caused project system problems in the past. Their advice was to use the guid instead.
  * Using `System.Guid` makes the API more clear/discoverable and potentially could reduce temporary string allocations.
* Error handling:
  * Use common practise of using exceptions for input validation (things caller should know before calling the API), and exceptional circumstances. Do not throw exceptions for expected scenarios.
  * Throw specific exceptions. When a caller needs to be able to branch depending on error condition, catch at the top level method and rethrow as RemoteInvocatonException, setting ErrorCode to a value they can use, and the original exception as the inner exception.  A future update to Visual Studio's RPC client will allow callers to automatically upwrap the RemoteInvocationException.
  * `IVsPackageInstallerServices.GetInstalledPackages(string)` has a bug where the returned package metadata returns requested version, not resolved version. It is deemed acceptible for this API to have the same bug, and be fixed in the future, despite the fact it's a change in behavior after shipping the initial version.
* `GetInstalledPackagesAsync`
  * Return both requested range and installed version. Roslyn uses `GetInstalledPackagesAsync` to suggest packages to install when a different project in the solution is using that package. The version property is used to install the same version as the other project. By including requested range, it enables the version string written to the project file to match when the first project used a range. There are other scenarios when the caller cares about resolved version, so that should be included as well. Hence the two version related properties.
  * Test explorer uses `InstallPath` to detect test adapters. We need to keep this property.

### References

[NuGet extensibility services](NuGetExtensibilityServices.md)
[IVsPackageInstallerServices should be async](https://github.com/NuGet/Home/issues/9577)
