# Support for handling multiple equivalent framework

- [Nikolche Kolev](https://github.com/nkolev92), [Andy Zivkovic](https://github.com/zivkan)
- GitHub Issue ([5154](https://github.com/NuGet/Home/issues/5154)) - Treat Target Framework as Aliases

## Summary

.NET SDK projects are capable of multi targeting based on a target framework where you can have different dependencies for each framework.
In some cases, it is convenient to multi target based on different pivots such as target application version or maybe the specific runtime, as packages can contain runtime assets.
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

The following hypothetical scenarios would be enabled.
Note that these examples are not being proposed as syntax that will be implemented.
Rather, they're intended to demonstrate a scenario that is not possible today.

Firstly, a single project that creates multiple packages for different platforms, but the same TFM:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFrameworks>linux;mac</TargetFrameworks>
  </PropertyGroup>

  <PropertyGroup>
    <TargetFrameworkIdentifier>.NETCoreApp</TargetFrameworkIdentifier>
    <TargetFrameworkVersion>v6.0</TargetFrameworkVersion>
    <TargetFrameworkMoniker>.NETCoreApp,Version=v6.0</TargetFrameworkMoniker>

    <DefineConstants>$(DefineConstants);$(TargetFramework)</>
    <PackageId>$(AssemblyName).$(TargetFramework)</PackageId>
  </PropertyGroup>

</Project>
```

Secondly, a Visual Studio Extension project targeting multiple versions of VS could look similar to the following.
In this example, the Visual Studio Extensibility SDK would be responsible for setting `TargetFrameworkIdentifier`, `TargetFrameworkVersion` and `TargetFrameworkMoniker`.

```xml
<Project Sdk="Microsoft.VisualStudio.Extensibility.Sdk">

  <PropertyGroup>
    <TargetFrameworks>vs17.7;vs16.11</TargetFrameworks>
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

### Assets file changes

In PackageReference, NuGet has a contract with the .NET SDK, where NuGet writes the assets file and the .NET SDK consumes it.
Therefore, the assets file schema that NuGet writes must match what's expected by the .NET SDK.
In most scenarios, people use `dotnet restore` and `dotnet build --no-restore` and there are no issues.
It is not uncommon that people use `nuget.exe restore` due to the fact that they have non-SDK projects in their solution and they have not modernized their CI build to use MSBuild restore.
Given that NuGet.exe and .NET SDK do not ship together, it is very common that the assets file was generated by a different version of NuGet.exe than what the .NET SDK can contains.
Normally, this works.
However, when NuGet makes a breaking change to the assets file, a significant number of customers will experience issues.
We should design the feature to avoid incorrect results, and also make error messages as easy as possible to understand and resolve.

#### Assets file version

A breaking change in the assets file will be very difficult to implement unless we allow a period where NuGet supports multiple versions of the assets file in the same release.
Additionally, the [.NET SDK assets file reader](https://github.com/dotnet/sdk/blob/main/src/Tasks/Microsoft.NET.Build.Tasks/ResolvePackageAssets.cs) and [non-SDK style projects assets file reader](https://github.com/dotnet/NuGet.BuildTasks) have different implementations, across different repos.
Therefore, unless Nuget supports multiple multiple asset file versions in a single binary, it would be necessary to insert the change simultaneously across NuGet, the .NET SDK, NuGet.BuildTools, VS, and possibly MSBuild.
This is so infeasible it's effectively impossible.

Therefore, the proposal is that the .NET SDK will define an MSBuild property `ProjectAssetsFileVersion`, with allowed values `3` or `4`.
When the property is not defined, it will assume `3`, in order to maintain backwards compatibility with the existing build tools.
The .NET SDK already defines property `PropertyAssetsFile`, which is the location it reads the assets file from, hence the proposal of `ProjectAssetsFileVersion`.
It may be that the non-SDK style project assets file reader (NuGet.BuildTools) may never migrate to v4 assets file, so supporting both assets file schemas could be a permanent cost, rather than a temporary situation.

Reading the assets file will need a new data structure, and therefore will need new APIs to read.
The goal is to enable the new data structure to be compatible with both v3 and v4 assets files, so that consumers of the assets file don't need multiple code paths to handle both assets file versions.
This is not only relevant for the .NET SDK, but NuGet's own Visual Studio integration.

The assets file already contains a `version` property, always written out as the first property on the root object.
This enables our assets file reader to use polymorphic deserialization to handle.
Although if this turns out to be difficult to implement, we can provide separate V3 and V4 read methods (but both using the new data structures), and callers will need to check the `ProjectAssetsFileVersion` MSBuild property to determine which one to use.
However, I'm reasonably confident that polymorphic deserialization should be feasible to implement.

#### Inner build pivot

There are multiple places in the assets fie where the "NuGet Framework" (before .NET 5 it was just the `TargetFrameworkMoniker` MSBuild property, but since .NET 5 it can include the TargetPlatformMoniker as well, although in a simplified format) is used as a JSON property key.
Sometimes with an additional Runtime Identifier (RID).
Since the goal of this spec is to allow multiple `TargetFramework`s to resolve to the same "NuGet Framework", this means these parts of the assets file have to change.

Here is a short extract from an assets file:

```json
  "targets": {
    ".NETFramework,Version=v4.8": {},
    ".NETFramework,Version=v4.8/win7-x64": {},
    "net8.0": {},
    "net8.0/win7-x64": {},
    "net8.0-windows7.0": {},
    "net8.0-windows7.0/win7-x64": {},
  },
```

Currently the `targets` section of the assets file is loaded into a `Dictionary<string, NotRelevant>`, and therefore the `targets` node cannot contain two identical TFMs when two Target Frameworks resolve to the same TFM. The proposal is to change this, and all other examples in the assets file, to use the `TargetFramework` as a string literal instead.

Todo: figure out best choice for proposed data model & schema.
Will there be a problem if customer uses `TargetFramework` with a `/` character?

### Lock file changes

NuGet's "repeatable build" feature adds a package lock file to the project directory.
The restore has a lock file has a similar schema to the assets file, so that schema would also need to be amended.
Fortunately when Central Package Management and its transitive pinning was introduced we introduced the concept of a PackagesLockFile version successfully.
We'd just add a version 3.

NuGet would:

- Add version 3 of the packages lock file.

NuGet's intra restore caching is based on the existing of a single framework.
It is difficult to predict the amount of work that'd be required to implement this correctly, but it'll certainly involve public API changes to NuGet libraries.
(NuGet ships libraries, NuGet.exe, VS and dotnet.exe)

### Pack changes

For the first version of this feature, projects that have more than one `TargetFramework` (inner-build) resolve to the same "NuGet Framework" will result in a pack error, therefore preventing these projects from being packed.
See [Extending Pack, under Future Possibilities](#extending-pack) for more information.

### dotnet.exe challenges

Today, some values in dotnet.exe work with an aliased `TargetFramework`, such as `build` and `publish`, using the `--framework` or `-f` argument.
The expectation is that all the commands support this, but this would require a deeper investigation.

#### dotnet list package

`dotnet list package` has an output that pivots on the effective target framework.
This would need to be changed to use the aliased value.

NuGet would need to:

- Display the output with an aliased pivot.
- Update the machine readable output to handle the new schema, <https://github.com/NuGet/Home/issues/11449>.

#### Visual Studio challenges

Currently the PM UI does not have any support for multi targeting.
This isn't anything new, but it can affect the experience of customers moving to SDK projects for the first time.
Especially for customers who are not comfortable hand editing XML or MSBuild files.

Another concern are all the APIs for displaying the dependencies, transitive dependencies and Get Installed Packages APIs in NuGet.VisualStudio.Contracts.
All of these APIs may require an incremental addition.

#### Project to Project references

MSBuild has a [`ProjectReference` protocol](https://github.com/dotnet/msbuild/blob/25fdeb3c8c2608f248faec3d6d37733ae144bbbb/documentation/ProjectReference-Protocol.md), which explains how `ProjectReferences` work.
This will need changes to support scenarios where a project where more than one `TargetFramework` resolves to the same "NuGet Framework".

Additionally, NuGet's `PackageReference` requires a project's entire dependency graph to be resolved, which includes projects, in order to calculate transitive packages.
Therefore, NuGet has the same, or at least very similar, problems as MSBuild with regards to `ProjectReference`s.

This needs further discussion between the MSBuild and NuGet teams.

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

From a high level feature point of view, the alternative is that customers must use separate projects, rather than a single project file.
Therefore, this feature is a binary decision to either support or not support this scenario.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

### Exact assets file schema changes

Should we "simply" replace the TFM in property keys with the Target Framework alias?
For example, change ".NETFramework,Version=4.7.2/win-x64" with "vs17.7/win-x64"?
But there will be parsing problems when a `TargetFramework` contains a `/` character.
While "something/another thing/win-x64" can determine that "win-x64" is a RID, when we get the RID-less "something/another thing" string, it's not clear that what follows the `/` is a RID, unless the assets file parser starts knowing the entire RID graph.

### How ProjectReferences will work

Currently ProjectReferences (P2P) do a compatibility check, both by MSBuild and NuGet (although I'm sure MSBuild delegates to NuGet APIs).
When a project has multiple `TargetFramework`s that map to a single "NuGet Framework", which one should MSBuild and NuGet use?
MSBuild needs to choose in order to know which dll to pass to the compiler (in case different aliases have different APIs), and so test projects actualy test the desired product binary.
NuGet needs to know for the package dependency graph.

A simple option is to match the alias string.
But do we want to support different projects using different aliases?
If so, then a way to "set the desired alias in the target project" will be needed.
That may be usable as a way to [override selection of "nearest" framework](https://github.com/NuGet/Home/issues/7416), which may or may not be considered a good thing, depending on your view if overriding asset selection is good or not.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

### Extending Pack

It seems feasible that if a single project can target multiple versions of Visual Studio, through a new Visual Studio Extensibility SDK, that someone will also want to create a package that supports multiple versions of Visual Studio.

Designing how this could work is out of scope for this spec, and can be introduced in a different spec.
