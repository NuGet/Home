# Support for handling multiple equivalent framework

- [Nikolche Kolev](https://github.com/nkolev92)
- Start Date: (2022-08-18)
- GitHub Issue ([5154](https://github.com/NuGet/Home/issues/5154)) - Treat Target Framework as Aliases

## Summary

.NET SDK projects are capable of multi targeting based on a target framework where you can have different dependencies for each framework.
In some cases, it is convenient to multi target based on different pivots such as target appplication version or maybe the specific runtime, as packages can contain runtime assets.
This proposals covers the steps that need to be taken to enable that capability.

## Motivation

Allowing the same framework to be using multiple times in restore would allow customers to use the same project to generate runtime specific assemblies based on the same target framework.
It would also allow scenarios such as different builds for VSIXes targeting different Visual Studio versions.

## Explanation

### Functional explanation

#### TargetFramework values are aliases today

NuGet currently treats `TargetFramework` as aliases. For example, the following is a valid project.

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>banana</TargetFramework>
  </PropertyGroup>

  <PropertyGroup Condition=" '$(TargetFramework)' == 'banana' ">
    <TargetFrameworkIdentifier>.NETFramework</TargetFrameworkIdentifier>
    <TargetFrameworkVersion>v4.7.2</TargetFrameworkVersion>
    <TargetFrameworkMoniker>.NETFramework,Version=v4.7.2</TargetFrameworkMoniker>
  </PropertyGroup>

</Project>
```

```console
C:\Code\Temp\Aliases [main]> dotnet restore
  Determining projects to restore...
  Restored C:\Code\Temp\Aliases\Aliases.csproj (in 47 ms).

C:\Code\Temp\Aliases [main]> dotnet build --framework banana
MSBuild version 17.3.0+92e077650 for .NET
  Determining projects to restore...
  All projects are up-to-date for restore.
  Aliases -> C:\Code\Temp\Aliases\bin\Debug\banana\Aliases.dll

Build succeeded.
    0 Warning(s)
    0 Error(s)

Time Elapsed 00:00:00.27

C:\Code\Temp\Aliases [main]> dotnet publish --framework banana
MSBuild version 17.3.0+92e077650 for .NET
  Determining projects to restore...
  All projects are up-to-date for restore.
  Aliases -> C:\Code\Temp\Aliases\bin\Debug\banana\Aliases.dll
  Aliases -> C:\Code\Temp\Aliases\bin\Debug\banana\publish\
```

The missing part is allowing the same framework to be targeting among these aliases.

The following scenarios would be enabled:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFrameworks>latestnet-linux;latestnet-mac</TargetFrameworks>
  </PropertyGroup>

  <PropertyGroup Condition=" '$(TargetFramework)' == 'latestnet-mac' OR '$(TargetFramework)' == 'latestnet-linux'">
    <TargetFrameworkIdentifier>.NETCoreApp</TargetFrameworkIdentifier>
    <TargetFrameworkVersion>v6.0</TargetFrameworkVersion>
    <TargetFrameworkMoniker>.NETCoreApp,Version=v6.0</TargetFrameworkMoniker>
  </PropertyGroup>
  
  </Project>
```

Alternatively, the VS extension scenario would be something like:

```xml
<Project Sdk="Microsoft.VisualStudio.Extensibility.Sdk">

  <PropertyGroup>
    <TargetFrameworks>vs17.2;vs17.3</TargetFrameworks>
  </PropertyGroup>
  
  </Project>
```

### Technical explanation

Implementing this feature will require several large and in some cases, breaking changes.
The breaking changes are not necessarily in the completely new NuGet and .NET SDK version, but for some scenarios where different versions of the tooling are combined.

Fortunately, attempting any of the to be enabled scenarios with current versions of the tooling will lead to an obvious issue.

```console
C:\Program Files\Microsoft Visual Studio\2022\Preview\Common7\IDE\CommonExtensions\Microsoft\NuGet\NuGet.targets(132,5)
: error : Invalid restore input. Duplicate frameworks found: 'net472, net472'. Input files: C:\Code\Temp\Aliases\Aliase
s.csproj. [C:\Code\Temp\Aliases\Aliases.csproj]
```

While this scenario does have a number of interesting uses, there are many commands that would be affected by NuGet supporting this.

| Scenario | Affected Commands | Cost | Notes |
|----------|-------------------|------|-------|
| Build Challenges | restore (NuGet side), and build (SDK side) | 2L | This requires changes in both NuGet & SDK |
| Restore challenges | restore | 2L | |
| Pack challenges | restore | L | The answer here is likely that first class support won't be available, but having an experience that's intuitive should be the priority.|
| dotnet.exe challenges | Non-NuGet dotnet.exe commands |  ? | Seems like most of the commands at hand do treat `TargetFramework` as a simple string, but this would need to confirmed. |
| dotnet list package | dotnet list package | L | The work here would likely follow the work from the the restore side |
| Visual Studio challenges | Multi targeting, displaying (transitive) dependencies | L(+) | |



### Build challenges

In PackageReference, NuGet has a contract with the .NET SDK, where NuGet writes the assets file and the .NET SDK consumes it.
In most scenarios, people use `dotnet restore` and `dotnet build --no-restore` and there are no issues.
It is not uncommon that people use `nuget.exe restore` due to the fact that they have non-SDK projects in their solution.

Given that NuGet.exe and .NET SDK do not ship together, it is super common that the assets file was generated by a newer/older version of NuGet.exe than the .NET SDK can support. 

Normally, this works. NuGet rarely makes non-additive changes to the assets file.

Sample part of an assets file:

```json
  "targets": {
    ".NETFramework,Version=v4.7.2": {},
    ".NETFramework,Version=v4.8.0": {}
  },

```

NuGet's assets file is written pivoting on the actual target framework.

To solve this, NuGet would need to:

- Add vNext for the assets file format, version 4. Version 4 would either a dictionary based on the `TargetFramework` value instead of the effective target framework, built by coming `TargetFrameworkMoniker` and `TargetPlatformMoniker`.
  - This behavior would probably have to be opt-in to avoid breaking all combinations of new `NuGet.exe`, old `.NET SDK` combinations, but we can choose to intentionally not do this to encourage maintaining the 2 versions equivalently.
- Make a decision what would be a satisfactory behavior for combining newer/older versions of `NuGet.exe` and `.NET SDK`. This is largely just confirming some of the recent decisions.

To solve this, the .NET SDK would need:

- Be able to `build` with both versions 3 and version 4 of the assets file. The NuGet dependencies would naturally flow into the .NET SDK and the work is to just differentiate between the 2 different versions.
  - The amount of work needed to be done here would likely be affected by the exact shape of the NuGet APIs. These changes may be seamless.

### Restore challenges

In addition to the assets file, restore has a lock file which has a similar schema, that schema would need to be amended. Fortunately when Central Package Management and its transitive pinning was introduced we introduced the concept of a PackagesLockFile version succesfully. We'd just add a version 3.

NuGet would:

- Add version 3 of the packages lock file.

NuGet's intra restore caching is based on the existing of a single framework. It is difficult to predict the amount of work that'd be required to implement this correctly, but it'll certainly involve public API changes to NuGet libraries. (NuGet ships libraries, NuGet.exe, VS and dotnet.exe)

### Pack challenges

Multi-targetted pack only really works when each build leg (TargetFramework value) has 1 target location such as `lib/net5.0`.
Packing projects that do target the same framework multiple may be helpful in some scenarios, so completely blocking it is likely not a great idea, but having a coherent experience would require better understanding of the scenarios at question.

At the minimum, the pack command should be able to detect the scenario at hand and *not succeed queitly* as there's no guarantee what gets packed.
This scenario would require separate design work.

### dotnet.exe challenges

Today, some values in dotnet.exe work with an aliased `TargetFramework`, such as `build` and `publish`. 
The expectation is that all the commands support this, but this would require a deeper investigation.

#### dotnet list package

`dotnet list package` has an output that pivots on the effective target framework. This would need to be changed to use the aliased value.

NuGet would need to:

- Display the output with an aliased pivot.
- Update the machine readable output to handle the new schema, <https://github.com/NuGet/Home/issues/11449>. Given that the machine readable output has not shipped yet, this may be something that can be done ahead of time.

#### Visual Studio challenges

Currently the PM UI does not have any support for multi targeting. This isn't anything new, but it can affect the experience of customers moving to SDK projects for the first time.

Another concern are all the APIs for displaying the dependencies, transitive dependencies and Get Installed Packages APIs in NuGet.VisualStudio.Contracts.
All of these APIs may require an incremental addition.

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

- N/A. This is a binary decision to either support or not support this scenario.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->