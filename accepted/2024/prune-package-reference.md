# ***PrunePackageReference - Support for Pruning platform provided packages***

- Nikolche Kolev <https://github.com/nkolev92>
- [7344](https://github.com/NuGet/Home/issues/7344)

## Summary

Provide a means to prune certain packages from project graphs because those packages are not going to be used at runtime.
This helps avoid downloading unnecessary reference and implementation packages that would not have their assemblies used because the versions in the .NET SDK or shared framework would be used instead.
This avoids false positive by features such as NuGetAudit and other scanners that may be using the dependency graph.

## Motivation

In the early versions of .NET (Core), individual assemblies from the runtime were shipped as packages.
Starting with .NET (Core) 3.0, targeting packs were used for delivering references assemblies. The reference assemblies are no longer represented in graphs the way Microsoft.NETCore.App, Microsoft.AspNetCore.App, and NETStandard.Library were.
When a .NET (Core) 3.0 or later project depends on these older platform packages, we want them to be ignored in the graph, as those APIs are supplied by the platform via other mechanisms, such as targeting packs at build time and runtime packs for self-contained deployments.

Even .NET 9, there are certain assemblies that ship as both packages, but are also part of certain shared frameworks such as ASP.NET. See details <https://github.com/dotnet/aspnetcore/issues/3609>. An example of such assembly/package is `Microsoft.Extensions.Logging`, which is [published on nuget.org](https://www.nuget.org/packages/Microsoft.Extensions.Logging/), but also part of the Microsoft.AspNetCore.App shared framework. Currently there's conflict resolution in the .NET SDK to ensure that the latest version is chosen.

There are a few benefits:

The fewer packages need to be downloaded, the better the performance of the restore algorithm will be.
Beyond that, the extra packages within the graph, do make the resolution step more challenging. Some of the targeting packs used to bring in such a large package graph, that affected the resolution performance significantly. See  and <https://github.com/NuGet/Home/issues/11993> for more details. Furthermore, certain versions of popular packages have taken dependencies on these targeting packs for historical reasons. Such an example is <https://www.nuget.org/packages/log4net/2.0.10> which performs significantly better than <https://www.nuget.org/packages/log4net/2.0.9> when installed in a .NET (Core) projects, see <https://github.com/NuGet/Home/issues/10030>.

Certain versions of these packages are no longer  part of the project graph, thus reducing the chances of false positives during scanning.
This is especially important in the context of assemblies that are part of shared frameworks. The build time conflict resolution ensures that the most up to date version is used, despite the fact that the user referenced package may habe vulnerabilities.
Examples: <https://github.com/dotnet/sdk/issues/30659#issuecomment-2072567192>.

This changes significantly helps align what gets restored and what gets published. By avoiding packages that are simply not going to be used at runtime, what gets used at runtime becomes more transparent.

## Explanation

### Functional explanation

A list of package id/versions to be pruned will be provided by the .NET SDK. The version will signify the highest version to be pruned.
When NuGet encounters any of the specified packages or lower, it will simply remove the package from the graph.
This package id will not be downloaded and will not appear in the assets file libraries or targets section, but there will be a detailed verbosity message indicating that the package id has been pruned for the given framework.

The feature is framework specific, and can be opted in/out using the `RestoreEnablePackagePruning` property.
Pruning is only possible for transitive packages, if a direct package reference is attempted to be pruned, a warning will be raised.

### Technical explanation

A list of package id/versions to be pruned will be provided by the .NET SDK.
To aid this, a new item type and collect targets will be introduced.

The `PrunePackageReference` item will support the following attributes:

| Attribute | Explanation |
|-----------|-------------|
| Version | A NuGet parsable version. The version is consider to the maximum version to be pruned. |

The collect target will be `CollectPrunePackageReferences`.

When NuGet sees any of these package ids in the resolution, it'll just skip them and log a message in detailed verbosity, indicating the package has been skipped.
We may capture some of this information in telemetry to track how often this feature is being used.

Duplicate item checking will be performed the same way it is performed for all other NUGet items such as `CollectPackageReferences`.

#### Special scenarios

- Pruning direct PackageReference of current project - Warn and don't prune.
- Pruning direct PackageReference of transitive projects - Prune
- Pruning transitive packages of current project - Prune
- Pruning package ids that are projects - Warn and don't prune
- Pruning package id that matches the current project - Error

#### Changes to the obj files

`project.assets.json`

```json
{
    "NuGet.LibraryModel/6.10.0": {
        "type": "package",
        "dependencies": {
          "NuGet.Common": "6.10.0",
          "NuGet.Versioning": "6.10.0"
        },
        "compile": {
          "lib/netstandard2.0/NuGet.LibraryModel.dll": {}
        },
        "runtime": {
          "lib/netstandard2.0/NuGet.LibraryModel.dll": {}
        }
      },
      "NuGet.Packaging/6.10.0": {
        "type": "package",
        "dependencies": {
          "Newtonsoft.Json": "13.0.3",
          "NuGet.Configuration": "6.10.0",
          "System.Security.Cryptography.Pkcs": "6.0.4"
        },
        "compile": {
          "lib/net5.0/NuGet.Packaging.dll": {}
        },
        "runtime": {
          "lib/net5.0/NuGet.Packaging.dll": {}
        }
      }
}
```

The above represents the targets section for a framework.
NuGet.Versioning is pruned. NuGet.Versioning *will not appear* as a dependency and it will not be in list since it was never chosen.

To improve diagnosability, a [new section detailing the list of packages pruned](#future-possibilities) *may* be added later.

`PackageSpec & project section of the assets file`

The list of PrunePackageReference items must only include relevant packages.
It will be included in the "project" section of the assets file, internally called the PackageSpec, similarly like the centralPackageVersions.

```json
  {
    "frameworks": {
      "net8.0": {
        "targetAlias": "net8.0",
        "dependencies": {
          "MyDependency": {
            "target": "Package",
            "version": "[2.3.0, )",
            "versionCentrallyManaged": true
          },
        },
        "centralPackageVersions": {
          "MyDependency": "2.3.0",
          "Microsoft.Build": "17.10.4",
        },
        "prunePackageReferences": {
          "System.Text.Json": "8.0.5"
        }
      }
    }
  }
```

The pruned packages won't be represented in the assets file in any other way.

### Additional validation considerations

- How does leaving the dependency in the assets file section affect features consuming the assets file.
  - The solution explorer tree - The solution explorer skips transitive references.
  - PM UI tab - The transitive packages aren't shown at all.
  - PM UI tab - The transitive packages aren't shown at all.
  - list package - Completes succesfully with/without pruned packages. Correctly reports pruned packages aren't part of the graph.
  - dotnet nuget why - Completes succesfully with/without pruned packages. Correctly reports pruned packages aren't part of the graph.

### NET SDK - selecting packages to be pruned

See [Prior art](#net-sdk-package-pruning) for more details on how the .NET SDK prunes packages at runtime today.
The particular pruning is based on the resulting list of shared frameworks.
The .NET SDK will provide the list at the beginning of the restore operation, as such the .NET SDK *must* only consider direct shared frameworks, and not transitive ones.
Given that packages are allowed to bring in a shared framework, and that is not known by the .NET SDK at the beginning of restore, package graphs brought in by packages are not going to be pruned with the current solution.

## Drawbacks

- The risk of this feature is driven by the packages that are being pruned.
Given that the list of packages that will be provided by the SDK is already being pruned in a different way, one could argue that the risks have been well mitigated there. However, there is a chance we end up pruning more/fewer packages in the end. There's also a chance we end up getting new dependencies since pruning packages may have an effect on the outcome of the cousin dependency rule.

## Rationale and alternatives

### Represent the packages as files

The list will be provided through a property pointing to a file that contains the list of packages in the `<id>|<version>` format, with a newline separating each package id. The property will be: `NuGetPlatformPackagesList`.

An example of the file format:

```txt
Microsoft.Win32.Registry|4.7.0
System.Diagnostics.EventLog|4.7.0
System.IO.Pipelines|4.7.0
System.Security.AccessControl|4.7.0
```

NuGet will assume that the file in question is immutable once written on disk. What this means is that in the up to date checks, NuGet just checks the file name, rather than the content itself. This approach matches the runtime.json approach.

- Pros:
  - Performance benefits.
  These lists will contain hundreds of packages.
  NuGet can cache the package list based on a file. With the current implementation, NuGet needs to maintain a list per framework, per project, arguably with a lot of duplication. Even if NuGet deduplicates the objects reprsenting the packages in some way, it would still register from a memory allocations perspective(which has been a focus), on both NuGet & project-system side.
  - Eliminate potential misuse.
- Cons:
  - The feature is no longer easy to generalize.
  There are various asks for the ability to simply ignore certain packages from graphs. More often than not, the reason is that an old package is being referenced and cannot be updated.

### Pruning shared frameworks on the fly

Pruning shared frameworks on the fly is a technically challenging feat. In particular, packages being brought in transitively, affecting which other packages are included beyond the dependencies node can potentially lead to unresolveable conflicts. In particular, a package version may bring in a shared framework, which if the shared framework packages were pruned could lead to not selecting the package that brough in the shared framework in the first place.

### Not doing the feature

With security being a focus of NuGet as a package manager, minimizing false positives is essential. The fact that there are still assemblies that ship both as packages and as part of shared frameworks means that the changes of false positives are not going away with a framework update.
We can consider not doing this feature and relying on platform packages to simply go away, especially with NuGetAudit enabling transitive dependency auditing recently, but that is not going to solve the long term concern of assemblies such `Microsoft.Extensions.Logging`.

## Prior Art

- This problem is .NET specific. Package pruning at the build level is already happening. 

### NET SDK package pruning

The .NET SDK assembly/package pruning is already happening currently.
The limitations of that implementation are that the package still appear in the assets file, still get downloaded and are thus included in the package auditing.
The pruning is happening on a per shared framework basis.
Example:

- Microsoft.NETCore.App 9.0 shared framework, <https://github.com/dotnet/runtime/blob/main/src/installer/pkg/sfx/Microsoft.NETCore.App/PackageOverrides.txt>

- Microsoft.AspNetCore.App 9.0 shared framework, <https://github.com/dotnet/aspnetcore/blob/main/eng/PackageOverrides.txt>

#### Aliases and Package Pruning

PackageReference, ProjectReference and Reference items all support the Aliases metadata. 

In the build side conflict resolution, <https://github.com/dotnet/sdk/blob/262b9c3d6cf67287f649e38d83e6c5d9d08feb8a/src/Tasks/Common/ConflictResolution/ResolvePackageFileConflicts.cs#L178-L182>, assemblies are pruned, so when aliases are seen, the assemblies are deduplicated and the aliases metadata is kept.
This is possible, because there are 2 references that are found and the alias is preserved even if the exact assembly being used is changed. 

The [PackageReference Aliases](https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files#packagereference-aliases) metadata, only works on direct PackageReference and as such it's not relevant here since we don't prune direct PackageReference.

Another way to specify metadata on assemblies coming from packages would be MSBuild's item Update, but in that case, the metadata will aply to the dll references only and as such isn't going to be broken by this work.

## Unresolved Questions

## Future Possibilities

- Add a section that indicates the list of pruned packages durign the restore operation.
- Say a project has a transitive framework reference brought through a package.
If there are packages in the graph that are part of the shared framework only brought in transitively, they would not be pruned.
The SDK could detect this occurence and warn the user.
- A code/csproj fixer for the warning indicating that a direct PackageReference was specified for pruning.
- Should platform package pruning data represent GA of a framework or the serviced version? <https://github.com/dotnet/sdk/issues/44566>

## References

- <https://github.com/dotnet/aspnetcore/issues/3609> - Handle conflicts between a ref-only Microsoft.AspNetCore.App and individual packages
- <https://github.com/dotnet/runtime/issues/3574>
- <https://github.com/dotnet/runtime/issues/33450> - Make conflict resolution eliminate old System.Native libs prior to rename
- <https://github.com/dotnet/runtime/issues/52318> - Extra package dependencies appearing for current framework
- <https://github.com/dotnet/sdk/issues/10973> - The dotnet store is incorrectly including BCL assemblies when targeting .NET Core 3.1
- <https://github.com/dotnet/sdk/issues/3582> - RID-specific self-contained .NET Core 3 app with dependency on Microsoft.NETCore.App 2.0.0 fails to run
- <https://github.com/NuGet/Home/issues/3541> - NuGet claims downgrades (NU1605) for packages brought in through lineup
- <https://github.com/NuGet/Home/issues/8087> - NuGet Package Vulnerability Auditing
- <https://github.com/NuGet/Home/issues/13405> - dotnet list packages should not report false positives for assemblies in shared directory
