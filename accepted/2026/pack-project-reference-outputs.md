# Pack opted-in project reference outputs

- Author Name: [Saibamen](https://github.com/Saibamen)
- GitHub Issue: [#3891](https://github.com/NuGet/Home/issues/3891)

## Summary

Add an explicit opt-in for SDK-style pack to include selected `ProjectReference` build outputs in the parent `.nupkg`, instead of always representing project references as package dependencies. The feature is intended for projects that deliberately ship several implementation assemblies as one NuGet package, while preserving the existing default behavior for all project references.

## Motivation

`dotnet pack` and `msbuild /t:pack` currently treat project references as package dependencies. This is the right default for projects that are independently packaged and versioned, but it is painful for packages that intentionally expose one package while their implementation is split across multiple projects.

Common scenarios from [NuGet/Home#3891](https://github.com/NuGet/Home/issues/3891) include:

- A public client package that has one or more private implementation projects. The implementation assemblies are required at runtime, but the project owners do not want to publish, version, and support each implementation project as an independent package.
- A package that contains a tightly versioned set of assemblies, such as a facade/client assembly plus contracts or shared implementation that must always ship in the same package version.
- Migration from `nuget.exe pack -IncludeReferencedProjects`, nuspec-based packaging, or custom `TargetsForTfmSpecificBuildOutput` workarounds to SDK-style pack.
- Packages that need referenced project outputs in non-default package folders, such as analyzer or build-task packages, where the package author must choose the final package layout explicitly.

There are also important anti-scenarios. This feature should not make it easy to accidentally redistribute arbitrary assemblies, hide dependencies that should be modeled as packages, or bundle the same implementation assembly into several packages that can be installed together. The default behavior therefore remains unchanged, and package authors must opt in per reference.

## Explanation

### Functional explanation

By default, a `ProjectReference` continues to be represented as a package dependency when packing an SDK-style project:

```xml
<ProjectReference Include="..\Implementation\Implementation.csproj" />
```

To bundle the referenced project's output assemblies into the parent package, the package author sets `Pack="true"` on the project reference:

```xml
<ProjectReference Include="..\Implementation\Implementation.csproj" Pack="true" />
```

For this opted-in reference:

- The referenced project's build outputs are added to the parent package.
- The referenced project is not emitted as a nuspec dependency.
- Package dependencies needed by the bundled project are still emitted as package dependencies of the parent package, so consumers can restore the external packages needed at runtime.
- Symbols are included consistently with existing `IncludeSymbols` behavior.
- The default package location follows the existing pack convention for build output, for example `lib/<tfm>/Implementation.dll`.

If a bundled project references another project, the default behavior should be to include the project-reference closure under the opted-in project. This is required for runtime correctness in common "private implementation assembly" scenarios. The package author opts in at the first redistributed edge; NuGet then follows the restored project graph from that edge so the package contains the implementation assemblies needed by that bundled project.

The package author may override the destination with `PackagePath`:

```xml
<ProjectReference
  Include="..\Analyzer\Analyzer.csproj"
  Pack="true"
  PackagePath="analyzers/dotnet/cs" />
```

When `PackagePath` is specified, NuGet places the referenced project's outputs under that path instead of under `BuildOutputTargetFolder` and the target framework folder. The package author is responsible for choosing a path that is meaningful for the package type. For normal library assemblies, omitting `PackagePath` is preferred so outputs remain under the target framework's `lib` folder.

For multi-targeting projects, pack applies the behavior per target framework. A project reference that only applies to a subset of target frameworks is bundled only for those frameworks. The feature is also controlled by existing pack switches: if `IncludeBuildOutput=false`, bundled project build outputs are not added to the package.

### Technical explanation

The implementation should keep restore as the source of truth for the project graph. Pack should not rediscover an independent project graph or infer project reference metadata from only the entry project.

At restore time, NuGet should preserve pack-specific project reference metadata in the restore graph and `project.assets.json`:

- `Pack`
- `PackagePath`

This metadata must flow through the existing restore entry points:

- MSBuild restore
- Static graph restore
- Visual Studio nomination
- `project.assets.json` read/write round-tripping

At pack time, NuGet reads the assets file to identify the project references that opted in to bundling. It then collects build outputs through the existing pack output group targets, using the target framework from the restore graph and avoiding a rebuild of project references during output collection.

Dependency generation changes only for opted-in project references. The bundled project itself is suppressed as a nuspec dependency. Package dependencies reachable through the bundled project are promoted into the parent package dependency group so package consumers still restore required external packages. Project dependencies reachable through the bundled project are traversed so their package dependencies are promoted too.

The initial implementation should be conservative about the packaging surface:

- Include build outputs that existing pack output groups already understand.
- Include debug symbols through the existing debug symbol output groups when symbols are requested.
- Do not include arbitrary content, source, native assets, or runtime-specific assets from referenced projects unless a follow-up design explicitly defines those behaviors.
- Do not change nuspec pack.
- Do not change `nuget.exe pack -IncludeReferencedProjects`.
- Do not change the default handling of project references.

The current implementation shape uses two assets-file reads during pack: one to collect all project references for the existing package-version lookup, and one to collect the subset of project references whose outputs should be packed. The packed project-reference items carry `TargetFramework`, `BuildProjectReferences=false`, and, when specified, the requested package path.

## Drawbacks

Bundling referenced assemblies can create packages that are harder for consumers to reason about. Assemblies inside a package are not truly private in .NET's normal load context; consumers can still reference them, observe type identities, or encounter binding/version conflicts.

The feature can encourage package authors to avoid creating proper packages for independently useful components. If two packages bundle different versions of the same implementation assembly, a consuming application can see duplicate assembly conflicts that NuGet cannot resolve as package version conflicts.

The feature also makes pack more complex because restore metadata, assets-file serialization, dependency generation, and output collection all need to agree on the same project-reference metadata.

Promoting dependencies from bundled projects can also change the apparent dependency graph of the parent package. This is desirable when it preserves runtime dependencies, but it may surprise authors if a private project has package references they did not expect to expose to package consumers.

## Rationale and alternatives

The design uses per-reference opt-in because the current default is safer and well established. Automatically bundling all non-packable projects, or all projects without `PackageId`, would be more convenient for some repositories but could redistribute assemblies without a clear author decision.

`Pack="true"` is reused because pack already uses `Pack` metadata on other MSBuild items to mean "include this item in the package." Reusing the existing term is more discoverable than adding a new metadata name such as `IncludeOutputDll`, and it leaves room for package layout to be controlled by `PackagePath`.

`PackagePath` is reused because it already controls where packed items land in the package. A new metadata name such as `PackageRoot` would be narrower, but it would create a separate concept for project references without clear benefit. For project-reference outputs, `PackagePath` is intentionally treated as a single destination for the referenced project's output files rather than as the multi-destination content-file syntax.

An alternative is to require users to keep using `TargetsForTfmSpecificBuildOutput` and custom MSBuild targets. That avoids a product change, but it leaves users to manually copy assemblies, handle symbols, and replicate package dependencies from referenced projects. The long-running issue shows that these workarounds are common and easy to get wrong.

Another alternative is to revive a single switch equivalent to `IncludeReferencedProjects`. That is simpler to explain, but it is too broad for SDK-style pack because it does not force authors to identify which references are intended to be redistributed.

Another alternative is to require `Pack="true"` on every project-reference edge that should be bundled. That gives the author more control over redistribution, but it is easier to produce broken packages because the first bundled project may depend on another project whose assembly is required at runtime. Following the restored project-reference closure from an explicitly opted-in edge better matches the runtime shape of the bundled implementation.

## Prior Art

- `nuget.exe pack -IncludeReferencedProjects` supports a broad version of this behavior for legacy pack workflows.
- SDK-style pack already supports adding additional files through `TargetsForTfmSpecificBuildOutput` and `TfmSpecificPackageFile`, but users must hand-author the graph and dependencies.
- NuGetizer has prior art for distinguishing project references that should become dependencies from projects whose outputs should be bundled.
- The original MSBuild pack design states that project-to-project references are treated as NuGet package references by default.

## Unresolved Questions

- Should NuGet warn when an opted-in project reference points to a project that is itself packable or has a `PackageId`, since that may indicate the project should remain a package dependency?
- Should transitive bundled project outputs inherit the root opted-in reference's `PackagePath`, or should only the directly opted-in project's outputs use that override? Inheriting the path is simple, but may be wrong for mixed asset types.
- Should package dependencies promoted from bundled projects preserve all include/exclude/private asset metadata, or should pack define a narrower dependency projection for bundled projects? The current implementation promotes package dependencies with include/exclude information from the lock file and does not preserve a private-assets suppress-parent value.
- Should pack emit a warning when two bundled project outputs resolve to the same package path, beyond the existing duplicate file warning?
- Should this feature require any new package authoring guidance about licensing and redistribution of referenced project outputs?

## Future Possibilities

Future designs could extend this to content files, runtime-specific assets, native assets, analyzers, or source files from bundled project references. Those should be designed separately because each asset class has different package layout and consumer behavior.

NuGet could also add warnings or analyzers that detect likely anti-patterns, such as the same assembly being bundled into multiple packages in a repository, or a project being both bundled and published as a package dependency.
