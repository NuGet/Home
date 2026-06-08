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
When enabled via `<RestoreEnableAnalyzerAssets>true</RestoreEnableAnalyzerAssets>`:
- Analyzers will be tracked in the `project.assets.json` file under a new "analyzers" group.
- PrivateAssets/ExcludeAssets will correctly filter analyzers, preventing them from being included in projects that should not have them.

This feature will initially be behind a feature flag defined as `<RestoreEnableAnalyzerAssets>`. 
This property should be set to true in the project file. 
This is done to avoid a breaking change.

### Technical explanation

#### File Structure

All `.dll` files under `analyzers/` are tracked, at any depth, excluding satellite `.resources.dll` assemblies. This mirrors the SDK's analyzer discovery, so the assets file does not assume a fixed folder layout.

|Pattern|Description|
|---|---|
|`analyzers/**/{name}.dll`|Any analyzer assembly, at any depth under `analyzers/`|
|`analyzers/dotnet/{language}/{name}.dll`|Language-specific analyzer (`cs`, `vb`, `fs`)|
|`analyzers/dotnet/{compilerApiVersion}/{language}/{name}.dll`|Analyzer for a specific compiler API version (`roslynX.Y`)|

The `{language}` and `{compilerApiVersion}` segments are optional and may appear at any depth. NuGet derives `codeLanguage` and `compilerApiVersion` metadata from them (see the example below) so the SDK can select the applicable analyzers, the same way `codeLanguage` is used for content files. Analyzers with no language segment get a `codeLanguage` of `any`, and `compilerApiVersion` is omitted when the path has no `roslynX.Y` segment. Excluded analyzers (for example via `PrivateAssets`) are written as a bare `analyzers/.../_._` placeholder with no metadata.

