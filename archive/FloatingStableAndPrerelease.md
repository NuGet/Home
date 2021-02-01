
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
| 5.* | 5.1.0 <br> 5.2.0 <br> 5.3.0 <br> 5.4.0 <br> 5.5.0-preview.1 <br> 5.5.0-preview.2 <br> 5.5.0-preview.3 | 5.4.0 |

There is no way to float to both stable and prerelease versions at the same time.

## Who are the customers

PackageReference customers. A popular customer issue with > 80 comments & 38+ up-votes.

## Requirements

From the issue:

* I would like to use floating versions that only resolve to stable versions of the package (Current behavior)
* I would like to use floating versions that can resolve to the latest version even if the latest happens to be a pre-release version.
* I should be able to use both the braces/regex formats i.e. 1.* or [1.0.0, 2.0.0) that can include pre-release versions
* I would like to additionally define whether I want to resolve to rc, beta, alpha or all pre-releases.

## Goals

* Define a versioning strategy that allows floating to both stable and prerelease versions simultaneously. Floating only prerelease and only stable versions is possible today with `1.0.0-*` and `1.*` respectively.

## Non-Goals

* Support for more than 1 prerelease label in floating versions. This is out of scope as floating prerelease versions are already available today, and this would be addition solely to that scenario.
* Floating versions are only supported as declarations in the project, not in the nuspec. This is not going to change.

## Solution

The proposed syntax is one commonly discussed in the linked issue, `*-*`.
Specifically `*-*` says, I want the absolute latest and greatest package, and it doesn't matter to me whether the latest version is stable or prerelease.
Notable that this approach merely builds on top of the current floating version approach. The stable part syntax is the same and the prerelease syntax stays the same. The difference is, we can now combine them.
For example whenever we float a minor and prerelease, ex `1.*-*`, the stable part can match individually, but the prerelease part has to have a matching stable part.

For example:

| Floating Version | Available Versions | Best Version |
| -----------------|--------------------|-----------------------|
| 5.*-rc.* | 4.9.0 <br> 5.1.0 <br> 5.2.0-beta.1 <br> 5.2.0-rc.3 <br> 6.0.0-rc.1 | [5.2.0-rc.3](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/find-best-version-match?versionRange=5.*-rc.*&versions=4.9.0%0D%0A5.1.0%0D%0A5.2.0-beta.1%0D%0A5.2.0-rc.3%0D%0A6.0.0-rc.1) |

### How do floating versions work

This section does not indicate a design change, rather summarizes the current behavior for clarity.

* Floating versions are **not regex**, despite the usage of `*` in the floating version grammar. Likewise, calling them wild card versions can be misleading as well. Floating version ranges have a semantic meaning that's applied when determining a match that's different from what a regex does.

* Given a version `5.0.0-preview.1`, the `5.0.0` will be referred to as the `stable part` and `preview.1` will be refered to as the `prerelease part`. The first `-` in a version/version range is the separator between the stable and prerelease parts.

* When specifying a floating version, stable versions are *always* allowed. See [example](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/find-best-version-match?versionRange=1.1.0-*&versions=1.1.0-beta%0D%0A1.1.0). For `1.1.0-*` with `1.1.0-beta` and `1.1.0` available, the selected version is `1.1.0`.

* Prerelease versions are only allowed when the prerelease part of a version is `floated`. Specifically `*`, `1.*`, `1.0.*` do not include prerelease versions.

* If no version matches a floating version range, the lowest potential version in the range is chosen. See [example](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/find-best-version-match?versionRange=1.1.*&versions=1.2.1%0D%0A1.3.1). For `1.1.*` with `1.2.1` and `1.3.1` available, the selected version is 1.2.1. It's the first suitable version in the range that's considered the best version.
For floating ranges, `1.*` implies `[1.*, )` in a similar way that `1.0.0` implies `[1.0.0, )`.

* The best way to think about floating versions is that they are still a range, but instead of choosing lowest first based on the version ordering, there is a set of preferred versions that take precendence. Just because a version is not a preferred one, it's not excluded from the range. 

