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
* Quickly return incomplete task to unblock thread.
* Works with Visual Studio Codespaces, and hopefully Live Share.

## Non-Goals

* This will not be a 1:1 replacement for any of NuGet's existing `IVs` interfaces.

## Solution

```cs
public interface INuGetProjectServices
{
    /// <summary>Gets the list of packages installed in a project.</summmry>
    /// <param name="project">Path and filename to project file.</param>
    /// <param name="options">Options to use. If null, uses GetInstalledPakcagesOptions.Default.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>
    /// The list of packages in the project.
    /// If the project does not exist in the solution, throws ArgumentException.
    /// If the project is not ready, throws NuGetProjectNotReadyException.
    /// </return>
    Task<IReadOnlyList<NuGetPackage>> GetInstalledPackagesAsync(string project, GetInstalledPackagesOptions options, CancellationToken cancellationToken);
}

public sealed class NuGetPackage
{
    /// <summary>The package id.</summary>
    string Id { get; }

    /// <summary>The package version</summary>
    /// <remarks>
    /// If the project uses packages.config, this will be the installed package version.
    /// If the project uses PackageReference, this would ideally be the resolved package version, but may be the requested package version.
    /// </remarks>
    string Version { get; }

    internal NuGetPackage(string id, string version);
}

public sealed class GetInstalledPackagesOptions
{
    public static GetInstalledPackageOptions Default { get; }

    // in the future may include options such as WaitForNomination, WaitForRestore.
}

public sealed class NuGetProjectNotReadyException : InvalidOperationException
{
}

```

## Future Work

* APIs for:
  * InstallPackageAsync
  * UninstallPackageAsync

## Open Questions

* How to handle errors
  * CPS projects (SDK-style .NET projects) work by: On project load, CPS sends NuGet a "nomination" with project/package information. Therefore, NuGet can't return packages in GetPackagesAsync until CPS nomination complete. With IVsPackageInstallerServices, we throw InvalidOperationException if we haven't got nomination info. Given that the new API needs to work over remoting scenarios, how should it be done?  There are multiple options
    1. Throw exception (task in faulted state). This might appear as a RemotingException to callers, so maybe hard to distinguish between different types of exceptions?
    2. Return additional error information. This might be a tuple or a result class. Should we use a type extending `Exception` (stack trace probably wouldn't transport), or have `string Code` and `string Message`?  Or just a `bool Success`, without details about why it was unsuccessful?
* GetInstalledPackagesAsync
  * Should returned package version be the resolved version, or the requested range, or the lower bound of the requested range? Leaning towards requested range. It means 
    * Should we return both requested and resolved versions?  Leaning to no: most components & extensions wouldn't care. If wanted, a PackageReference (PR) specific service could be added, which allows it to provide PR specific properties.
  * Should there be options to wait for nomination, rather than throwing an exception?
  * If `NuGetPackage.Version` is the resolved version, do we distinguish between project not nominated vs restore not complete?  What about if restore failed?
* NuGetPackage could have property saying if package is direct or transitive. (future work)
* Test Explorer uses IVsPackageMetadata.PackagePath. Check if this actually works for PackageReference projects, and consider adding to NuGetPackage. (future work)

## Considerations

TODO: document outcomes of Open Questions

### References

[NuGet extensibility services](NuGetExtensibilityServices.md)
[IVsPackageInstallerServices should be async](https://github.com/NuGet/Home/issues/9577)
