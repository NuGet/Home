
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
Notable that this approach merely builds on top of the current floating version approach. The stable part syntax is the same and the prerelease syntax stays the same. The difference is, we can now combine them.
For example whenever we float a minor and prerelease, ex `1.*-*`, the stable part can match individually, but the prerelease part has to have a matching stable part. 

For example:

| Floating Version | Available Versions | Versions that match |
| -----------------|--------------------|-----------------------|
| 5.*-rc.* | 4.9.0 <br> 5.1.0 <br> 5.2.0-beta.1 <br> 5.2.0-rc.3 <br> 6.0.0-rc.1 | 5.1.0 <br> 5.2.0-rc.3 |

Note that 5.2.0-beta.1 and 6.0.0-rc.1 do not match.

The behavior is best illusrated with examples

| Floating Version | Available Versions | Matching Versions | Best version | Notes |
| -----------------|--------------------|-------------------|--------------|-------|
| *                | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 1.1.0 <br> 2.0.0 | 2.0.0 | Only stable versions are matched | 
| 1.*              | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 1.1.0 | 1.1.0 | Only stable versions starting 1.* are matched | 
| 1.2.0-*          | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 1.2.0-rc.1 <br> 1.2.0-rc.2 | 1.2.0-rc.2 | The highest matching prerelease is selected |
| *-*              | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 3.0.0-beta.1 | 3.0.0 is the highest version |
| 1.*-*              | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 | 1.2.0-rc.2 | A prerelease version is the highest matching version |
| *-rc.*              | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 | 2.0.0 | A stable version is the highest matching version |

For convenience, the implementation of this proposal has been uploaded to a helper service where you can try out the version parsing and the version selection. https://nugettoolsdev.azurewebsites.net/5.3.0

You can switch the versions to compare the behavior.

### Grammar

TODO NK

## Considerations

*  Why not use an extra parameter like `<PackageReference Include="NuGet.Packaging" Version="1.*" IncludePrerelease="true" />`

A few reasons for that approach:

1. The PackageReference opt in into prerelease version for ranges is dependant on the version requested. PackageReference allows prereleases as potential versions for dependencies due to (link issue)
1. You can not specify which prerelease versions you want included. For  example, you can not express the following version from the proposed approach `5.1.*-rc.*`. 
1. It adds an additional element which could realistically be added anywhere. PackageReference is integrated within MSBuild, you could easily add 
1. It does not apply in certain situations, creating redundancies.

* How will old clients behave

Old clients fail to parse this version. This is arguably the desired behavior, as it allows the customer to recognize very early that things will not work the way they expect them to. 

### Open Questions