### Scenarios

For convenience, the implementation of this proposal has been uploaded to a [helper service](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/parse-version-range?versionRange=*-*) where you can [try out](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/) the version parsing and the version selection. 
You can switch to published versions of NuGet to compare the behavior.

#### Common Scenarios

The NuGet floating version syntax allows for some pretty powerful version ranges, but it is likely that your scenario will be mostly satisfied by the following 3 floating versions

* `*-*` - Float everything! Latest version available
* `1.*-*` - Prefer latest 1.X version, include prerelease and stable
* `1.0.*-*` - Prefer latest 1.0.X version, include prerelease and stable

The behavior is best illustrated with examples, you can examine the exact selection in an online tool by clicking the link in the best version column. Note that the potential versions are sorted by priority.

| Floating Version | Available Versions | Preferred Versions | Potential Versions | Best version | Notes |
| -----------------|--------------------|-------------------|--------------------|--------------|-------|
| `*`              | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 1.1.0 <br> 2.0.0 | 2.0.0 <br> 1.1.0 | [2.0.0](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/find-best-version-match?versionRange=*&versions=1.1.0%0D%0A1.2.0-rc.1%0D%0A1.2.0-rc.2%0D%0A2.0.0%0D%0A3.0.0-beta.1) | Only stable versions are matched |
| `1.*`            | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 1.1.0 | 1.1.0 <br> 2.0.0 | [1.1.0](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/find-best-version-match?versionRange=1.*&versions=1.1.0%0D%0A1.2.0-rc.1%0D%0A1.2.0-rc.2%0D%0A2.0.0%0D%0A3.0.0-beta.1) | Stable versions starting with 1.* are preferred. |
| `1.2.0-*`        | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 1.2.0-rc.1 <br> 1.2.0-rc.2 | 1.2.0-rc.2 <br> 1.2.0-rc.1 <br> 2.0.0 <br> 3.0.0-beta.1 | [1.2.0-rc.2](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/find-best-version-match?versionRange=1.2.0-*&versions=1.1.0%0D%0A1.2.0-rc.1%0D%0A1.2.0-rc.2%0D%0A2.0.0%0D%0A3.0.0-beta.1) | The highest matching prerelease is selected |
| `1.2.0-*`        | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 1.2.0| 1.2.0-rc.1 <br> 1.2.0-rc.2 | 1.2.0 <br> 1.2.0-rc.2 <br> 1.2.0-rc.1 <br> 1.2.0 | [1.2.0](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/find-best-version-match?versionRange=1.2.0-*&versions=1.1.0%0D%0A1.2.0-rc.1%0D%0A1.2.0-rc.2%0D%0A1.2.0) | Despite this being a version range with a prerelease floating part, stables are allowed if they match the stable part. Given that 1.2.0 > 1.2.0-rc.2, it is chosen. |
| `*-*`            | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 3.0.0-beta.1 <br> 2.0.0 <br> 1.2.0-rc.2 <br> 1.2.0-rc.1 <br> 1.1.0  | [3.0.0-beta.1](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/find-best-version-match?versionRange=*-*&versions=1.1.0%0D%0A1.2.0-rc.1%0D%0A1.2.0-rc.2%0D%0A2.0.0%0D%0A3.0.0-beta.1) | 3.0.0 is the highest version |
| `1.*-*`          | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 | 1.2.0-rc.2 <br> 1.2.0-rc.1 <br> 1.1.0 <br> 2.0.0 <br> 3.0.0-beta.1 | [1.2.0-rc.2](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/find-best-version-match?versionRange=1.*-*&versions=1.1.0%0D%0A1.2.0-rc.1%0D%0A1.2.0-rc.2%0D%0A2.0.0%0D%0A3.0.0-beta.1) | A prerelease version is the highest matching version |

#### Advanced scenarios

While the above cover the majority of the customer scenarios, there are additional ones that are decidedly more challenging to reason about. 
Note that the release label behavior here is consistent with the current implementation of floating versions.

