# ***Pruning platform provided packages***

- Nikolche Kolev <https://github.com/nkolev92>
- [7344](https://github.com/NuGet/Home/issues/7344)

## Summary

<!-- One-paragraph description of the proposal. -->
Provide a means to prune certain packages from packages because those packages are not going to be used at runtime.
This helps avoid downloading unnecessary reference and implementation packages that would not have their assemblies used because the versions in the .NET SDK or shared framework would be used instead.
Finally this avoids false positive by features such as NuGetAudit and other scanners that may be using the dependency graph.

## Motivation

In the early versions of .NET (Core), individual assemblies from the runtime were shipped as packages.
Starting with .NET (Core) 3.0, targeting packs were used for delivering references assemblies. The reference assemblies are no longer represented in graphs the way Microsoft.NETCore.App, Microsoft.AspNetCore.App, and NETStandard.Library were.
When a .NET (Core) 3.0 or later project depends on these older platform packages, we want them to be ignored in the graph, as those APIs are supplied by the platform via other mechanisms, such as targeting packs at build time and runtime packs for self-contained deployments.

Even .NET 9, there are certain assemblies that ship as both packages, but are also part of certain shared frameworks such as ASP.NET. See details <https://github.com/dotnet/aspnetcore/issues/3609>. An example of such assembly/package is `Microsoft.Extensions.Logging`, which is [published on nuget.org](https://www.nuget.org/packages/Microsoft.Extensions.Logging/), but also part of the Microsoft.AspNetCore.App shared framework. Currently there's conflict resolution in the .NET SDK to ensure that the latest version is chosen.

There are a few benefits:

It is trivial to make the assumption that the fewer packages need to be downloaded, the better the performance will be.
Beyond that, the extra packages within the graph, do make the resolution step more challenging. Some of the targeting packs used to bring in such a large package graph, that affected the resolution performance significantly. See  and <https://github.com/NuGet/Home/issues/11993> for more details. Furthermore, certain versions of popular packages have taken dependencies on these targeting packs for historical reasons. Such an example is <https://www.nuget.org/packages/log4net/2.0.10> which performs significantly better than <https://www.nuget.org/packages/log4net/2.0.9> when installed in a .NET (Core) projects, see <https://github.com/NuGet/Home/issues/10030>.

Certain versions of these packages are no longer  part of the project graph, thus reducing the chances of false positive scanning.
This is especially important in the context of assemblies that are part of shared frameworks. The build time conflict resolution ensures that the most up to date version is used, despite the fact that the user referenced package may habe vulnerabilities.
Examples: <https://github.com/dotnet/sdk/issues/30659#issuecomment-2072567192>.

This changes significantly helps align what gets restored and what gets published. By avoiding packages that are simply not going to be used at runtime, what gets used at runtime becomes more transparent.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

A list of package id/versions to be pruned will be provided by the .NET SDK. The version will signify the highest version to be pruned.
When NuGet encounters any of the specified packages or lower, it will simply remove the package from the graph. This package id will not appear in the assets file, but there will be a detailed verbosity message indicating that the package id has been pruned for the given framework.

The feature is framework specific, and can be opted in/out using the `NuGetPrunePlatformPackages` property.
In the first version in which the feature ships, it will be enabled by default for the framework that matches the major version of the .NET SDK. For example, if it ships in .NET 10, it will be automatically opted in for the `net10.0` framework. In the next version, it'll be enabled for frameworks netcoreapp3.0 and later.

### Technical explanation

A list of package id/versions to be pruned will be provided by the .NET SDK.
The list will be provided through a property pointing to a file that contains the list of packages in the `<id>|<version>` format, with a newline separating each package id. The property will be: `NuGetPlatformPackagesList`.

An example of the file format:

```txt
Microsoft.Win32.Registry|4.7.0
System.Diagnostics.EventLog|4.7.0
System.IO.Pipelines|4.7.0
System.Security.AccessControl|4.7.0
```

Note that this allows existing files such as `C:\Program Files\dotnet\packs\Microsoft.AspNetCore.App.Ref\3.1.10\data\PackageOverrides.txt` to be reused. TODO NK - OK, not really.

NuGet will assume that the file in question is immutable once written on disk. What this means is that in the up to date checks, NuGet just checks the file name, rather than the content itself. This approach matches the runtime.json approach.

When NuGet sees any of these package ids in the resolution, it'll just skip them. NuGet will log a detailed verbosity message, indicating the package has been skipped.
We may capture some of this information in telemetry to track how often this feature is being used.

## Drawbacks

- The risk of this feature is driven by the packages that are being pruned. Given that the list of packages that will be provided by the SDK is already being pruned in a different way, one could argue that the risks have been well mitigated there.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
- An alternative design would be to specify the package list via MSBuild properties.
  - Pros:
    - The feature can be generalized, since MSBuild time manipulation provides more flexibility in specifying these packages.
  - Cons:
    - The list of packages is always couple of hundred long and can only grow.
    This would be duplicate for each framework and project.
    We're paying string allocation cost at both the project-system and NuGet side.

- With security being a focus of NuGet as a package manager, minimizing false positives is essential. The fact that there are still assemblies that ship both as packages and as part of shared frameworks means that the changes of false positives are not going away with a framework update.

- We can consider not doing this feature and relying on platform packages to simply go away, especially with NuGetAudit enabling transitive dependency auditing recently, but that is not going to solve the long term concern of assemblies such `Microsoft.Extensions.Logging`.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

- This problem is .NET specific.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

- How flexible should this feature be? MSBuild items vs a file.
  - If we go the approach of MSBuild items, what should the item name be? Example: `PrunedPackageReference`, `IgnorePackageReference`

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
