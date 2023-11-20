# PackageReference, All Stable floating '*' normalization technical spec

* Status: **Reviewing**
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)

## Issue

[8472](https://github.com/NuGet/Home/issues/8472) - Certain version ranges have normalized version strings that do not round trip.

[8432](https://github.com/NuGet/Home/issues/8432) - NuGet.exe does not resolve to the latest version of a package when using * in PackageReference (MSBuild/Dotnet/VS restore do).

[8073](https://github.com/NuGet/Home/issues/8073) - Lock file is not honored in "*" scenarios

[6697](https://github.com/NuGet/Home/issues/6697) - Wrong package dependency version If package dependency version is set to '*'

## Background

NuGet introduced the concept of floating versions (version ranges) in 3.x with the birth of project.json. The same concept was retained when the transitive world moved to PackageReference. Refer to [Dependency resolution - floating versions](https://docs.microsoft.com/en-us/nuget/concepts/dependency-resolution#floating-versions) and [Package References in project files - floating versions](https://docs.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files#floating-versions).
The regular version ranges always resolve minimum available. The floating version ranges always resolve latest available.

Throughout the client NuGet uses normalized versions to uniquely and consistently represent the user input version or version range.
NuGet version ranges are supported with an interval notation. For example:

| Notation | Applied rule | Normalized version | Description |
|----------|--------------|--------------------|-------------|
| 1.0.0 | x => 1.0.0 | [1.0.0, ) |Minimum version, inclusive |
| (1.0.0,) | x > 1.0.0 | (1.0.0, )|Minimum version, exclusive |
| [1.0.0, 2.0.0) | 2.0.0 > x => 1.0.0 | [1.0.0, 2.0.0) | Exact range, minimum version, inclusive, maximum version exclusive |
| [, 2.0.0) | 2.0.0 > x | (, 2.0.0)|Maximum 2.0.0 exclusive, note the change in the inclusivity in the normalized representation. If there's no version, no inclusive range can exist. |

Similarly floating version ranges normalize, albeit they have a bit different behavior:

| Notation | Applied rule | Normalized version | Description |
|----------|--------------|--------------------|-------------|
| 1.* | x => 1.0.0, latest | [1.*, ) | Minimum version 1.0.0, get latest stable version where the major is 1. If none is available, get the first version satisfying the range  |
| [1.*, 2.0.0) | 2.0.0 > x > 1.0.0, latest | [1.*,2.0.0)|Minimum 1.0.0, inclusive, get latest stable version where the major is 1. No fail over is allowed. Max version is 2.0.0 exclusive. |
| (1.1.*, 2.0.0) | 2.0.0 > x > 1.0.0, latest | (1.1.*, 2.0.0)|Minimum 1.1.0, exclusive, get latest stable version where the major is 1. No fail over is allowed. Max version is 2.0.0 exclusive. |
| [*, 2.0.0) | 2.0.0 > x >= 0.0.0, latest | [*, 2.0.0)| Latest version available smaller than 2.0.0, exclusive. Note that the min version is treated as 0.0.0 |

The problem here is how the '*' gets normalized.
Refer to the below table. Here's how NuGet will interpret the respective notation.

| Notation | Applied rule | Normalized version | Description |
|----------|--------------|--------------------|-------------|
| * | Latest stable | (, ) | Latest stable version, no restrictions |
| (, ) | No restrictions, minimum available version | (, ) | Any version, prefer smallest because it's not floating |

### Visual Studio Package Manager UI and floating versions

The floating versions are not nicely displayed in the PackageManager UI.
See [3788](https://github.com/NuGet/Home/issues/3788). Before and after my proposed change, the experience remains the same.

### Workarounds

There are 2 workarounds that customers can use:

* The first one is [suggested by a customer](https://github.com/NuGet/Home/issues/7328#issuecomment-425942851) in one of the issues `[*,9999.0]`
* The second one, and the one I personally prefer it using `[*,)`

## Who are the customers

PackageReference NuGet customers that use floating versions.

## Requirements

* The scenarios described in the above issues, using '*' to work.

## Solution

The root cause here is that the normalized version of `*` does not round trip accurately.
Programmatically the reason for that is that there is no min version.
Refer to [code](https://github.com/NuGet/NuGet.Client/blob/caac28293a4032de8629b39597a179df988a612a/src/NuGet.Core/NuGet.Versioning/VersionRangeFormatter.cs#L167).
Specifically why '*' is a problem is because there will be no min version specified, so the normalization code does not know it needs a value there, [code](https://github.com/NuGet/NuGet.Client/blob/caac28293a4032de8629b39597a179df988a612a/src/NuGet.Core/NuGet.Versioning/VersionRangeFactory.cs#L107).

There are ways to create a NuGetVersionRange object that cannot be represented as a string (yet), or that there are more than one version range objects that mean similar/exactly the same thing, often times unintentionally, see [8472](https://github.com/NuGet/Home/issues/8472).
Effectively the NuGetVersionRange model has a min/max version object and a includeMin/max versions bool,see [code](https://github.com/NuGet/NuGet.Client/blob/caac28293a4032de8629b39597a179df988a612a/src/NuGet.Core/NuGet.Versioning/VersionRangeBase.cs#L25-L35).

Given what we know, there are 2 potential approaches to fix this.

* Change the way we determine the normalized version for a VersionRange is, ie stop relying on having a min version.

The approach here would be to look at the floating range first and then if existing immediately assume there's a min version.
This would lead to a `(*, )` representation, despite the fact that VersionRange object is created with min inclusive. That could not be observed because there's no actual min version.

* Add an implied min version for * in the parsing step.

Given that `*` is only ever allowed in the min version of the version range, I would argue that putting a min version in the range parsed by * is the correct thing.
After all, `1.*` means a min version of `1.0.0`, it's only logical that the min version allowed by `*` is the minimum possible stable version of 0.0.0.
This would change certain representations of the version range, but I believe those are warranted. Specifically this would mean that `*` normalizes to `[*, )`.

Specifically compare [`*`](https://nugettoolsdev.azurewebsites.net/5.3.0/parse-version-range?versionRange=*), [`[*, )`](https://nugettoolsdev.azurewebsites.net/5.3.0/parse-version-range?versionRange=%5B*%2C%29), [`(,2.0.0)`](https://nugettoolsdev.azurewebsites.net/5.3.0/parse-version-range?versionRange=%28%2C2.0.0%29), and [`[*, 2.0.0)`](https://nugettoolsdev.azurewebsites.net/5.3.0/parse-version-range?versionRange=%5B*%2C+2.0.0%29). Note the implied min version when using a `*`, but it's not there when using floatless version ranges.

|  | * | [*, ) | (,2.0.0) | [*, 2.0.0) |
|--|---|-------|----------|------------|
|Range | floating | floating | not floating| floating |
| Normalized range | (, ) | [*, ) | (, 2.0.0)| [*, 2.0.0) |
| Pretty print | | (>= 0.0.0) | (< 2.0.0) | (=> 0.0.0 && < 2.0.0)|
| Legacy string | (, ) | [0.0.0, ) | (, 2.0.0)| [0.0.0, 2.0.0) |
| Lower Bound | none | 0.0 | none | 0.0 |
| Upper Bound | none | none | 2.0.0 | 2.0.0 |

## Considerations

### Validation - pack and NuGet.exe scenarios

When using the exact same version of the tooling for all scenarios, all of the validation scenarios are covered by automation.
If customers are using different version of the tooling, it is possible that they run into inconsistencies.
However, their scenarios were not working as expected, and they would've had to work around them in a way that wouldn't be affected by this change.

### Validation - repeatable build customers

Using different versions of the tooling will lead to failure, which is a satisfactory behavior, as using the tooling across all builds is important for repeatability.
Locked mode scenario with `*` would have been broken, and will fail if the old tooling is used, so there will no unexpected results for customers.

### Other considerations

The version range model created contains an inclusive max version property to true.
Why not make * roundtrip to `[*, ]`?
My thought is, let's no complicate things even more. Adding a `]` means that there's an actual max version.
Currently `[1.0.*, ]` normalizes to `[1.0.*, )`. An inclusive max version without providing one makes little sense, because while there is an obvious min version, the max version is pretty much implementation detail.
