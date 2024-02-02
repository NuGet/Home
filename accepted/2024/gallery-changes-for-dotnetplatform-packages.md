# **Behavioral changes in Gallery for DotnetPlatform Packages**
- [baronfel](https://github.com/baronfel)
- N/A (will replace later)

## Summary

This spec proposes to make two behavioral changes to the Gallery for Packages that use the `DotnetPlatform` [PackageType](https://github.com/NuGet/NuGet.Client/blob/bd0764b4a5b78eea77c61f5b82078623c4fc0cfe/src/NuGet.Core/NuGet.Packaging/Core/PackageType.cs#L15-L20) to identify .NET SDK Workloads-related packages. These changes are intended to reduce user confusion and improve the suitability of NuGet.org search results for terms that overlap with terms present in Workload-related packages.

## Motivation 
 
Workloads have been a key part of the .NET experience for the past 3 major versions, and over that time key .NET platform features have been added to the set of known workloads, and new workloads concepts like workload sets have been added. New tooling experiences like Aspire and MAUI, and new platforms like WASM, are purely distributed as Workloads.

As a result, workloads-related packages have proliferated on NuGet.org, and in  highly-searched areas like Aspire and MAUI the workloads-related packages often drowned out other user-facing packages that are more relevant to the user's search.

The SDK team believes that a) workload packages are not intended to be directly installed by users, instead being installed by proxy through the `dotnet workload install` and/or `dotnet workload restore` commands, and b) most users are not interested in seeing workload packages in their search results, because they are typically looking for support packages for MAUI, Aspire, etc. instead of the raw implementation packages.

Because workload packages are published with the `DotnetPlatform` `PackageType`, NuGet has a first-class idea of what a Workloads-related package is and it can use that information to improve the search experience for users. Today, searching NuGet.org for `MAUI` returns 2750 packages, and of the first 10 results 8 are workloads packages that a user would never install as a PackageReference. This makes it much hard to discover MAUI-compatible packages as an end user.

## Explanation

### Functional explanation

Concretely, we'd like to suggest two orthogonal changes to the way the NuGet gallery treats `DotnetPlatform` packages:

1) change the default free-form search filter to filter out `DotnetPlatform` packages
  a) this implies adding a new filter to the search UI that allows users to opt-in to seeing `DotnetPlatform` packages in their search results, like .NET Tool and Template packages are today
  b) we would need a new filter for `DotnetPlatform` packages explicitly so that devs could still locate specific package detail pages if they needed to, for example a .NET platform developer wanting to get a direct link to nuget.info for a package to investigate package contents or metadata

2) change the rendering behavior for `DotnetPlatform` packages on the package details page to remove the 'package manager installation' section, as this is never correct for workload packages
  a) in the future this could be changed to offer a `dotnet workload install` command that would result in this package getting installed, but this is a surprising amount of work to discover and we don't want to ask for it without further end-user signal


### Technical explanation

* The Gallery will add a new filter to the search UI that allows users to opt-in to seeing `DotnetPlatform` packages in their search results, like .NET Tool and Template packages are today
* The Gallery will change the rendering behavior for `DotnetPlatform` packages on the package details page to remove the 'package manager installation' section, as this is never correct for workload packages
* The Gallery will change the default filters for server-side search to exclude `DotnetPlatform` packages by default, unless the `&packagetype=dotnetplatform` query parameter is explicitly appended.

## Drawbacks

Users may be confused by the new behavior, and may not understand why they can't find a package they know exists on NuGet.org. This is mitigated by the fact that the new behavior is opt-in, and the new behavior is consistent with the behavior of other package types like .NET Tool and Template packages.

## Rationale and alternatives

This is a good design because it integrates nicely with the existing PackageType concept, recognizes a class of package that is fundamental to the ecosystem, important to organizational goals, and almost guaranteed to grow more in the future.

Other designs might codify patterns outside of NuGet itself (like naming conventions, or hijacking metadata in the NuSpec) that would make it more difficult to standardize the behavior across the ecosystem.

## Prior Art

Other types of packages have gotten this same treatment in the past:
* .NET SDK Tools
* .NET SDK Templates

These similarly are foundational to the way the .NET ecosystem works and are worth filtering (either out or in).

## Unresolved Questions

## Future Possibilities