| Floating Version | Available Versions | Preferred Versions | Potential Versions | Best version | Notes |
| -----------------|--------------------|-------------------|--------------------|--------------|-------|
| `1.2.0-alpha.*`        | 1.1.0 <br> 1.2.0-alpha-1 <br> 1.2.0-alpha.3 <br> 1.2.0-beta.1 <br> 1.2.0-rc.2 | 1.2.0-alpha.1 <br> 1.2.0-alpha.3 | 1.2.0-alpha.3 <br> 1.2.0-alpha.3 <br> 1.2.0-rc.2 <br> 1.2.0-rc.1| [1.2.0-alpha.3](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/find-best-version-match?versionRange=1.2.0-alpha.*&versions=1.1.0+%0D%0A1.2.0-alpha-1+%0D%0A1.2.0-alpha.3+%0D%0A1.2.0-beta.1+%0D%0A1.2.0-rc.2+%0D%0A1.2.0) | The version range prefers the alpha prerelease labels. |
| `*-rc.*`         | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 <br> 3.0.0-beta.1 | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 2.0.0 | 2.0.0 <br> 1.2.0-rc.2 <br> 1.2.0-rc.1 <br> 1.1.0 <br> 3.0.0-beta.1 | [2.0.0](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/find-best-version-match?versionRange=*-rc.*&versions=1.1.0%0D%0A1.2.0-rc.1%0D%0A1.2.0-rc.2%0D%0A2.0.0%0D%0A3.0.0-beta.1) | A stable version is the highest matching version |
| `1.*-rc*`        | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 1.2.0-rc1 <br> 2.0.0 <br> 3.0.0-beta.1 | 1.1.0 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 1.2.0-rc1 | 1.2.0-rc1 <br> 1.2.0-rc.1 <br> 1.2.0-rc.2 <br> 1.1.0 <br> 2.0.0 <br> 3.0.0-beta.1 | [1.2.0-rc1](https://nugettoolsdev.azurewebsites.net/5.5.0-floating.7611/find-best-version-match?versionRange=1.*-rc*+&versions=1.1.0%0D%0A1.2.0-rc.1%0D%0A1.2.0-rc.2%0D%0A1.2.0-rc1%0D%0A2.0.0%0D%0A3.0.0-beta.1) | A prerelease version with a common prefix is the highest available version |

## Considerations

* Why not use an extra parameter like `<PackageReference Include="NuGet.Packaging" Version="1.*" IncludePrerelease="true" />`

There are a few reasons why we decided against that approach:

1. The PackageReference opt in into prerelease version for ranges is dependant on the version requested. PackageReference allows prereleases as potential versions when opted in.
1. You can not specify which prerelease versions you want included. For example, you can not express the following version from the proposed approach `5.1.*-rc.*`.
1. It adds an additional element which could realistically be added anywhere. PackageReference is integrated within MSBuild, you could easily add the attribute somewhere totally different and that'd be invisible to someone reading the csproj.
1. It does not apply in certain situations, creating redundancies.

* How will old clients behave

Old clients fail to parse this version. This is arguably the desired behavior, as it allows the customer to recognize very early that things will not work the way they expect them to.
The error message with which old clients fail is:

```console
error : '*-*' is not a valid version string. [F:\Test\floating.csproj]
```

The error itself does not indicate a required action, but in general it's difficult for old clients to predict what would be valid in future versions.
In general, the focus is on the user to ensure all their tooling is up to date across their local development machines and CI.

### Open Questions

### Related issues

* [9111](www.github.com/NuGet/Home/9111) - Stable part partial numeric floating behaves different from prerelease part numeric floating
* [1861](https://github.com/NuGet/docs.microsoft.com-nuget/issues/1861) - Floating versions should not be called wildcard versions
* [1862](https://github.com/NuGet/docs.microsoft.com-nuget/issues/1862) - Floating version selection explained
* [5097](https://github.com/NuGet/Home/issues/5097) - Floating version patterns like '1.*` are treated as ranges without a max, `1.*` is [1.*, )
