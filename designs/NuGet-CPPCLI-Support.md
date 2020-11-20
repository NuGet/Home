# NuGet C++/CLI support

* Status: In Review
* Author(s): [Nikolche](https://github.com/nkolev92)
* Issue: [8195](https://github.com/NuGet/Home/issues/8195) and [10194](https://github.com/NuGet/Home/issues/10194) NuGet support for C++/CLI projects.

## Problem Background

C++/CLI is a project type that allows C++ programs to use .NET classes.
This effort tackles the NuGet side of allowing package installation of NuGet packages into these projects to take place.

This effort requires coordination from NuGet, project-system and C++.
Some of the NuGet side effort has already been done by the project-system team.

Currently NuGet special cases C++ projects by looking at the extension and treating every vcxproj as packages.config `native`.

The packages.config/PackageReference support story is owned by the C++ team and as of VS 16.8, all C++ projects are `packages.config`.

This investigation is done in cooperation with the effort to add PackageReference support for C++/CLI scenarios, primarily targeting .Net Core.

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

## Who are the customers

Customers using C++/CLI projects.

## Goals

Support the C++ team as necessary to provide NuGet PackageReference support for C++/CLI projects.

At this point focused to:

* Ensure NuGet is interpreting the correct framework.

## Non-Goals

* packages.config support for C++/CLI projects. Focus is on .NET Core scenarios right now.

## Solution Overview

In managed projects, NuGet interprets the effective framework by looking at `TargetFrameworkMoniker`, `TargetPlatformMoniker` and in UWP cases, `TargetPlatformMinVersion`.

C++ projects have an additional property CLRSupport that's set for C++ projects.

Currently the steps for NuGet framework inference for project types still actively supported are as follows:

1. Does the project file extension end with `.vcxproj`? Then `native0.0`
1. Does `TargetPlatformMoniker` start with `UAP`? Then the framework is `UAP{version}`, where `TargetPlatformMinVersion` is preferred over `TargetPlatformVersion`.
1. `TargetPlatformMoniker`, unless the framework is `.NETCoreApp` with version greater than 5.0, then it's the combination of `TargetFrameworkMoniker` and `TargetPlatformMoniker`.

To understand the proposed changes, here's a mapping of all `C++` project types and the property value for the appropriate ones.

| Project type | TargetFrameworkMoniker | TargetPlatformMoniker | CLRSupport | Effective NuGet framework | Notes | Open questions |

|--------------|---------------------------|--------------------|------------|---------------------------|-------|----------------|
| Native C++ | .NETFramework,Version=v4.0 | Windows,Version=10.0.19041.0 | false | native | NuGet will continue special casing vcxproj. | |
| C++ UWP App | | UAP,Version=10.0.18362.0 | false | native | NuGet will continue special casing vcxproj. | |
| CLR C++ | .NETFramework,Version=v4.7.2 | Windows,Version=10.0.19041.0 | true | ??? | This project has .NET Framework CLR support | Are these projects expected to be PackageReference or packages.config? What's the effective target framework |
| Core CLR C++ | .NETCoreApp,Version=v5.0 | Windows,Version=10.0.19041.0 | NetCore | ??? | What's the effective framework? Is it `net5.0-windows`? |

In the background, it is said that C++/CLI projects are supposed to support installing both managed and native packages. This would require some amendments to NuGet's framework model.

`native` framework is not compatible with anything but `native` and that will remain.
NuGet has a fallback compatibility mode as well.
For example: .NET Core projects have a fallback to .NET Framework with a warning. This is also callled `Asset Target Fallback`.
If a package supports .NET Core or .NET Standard, it's fully compatible with a .NET Core project. Otherwise if a package has .NET Framework assets, the package is installed, but with a *warning*.

The `Asset Target Fallback` implementation currently suffers from a bug where the dependencies are not pulled in correctly, see [5957](https://github.com/NuGet/Home/issues/5957).

Asset Target Fallback would require project type changes. The project type would specify which target framework to fall back to. This likely requires fixing [5957](https://github.com/NuGet/Home/issues/5957).
Note that this would *generate* a warning when managed packages are used.

The likely solution is to introduce a `dedicated dual compatibility` framework

Similar to how `.NET Core` implements `.NET Standard` and supports `.NET Core` as a same family framework, we can add a framework type that's only allowed in projects, and not packages. This framework could define it's compatible as both `native` and `managed`.

The downside here is that NuGet does not have a framework that's only supported in projects. Given that this is not a real `target`, it is counter to what NuGet frameworks are supposed to represent.

An open question is whether packing of these projects is supported. 

## Test Strategy

TBD

## Future Work

## Open Questions

* Is PackageReference support being added for .NET Framework C++/CLI as well? Or only .NET Core C++/CLI projects?

* When a package contains both `native` and `managed` assets, which ones are preferred?

* Which frameworks are going to be supported with .NET Core C++/CLI? Will net5.0-windows be supported eventually? Asset Target Fallback becomes tricky if so.

* Can these projets be packaged? Are they distributing native or managed assets? Both?

## Considerations

### References

* [Asset Target Fallback](https://github.com/NuGet/Home/wiki/Enable-.NET-Core-2.0-projects-to-work-with-.NET-Framework-4.6.1-compatible-packages)
