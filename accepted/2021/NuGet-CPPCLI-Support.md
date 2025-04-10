# NuGet C++/CLI support

- Author Name [Nikolche Kolev](https://github.com/nkolev92)
- Start Date 2021-04-01
- GitHub Issue [8195](https://github.com/NuGet/Home/issues/8195) and [10194](https://github.com/NuGet/Home/issues/10194)
- Status: Implemented

## Summary

## Goals

* Cooperate with the respective partner team to enable PackageReference support for C++/CLI projects on the commandline and in Visual Studio.
  * C++/CLI binaries are managed binaries not native. They can consume native code, but they themselves are managed.
  * Ensure NuGet is interpreting the correct framework, to fullfill the primary goal of enabling the consumption of both `managed` packages `native` packages.

## Non-Goals

* PackageReference support for .NET Framework C++/CLI projects.
* packages.config support for C++/CLI projects.
* PackageReference support for native C++ projects.


## Motivation

C++/CLI is a project type that allows C++ programs to use .NET classes. This effort captures the NuGet side of enabling PackageReference for .NET Core C++\CLI projects.
There are multiple components involved in this work:

- NuGet
- project-system
- MSBuild & SDK
- C++

Currently NuGet special cases C++ projects by looking at the extension and treating every vcxproj as packages.config `native`.
The packages.config/PackageReference support story is owned by the C++ team and as of VS 16.8, all C++ projects are `packages.config`.

When discussing the changes here is a summary from a member on the C++ team.

```md
TargetFramework*/TargetPlatform* properties for C++/CLI are pretty much the same as for c#, so they should be used in nuget instead of just checking for .vcxproj extension. Also, C++/CLI can use/reference not only managed, but native code as well, so “native” packages should be allowed together with the appropriate managed ones.
You can use the following properties to distinguish vc projects:
TargetPlatformIdentifier/Version/Moniker should be defined for all vc projects.
CLRSupport
False or empty – native project
NetCore – C++/CLI .NET Core project
Everything else (true, safe, etc)  - C++/CLI .NET Framework project
TargetFramework is only defined for C++/CLI .NET Core projects.
TargetFrameworkIdentifier/Version/Moniker properties are defined for C++/CLI .NET Framework projects. Note, that they are also confusingly defined for pure native ones too (in msbuild common targets, at least, they used to be), so you need to check other properties first (i.e. TargetPlatformIdentifier and CLRSupport). You can also use project capabilities: “native” vs “managed”
```

C++/CLI projects produce managed binaries (which can be used in other managed projects) and (if there are native exports) native import libraries (which can be used in native or c++/CLI projects).

## Explanation

### Functional explanation

Installing managed packages in C++/CLI .NET Core projects is currently not possible.
The work here is largely technical, and it involves enabling that functionality through coordination of C++, .NET Core SDK, project-system & NuGet.

### Technical explanation

### What is PackageReference support

The PackageReference integration as a project style involves several scenarios that are not immediately obvious for a packages.config user.
Supporting PackageReference includes the following:

- Installation of NuGet packages most compatible asset selection with a given pivot framework, such as .NET 5.0.
- Allowing redistribution of a PackageReference project through `pack`. `pack` should be able to create a NuGet package that can later be used by a different project.
- PackageReference transitivity; Given a project, Project1, that references a package, `PackageA`, that is compatible with said project, any project that references `Project1` should be able to restore `PackageA` as well.
- [ProjectReference protocol](https://github.com/dotnet/msbuild/blob/main/documentation/ProjectReference-Protocol.md). The framework to framework compatibility is owned by NuGet, so as such when 2 projects have different frameworks, NuGet participates in this compatibility check. 

All of this boils down to the fact that, given a project, NuGet needs to interpret an effective target framework, and then use that target framework in *all* of the above scenarios.

### C++/CLI target framework inference

In managed projects, NuGet interprets the effective framework by looking at `TargetFrameworkMoniker`, `TargetPlatformMoniker` and in UWP cases, `TargetPlatformMinVersion`.
C++\CLI projects have an additional property `CLRSupport`.

Currently the steps for NuGet framework inference for project types still actively supported are as follows:

1. Does the project file extension end with `.vcxproj`? Then `native0.0`
1. Does `TargetPlatformMoniker` start with `UAP`? Then the framework is `UAP{version}`, where `TargetPlatformMinVersion` is preferred over `TargetPlatformVersion`.
1. `TargetPlatformMoniker`, unless the framework is `.NETCoreApp` with version greater than 5.0, then it's the combination of `TargetFrameworkMoniker` and `TargetPlatformMoniker`.

C++/CLI projects are supposed to support installing both managed and native packages. This would require some amendments to NuGet's framework model.

When a package contains `managed` and `native` assets, the managed ones will be preferred.

To understand the proposed changes, here's a mapping of all `C++` project types and the property value for the appropriate ones.

| Project type | TargetFrameworkMoniker | TargetPlatformMoniker | CLRSupport | Effective NuGet framework | Notes |
|--------------|---------------------------|--------------------------|------------|---------------------------|-------|
| Native C++ | .NETFramework,Version=v4.0 | Windows,Version=10.0.19041.0 | false | native | NuGet will continue special casing vcxproj. |
| C++ UWP App | | UAP,Version=10.0.18362.0 | false | native | NuGet will continue special casing vcxproj. |
| CLR C++ | .NETFramework,Version=v4.7.2 | Windows,Version=7.0 | true | ??? | This project has .NET Framework CLR support. This is not a focus scenario |
| Core CLR C++ | .NETCoreApp,Version=v5.0 | | NetCore | ??? | Dual compatibility. Supports everything that net5.0 support & everything native supports |
| Core CLR C++ | .NETCoreApp,Version=v5.0 | Windows,Version=7.0 | NetCore | ??? | Dual compatibility. Supports everything that net5.0 support & everything native supports. Note that for CPP/CLI projects NuGet *ignores* the TargetPlatformMoniker. In particular, `CLRSupport` being `NetCore` implies that the `TargetPlatformMoniker` is not considered. |

Worth noting that, `native` framework is not compatible with anything but `native` and that will remain.
From C++/SDK perspective, net5.0-windows projects will be supported. NuGet would normally not special case which .NET target frameworks are supported.

### Project to project and project to package scenarios

C++/CLI projects don't have the same scenarios as purely managed project types. As such the important scenarios are limited.

- .NET Core C++/CLI projects can only build libraries and not exes.
- .NET Core C++/CLI projects are not packable by the standard `pack` target. This will be disabled in the projects, but we can consider disabling it in the NuGet.targets as well.

```cli
C# project -> C++/CLI project -> ManagedPackage 1.0.0
```

- Project to Project transitivity applies and ManagedPackage would be consumed in the C# project
- The C++/CLI project is not packable, but the C# project is. The burden in on the package author to ensure all the correct dependencies are carried on.

```cli
C# project -> C++/CLI project -> NativePackage 1.0.0
```

- Given that all the projects are PackageReference enabled, NuGet will apply the package transitively.
  - There are compatibility concerns here, but given that most native packages only have a build folder, it is likely they will install correctly in the managed project.
  - If it does fail, the guidance is that `PrivateAssets=all` is specified on the NativePackage's PackageReference.

```cli
- C++ project -> C++/CLI -> NativePackage 1.0.0
```

- C++/CLI projects can consume native packages.
- A C++ project is packages.config, so the project reference protocol does not apply.
- This is not expected to be a super common scenario, you'd likely have native projects only.

```cli
C++ project -> C++/CLI project -> ManagedPackage 1.0.0
```

- Given that the C++ project is not PackageReference compatibility, the transitivity concerns do not apply here.
- At this point, the burden is on the consumer to ensure that the project author works.
- This is not expected to be a common scenario.

## Drawbacks

<!-- Why should we not do this? -->

- The limitations of the proposal is that NuGet does not have a framework that's only supported in projects. Given that this is not a real `target`, it is counter to what NuGet frameworks are.
- This scenario is not extremely common, and the distribution story is not coherent. As such the project to project scenarios have a lot of caveats.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

### AssetTargetFallback

NuGet has a fallback compatibility mode.
For example: .NET Core projects have a fallback to .NET Framework with a warning. This is also callled `Asset Target Fallback`.
If a package supports .NET Core or .NET Standard, it's fully compatible with a .NET Core project. Otherwise if a package has .NET Framework assets, the package is installed, but with a *warning*. This fallback model is not appropriate for the C++/CLI scenario as the warning being raised is inappropriate.

The `Asset Target Fallback` implementation currently suffers from a bug where the dependencies are not pulled in correctly, see [5957](https://github.com/NuGet/Home/issues/5957).

This would require project type changes. The project type would specify which target framework to fall back to. This likely requires fixing [5957](https://github.com/NuGet/Home/issues/5957).

[Asset Target Fallback design document](https://github.com/NuGet/Home/wiki/Enable-.NET-Core-2.0-projects-to-work-with-.NET-Framework-4.6.1-compatible-packages)
[AssetTargetFallback docs](https://docs.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files#assettargetfallback)

## Prior Art

- [AssetTargetFallback](#assettargetfallback) represents a similar functionality.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

- Currently C++/CLI projects can only build against .NET Core assemblies, and not .NET Standard ones. This is *not* a scenario NuGet supports right now.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
