# ***Pruning platform provided packages***

- Nikolche Kolev <https://github.com/nkolev92>
- [7344](https://github.com/NuGet/Home/issues/7344)

## Summary

<!-- One-paragraph description of the proposal. -->
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

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

A list of package id/versions to be pruned will be provided by the .NET SDK. The version will signify the highest version to be pruned.
When NuGet encounters any of the specified packages or lower, it will simply remove the package from the graph.
This package id will not be downloaded and will not appear in the assets file libraries or targets section, but there will be a detailed verbosity message indicating that the package id has been pruned for the given framework.

The feature is framework specific, and can be opted in/out using the `NuGetEnablePrunedPackages` property.

### Technical explanation

A list of package id/versions to be pruned will be provided by the .NET SDK.
To aid this, a new item type and collect targets will be introduced.

The `PrunedPackageReference` item will support the following attributes:

| Attribute | Explanation |
|-----------|-------------|
| Version | A NuGet parsable version. The version is consider to the maximum version to be pruned. |

The collect target will be `CollectPrunedPackageReferences`.

When NuGet sees any of these package ids in the resolution, it'll just skip them and log a message in detailed verbosity, indicating the package has been skipped.
Pruning direct PackageReference is *not allowed*.
We may capture some of this information in telemetry to track how often this feature is being used.

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
          "NuGet.Versioning": "6.10.0",
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
NuGet.Versioning is pruned. NuGet.Versioning will appear as a dependency, but it will not be in the list since it was never chosen.

`PackageSpec & project section of the assets file`

The list of PrunedPackageReference items must only include relevant packages.
It will be included in the "project" section of the assets file, internally called the PackageSpec, similarly like the centralPackageVersions.

```json
  "project": {
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
        "prunedPackageReferences": {
          "System.Text.Json": "8.0.5"
        }
```

### Additional validation considerations

- How does leaving the dependency in the assets file section affect features consuming the assets file.
  - The solution explorer tree - Prototype shows the solution explorer is skipping the reference.
  - PM UI tab - Prototype shows that since the reference does not really exist, it is not shown at all.
  - list package - Prototype shows that since the reference does not really exist, it is not shown at all.
  - dotnet nuget why - TODO NK

### NET SDK - selecting packages to be pruned

See [Prior art](#net-sdk-package-pruning) for more details on how the .NET SDK prunes packages at runtime today.
The particular pruning is based on the resulting list of shared frameworks.
The .NET SDK will provide the list at the beginning of the restore operation, as such the .NET SDK *must* only consider direct shared frameworks, and not transitive ones.
Given that packages are allowed to bring in a shared framework, and that is not known by the .NET SDK at the beginning of restore, package graphs brought in by packages are not going to be pruned with the current solution.

## Drawbacks

- The risk of this feature is driven by the packages that are being pruned. Given that the list of packages that will be provided by the SDK is already being pruned in a different way, one could argue that the risks have been well mitigated there.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

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

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

- This problem is .NET specific. Package pruning at the build level is already happening. 

### NET SDK package pruning

The .NET SDK assembly/package pruning is already happening currently.
The limitations of that implementation are that the package still appear in the assets file, still get downloaded and are thus included in the package auditing.
The pruning is happening on a per shared framework basis.
Example:

- Microsoft.NETCore.App 9.0 shared framework, <https://github.com/dotnet/runtime/blob/main/src/installer/pkg/sfx/Microsoft.NETCore.App/PackageOverrides.txt>

- Microsoft.AspNetCore.App 9.0 shared framework, <https://github.com/dotnet/aspnetcore/blob/main/eng/PackageOverrides.txt>

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

- MSBuild items/properties vs a file with the data
- MSBuild item name ideas: `PrunedPackageReference` was used. `IgnoredPackageReference` and `SkippedPackageReference` are alternatives.
- What if a project id is specified in PrunedPackageReference? Warn? Error? Skip? Prune & Warn?
- What to do when a direct PackageReference is specified to be pruned?
- Should the pruned package reference dissapear from the dependencies section completely? Strong preference towards no, since it aids visibility.
- Should the assets file contain the list of pruned packages? Are only ids important, or do we need versions as well?
- Should the version attribute of PrunedPackageReference be a version range instead? Should the attribute be named MaxVersion instead?

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

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
