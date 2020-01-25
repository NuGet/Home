
# Support pre-release packages with floating versions

* Status: **In Review**
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)
* Issue: [912](https://github.com/NuGet/Home/issues/912) Support pre-release packages with floating versions
* Type: Feature

## Problem Background

Consider a PackageReference as such:

```xml
<ItemGroup>
    <PackageReference Include="NuGet.Packaging" Version="5.*" />
</ItemGroup>
```

Right now this will only include stable package versions.
| Floating Version | Available Versions | Best matching version |
| -----------------|--------------------|-----------------------|
| 5.* | 5.0.0 <br> 5.1.0 <br> 5.2.0 <br> 5.3.0 <br> 5.4.0 <br> 5.5.0-preview.1 <br> 5.5.0-preview.2 | 5.4.0 |

## Who are the customers

PackageReference customers. A popular customer with > 80 comments & 38+ up-votes.

## Requirements

From the issue:

As Noel, who uses NuGet packages in PackageReference based projects,

I would like to use floating versions that only resolves to stable versions of the package (Current behavior)
I would like to use floating version that can resolve to the latest version even if the latest happens to be a pre-release version.
I should be able to use both the braces/regex formats i.e. 1.* or [1.0.0, 2.0.0) that can include pre-release versions
I would like to additionally define whether I want to resolve to rc, beta, alpha or all pre-releases.

## Goals

* Define a versioning strategy that allows floating to both stable and prerelease versions simultaneously. Floating only prerelease and only stable versions is possible today with `1.0.0-*` and `1.*` respectively.

## Non-Goals

* Support for more than 1 prerelease label in floating versions. This is out of scope, because there is no way today with the prerelease only floating versions. As such it can be treated as a separate feature.

## Solution

The proposed syntax is one commonly discussed in the linked issue, `*-*`.
Specifically `*-*` says, I want the absolute latest and greatest package, and it doesn't matter to me whether the latest version is stable or prerelease.
Notable that 

## Considerations

* Why not use an extra parameter like `<PackageReference Include="NuGet.Packaging" Version="1.*" IncludePrerelease="true" />`

A few reasons for that approach:
    * The PackageReference opt in into prerelease version for ranges is dependant on the version requested.

### Open Questions
