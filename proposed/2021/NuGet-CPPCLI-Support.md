# NuGet C++/CLI support

* Status: In Review
* Author(s): [Nikolche](https://github.com/nkolev92)
* Issue: [8195](https://github.com/NuGet/Home/issues/8195) and [10194](https://github.com/NuGet/Home/issues/10194) NuGet support for C++/CLI projects.

## Problem Background

C++/CLI is a project type that allows C++ programs to use .NET classes. This effort captures the NuGet side of enabling PackageReference for .NET Core C++\CLI projects.
There are multiple components involved in this work:

* NuGet
* project-system
* MSBuild & SDK
* C++

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

## Who are the customers

Customers using .NET Core C++/CLI projects.

## Goals

* Cooperate with the respective partner team to enable PackageReference support for C++/CLI projects on the commandline and in Visual Studio.
  * C++/CLI binaries are managed binaries not native. They can consume native code, but they themselves are managed.
  * Ensure NuGet is interpreting the correct framework, to fullfill the primary goal of enabling the consumption of both `managed` packages `native` packages.

## Non-Goals

* PackageReference support for .NET Framework C++/CLI projects.
* packages.config support for C++/CLI projects.
* PackageReference support for native C++ projects.

## Solution Overview

### What is PackageReference support

The PackageReference integration as a project style involves several scenarios that are not immediately obvious for a packages.config user.
Supporting PackageReference includes the following:

* Installation of NuGet packages most compatible asset selection with a given pivot framework, such as .NET 5.0.
* Allowing redistribution of a PackageReference project through `pack`. `pack` should be able to create a NuGet package that can later be used by a different project.
* PackageReference transitivity; Given a project, Project1, that references a package, `PackageA`, that is compatible with said project, any project that references `Project1` should be able to restore `PackageA` as well.
* [ProjectReference protocol](https://github.com/dotnet/msbuild/blob/main/documentation/ProjectReference-Protocol.md). The framework to framework compatibility is owned by NuGet, so as such when 2 projects have different frameworks, NuGet participates in this compatibility check.

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

| Project type | TargetFrameworkIdentifier | TargetPlatformIdentifier | CLRSupport | Effective NuGet framework | Notes |
|--------------|---------------------------|--------------------------|------------|---------------------------|-------|
| Native C++ | .NETFramework,Version=v4.0 | Windows,Version=10.0.19041.0 | false | native | NuGet will continue special casing vcxproj. |
| C++ UWP App | | UAP,Version=10.0.18362.0 | false | native | NuGet will continue special casing vcxproj. |
| CLR C++ | .NETFramework,Version=v4.7.2 | Windows,Version=7.0 | true | ??? | This project has .NET Framework CLR support. This is not a focus scenario |
| Core CLR C++ | .NETCoreApp,Version=v5.0 | Windows,Version=10.0.19041.0 | NetCore | ??? | Dual compatibility. Supports everything that net5.0-windows support & everything native supports |

Worth noting that, `native` framework is not compatible with anything but `native` and that will remain.
From C++/SDK perspective, net5.0-windows projects will be supported. NuGet would normally not special case which .NET target frameworks are supported.

The downside of this proposal is that NuGet does not have a framework that's only supported in projects. Given that this is not a real `target`, it is counter to what NuGet frameworks are supposed to represent.

### Scenarios

For the purposes of *all* scenarios, `ManagedPackage` represents a package targeting `net5.0` and `NativePackage` represents a native NuGet package.

1. C++/CLI project referencing both `ManagedPackage` and `NativePackage`.

```cli
C++/CLI project -> ManagedPackage 1.0.0
                -> NativePackage 1.0.0
```

Expected:

* Assets from both packages are succesfully selected and included in the build.

Open Questions:

* Can this project be packed? How does the package content and it's nuspec look like in this scenario?

1. C# exe, referencing a C++/CLI project that references a `NativePackage`.

```cli
C# project (net5.0-windows) -> C++/CLI project -> NativePackage 1.0.0
```

Expected:

Open Questions:

* Does C# project get `NativePackage` transitively?
* Can the C# project be packed?

1. A c++ exe, referencing C++/CLI dll (with PackageReference to Microsoft.Windows.Compatibility), referencing c#dll

```cli
C++ project  -> C++/CLI project -> ManagedPackage 1.0.0
```

Expected:

Open Questions:

* Is there a compatibilty check happening here?
* Does ManagedPackage 1.0.0 need to be copied to the C++ output?

## Test Strategy

## Future Work

## Open Questions

* Refer to Open Questions in the [scenario](#scenarios) section.

## Considerations

* AssetTargetFallback

NuGet has a fallback compatibility mode.
For example: .NET Core projects have a fallback to .NET Framework with a warning. This is also callled `Asset Target Fallback`.
If a package supports .NET Core or .NET Standard, it's fully compatible with a .NET Core project. Otherwise if a package has .NET Framework assets, the package is installed, but with a *warning*. This fallback model is not appropriate for the C++/CLI scenario as the warning being raised is inappropriate.

The `Asset Target Fallback` implementation currently suffers from a bug where the dependencies are not pulled in correctly, see [5957](https://github.com/NuGet/Home/issues/5957).

This would require project type changes. The project type would specify which target framework to fall back to. This likely requires fixing [5957](https://github.com/NuGet/Home/issues/5957).

### References

* [Asset Target Fallback](https://github.com/NuGet/Home/wiki/Enable-.NET-Core-2.0-projects-to-work-with-.NET-Framework-4.6.1-compatible-packages)