Examples: 
- `analyzers/dotnet/cs/MyAnalyzer.dll` (C# analyzer)
- `analyzers/dotnet/vb/MyAnalyzer.dll` (VB.NET analyzer)
- `analyzers/dotnet/roslyn4.0/cs/MyAnalyzer.dll` (C# analyzer for Roslyn 4.0+)

**NuGet Changes**

- Add "analyzers" group to project.assets.json during restore.
- Respect `PrivateAssets` and `ExcludeAssets` when populating this group.

**SDK Changes**

Update SDK asset resolution logic (e.g., ResolvePackageAssets.cs) to:
- Read analyzer assets directly from the "analyzers" group in "targets", instead of scanning all files in "libraries".
- Only load analyzers that are listed in this group.
- Select the applicable analyzers from the group using the `codeLanguage` and `compilerApiVersion` metadata (the group lists analyzers for all languages and compiler versions), mirroring how `codeLanguage` selects content files. When several analyzers apply to the same language, the SDK picks the highest applicable compiler API version.
- When `<RestoreEnableAnalyzerAssets>` is set to true, the SDK will only use the analyzer group that is in the assets file to determine which analyzers to include. 
- If the analyzers group is missing from the assets file and the feature flag is enabled, the SDK won't fall back to legacy scanning. 
- If the feature flag is not set or is false, the SDK will use the legacy scanning behavior to discover analyzers and preserve compatibility. 

**Example Output**
```json
"version": 4,
"targets": {
  ".NETCoreApp,Version=v11.0": {
    "My.Analyzer.Package/1.0.0": {
      "type": "package",
      "compile": { ... },
      "runtime": { ... },
      "analyzers": {
        "analyzers/dotnet/cs/MyAnalyzer.dll": {
          "codeLanguage": "cs"
        },
        "analyzers/dotnet/roslyn4.0/cs/MyAnalyzer.dll": {
          "codeLanguage": "cs",
          "compilerApiVersion": "roslyn4.0"
        }
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

| Attribute | What It Should Do | What Happens |
|-----------|-------------------|--------------|
| `PrivateAssets="analyzers"` | Prevent analyzers from flowing to dependent projects | Analyzers still flow transitively |
| `ExcludeAssets="analyzers"` | Exclude analyzers from this project entirely | Analyzers still included |
| `IncludeAssets="compile;runtime"` | Only include compile and runtime assets (exclude analyzers) | **Analyzers still included** - not controlled by asset filtering |

### New Behavior (With RestoreEnableAnalyzerAssets=true)

**Scenario 1: Library with PrivateAssets**
```xml
<!-- Library.csproj -->
<PackageReference Include="MyAnalyzer" Version="1.0.0" 
                  PrivateAssets="analyzers" /> <!--default value-->
```

**Library's project.assets.json:**
```json
"MyAnalyzer/1.0.0": {
  "type": "package",
  "analyzers": {
    "analyzers/dotnet/cs/MyAnalyzer.dll": {
      "codeLanguage": "cs"
    }
  }
}
```
**App's project.assets.json (references Library):**
```json
"MyAnalyzer/1.0.0": {
  "type": "package",
  "analyzers": {
    "analyzers/dotnet/cs/_._": {}
  }
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
- **Default Behavior of Analyzers:** `PrivateAssets=build;contentFiles;analyzers`
- **Without PrivateAssets:** Analyzers flow from C to B to A
- **With PrivateAssets on B's reference to C:** Analyzers stop at B

## Breaking Changes

### No Breaking Changes Initially 

Initially this feature is opt-in and is only honored for projects targeting .NET 11 or greater; on earlier target frameworks the property is ignored. Enabling it by default for the latest TFM is a later step in the rollout. 

The opt-in is via `<RestoreEnableAnalyzerAssets>true</RestoreEnableAnalyzerAssets>`, so existing projects will not be affected until they explicitly enable it on a supported target framework.

### When Enabled by Default

Projects using `PrivateAssets="analyzers"` or `ExcludeAssets="analyzers"` will start working as intended

**Build Behavior Changes:**
- Missing analyzer diagnostics in dependent projects
- Different warning/error counts in build output
- TreatWarningsAsErrors outcomes may change

**CI/CD Pipeline Impact:**
- Builds expecting certain analyzers may fail
- Builds may pass that previously failed on analyzer warnings
- Since analyzers are also source generators, it may fail because transitive analyzers that were included are no longer applied due to them respecting asset filtering.

**Mitigation:**
```xml
<PropertyGroup>
  <RestoreEnableAnalyzerAssets>false</RestoreEnableAnalyzerAssets>
</PropertyGroup>
```

### Rollout Strategy

The initial rollout is opt-in via `<RestoreEnableAnalyzerAssets>true</RestoreEnableAnalyzerAssets>`, and the opt-in is only available for projects targeting .NET 11 or greater; on earlier target frameworks it is ignored.
The next step is to enable it by default for projects that target .NET 11 or greater, while remaining opt-in elsewhere.
The last step will be to remove the feature flag. 


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

**Content Files**
Language-specific content selection (`contentFiles/{language}/`) demonstrates similar filtering patterns already work in the ecosystem.

The SDK is able to determine the project language by the type of project file: 
- `.csproj` files are treated as C# projects
- `.vbproj` files are treated as VB.NET projects

The NuGet package can contain analyzers and content files for multiple languages, and they are sorted into folders such as `contentFiles/cs/` and `contentFiles/vb/`.
During the restore process, NuGet lists all of the content files into the `project.assets.json` file, regardless of the language. 

In the `project.assets.json` file, each content file entry includes metadata, such as `"buildAction"`, `"codeLanguage"`, `"copyToOutput"`, etc. 
- The `codeLanguage` property is what enables the SDK to filter and include the files that are relevant to the project's language

For each file, MSBuild checks the `"codeLanguage"` property to determine if it should be included in the build
- If `"codeLanguage"` matches the project language, the file is included in the build. 
As a result, only the correct assets for the current project's are compiled, copied, or referenced. 

This is similar to language-specific analyzer selection (`analyzers/dotnet/{language}/`).
- The SDK determines the project language from the project file type (e.g., `.csproj`, `.vbproj`, `.fsproj`)

Example: 
- If a package contains `analyzers/dotnet/cs/Analyzer.dll` and `analyzers/dotnet/vb/VBAnalyzer.dll`:
  - The C# project will only include `Analyzer.dll`
  - The VB.NET project will only include `VBAnalyzer.dll`

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

This is a feature that is going to be enabled by default for all builds.

Something that would be valuable would be an analysis of NuGet packages that have analyzers, and focusing on analyzers as dependencies. 
It would also look at the impact of the `IncludeAssets` and `ExcludeAssets` settings. 

Ideally, this analysis would:
- Identify packages that rely on analyzers as dependencies and determine whether the new asset selection mechanics would change their behavior.
- Provide data on how many packages (and consumers) would be impacted by a change in default behavior, helping to mitigate surprises or unintended consequences.
- Affirm the correctness and robustness of the proposed design prior to broad deployment.

Also, provide analysis on source generators as analyzers. Since it is possible for people to depend on source generators in a way that their build will fail without them, there should be data on which ones may fail. 

Additional follow up should also be done in Component Governance. Currently, packages that exclusively contribute to `Compile` assets are treated as development dependencies.
There are special case analyzers, such as in the SDK, that should be removed once this feature is implemented. 

We should also consider creating a dedicated design time package graph. This will explicitly resolve and track packages that are meant to run as analyzers or tasks, making the process more accurate and maintainable
<!-- What future possibilities can you think of that this proposal would help with? -->

### References

- [Controlling dependency assets](https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files#controlling-dependency-assets)
- [Analyzer conventions](https://learn.microsoft.com/en-us/nuget/create-packages/analyzers)
