# Support for handling multiple equivalent framework

- [Nikolche Kolev](https://github.com/nkolev92), [Andy Zivkovic](https://github.com/zivkan)
- GitHub Issue ([5154](https://github.com/NuGet/Home/issues/5154)) - Treat Target Framework as Aliases

## Summary

.NET SDK projects are capable of multi targeting based on a target framework where you can have different dependencies for each framework.
In some cases, it is convenient to multi target based on different pivots such as target application version or maybe the specific runtime, as packages can contain runtime assets.
This proposal covers the steps that need to be taken to enable that capability.

## Motivation

Allowing the same framework to be using multiple times in restore would allow customers to use the same project to generate runtime specific assemblies based on the same target framework.
It would also allow scenarios such as different builds for VSIXes targeting different Visual Studio versions.

## Explanation

### Functional explanation

#### TargetFramework values are already aliases

NuGet, and the .NET SDK more generally, uses `TargetFrameworkMoniker` and `TargetPlatformMoniker` for project and package compatibility.
Each of the two `*Moniker` properties are composed of `*Identifier` and `*Version` properties, which NuGet doesn't use, but might be used by other components, so should also be set correctly.
If these properties do not have values, the .NET SDK will infer the values by parsing the `TargetFramework` property, which is what we typically see defined in project files.
However, if the `TargetFrameworkMoniker` property is defined explicitly (`TargetPlatformMoniker` is allowed be be undefined), NuGet (and several other components, like the .NET SDK and Visual Studio's dotnet/project-system) will already treat these values as aliases.

For example, the following is a valid project that works before this spec is implemented.

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

However, what doesn't currently work is when multiple TargetFramework values resolve to the same `*Moniker` property value.

#### The proposal

The changes proposed in this document will enable the following hypothetical scenarios.
Note that projects and SDKs are responsible for setting the `TargetFramework*` and `TargetPlatform*` properties, which NuGet uses as the canonical framework to use for compatibility checks.
Therefore, the exact `TargetFrameworks` value is not important to NuGet, as it is either the SDK author, or the project owner, to set any value that is reasonable to them.

Firstly, a single project that creates multiple platform specific assemblies, all targeting the same .NET version.

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
    <AssemblyName>$(MSBuildThisFileName).$(TargetFramework)</AssemblyName>
  </PropertyGroup>

</Project>
```

Secondly, a Visual Studio Extension project targeting multiple versions of VS could look similar to the following.
In this example, the Visual Studio Extensibility SDK would be responsible for setting `TargetFrameworkIdentifier`, `TargetFrameworkVersion` and `TargetFrameworkMoniker` properties.

```xml
<Project Sdk="Microsoft.VisualStudio.Extensibility.Sdk">

  <PropertyGroup>
    <TargetFrameworks>vs17.7;vs16.11</TargetFrameworks>
  </PropertyGroup>

</Project>
```

#### Compatibility

Customers that both restore and build their projects with the `dotnet` CLI or MSBuild should not encounter any issues.

However, many customers have old pipelines that use NuGet.exe to restore, or create new pipelines that continue to use NuGet.exe because we've been unable to spread knowledge to use more modern tooling.
Typically customers do not update the version of NuGet.exe used as frequently as using newer versions of the .NET SDK or MSBuild.
When newer versions of NuGet don't change the restore output (files written to the `obj/` directory), then using older versions of NuGet will not cause pipeline failures.
However, the changed proposed by this document require changes to the assets file, and as a result using an older NuGet.exe with a newer .NET SDK or MSBuild will cause build failures similar to the following.

```console
C:\Program Files\Microsoft Visual Studio\2022\Preview\Common7\IDE\CommonExtensions\Microsoft\NuGet\NuGet.targets(132,5)
: error : Invalid restore input. Duplicate frameworks found: 'net472, net472'. Input files: C:\Code\Temp\Aliases\Aliases.csproj. [C:\Code\Temp\Aliases\Aliases.csproj]
```

Unfortunately this error does not contain a NU code, which would make it easier for customers to find a documentation page explaining the issue and probable fixes.
Instead, customers who are not aware of this tooling version issue will likely need to search the error message and we have to hope that search engines will direct them to a page that informs them to upgrade to a newer version of NuGet.exe, or ideally switch to `MSBuild -t:restore` or `dotnet restore`.

This problem is not technically unique to this design change, but since assets file changes are uncommon, this feature is significantly more likely to expose this issue than other features.

### Technical explanation

There are many changes required to implement this feature.

1. [Restore output (assets file) changes](#restore-output-assets-file-changes)
1. [Components iterating target frameworks](#components-iterating-target-frameworks)
1. [Lock file changes](#lock-file-changes)
1. [ProjectReference changes](#project-to-project-references)
1. [Pack changes](#pack-changes)
1. [Visual Studio Challenges](#visual-studio-challenges)

The changes listed are largely what NuGet needs to implement in code we own, but there will be impacts to other components as well.
In particular the .NET SDK will need some (hopefully small) changes to be able to use the assets file correctly.
However, it's likely that other tools, like various Visual Studio components, might have assumptions about TFM uniqueness in the project, which this feature changes.
Therefore, while the NuGet team works very closely with the .NET SDK team and we will ensure that building projects work, there will increased risk of other features and tools breaking, which would normally not be affected by NuGet changes.

### Restore output (assets file) changes

In PackageReference, NuGet has a contract with the .NET SDK where NuGet writes the assets file and the .NET SDK consumes it.

This feature will require the following changes to the asset file:

1. [Increment Version Number](#assets-file-version)
1. [Target Framework Pivots](#target-framework-pivots)
1. [Add List Lengths](#add-list-lengths)

However, PackageReference is also supported by non-SDK style projects, which use [dotnet/NuGet.BuildTools](https://github.com/NuGet.BuildTools) which, despite the name, is owned by the non-SDK project system team, not NuGet.
Their implementation parses the JSON file directly, rather than using NuGet.ProjectModel.
Therefore, if we can implement the assets file changes without breaking changes to the NuGet.ProjectModel APIs, the .NET SDK may "just work" when the newer version of NuGet is inserted into the .NET SDK.
However, the non-SDK project system will fail.
This means that we either need to implement NuGet to support reading and writing two different assets file schemas, or we need to synchronize 3 different components (NuGet, .NET SDK, and NuGet.BuildTools) to implement support in the same VS insertion.
The multi-rep synchronization insertion would have a lot of risk and difficulty, so allowing NuGet.ProjectModel to support multiple versions of the assets file schema seems the better choice.

There are still two ideas for how this can be implemented.

1. Assets file version as a restore input

   NuGet could require read a `RestoreAssetsFileVersion` property on each project, defaulting to 3 when not specified.
   This allows project systems that have not yet adapted to the new assets file schema to keep working as before.

1. Use the newer assets file automatically when a project multi-targets

  Non-SDK style project can only single target, so those project types won't see a change.
  Single targeting SDK style projects will also continue to use the V3 assets file.
  However, multi-targeting SDK style projects will use the V4 assets file.

The automatic version selection based on single or multi targeting projects will make NuGet.exe not backwards compatible with older versions of the .NET SDK.
There are some customers who explicitly run `nuget.exe update -self`, or download NuGet.exe from the `latest` directory, or use build tools which do the equivalent.
If we choose automatic version selection based on single- or multi-targeting, then these customers will experience build failures on release of NuGet.exe with this feature, until they also update to a newer version of the .NET SDK.
If we choose asset file version via MSBuild property, then newer NuGet.exe versions will remain backwards compatible with older .NET SDK versions.

#### Assets File Version

The assets file contains a `version` property since it was first created, and is always the first property in the file.
The current assets file version is 3, and this feature will increment the version to 4.

```diff
-"version": 3
+"version": 4
```

#### Target Framework Pivots

There are multiple places in the assets file where the "NuGet Framework" is used as a JSON object property key.

Imagine a project using `<TargetFramework>production</TargetFramework>`, `<TargetFrameworkMoniker>.NETCoreApp,Version=v8.0</TargetFrameworkMoniker>`, and `<RuntimeIdentifiers>linux-x64</RuntimeIdentifiers>`.
The following changes will be made to the assets file.

1. `$/targets`

    ```diff
      "targets": {
    -    "net8.0": {},
    -    "net8.0/linux-x64": {},
    +    "production": {},
    +    "production/linux-x64": {},
      },
    ```

1. `$/projectFileDependencyGroups`

    ```diff
      "projectFileDependencyGroups": {
    -    "net8.0": [],
    +    "production": [],
      },
    ```

1. `$/project/restore/frameworks`

    ```diff
      "originalTargetFrameworks": [
    -    "net8.0"
    +    "production"
      ],
    ```

1. `$/project/frameworks`

    ```diff
    "frameworks": {
    -  "net8.0": {
    -    "targetAlias": "production",
    +  "production": {
    +    "targetFramework": "net8.0",
      }
    }
    ```

    Additionally, NuGet was previously using the canonical `TargetFrameworkMoniker` value in the assets file for all target frameworks that are not .NET 5 or later.
    For example, `.NETFramework,Version=v4.8`.
    I propose that as part of this schema change we standardize on the "short name" (`net48`) instead.
    However, implementing this might be non-trivial, in which case it's not worth the effort, even if it's not difficult.

#### Add List Lengths

This is not required for this feature, but taking advantage of a breaking change in the JSON schema, we may be able to improve performance.
When deserialized, many parts of the assets file become some kind of collection, such as a `List<T>` or a `Dictionary<Tkey, Tvalue>`.
During deserialization, if the collection size is not known, then .NET will create a backing array with a default size, and every time the collection exceeds the current capacity, it will need to double the backing array size and copy the old array data into the new array.
This is a known cause of performance degradation.
This is particularly important in large collections, where the resize will happen multiple times, which includes `$/targets/*` and `$/libraries` in the assets file.

I will not enumerate every location that could benefit from a count, I consider that an implementation detail that will absolutely be hidden by the Nuget.ProjectModel APIs.
But as for some examples, I propose `$/librariesCount` to specify the number of property keys under `$/libraries`.
`$/targets/tfm1/@count` could be the first property in `$/target/tfm1`, since `@` is an invalid character for a package ID.

### Components iterating target frameworks

There are some components that either read the assets file directly, or interact with project `TargetFrameworks` in another way.
Some examples are:

- The .NET SDK, as part of build, as previously discussed.
- Any `dotnet` CLI command with a `--frameworks` or `-f` argument, such as `dotnet build`, `dotnet publish`, `dotnet test`.
- `dotnet list package`.
- Numerous features in Visual Studio.
  - Test Explorer.
  - Text editor (left-most dropdown, for TFM specific Intellisense).
  - Solution Explorer's Dependencies node.

### Lock file changes

NuGet's "repeatable build" feature adds a package lock file to the project directory.
The restore has a lock file has a similar schema to the assets file, so that schema would also need to be amended.
Fortunately when Central Package Management and its transitive pinning was introduced we introduced the concept of a PackagesLockFile version successfully.
We'd just add a version 3.

NuGet would add version 4 of the packages lock file, which will [pivot on the target framework alias, just as assets files will](#target-framework-pivots).

NuGet's intra restore caching is based on the existing of a single framework.
It is difficult to predict the amount of work that'd be required to implement this correctly, but it'll certainly involve public API changes to NuGet libraries.
(NuGet ships libraries, NuGet.exe, VS and dotnet.exe)

### Pack changes

For the first version of this feature, projects that have more than one `TargetFramework` (inner-build) resolve to the same "NuGet Framework" will result in a pack error, therefore preventing these projects from being packed.
See [Extending Pack, under Future Possibilities](#extending-pack) for more information.

### Visual Studio challenges

Currently the PM UI does not have any support for multi targeting.
This isn't anything new, but it can affect the experience of customers moving to SDK projects for the first time.
Especially for customers who are not comfortable hand editing XML or MSBuild files.

Another concern are all the APIs for displaying the dependencies, transitive dependencies and Get Installed Packages APIs in NuGet.VisualStudio.Contracts.
All of these APIs may require an incremental addition.

### Project to Project references

MSBuild has a [`ProjectReference` protocol](https://github.com/dotnet/msbuild/blob/25fdeb3c8c2608f248faec3d6d37733ae144bbbb/documentation/ProjectReference-Protocol.md), which explains how `ProjectReferences` work.
MSBuild calls the `GetReferenceNearestTargetFrameworkTask`, which NuGet implements, in order to obtain best TFM matching.

Currently `GetReferenceNearestTargetFrameworkTask` is implemented by running NuGet's "nearest match" algorithm.
This feature would extend it to first try nearest match, and if there is more than one matching `TargetFramework`, then look for a `TargetFramework` that has an exact name match in both projects.
If there are more than one "nearest" framework, but no exact name match, then for the first version of this feature, NuGet will report an error.
Depending on customer feedback, build customization can be added in the future.

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

### TargetFramework alias to block `/` character

As previously shown in [the assets file pivots changes](#target-framework-pivots), NuGet uses `tfm/rid` as the property name in the `$/targets` object.
Therefore, a `TargetFramework` that includes a `/` will cause significant parsing challenges.

However, an alternative to this specific challenge is that the assets file could have more substantial schema change:

```diff
  "targets": {
-    "net8.0": {},
-    "net8.0/linux-x64": {},
+    "production": {
+      "any": {},
+      "linux-x64": {}
+    }
  },
```

This assumes that the "rid-less" TFM is equivalent to the `any` RID, and that `<RuntimeIdentifier>any</RuntimeIdentifier>` is not meaningful currently.

### Other TargetFramework alias naming restrictions

Should we block characters that need to be encoded in JSON files, like `"`, or non-ASCII characters?

Since the `TargetFramework` value is used by the .NET SDK as the directory name for build output, should we block invalid characters on Windows file systems? (Linux doesn't prevent any characters, with the possible exception of `/`, since that's used as the directory separator).

### More significant assets file schema changes?

Should we consider more significant schema changes in the assets file?

Under `$/libraries`, each package lists every file in the package.
However, the performance penalty of needing to parse that list every time the assets file is read may be worse than any benefit it provides from avoiding enumerating the filesystem when it is needed.
The assets file primary purpose is to tell the .NET SDK and dotnet/NuGet.BuildTools what package assets are used by the project, and they don't need or use the `$/libraries` section at all.
While reading the assets file might be a small percentage of the overall build process, if we consider reading the assets file in isolation, there could be a fairly significant performance increase by removing this entire section of the assets file.

`$/projectFileDependencyGroups` appears to be a duplication of the information available in `$/project/frameworks`.

`$/project/originalTargetFrameworks` duplicates information already available in `$/project/restore/frameworks`

Since the .NET SDK has to read the assets file after NuGet writes it, time and memory allocations spent on parts of the assets file not relevant to asset selection reduces performance.
Additionally, MSBuild binlogs embed the assets file, which bloats the binlog size.

Removing the duplicated data should be non-controversial.
But the `$/libraries` section is useful for diagnosing customer complaints.
Whether impacting the performance of every build is worth occasional benefit in helping debug customer issues is subjective.
An alternative is we add a `<RestoreVerboseAssetsFile>` property to include it, but otherwise have it off by default for performance reasons.
Although the .NET SDK already have a cache, so they should only read the assets file when the assets file changes.

### More significant lock file schema changes

I don't want to make the scope of this feature so large that it takes an unreasonably long time to implement.
However, breaking changes are rarely made in NuGet, so if we have to make a breaking change to enable a feature, it's tempting to take advantage and propose other changes at the same time.

Since the lock file contains the package's content hash, and the package's `nuspec` is included in that content hash, this means that the dependencies in the the lock file are a redundant duplication of information available elsewhere.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

### Extending Pack

It seems feasible that if a single project can target multiple versions of Visual Studio, through a new Visual Studio Extensibility SDK, that someone will also want to create a package that supports multiple versions of Visual Studio.

Designing how this could work is out of scope for this spec, and can be introduced in a different spec.

### Customizing ProjectReference TargetFramework selection

As [previously mentioned](#project-to-project-references), the first version of this feature proposes only doing exact name matches, when more than one `TargetFramework` is a "best match" for a project reference.
