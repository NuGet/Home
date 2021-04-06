# Duplicate NuGet item error handling

- Author Name: [nkolev92](https://github.com/nkolev92)
- Start Date 2021-04-01
- GitHub Issue - Duplicate PackageReference [9864](https://github.com/NuGet/Home/issues/9864), CPVM duplicate erroring [9467](https://github.com/NuGet/Home/issues/9467)
- GitHub PR [3928](https://github.com/NuGet/NuGet.Client/pull/3928)

## Summary

It's uncommon that PackageReference (or PackageVersion, PackageDownload etc) items are included through secondary files and/or are manually edited, which sometimes leads to multiple items with the same name being included.
In some scenarios, this can cause restore inconsistencies. We will to detect these scenarios and raise a warning. NoWarn and TreatWarningsAsErrors are also respected.

## Motivation

Take the following project:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net5.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="NuGet.Protocol" Version="5.5.0" />
    <PackageReference Include="NuGet.Protocol" Version="5.6.0" />
  </ItemGroup>

</Project>
```

Note the duplicate PackageReference declaration. Digging further reveals that different project types and different tools handle it differently.

See the below table for details

| Restore Flavor | PackageReference declaration |
| - | - |
| Commandline restore (all) | First |
| Static graph restore (all) | First |
| VS - SDK based projects | Last |
| VS - Legacy PR projects | First |

This leads to issues as the ones described in [arcade/issues#5550](https://github.com/dotnet/arcade/issues/5550).

The inconsistencies are likely and common in SDK based PackageReference projects. As such addressing those scenarios is the primary goal.

## Explanation

### Functional explanation

For each of the NuGet package declaration items, PackageReference, PackageDownload & PackageVersion, a coded warning will be raised when duplicate items are included.
All these warnings will respect project level NoWarn(no package item level no warn can be respected because of the deduplication requirement) and TreatWarningsAsErrors.

Due to technical limitations, the warning will be best effort, and only added where possible.
The below table covers the scenarios targetted.

| PackageReference project stye | NuGet Client tool | Warnings Raised |
| - | - | - |
| SDK | MSBuild.exe/dotnet.exe | Yes |
| Legacy csproj | MSBuild.exe/dotnet.exe | Yes |
| SDK | Visual Studio | Yes |
| Legacy csproj | Visual Studio | No |
| SDK | NuGet.exe | No |
| Legacy csproj | NuGet.exe | No |

The warnings will be coded as following:

| Log Code | Item type |
|----------|-----------|
| NU1504 | PackageReference |
| NU1505 | PackageDownload |
| NU1506 | PackageVersion |

### Technical explanation

- In dotnet.exe, msbuild.exe restore scenarios, NuGet reads the items by itself by calling the `Collect{ItemName}s` targets. Given that NuGet has full control over the project interpretation, the items can be deduplicated in these respective targets. The warnings and errors will be respected there as well.

- In Visual Studio, the project systems are the ones that collect the items for NuGet. The legacy project system collects all the items without the conditions. The new project system calls the `Collect{ItemName}s` targets.

- In nuget.exe scenarios, NuGet uses the same logic as the dotnet.exe/msbuild.exe generation. The one difference is that NuGet.exe shells out to an msbuild process for reading and then does the restore by itself.
The contract between these 2 is the dg spec file, which effectively contains *all* inputs necessary for a restore.

Given the combinations of tooling and project style, we have 6 scenarios of interest.

1. SDK + MSBuild.exe/dotnet.exe

NuGet completely controls the reading of the items. By adding the warning in the collector targets, the warnings can be raised.
When the warning is elevated to an error, the error scenario is fail fast, so restore *will not* run. This is unusual and different from the other input errors.

1. SDK + Visual studio

The project-system calls the `Collect{ItemName}s` targets. These warnings will be raised in this target.
For design time purposes, we respect the `ContinueOnError` property.
When the warning is elevated to an error, no items for that target are nominated.
This can lead to an awkward scenario where many errors appear in the user's error list.

It is possible that restore succeeds in this case, despite the collect target erroring out. This is another tecnhical limitation.

1. SDK + NuGet.exe

NuGet.exe shells out to MSBuild to generate the restore graph. The warnings from the targets are swallowed in this scenario. Due to the support for TreatWarningsAsErrors, to prevent silent failures, NuGet.exe restore will not raise any warnings/errors.

1. Legacy csproj + MSBuild.exe/dotnet.exe

NuGet completely controls the reading of the items. By adding the warning in the collector targets, the warnings can be raised.
When the warning is elevated to an error, the error scenario is fail fast, so restore *will not* run. This is unusual and different from the other input errors.

1. Legacy csproj + Visual studio

The legacy project system does not call the `Collect{ItemName}s` targets. As such, raising a warning without an API change is difficult. There are arguably better designs that'd work for both legacy & CPS based PackageReference but the return of investment is not super high.

1. Legacy csproj + NuGet.exe

NuGet.exe shells out to MSBuild to generate the restore graph. The warnings from the targets are swallowed in this scenario. Due to the support for TreatWarningsAsErrors, to prevent silent failures, NuGet.exe restore will not raise any warnings/errors.

## Drawbacks

This is an imperfect, best effort solution. There are *many* caveats.

- NuGet.exe will not be able to raise warnings.
- Legacy csproj projects will not raise warnings/errors in Visual Studio.
- SDK based projects in Visual Studio do not nominate that item when the warning has been elevated to an error, leading to a potentially challenging experience.
- SDK based projects in Visual Studio that have errors due to duplicate items may succeed at restore or even build time, thus creating a false positive build.

## Rationale and alternatives

- Deduplicate silently. We can take a similar approach and deduplicate silently. This will ensure consistent behavior, but it may cause some unexpected behavior.

## Prior Art

- N/A

## Unresolved Questions

- Can the project-system nominate even when an error is raised? This could lead to fewer errors in the error list making it very apparent what the problem is.

## Future Possibilities

- Raising the warnings in NuGet.exe. This technically very challenging, but not impossible.
