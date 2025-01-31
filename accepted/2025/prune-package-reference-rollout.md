# PrunePackageReference in .NET 10

- Nikolche Kolev <https://github.com/nkolev92>
- [#NuGet/Client.Engineering#3110](https://github.com/NuGet/Client.Engineering/issues/3110)

## Summary

`NuGetAudit` scans the dependencies in your package graph for vulnerabilities, reporting vulnerabilities for every package that ended up in your resulting graph.

[`PrunePackageReference`](https://github.com/NuGet/Home/blob/dev/accepted/2024/prune-package-reference.md) allows NuGet to skip platform packages that are already available within the framework that the project is building.
For example, if your project, targetting .NET 9 has a transitive dependency to System.Text.Json 8.0.4, which is vulnerable, enabling pruning will allow NuGet to prune it from the defined list of dependencies during graph resolution. This package will not be downloaded and it will not appear in the resolved dependency graph.

We propose that we enable the `PrunePackageReference` feature by default for *all* .NET (Core) and .NET Standard 2.0 and above in .NET 10 preview 1 to reduce false positives by NuGetAudit and related scanning tools and improve performance.

This has 2 benefits:

1. Reduces false positives by NuGet Audit, Component Governance and other dependency auditing tools.
Our data investigations show that up 30% of transitive vulnerabilities are within packages that may be removed by pruning.
1. Improves performance, by virtue of having smaller dependency graphs and fewer packages downloaded.

For a feature like this, normally we'd need roll it out based on the target framework, but our telemetry shows that up to 30% of transitive vulnerability warnings may be addressed by enabling the pruning feature.
The list of packages being removed is the exact same that's part of the build time conflict resolution in the .NET SDK. In a way, this moves the conflict resolution to an earlier part of the build.
The packages that are being pruned carried assemblies that were excluded from the final output of the project by the aforementioned conflict resolution.

- As we are enabling this feature in .NET 10 Preview 1, it gives a very long runway should we eventually decide to go with a more convervative roll-out strategy.
- If there are any issues, users can easily disable the feature by setting `RestoreEnablePackagePruning` to `false` in their project/props.
- We will continuously monitor telemetry and feedback around the feature through all the previews.

### Testing & Validation

The feature has been development since November and the implementation has been extensively tested through automation, but we also ensured that our own repos can dogfood without any issues.

We validated the .NET SDK build that it *does not affect the builds negatively of the following repos*:

- NuGet/NuGet.Client
- dotnet/sdk
- dotnet/roslyn - <https://github.com/dotnet/roslyn/pull/76898>
- dotnet/runtime - <https://github.com/dotnet/runtime/pull/111767>
- dotnet/aspnetcore - <https://github.com/dotnet/aspnetcore/pull/60025>

### Observable build changes

- Customers who expect the output of their project to produce identical results will notice smaller deps files. This is intentional.
- Customers who observe the output of component governance / NuGet Audit will notice these components are no longer reported. This is intentional.
- Customers who use packages lock files (1% usage) with locked mode may run into restore failures due to restore bringing in fewer dependencies. This is intentional.
- Customers with builds that have customization may run into build failures if they are:
  - Manually referencing an assembly or props/targets from a package from the global packages folder. Note that pruning is not allowed for direct dependencies, so this would need to be a transitive package.
    - Manually copying assembly during a build - at runtime, the platform version will be preferred anyways, but it could lead to the build failing if the package cannot be found on disk anymore.
  - We don't expect this to be a common scenario given that the packages being pruned are within the framework and customers do not need do to anything custom to make things work.

## Rationale and alternatives

- Roll-out the feature based on the target framework.
  - Enable pruning for .NET 10 frameworks only.
  - Enable pruning for all frameworks of projects that target .NET 10 (ie. multi-targetting .NET 10 and NET 8.0 in a project enables pruning for both).
- Enable pruning when NuGetAuditMode is set to `all` - reducing transitive false positives for audit.

## Prior Art

- Pruning is the restore equivalent of [the build time conflict resolution](<https://github.com/dotnet/sdk/blob/262b9c3d6cf67287f649e38d83e6c5d9d08feb8a/src/Tasks/Common/ConflictResolution/ResolvePackageFileConflicts.cs#L178-L182>), that is current enable for every framework.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

- Enabling pruning for .NET Framework.
