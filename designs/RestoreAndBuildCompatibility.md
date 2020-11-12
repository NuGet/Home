
# Spec Name

* Status: In Review
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)
* Issue: [1](https://github.com/NuGet/Home/issues/1) Issue Title

## Problem Background

### NuGet packages.config

NuGet as a product has grown it's importance in the .NET ecosystem over the years.
What started with nuget.exe & Visual Studio support has led to a first class experience in **the CLI**, dotnet.exe.

With packages.config, NuGet was built on top of the build experience, NuGet functioned as an add on.
NuGet used concept such as `Reference` to add package dependencies. These references were written in the project file directly, with a relative path to a `known` packages folder.
This meant that you can use NuGet.exe 3.4.4 with VS 2015 & VS 2013 as the build tooling.

On the CI, the workflow usually is:

* nuget.exe restore - which downloads a defined list of packages to a specific folder.
* build - with your tooling of choice. Said tooling doesn't need to be aware of the fact that NuGet is involved in any way.

### NuGet PackageReference

Since the introduction of project.json and PackageReference (2015 & 2017 respectively), NuGet has become tightly integrated with the build.
Today NuGet's PackageReference is the tooling of choice for *all* .NET Core, now one unified .NET, projects.

With PackageReference projects a restore is now *a must*.
In addition to `nuget.exe`, you can restore PackageReference based projects with `msbuild /t:restore` and `dotnet.exe restore`.

The `restore` and `build` operations have a contract expressed through 3 files:

* `project.assets.json`
* `projectName.ext.nuget.g.props`
* `projectName.ext.nuget.g.targets`

At build-time these files are loaded and interpreted as necessary.
This now meant that the NuGet version and build tooling version have an implied compatibility matrix.

### CI experience and compatibility matrices 

The additional tooling options, the combination of project types in one repository now means that there are many ways people run the restore/build gestures on CI.

1. dotnet.exe
With dotnet.exe, the CI commands would normally look like one of the below options: 

    * dotnet.exe restore & dotnet.exe build --no-restore
    * dotnet.exe build (restore is implied)

This is the recommended and full proof way if you have only projects that are supported by the [`.NET SDK`](https://github.com/dotnet/sdk).
packages.config projects *are not* supported with dotnet.exe.

dotnet.exe and it's respective SDK are a self-contained build tool. The restore and build contract is 100% understood and there are no compatibility concerns.

2. MSBuild.exe

With MSBuild.exe, the CI commands would normally look like one of the below options:

* MSBuild.exe /t:restore & MSBuild.exe /t:build
* MSBuild.exe /restore /t:build

MSBuild.exe has had PackageReference restore support since VS 2017. Starting with VS 2019, update 5, MSBuild now has project specific packages.config support.

Using MSBuild.exe to restore and build the repo means that the restore and build contract is 100% understood.

3. NuGet.exe

NuGet.exe is the oldest tool that can be used to restore on CIs.
It supports PackageReference and packages.config, but obviously it cannot build, so one still needs to build, usually using MSBuild.exe.
So the steps are usually:

* NuGet.exe restore
* MSBuild.exe /t:build

In packages.config, this usually just works because of packages.config's architecture.
In PackageReference, there's a nuance, because now you have a restore and build steps that are from potential different versions of the tooling.  

Naturally this leads to 2 potential different problems.

#### Old NuGet tooling, newer build tooling

In recent years, NuGet restore has added many capabilities to support .NET Core. From FrameworkReference in 5.3 to support for .NET 5 TFMs in 5.8.
In *most* situations, using an older version of NuGet.exe *will not* cause any problems at build time. 5.8 and .NET 5 in particular are not such versions.
An example is the following Developer Community [issue](https://developercommunity2.visualstudio.com/t/NuGet-Restore-build-issues---projectass/1190427).

#### New NuGet tooling, old build tooling

## Who are the customers

Customers affected by this change.

## Goals

Specifically call out the goals for this proposed design.

## Non-Goals

Call out things that are not in consideration for this design. 

## Solution Overview

Describe the proposed solution in as much detail as you deem necessary.

## Test Strategy

Other than Unit Tests, which automated and manual integration, component, and end-to-end tests will be needed to validate the implementation? Is a special roll-out strategy (including kill-switch, opt-in flag, etc.) needed?

## Future Work

Declare any future work if applicable.

## Open Questions

Any open questions not specifically called out in the design.

## Considerations

Any other solutions or approaches considered? 
The rejected designs are often just as important as the proposed ones!

### References

* NuGet restore build [issues](https://developercommunity2.visualstudio.com/t/NuGet-Restore-build-issues---projectass/1190427)
