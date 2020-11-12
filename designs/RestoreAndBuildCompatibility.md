
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

#### Old NuGet tooling, newer build tooling - NuGet forward compatibility

In recent years, NuGet restore has added many capabilities to support .NET Core. From FrameworkReference in 5.3 to support for .NET 5 TFMs in 5.8.
In *most* situations, using an older version of NuGet.exe *will not* cause any problems at build time. 5.8 and .NET 5 in particular are not such versions.
[NuGet/Home#9756](https://github.com/NuGet/Home/issues/9756) introduces a change that was needed to support .NET 5 tfms and that change in itself required a significant change to how the build tasks interpret the `project.assets.json`.
An example is the following Developer Community [issue](https://developercommunity2.visualstudio.com/t/NuGet-Restore-build-issues---projectass/1190427).

#### New NuGet tooling, old build tooling - NuGet backward compatibility

A newer NuGet version *might* generate an assets file that has more/different details than what the build tasks expect.
A recent example is the following Developer Community [issue](https://developercommunity2.visualstudio.com/t/vsbuild-msbuild-task-failing-since-2020-11-10/1249432) which is not 100% understood yet.

In this design, we are trying to improve the general mismatched tooling experience, but also consider alternatives for the particular issues customers are hitting with VS 16.8/NuGet 5.8/ SDK 5.0.100.

## Who are the customers

PackageReference customers

## Goals

* Improve the experience for mismatched versions of restore/build tooling.

## Non-Goals

## Solution Overview

In the 2 particular problems described above the experience when things go wrong is inconsistent. It's not *always* apparent why something goes wrong.
This proposal covers improving that warning/error experience.

### NuGet output versioning

When PackageReference restore is run, NuGet writes out the 3 files mentioned above. 2 of those files have a `version`.

* The `project.assets.json` has a version that has historically been used for `reading`, not tooling compatibility checks.
* The `nuget.g.props` contains a `NuGetToolVersion` property.

### Build Tasks warning (SDK)

Given that the implied compatibility exists, the proposal is for the SDK build tasks raise a suppressible warning when the output is not in the expected shape.

* Warn when the restore output is from an older tool than anticipated.
* Warn when the restore output is from a newer tool than anticipated.

There are 2 technical options and each might have a different effect on the frequency in which this warning is raised.

#### Option 1 - Use assets file version

NuGet increments the `project.assets.json` version every time there's a functional change in behavior. The build tasks in the SDK are built with a specific version of NuGet, and the SDK could raise a warning when the `project.assets.json` version is not the one it expects.

Cons:

* This version was not used with tool compatibility in mind, but rather  While unlikely, it's possible that other tooling depends on it.

Pro:

* We would only increment this when a functional restore change is made.

Alternatively we could add a new version property, but that's probably unnecessary.

#### Option 2 - Use NuGet tool version

The nuget.g.props write out a `NuGetToolVersion` property which contains the version of the NuGet tooling that generated it.

Cons:

* This has the potential to be too noisy. Just because the version change that doesn't mean it's not compatible.

Pros:

* The flip side is that we prefer that customers use consistent versions of the tooling, so going this direction has the added benefit of consolidating tooling for our customers.

## Test Strategy

These changes require integration test slightly different than the ones run today in both SDK and NuGet repo.
The SDK is already considering adding tests for the cross version scenarios in the following [PR](https://github.com/dotnet/sdk/pull/14517).

## Future Work

None

## Open Questions

## Considerations

* Should NuGet restore output always be backward/forward compatible?

No. The build tooling shipped today, which NuGet is a part of, is self contained. NuGet.exe customers are the only ones likely to run this mismatched scenario and we have done work to help them migrate, through MSBuild.exe restore and packages.config support for restore.
Furthemore this increases the testing and support matrix significantly. It is not something we have promised customers.

### References

* NuGet restore build [issues](https://developercommunity2.visualstudio.com/t/NuGet-Restore-build-issues---projectass/1190427)
* Making SDK tooling compatible with assets file generated by 5.7, [PR](https://github.com/dotnet/sdk/pull/14517).
* Forward compatibility case [issue](https://developercommunity2.visualstudio.com/t/vsbuild-msbuild-task-failing-since-2020-11-10/1249432) 