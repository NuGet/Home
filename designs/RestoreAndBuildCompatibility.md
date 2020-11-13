
# Improving the restore and build compatibility experience

* Status: In Review
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)
* Issue: [10259](https://github.com/NuGet/Home/issues/10259) Improving the experience when incompatible versions of the restore/build tooling are used

## Problem Background

NuGet as a product has grown its importance in the .NET ecosystem over the years.
What started with NuGet.exe & Visual Studio support has led to a first class experience in **the CLI**, dotnet.exe.

### NuGet packages.config

With packages.config, NuGet was built on top of the build experience, and functions as an add on.
NuGet used concept such as `Reference` to add package dependencies. These references were written in the project file directly, with a relative path to a `known` packages folder.
This meant that you can use NuGet.exe 3.4.4 with VS 2015 & VS 2013 as the build tooling.

The workflow for that usually is:

* NuGet.exe restore - which downloads a defined list of packages to a specific folder.
* build - with your tooling of choice. Said tooling doesn't need to be aware of the fact that NuGet is involved in any way.

### NuGet PackageReference

Since the introduction of project.json and PackageReference (2015 & 2017 respectively), NuGet has become tightly integrated with the build.
Today NuGet's PackageReference is the tooling of choice for *all* .NET Core, now one unified .NET, projects.

With PackageReference projects a restore is now *a must*.
In addition to `NuGet.exe`, you can restore PackageReference based projects with `msbuild /t:restore` and `dotnet.exe restore`.

The `restore` and `build` operations have a contract expressed through 3 files:

* `project.assets.json`
* `projectName.ext.nuget.g.props`
* `projectName.ext.nuget.g.targets`

At build-time these files are loaded and interpreted as necessary.
This means that the NuGet and build tooling version have an implied compatibility matrix.

### Restore, Build and Continuous Integration

When developing in Visual Studio or any other editor, the restore and build steps are integrated and things normally just work.  

On the CI, the story is a little bit different.

#### Tooling options

Starting with VS 2017 and now VS 2019, there 3 different tooling options one can use to run a restore on their CI.

* MSBuild.exe
  * Ships with Visual Studio
  * Supports PackageReference
  * Starting with VS 2019, Update 5, packages.config scenarios in an opt-in fashion through `-p:RestorePackagesConfig=true`.
    * Consider setting `RestorePackagesConfig` to `true` in a [Directory.Build.Props](https://docs.microsoft.com/en-us/visualstudio/msbuild/customize-your-build?view=vs-2019#directorybuildprops-and-directorybuildtargets).

* dotnet.exe
  * Ships with the .NET SDK
    * Bundled in Visual Studio with the Cross Platform .NET Development workload
    * Standalone.
  * Supports PackageReference, .NET SDK based projects only.

* NuGet.exe
  * NuGet.exe is the oldest tool that can be used to restore on CIs.
  * NuGet.exe is *not* bundled with Visual Studio or dotnet.exe, as they both carry their own functionality.
  * NuGet.exe supports packages.config & PackageReference

#### Continious integration considerations

GitHub Actions and Azure Pipelines are the most commonly used (and Microsoft run) automation services.
Usually customers will have a `yaml build file` that specifies the list of steps to run, and the machines with the build tooling are often provided by these services. For example, Azure pipelines provides [Microsoft-hosted agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=yaml), which handle maintenance and upgrade of these agents.
In that maintenance, VS upgrades are one of those included things.

Given all those tooling options, there are a few *common* ways customers build their repos.

1. dotnet.exe
With dotnet.exe, the CI commands would normally look like one of the below options:

    * dotnet.exe restore & dotnet.exe build --no-restore
    * dotnet.exe build (restore is implied)

This is the recommended and foolproof way if you have only projects that are supported by the [`.NET SDK`](https://github.com/dotnet/sdk).
dotnet.exe and its respective SDK are a self-contained build tool. The restore and build contract is 100% understood and there are no compatibility concerns.

2. MSBuild.exe

With MSBuild.exe, the CI commands would normally look like one of the below options:

* MSBuild.exe /t:restore & MSBuild.exe /t:build
* MSBuild.exe /restore /t:build

Using MSBuild.exe to restore and build the repo means that the restore and build contract is 100% understood because the same tooling version is used for both operations.

3. NuGet.exe

NuGet.exe supports restore, but it cannot build, so one still needs to build, usually using MSBuild.exe.
The steps are normally:

* Acquire NuGet.exe
* NuGet.exe restore
* MSBuild.exe /t:build

In packages.config, this usually just works because the build tooling is oblivious to NuGet.
In PackageReference, there's nuance, because now you have a restore and build steps that can use different versions of the tooling--`NuGet.exe` will write assets that may differ from what the MSBuild-embedded tooling expects.

Due to the fact that `NuGet.exe` is acquired standalone, it's considerably more difficult to ensure restore & build compatibility.

Naturally this can lead to 2 potential different problems.

#### Older NuGet tooling, newer build tooling

Say a customer has pinned to a specific NuGet.exe version in their build. When a new version of Visual Studio gets released, the build machines for hosted againsts get automatically update and the customer can now run into a problem *without* any action of their own.

In recent years, NuGet restore has added many capabilities to support .NET Core. From FrameworkReference in 5.3 to support for .NET 5 TFMs in 5.8.
In *most* situations, using an older version of NuGet.exe *will not* cause any problems at build time. 5.8 and .NET SDK 5.0.100 in particular _do_ cause problems.
[NuGet/Home#9756](https://github.com/NuGet/Home/issues/9756) introduces a change that was needed to support .NET 5 tfms and that change in itself required a significant change to how the build tasks interpret the `project.assets.json`.
An example is the following Developer Community [issue](https://developercommunity2.visualstudio.com/t/NuGet-Restore-build-issues---projectass/1190427).

#### Newer NuGet tooling, older build tooling

Say a customer has configured to get latest NuGet in their build tasks. While NuGet.exe and VisualStudio do ship on the same day, the rollout to all build machines is not atomic. The customers could end up in this mismatched situation without an explicit action.

A newer NuGet version *might* generate an assets file that has more/different details than what the build tasks expect.
A recent example is the following Developer Community [issue](https://developercommunity2.visualstudio.com/t/vsbuild-msbuild-task-failing-since-2020-11-10/1249432) which is not 100% understood yet.

In this design, we are trying to improve the general mismatched tooling experience, but also consider alternatives for the particular issues customers are hitting with VS 16.8/NuGet 5.8/ SDK 5.0.100.

## Who are the customers

PackageReference customers using NuGet.exe to restore separately from build tooling.

## Goals

* Improve the experience for mismatched versions of restore/build tooling.

## Non-Goals

* Introducing explicit backwards/forward compatibility. That's a lateral effort.

## Solution Overview

In the 2 particular problems described above the experience when things go wrong is inconsistent. It's not *always* apparent why something goes wrong.
This proposal covers improving that warning/error experience.

### NuGet output versioning

When PackageReference restore is run, NuGet writes out the 3 files mentioned above. 2 of those files have a `version`.

* The `project.assets.json` has a version that has historically been used for schema changes, not tooling compatibility checks. For example, aliases addition involved adding more information to the assets file, but not a schema change so this number was not incremented.
* The `nuget.g.props` contains a `NuGetToolVersion` property.

### Build Tasks warning (SDK)

Given that the implied compatibility exists, the proposal is for the SDK build tasks raise a suppressible warning when the output is not in the expected shape.

* Warn when the restore output is from an older tool than anticipated.
* Warn when the restore output is from a newer tool than anticipated.

There are 3 technical options and each might have a different effect on the frequency in which this warning is raised.

#### Option 1 - Use assets file version

NuGet increments the `project.assets.json` version every time there's a functional change in behavior. The build tasks in the SDK are built with a specific version of NuGet, and the SDK could raise a warning when the `project.assets.json` version is not the one it expects.

Cons:

* Thas version that has historically been used for schema changes, not tooling compatibility checks. For example, aliases addition involved adding more information to the assets file, but not a schema change so this number was not incremented.

Pros:

* We would only increment this when a functional restore change is made.

Alternatively we could add a new version property, but that's probably unnecessary.

#### Option 2 - Use NuGet tool version

The nuget.g.props write out a `NuGetToolVersion` property which contains the version of the NuGet tooling that generated it.

Cons:

* This has the potential to be too noisy. Just because the version change that doesn't mean it's not compatible.

Pros:

* The flip side is that we prefer that customers use consistent versions of the tooling, so going this direction has the added benefit of consolidating tooling for our customers.

#### Option 3 - Define a new compatibility version

Pros:

* We would only increment this when a functional restore change is made.

Cons:

* Both NuGet and SDK tooling require changes to add the initial warning.

## Test Strategy

These changes require integration test slightly different than the ones run today in both SDK and NuGet repo.
The SDK is already considering adding tests for the cross version scenarios in the following [PR](https://github.com/dotnet/sdk/pull/14517).

## Future Work

None

## Open Questions

* Should the warnings/errors that the SDK raises could be context aware?
For example, if the versions are missmatched, but the SDK is still able to find the assets, it can do a best effort and raise a warning. If the assets cannot be found, fail with an error *clearly* indicating the problem is the mismatched tooling versions.

## Considerations

* Should NuGet restore output always be backward/forward compatible?

No. The build tooling shipped today, which NuGet is a part of, is self contained. NuGet.exe customers are the only ones likely to run this mismatched scenario and we have done work to help them migrate, through MSBuild.exe restore and packages.config support for restore.
Furthermore this increases the testing and support matrix significantly. It is not something we have promised customers.

### References

* NuGet restore build [issues](https://developercommunity2.visualstudio.com/t/NuGet-Restore-build-issues---projectass/1190427)
* Making SDK tooling compatible with assets file generated by 5.7, [PR](https://github.com/dotnet/sdk/pull/14517).
* Forward compatibility case [issue](https://developercommunity2.visualstudio.com/t/vsbuild-msbuild-task-failing-since-2020-11-10/1249432).
* [GitHub Actions](https://docs.github.com/en/free-pro-team@latest/actions)
* Note that the complete implementation of the aliases feature in [NuGet/Home#5154](https://github.com/nuget/home/issues/5154) will definitely cause a problem if mismatched tooling is used. While we'd like the scenarios to work as often as possible, certain features do require big changes.
