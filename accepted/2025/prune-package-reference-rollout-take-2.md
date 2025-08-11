# PrunePackageReference in .NET 10

- Nikolche Kolev <https://github.com/nkolev92>
- <https://github.com/NuGet/Home/issues/14345>

## Summary

In this document, the various roll-out options for [PrunePackageReference](https://github.com/NuGet/docs.microsoft.com-nuget/blob/main/docs/consume-packages/Package-References-in-Project-Files.md#prunepackagereference).

The ideas explored are:

- Enabling pruning for all .NET versions + .NET Standard 2.0+ (.NET 10 Preview 1 behavior)
- Enabling pruning for .NET 8+ and .NET Standard 2.0+ (proposed .NET 10 Preview 7 behavior)
- Enabling pruning for .NET 10 only (new)
- Enabling pruning for all frameworks when .NET 10 is targeted  (new)
- Enabling pruning when NuGetAuditMode is all. (new)

Post-discussion, the discussion was to go with `Enabling pruning for all frameworks when .NET 10 is targeted  (new)`.

## Motivation

The main benefits of pruning

1. Reduces false positives by NuGet Audit, Component Governance and other dependency auditing tools.
Our data investigations show that up 30% of transitive vulnerabilities are within packages that may be removed by pruning.
This improves the confidence in NuGetAudit and reduces unnecessary alerts by scanners that do not ship as part of the .NET SDK tooling.
1. Improves performance, by virtue of having smaller dependency graphs and fewer packages downloaded.

The following list summarizes the list of per framework changes that would happen with pruning enabled.

### Observable build changes for pruning

- Transitive packages:
  - Packages are removed and not downloaded. Packages are excluded from the project.assets.json and deps.json files, compared to the previous experience.
- Direct packages, `PrivateAssets='all'` and `IncludeAssets='none'` are implicitly applied.
  - `IncludeAssets='none'` ensures that the assemblies from this package are not used during the build. Before pruning existed, the conflict resolution during the build ensured that platform assemblies were preferred over those coming from the packages.
  - `PrivateAssets='all'` ensures that the packages aren't included in packages or through project references.
- Customers with builds that have customization may run into build failures if they are:
  - Manually referencing an assembly or props/targets from a package from the global packages folder. Note that pruning does not remove direct dependencies, so this would need to be a transitive package.
    - Manually copying assembly during a build - at runtime, the platform version will be preferred anyways, but it could lead to the build failing if the package cannot be found on disk anymore.
  - Aliases for PackageReference that will be pruned will stop working. This is *unlikely* to be a problem, since we normally wouldn't expect customers to alias platform packages.
  - We don't expect this to be a common scenario given that the packages being pruned are within the framework and customers do not need to do anything custom to make things work.
- If the project targets .NET 10, [NU1510](https://github.com/NuGet/docs.microsoft.com-nuget/blob/main/docs/reference/errors-and-warnings/NU1510.md) and [NU1511](https://github.com/NuGet/docs.microsoft.com-nuget/blob/main/docs/reference/errors-and-warnings/NU1510.md) may be raised.

## Explanation

### Pruning in .NET 10 historical log

- .NET 10 Preview 1
  - default for every framework when using the .NET 10. SDK Details in the following design: <https://github.com/NuGet/Home/blob/dev/accepted/2025/prune-package-reference-rollout.md>.
  Given that this was an early preview, we considered 
  - NU1510, warning for prunable direct PackageReference was raised on a per framework level in every situation pruning was enabled.
- .NET 10 Preview 3
  - NU1510, warning for prunable direct PackageReference, was gated behind .NET 10 frameworks only. This meant that it was no longer a breaking change.
- .NET 10 Preview 5
  - NU1510 heuristic was updated
- .NET 10 Preview 7
  - Direct PackageReference within pruning range are automatically applied with `PrivateAssets=all` and `IncludeAssets=none`. <https://github.com/NuGet/Home/blob/dev/accepted/2025/PrunePackageReference-with-direct-PackageReference>.

### What went wrong

During the insertion into .NET 10 SDK Preview 7, <https://github.com/dotnet/sdk/pull/49740>, we discovered a bug in the .NET Core App 2.2 and below pruning behavior.
In particular, pruning applied `IncludeAssets=none` to `Microsoft.NETCore.App`, since it was specified for pruning.
This is a conflict in the input for restore, since `Microsoft.NETCore.App` is actually needed for building netcoreapp2.2 and below. <https://github.com/dotnet/sdk/issues/49917>

### What did we do

Given that .NET 10 Preview 7 was really close to shipping, we decided to enable pruning for .NET8+ as an immediate remediation. The motivation behind our policy was to enable by default for the frameworks in support, while minimizing the risk for unexpected bugs.
We are currently reevaluating what the best strategy in terms of feature benefit + risk is.

### Enable per framework comparison

For the following list comparing the approaches a few things are important to consider:

- NuGetAuditMode=all for projects targeting .NET 10 or above.
What this means is that if at least 1 framework is .NET 10, the whole projects auditing warnings.
NuGetAudit cannot be partially enabled.
    | Frameworks | NuGetAuditMode |
    |------------|----------------|
    | net10.0 | all |
    | net9.0 | direct |
    | net9.0;net10.0 | all |
- Pruning runs per framework, or in other words, it can be partially enabled.
- Every customer can enable pruning in their projects already (shipped originally in 9.0.200) by setting `RestoreEnablePackagePruning=true`
- We should fix <https://github.com/dotnet/sdk/issues/49917>, regardless of the defaults, but some defaults increase the criticality of it. We can always say pruning is not supported for <= .NET (Core) 2.2.

#### All .NET & .NET Standard 2.0 >=

Pros:

- NET 10 P1 behavior. Nearly completely eliminates false positives in NuGetAudit, component governance and 3rd party scanners.
  - We have had pruning for transitive enabled since .NET 10 preview 1, and we have not received any breaking bugs aside from the NU1510 diagnostics, which has been fixed, and is disabled for projects targeting .NET 9 and earlier)
- Unnecessary platform packages will not be a part of any package built with the .NET 10 SDK (due to direct PrivateAssets=all)

Cons:

- Potential of a breaking change for pre-existing projects.
- NuGetAuditMode is gonna be direct for a large majority of existing projects, which target .NET 9 and older (Only 1% of restores have manually enabled NuGetAuditMode=all)
We will see reduction in downloads of these packages and reduction of these packages being part of newly published packages, but we won't necessarily reduce the warnings count (overall we do want to eliminate vulnerable package usage).
The primary benefit is prunable packages not appearing in newly published packages due to automatic PrivateAssets=all.

#### >= .NET (Core) 3 & .NET Standard 2.0 >=

Pros:

- Nearly completely eliminates NuGetAudit and component governance false positives. .NET CoreApp 2.2 comprise under 10% of projects.
- Bug free zone. This is the broadest set of frameworks we can enable it for that has not encountered pruning bugs yet.

Cons:

- Potential of a breaking change for pre-existing projects.
- NuGetAuditMode is gonna be direct for a large majority of existing projects (Only 1% of restores have NuGetAuditMode=all)
We will see reduction in downloads of these packages and reduction of these packages being part of newly published packages, but we won't necessarily reduce the warnings count, since the warnings are not being raised (overall we do want to eliminate vulnerable package usage).
The primary benefit is prunable packages not appearing in newly published packages due to automatic PrivateAssets=all.
- If we are going to go with this approach, we are better off fixing the bug and enabling it for all .NET frameworks or just declaring pruning unavaiable for <= .NET Core 2.2 and not fixing the bug.

#### >= .NET 8 & .NET Standard 2.0 >=

Pros:

- Enables pruning for all in support frameworks. Providing benefits to projects staying current.
- Does not address false positives for every customer currently getting false positive warnings (see example: <https://github.com/dotnet/sdk/issues/49226>). 
- Still impacts a considerable amount of projects, about 2/3 of projects.

Cons:

- Potential of a breaking change for pre-existing projects. These are projects target actively supported runtimes, so these users may be more receptive of the risk.
- NuGetAuditMode is gonna be direct for a large majority of existing projects (Only 1% of restores have NuGetAuditMode=all)
We will see reduction in downloads of these packages and reduction of these packages being part of newly published packages, but we won't necessarily reduce the warnings count (overall we do want to eliminate vulnerable package usage).
The primary benefit is prunable packages not appearing in newly published packages due to automatic PrivateAssets=all.
- We are making a TFM based enablement on the runtime supported, but that logic really only applies for applications, but pruning and audit are enabled for both apps and libraries. Library authors will often target lower version of the framework because that's all they need.
Some relevant context in <https://github.com/dotnet/sdk/issues/28518>.

### >= .NET 10 only

Pros:

- Not a breaking change.
- Addresses false positives for .NET 10 and above

Cons:

- Does not address false positives for every customer actively getting false positive warnings (0% of projects in 17.14 get the benefit.)
- Projects multi targeting .NET 10 and above, get only partial benefits, since pruning will only work for .NET 10. Say they System.Text.Json 8.0.0 in project targeting .NET 10, and .NET 8, they'll get a false positive warning because pruning is not enabled for .NET 8.
- NU1510, unnecessary package warning, is likely to never be triggered for multi-targeted projects.

### NuGetAuditMode=all enables pruning

Pros:

- Nearly completely eliminates NuGetAudit false positives
- Potential breaking change only for 1% of total .NET SDK projects.
- NU1510, unnecessary package warning, will be triggered correctly in all scenarios (.NET 10 only warning, so no breaking change.)
- Can choose to combine this with `>= .NET 10 only` and `>= .NET 8 & .NET Standard 2.0 >=`.

Cons:

- Potential of a breaking change for pre-existing projects. However, the benefits for these customers are more obvious, since they are likely to see fewer vulnerability warnings. They made an explicit decision to adopt NuGetAudit, and they will likely be receptive of a feature improve NuGetAudit itself. (see example: <https://github.com/dotnet/sdk/issues/49226>)
- Features get a bit tangled and enabling one feature opting you into another one could cause confusion.

### >= .NET 10 enables pruning for all frameworks

Pros:

- Not a breaking change.
- Addresses false positives for .NET 10 and above.
- Projects multi-targeting .NET 10  get full benefits of pruning.
Matches the NuGetAudit behavior, so new defaults work well together, but are still independent (ie, you could have pruning without audit).

Cons:

- Does not address false positives for every customer actively getting false positive warnings (0% of projects in 17.14 get the benefit.)

## Prior Art

- Pruning is the restore equivalent of [the build time conflict resolution](<https://github.com/dotnet/sdk/blob/262b9c3d6cf67287f649e38d83e6c5d9d08feb8a/src/Tasks/Common/ConflictResolution/ResolvePackageFileConflicts.cs#L178-L182>), that is currently enabled for every framework.

## Unresolved Questions

## Future possibilities

- Consider enabling for all frameworks in future releases.
- Encourage customers with NuGetAuditMode=all to enable pruning
