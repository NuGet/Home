# project.assets.json should indicate analyzer assets
<!-- Replace `Title` with an appropriate title for your design -->

- Author Name: [kfikadu](https://github.com/kfikadu)
- GitHub Issue: [Issue #6279](https://github.com/NuGet/Home/issues/6279)

## Summary

`project.assets.json` does not currently indicate which analyzers are active, and analyzers are added even when `PrivateAssets` or `ExcludeAssets` should prevent this.
This leads to analyzers being included in projects, which are not the expected behavior, especially when defaults for private/excluded assets are not respected

## Motivation

Currently, analyzer assets in NuGet packages do not respect asset filtering options like ExcludeAssets and PrivateAssets, unlike other asset types (compile, runtime).
Analyzers are included based on pattern matching in package files, not by explicit references in project.assets.json.
Developers who try to exclude analyzers using asset filters still see analyzers loaded and executed during builds, leading to unexpected warnings or errors.
This causes wasted time, frustration, and confusion, as configuration changes appear ineffective and troubleshooting becomes more difficult.
Package authors cannot reliably control analyzer distribution or exclusion in downstream projects, making support and package design more complex.
Real-world feedback shows users resorting to custom MSBuild scripts, manual artifact modification, or abandoning packages due to inability to control analyzer inclusion.

## Explanation

### Functional explanation

Analyzer assets in NuGet packages will now respect asset filtering options like ExcludeAssets and PrivateAssets, just as other asset types do.
- When excluding analyzers from a package, they will no longer be included or executed during the project's build.
- Configurations will accurately control which analyzers are present, eliminating unexpected analyzer warnings or errors.
- Both package authors and consumers will have clear, reliable control over analyzer inclusion without needing custom workarounds.

This feature will initially be behind a feature flag to avoid doing a breaking change.

### Technical explanation

#### NuGet changes

Update the NuGet restore process to:
- Identify analyzer DLLs in each package.
- Filter out analyzers that are excluded by PrivateAssets/ExcludeAssets
- Add an "analyzers" group under the appropriate "targets" node for each package in project.assets.json.

Example Output
```json
"targets": {
  ".NETCoreApp,Version=v8.0": {
    "My.Analyzer.Package/1.0.0": {
      "analyzers": [
        "analyzers/dotnet/cs/MyAnalyzer.dll"
      ]
    }
  }
}
```

#### SDK Changes

Update SDK asset resolution logic (e.g., ResolvePackageAssets.cs) to:
- Read analyzer assets directly from the "analyzers" group in "targets", instead of scanning all files in "libraries".
- Only load analyzers are listed in this group.
- If the "analyzers" group is absent (e.g., from older lock files), fall back to legacy scanning to preserve compatibility

#### Testing

Validate correct behavior with:
- Analyzer packages with and without exclusion flags.
- Multi-targeted packages (ensure correct analyzer/TFM pairing).
- Projects with the feature flag enabled, confirming that included/excluded analyzers match expectations.

## Drawbacks

- Requires changes to both NuGet restore logic and .NET SDK asset resolution, which may increase maintenance complexity and introduce risk of regression.
- May require updates to existing tooling, documentation, or custom scripts that expect the current analyzer handling behavior.
- Potential for minor performance impact during restore and build, as asset filtering and lock file generation become more granular for analyzers.
- Older packages or tools that do not adopt the new pattern may continue to exhibit legacy behavior, requiring a fallback or compatibility layer that adds to system complexity.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

## Prior Art

- Existing NuGet asset filtering (ExcludeAssets, PrivateAssets) works for compile, runtime, and other assets groups, providing a good model for how analyzer filtering should work

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
