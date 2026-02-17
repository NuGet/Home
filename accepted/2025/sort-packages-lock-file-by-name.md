# Sort packages.lock.json Dependencies by Name

- [Apoorv Darshan](https://github.com/apoorvdarshan)
- GitHub Issue: [#14115](https://github.com/NuGet/Home/issues/14115)

## Summary

This proposal adds alphabetical sorting by package name (within each dependency type group) when generating `packages.lock.json`, reducing diff churn and improving readability — especially when migrating to Central Package Management (CPM).

## Motivation

Currently, `packages.lock.json` dependencies are sorted only by their `PackageDependencyType` (Direct, Transitive, Project, CentralTransitive). Within each type group, the order depends on the resolution order of the dependency resolver, which can vary between restores.

This causes two problems:

1. **CPM migration diffs are noisy.** When adopting CPM, transitive dependencies that become centrally pinned change type from `Transitive` (enum value 1) to `CentralTransitive` (enum value 3). Since dependencies are ordered by type, these packages move from the middle of the file to the bottom — producing a large diff even when no package versions changed.

2. **Non-deterministic ordering.** Even without CPM, the order of packages within a type group can shift between restores, creating spurious diffs that make it harder to review meaningful changes like version bumps.

Adding a secondary sort by package name makes diffs minimal and meaningful, which is particularly valuable when using lock files to validate transitive dependency changes after enabling transitive pinning.

## Explanation

### Functional explanation

After this change, `packages.lock.json` dependencies within each target framework are sorted by:

1. **Primary key:** `PackageDependencyType` (Direct → Transitive → Project → CentralTransitive) — preserving the existing grouping behavior.
2. **Secondary key:** Package name (case-insensitive ordinal) — new, ensures stable alphabetical order within each group.

**Before (current behavior):**
```json
{
  "net8.0": {
    "Newtonsoft.Json": { "type": "Direct", ... },
    "Serilog": { "type": "Direct", ... },
    "System.Memory": { "type": "Transitive", ... },
    "Microsoft.Extensions.Logging": { "type": "Transitive", ... },
    "Azure.Core": { "type": "CentralTransitive", ... },
    "System.Text.Json": { "type": "CentralTransitive", ... }
  }
}
```

**After (proposed behavior):**
```json
{
  "net8.0": {
    "Newtonsoft.Json": { "type": "Direct", ... },
    "Serilog": { "type": "Direct", ... },
    "Microsoft.Extensions.Logging": { "type": "Transitive", ... },
    "System.Memory": { "type": "Transitive", ... },
    "Azure.Core": { "type": "CentralTransitive", ... },
    "System.Text.Json": { "type": "CentralTransitive", ... }
  }
}
```

Note: `Microsoft.Extensions.Logging` now appears before `System.Memory` in the Transitive group because of alphabetical ordering.

### Technical explanation

The change is in [`PackagesLockFileBuilder.cs`](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Commands/PackagesLockFileBuilder.cs) in the `NuGet.Client` repository, in the `CreateNuGetLockFile()` method where target dependencies are ordered before being assigned to the lock file target.

**Current code:**
```csharp
nuGettarget.Dependencies = nuGettarget.Dependencies
    .OrderBy(d => d.Type)
    .ToList();
```

**Proposed code:**
```csharp
nuGettarget.Dependencies = nuGettarget.Dependencies
    .OrderBy(d => d.Type)
    .ThenBy(d => d.Id, StringComparer.OrdinalIgnoreCase)
    .ToList();
```

`StringComparer.OrdinalIgnoreCase` is chosen because NuGet package IDs are case-insensitive. This is consistent with how package ID comparisons are performed elsewhere in the NuGet codebase.

**Lock file validation is unaffected.** `PackagesLockFileUtilities.IsLockFileStillValid()` compares dependencies using dictionary lookups keyed by package ID, not by list position. Changing the serialization order does not change the semantic content.

## Drawbacks

- **Lock file version bump consideration.** Any existing `packages.lock.json` files will be rewritten with the new ordering on the next restore, producing a one-time diff. However, this is the same class of change that occurs during any NuGet SDK update, and the resulting diffs are purely cosmetic.
- **Labeled as Breaking-Change.** While the lock file content is semantically identical, tools that do strict byte-for-byte comparison of lock files would see a difference. The NuGet lock file validation itself is not affected.

## Rationale and alternatives

### Why sort in the builder rather than the writer?

Sorting in `PackagesLockFileBuilder` (where ordering is already established) ensures the in-memory model is consistently ordered everywhere it's consumed. The alternative of sorting in `PackagesLockFileFormat.WriteTarget()` would only affect serialization but not any in-memory consumers.

### Why not sort only by name (ignoring type)?

Preserving the type-based grouping maintains the visual separation between Direct, Transitive, Project, and CentralTransitive dependencies, which aids readability when reviewing lock files. Removing the type grouping would be a more disruptive change with less clear benefit.

### Impact of not doing this

Without this change, teams adopting CPM will continue to see noisy, hard-to-review diffs in `packages.lock.json`, reducing the practical value of lock files as a validation tool for transitive dependency changes.

## Prior Art

- **`project.assets.json`** (NuGet's other lock file) already sorts many of its internal collections alphabetically, e.g., `library.Dependencies.OrderBy(dependency => dependency.Id, StringComparer.Ordinal)` in `LockFileFormat.cs`.
- **npm's `package-lock.json`** sorts packages alphabetically by name.
- **Yarn's `yarn.lock`** sorts entries alphabetically.
- **Cargo's `Cargo.lock`** sorts packages by name.

Alphabetical ordering in lock files is the industry standard.

## Unresolved Questions

- Should the lock file `version` field be incremented to signal the ordering change? This could allow tools to distinguish between old and new lock file formats, but may also force unnecessary lock file regeneration across projects.

## Future Possibilities

- The same alphabetical sorting could be applied when reading and normalizing lock files, ensuring that hand-edited or third-party-generated lock files also get normalized on the next restore.
- A `--sort` or `--normalize` flag for `dotnet restore` could allow explicit opt-in to lock file normalization without requiring a full restore.
