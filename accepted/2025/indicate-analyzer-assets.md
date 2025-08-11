# project.assets.json should indicate analyzer assets
<!-- Replace `Title` with an appropriate title for your design -->

- Author Name: [kfikadu](https://github.com/kfikadu)
- GitHub Issue: [Issue #6279](https://github.com/NuGet/Home/issues/6279)

## Summary

`project.assets.json` does not currently indicate which analyzers are active, and analyzers are added even when `PrivateAssets` or `ExcludeAssets` should prevent this.
This leads to analyzers being included in projects, which is not the expected behavior, especially when defaults for private/excluded assets are not respected

## Motivation

- Analyzer assets currently don't respect standard NuGet asset filtering options like `ExcludeAssets` and `PrivateAssets`.
- Developers can't control analyzer inclusion in their projects, leading to unexpected warnings or errors.
- Users are required to use custom MSBuild scripts or abandon packages due to inability to control analyzer inclusion.
- Package authors can't reliably control analyzer distribution

## Explanation

### Functional explanation

Enable analyzer assets to respect asset filtering options like other asset types.
When enabled via `<EnableIndicateAnalyzerAssets>true</EnableIndicateAnalyzerAssets>`:
- Analyzers will be tracked in the `project.assets.json` file under a new "analyzers" group.
- PrivateAssets/ExcludeAssets will correctly filter analyzers, preventing them from being included in projects that should not have them.
- Developers will gain proper control over analyzer inclusion

This feature will initially be behind a feature flag defined as `<EnableIndicateAnalyzerAssets>`. 
This property should be set as true in the project file. 
This is done to avoid a breaking change.

### Technical explanation

#### File Structure

|Pattern|Description|Example|
|---|---|---|
|`analyzers/dotnet/cs/{name}.dll`|C# analyzers|`analyzers/dotnet/cs/MyAnalyzer.dll`|
|`analyzers/dotnet/vb/{name}.dll`|VB.NET analyzers|`analyzers/dotnet/vb/MyAnalyzer.dll`|
|`analyzers/dotnet/{language}/{name}.dll`|Language-specific analyzers|`analyzers/dotnet/{language}/MyAnalyzer.dll`|

**NuGet Changes**

- Add "analyzers" group to project.assets.json during restore.
- Respect `PrivateAssets` and `ExcludeAssets` when populating this group.

**SDK Changes**

Update SDK asset resolution logic (e.g., ResolvePackageAssets.cs) to:
- Read analyzer assets directly from the "analyzers" group in "targets", instead of scanning all files in "libraries".
- Only load analyzers that are listed in this group.
- When `<EnableIndicateAnalyzerAssets>` is set to true, the SDK will only use the analyzer group that is in the assets file to determine which analyzers to include. 
- If the analyzers group is missing from the assets file and the feature flag is enabled, the SDK won't fall back to legacy scanning. 
  - In this case, no analyzers will be selected, even if analyzer assets exist in the packages.
- If the feature flag is not set or is false, the SDK will use the legacy scanning behavior to discover analyzers and preserve compatibility. 

**Example Output**
```json
"targets": {
  ".NETCoreApp,Version=v8.0": {
    "My.Analyzer.Package/1.0.0": {
      "type": "package",
      "compile": { ... },
      "runtime": { ... },
      "analyzers": {
        "analyzers/dotnet/cs/MyAnalyzer.dll": {}
      }
    }
  }
}
``` 

#### Testing

Validate correct behavior with:
- Analyzer packages with and without exclusion flags.
- Multi-targeted packages (ensure correct analyzer/TFM pairing).
- Projects with the feature flag enabled, confirming that included/excluded analyzers match expectations.

## Private Assets and Transitive Behavior

### Current Behavior (Without Feature Flag)

| Attribute | What It Should Do | What Actually Happens | project.assets.json |
|-----------|-------------------|----------------------|---------------------|
| `PrivateAssets="analyzers"` | Prevent analyzers from flowing to dependent projects | analyzers still flow transitively | No analyzer information tracked |
| `ExcludeAssets="analyzers"` | Exclude analyzers from this project entirely | analyzers still included | No analyzer information tracked |
| `IncludeAssets="compile;runtime"` | Only include compile and runtime assets (exclude analyzers) | **Analyzers still included** - not controlled by asset filtering | No analyzer information tracked |

### New Behavior (With EnableIndicateAnalyzerAssets=true)

**Scenario 1: Library with PrivateAssets**
```xml
<!-- Library.csproj -->
<PackageReference Include="MyAnalyzer" Version="1.0.0" 
                  PrivateAssets="analyzers" />
```

**Library's project.assets.json:**
```json
"MyAnalyzer/1.0.0": {
  "type": "package",
  "analyzers": {
    "analyzers/dotnet/cs/MyAnalyzer.dll": {}
  }
}
```
**App's project.assets.json (references Library):**
```json
"MyAnalyzer/1.0.0": {
  "type": "package"
  // No "analyzers" section - blocked by PrivateAssets
}
```

**Scenario 2: App with ExcludeAssets**
```xml
<!-- App.csproj -->
<PackageReference Include="LibraryWithAnalyzers" Version="1.0.0" 
                  ExcludeAssets="analyzers" />
```
Result: App's project.assets.json will not contain analyzer entries for LibraryWithAnalyzers

### How Transitivity Works

```
Project A -> Project B -> Package C (with analyzers)
```

- **Without PrivateAssets:** Analyzers flow from C to B to A
- **With PrivateAssets on B's reference to C:** Analyzers stop at B

## Breaking Changes

### No Breaking Changes Initially 

This feature is opt-in via `<EnableIndicateAnalyzerAssets>true</EnableIndicateAnalyzerAssets>`, so existing projects will not be affected until they explicitly enable it.

### When Enabled by Default

Projects using `PrivateAssets="analyzers"` or `ExcludeAssets="analyzers"` will start working as intended:

**Build Behavior Changes:**
- Missing analyzer diagnostics in dependent projects
- Different warning/error counts in build output
- TreatWarningsAsErrors outcomes may change

**CI/CD Pipeline Impact:**
- Builds expecting certain analyzers may fail
- Builds may pass that previously failed on analyzer warnings

**Mitigation:**
```xml
<PropertyGroup>
  <EnableIndicateAnalyzerAssets>false</EnableIndicateAnalyzerAssets>
</PropertyGroup>
```

### Rollout Strategy

1. **Current:** Opt-in via feature flag
2. **Future:** Enable by default with clear communication
3. **Later:** Remove feature flag


## Drawbacks

- Requires coordinated changes to NuGet and SDK
- Breaking change when enabled by default
- Potential minor performance impact during restore
- Older tools may not understand the new project.assets.json format

## Rationale and alternatives

This design is chosen to align with existing NuGet asset filtering patterns while providing a clear, structured way to manage analyzers.
By introducing a new "analyzers" group in `project.assets.json`, it allows for consistent handling of analyzers similar to other asset types, while respecting existing filtering options like `PrivateAssets` and `ExcludeAssets`.
It also maintains backward compatibility by being opt-in via a feature flag, allowing developers to adopt it gradually without breaking existing projects.
<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

## Prior Art

NuGet's existing asset filtering system (compile, runtime assets) provides the model.

Language-specific content selection (`contentFiles/{language}/`) demonstrates similar filtering patterns already work in the ecosystem.
For example, a package can include assets such as `empty.txt` in both `contentFiles/cs/net9.0/` and `contentFiles/vb/net9.0/`, mapped via the `packagepath` property.

To validate this behavior, a test was performed using a .NET 9 project that packed `empty.txt` into both C# and VB.NET content file folders. 
The resulting NuGet package contained the file in both locations. When referenced by a C# project, only the C# content file was selected by the SDK; the VB.NET file was ignored.
This was confirmed by inspecting the `project.assets.json`, which included both files in the package metadata but only used the language-appropriate asset.

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
