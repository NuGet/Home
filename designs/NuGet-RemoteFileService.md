
# Spec Name

* Status: In Review
* Author(s): [Rob Relyea](https://github.com/rrelyea)
* Issue: [10151](https://github.com/NuGet/Home/issues/10151) INuGetRemoteFileService - Fetch Images and embedded licenses for codespaces and normal execution

## Problem Background

With Codespaces support added to NuGet client, our code needs to be able to handle all packages and communication with feeds happening on a server node. This is architected as async method calls to services that are remoted. In most cases, we also have chosen to have 1 code path, for normal execution and remoted execution. These services are still used in the normal execution, however, the service runs in the same process, as opposed to being remoted across the network.

Package Icons can either come from:
- a package feeds search service
- (old style) or a URI to an arbitrary place on the web
- embedded in a package

Licenses can also come from a few places, including a license file embedded in a package.

## Who are the customers

All PM UI customers.

## Goals

Support remote and normal fetching of icons and licenses.

## Non-Goals

## Solution Overview

### Fetching Files
Defined a new interface for this service:

namespace NuGet.VisualStudio.Internal.Contracts
{
    public interface INuGetRemoteFileService : IDisposable
    {
        ValueTask<Stream?> GetPackageIconAsync(PackageIdentity packageIdentity, CancellationToken cancellationToken);
        ValueTask<Stream?> GetEmbeddedLicenseAsync(PackageIdentity packageIdentity, CancellationToken cancellationToken);
    }
}

On the service side, in SearchObject.CacheBackgroundData(), beyond the packageSearchMetadata caching that was already done, we call a RemoteFileService instance to AddIconToCache() and to AddLicenseToCache().

On the client side, when trying to Fetch the Icon, we call RemoteFileService.GetPackageIconAsync, passing in the package identity.

On the service side, we then retrieve the appropriate file from the appropriate location based on the entries in the MemoryCache.

Issue: should GetEmbeddedLicenseAsync be more generic. (question from zkat)
    zkat - I guess this is fine for now, but I'd really like it if now-or-eventually, this is abstracted away into a set of supported "Well Known Files"--for example, if we want to add Changelog or docs support in the future.

    rrelyea - thought a bit about it... i'd imagine we could pass an enum into a method... packageIdentity, wellKnownEmbeddedFile

    where wellKnownEmbeddedFiles might be readme, license and what else?
    maybe icon...but that isn't always embedded, can also be a url outside of the package.
    i lean towards not doing this in a generic way yet...as we don't know the full set of needs yet...and since the nuspec is on the server, we cannot just take a relative path, etc...

    would love to discuss, hear other thoughts.

### Other Changes

Several classes had a PackageReader property that was of type Func<PackageReader>.
Func<PackageReader> wasn't designed to be remoted nicely. In serveral places, i replaced the PackageReader property with a PackagePath property, to be used when appropriate for loading files from a Package.

## Test Strategy

Added unit tests for NuGetRemoteFileService and updated many existing tests for this new implemenation of icons/licenses.

## Future Work

None critical.

## Open Questions

Any open questions not specifically called out in the design.

## Considerations

At one point, the design of this interface passed in URIs...we moved to PackageIdentity and storing in the MemoryCache to tighten security of the feature.

### References
