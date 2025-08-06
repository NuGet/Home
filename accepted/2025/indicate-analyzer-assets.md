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

This feature will initially be behind a feature flag defined as `<EnableIndicateAnalyzerAsset>`. 
This property should be set as true in the project file. 
This is done to avoid a breaking change.

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
- When <EnableIndicateAnalyzerAssets> is set to true, the SDK will only use the analyzer group that is in the assets file to determine which analyzers to include. 
- If the analyzers group is missing from the assets file and the feature flag is enabled, the won't fall back to legacy scanning. 
  - In this case, no analyzers will be selected, even if analyzer assets exist in the packages.
- If the feature flag is not set or is false, the SDK will use the legacy scanning behavior to discover analyzers and preserve compatibility. 

#### Testing

Validate correct behavior with:
- Analyzer packages with and without exclusion flags.
- Multi-targeted packages (ensure correct analyzer/TFM pairing).
- Projects with the feature flag enabled, confirming that included/excluded analyzers match expectations.

## Analyzer and Compile Asset Transitivity

NuGet handles different asset types (compile, analyzers, etc.) with specific rules for transitivity and filtering.

**Analyzers**
- Treated as private assets by default. They do not flow transitively, meaning that analazers from a package will not be included in projects that reference the package unless explicitly included.

**Compile Assets**
- These are transistive. Unless you explicity exclude them, they will flow through the entire dependency chain.

### Test Results
- Setting `ExcludeAssets="analyzers"` or `PrivateAssets="all"` on a `PackageReference` only affects that specific reference; analyzers do not flow through dependencies.
- Compile assets are transitive. If you set `ExcludeAssets="compile"` on a reference, compile-time assemblies from that reference are excluded, but will still flow from other dependencies unless also excluded.
- The risk of old packages unintentionally redistributing analyzers is low because analyzers must be explicitly included by the package author.


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

### Language Selection 

The .NET SDK and NuGet packaging system provide established support for language-specific content file selection using the `contentFiles/{language}/` convention. 
For example, a package can include assets such as `empty.txt` in both `contentFiles/cs/net9.0/` and `contentFiles/vb/net9.0/`, mapped via the `packagepath` property.

To validate this behavior, a test was performed using a .NET 9 project that packed `empty.txt` into both C# and VB.NET content file folders. 
The resulting NuGet package contained the file in both locations. When referenced by a C# project, only the C# content file was selected by the SDK; the VB.NET file was ignored.
This was confirmed by inspecting the `project.assets.json`, which included both files in the package metadata but only used the language-appropriate asset.

### Asset Filtering
Existing NuGet asset filtering (ExcludeAssets, PrivateAssets) works for compile, runtime, and other assets groups, providing a good model for how analyzer filtering should work

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

Something that would be valuable would be an analysis of NuGet packages that have analyzers, and focusing on analyzers as dependencies. 
It would also look at the impact of the `IncludeAssets` and `ExcludeAssets` settings. 

Ideally, this analysis would:
- Identify packages that rely on analyzers as dependencies and determine whether the new asset selection mechanics would change their behavior.
- Provide data on how many packages (and consumers) would be impacted by a change in default behavior, helping to mitigate surprises or unintended consequences.
- Affirm the correctness and robustness of the proposed design prior to broad deployment.

<!-- What future possibilities can you think of that this proposal would help with? -->

### References

- [Controlling dependency assets](https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files#controlling-dependency-assets)
- [Analyzer conventions](https://learn.microsoft.com/en-us/nuget/create-packages/analyzers)
