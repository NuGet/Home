# Opt-in experience for PrivateAssets and ExcludeAssets options are independent

- Author Name <https://github.com/erdembayar>
- Start Date 2022-12-07
- GitHub Issue <https://github.com/NuGet/Home/issues/6938>
- GitHub PR <https://github.com/NuGet/NuGet.Client/pull/4976>

## Summary

<!-- One-paragraph description of the proposal. -->
Currently asset consumption via `PrivateAssets` option experience for assets from transitive package in a project/package is not deterministic for parent consuming project, here `PrivateAssets` option calculation is not independent from `IncludeAssets/ExcludeAssets` option.
This proposal introduces new a `PrivateAssetIndependent` opt-in property to make `PrivateAssets` option independent from `IncludeAssets/ExcludeAssets` option.
In below both `Consumption via package reference` and `Consumption via project reference` sub-sections are explaining same things for 2 different scenarios. So, I intentionally choose bit examples in them to expose what problem we're solving with this new opt-in feature.

### Consumption via package reference

The `IncludeAssets`/`ExcludeAssets`, and `PrivateAssets` metadata on `PackageReference` items control two different features. Firstly, which assets from a package that are included in the current project. Secondly, whether the assets will be listed in the package's dependency assets, for those assets to flow transitively, if the project is packed.

For example, `<PackageReference Include="Microsoft.SourceLink.GitHub" Version="1.0.0" PrivateAssets="all" />` means "Include the default assets in the current project, but if packed or consumed via a ProjectReference, all of the assets are excluded, so this package will not be a dependency".

Another example, `<PackageReference Include="NuGet.Protocol" Version="6.4.0" PrivateAssets="compile" />` means "include the default assets in the current project, but if packed or consumed via a ProjectReference, the "compile" asset should be excluded from the package dependency, so that my package's dependencies do not leak APIs into projects using my package".

A third example, `<PackageReference Include="Microsoft.Build" Version="17.0" ExcludeAssets="runtime" />` means "in the current project, make the `compile` assets available (so both intellisense and the compiler can access APIs from the package), but `Microsoft.Build`'s dlls are not copied to `bin` on build (`runtime` assets), and if the project is packed or consumed via a ProjectReference, then `runtime` assets also be excluded for the `Microsoft.Build` dependency for any project that references the current project's package.

However, a scenario that is missing is "exclude a package asset from a current project, but do not exclude it from the dependency when the current project is packed", i.e
`<PackageReference Include="Microsoft.Windows.CsWin32" Version="0.2.138-beta"  PrivateAssets="none" IncludeAssets="none" />`.
This missing feature is more obvious when looking at a project/flow matrix below (see 3rd row), because `PrivateAssets` is not independent from `IncludeAssets`. We want to change that with opt-in property, it would let assets flow to the parent project on that case.

Let's consider some particular asset (e.g. `build`, `compile`, or even `all`) that may appear in the list of `IncludeAssets` or `PrivateAssets` metadata. When it appears in one or both of these lists, they may interact to control whether the asset flows transitively. The ☑️ symbol means this asset is listed in that metadata, and 🔲 means it is _not_ listed. Note that presence in PrivateAssets indicates that an asset should *not* flow transitively.

IncludeAssets|PrivateAssets|Flows transitively
--|--|--
☑️ | 🔲 | ✅
☑️ | ☑️ | ❌
🔲 | 🔲 | ❌ (unexpected?)
🔲 | ☑️ | ❌

Note how `PrivateAssets` can only subtract assets from the assets listed by `IncludeAssets`. It cannot *add* them by setting `PrivateAssets=none`. This means (without the feature described in this spec) that there is simply no way to flow an asset transitively that is not also directly consumed by the project.

### Consumption via project reference

The above observation applies to `ProjectReference` from 'parent' projects too when `restore/build` operation happens.
Let's say the current project is `LibraryProj.csproj` and parent project has `<ProjectReference Include="..\LibraryProj.csproj" />` reference to it.

For example, `<PackageReference Include="Microsoft.SourceLink.GitHub" Version="1.0.0" PrivateAssets="none" />` in `LibraryProj.csproj` means  "Include the default assets in the current project, but all assets flow to parent project".

Another example, `<PackageReference Include="Microsoft.SourceLink.GitHub" Version="1.0.0"  IncludeAssets="none" />` in `LibraryProj.csproj` means "Consume no assets in the current project, but default assets flow to parent project".

However if we combine above examples where both cases some assets flowing to parent project, `<PackageReference Include="Microsoft.Windows.CsWin32" Version="0.2.138-beta"  PrivateAssets="none" IncludeAssets="none" />`, the current experience is that no asset flows into parent project even though it requested all assets flow to parent project (see above table 3rd row), because `PrivateAssets` is not independent from `IncludeAssets`. We want to change that with opt-in property, it would let assets flow to the parent project in that case.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
A package author should be able to deterministically decide which asset flow to parent consuming projects when this project is consumed as package. It enables parent projects to consume transitive packages without having to directly reference them, therefore it reduces the number of packages developers need to keep track of. So, it'll give more flexible control to the package author, not less.
We couldn't make this default experience because it'll break customers who rely on current behavior.

In addition to the above code author should be able to deterministically decide which asset flow to parent consuming projects when this project is consumed as project reference(P2Ps that reference this project).
If the current project consuming any packages, then it can be transitively consumed by parent project if code author wants to.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
The new `PrivateAssetIndependent` property causes the `PrivateAssets` metadata to exclusively decide which assets flow to consuming parent project, but doesn't affect restore experience for current project so there would be no change in `project.assets.json` lock file, i.e it doesn't change `IncludeAssets/ExcludeAssets` calculation for current project.

It'll change how `compile, runtime, contentFiles, build, buildMultitargeting, buildTransitive, analyzers, native` dependencies flow into the projects consuming it via `PackageReference` and `ProjectReference` references.

For the following table assume `PrivateAssetIndependent` opt-in property is set `true` in current project, iterating possible scenarios (not full list) for consuming parent project.

| Asset flowing to parent project | New feature enabled | Possible downside |
|-----------------------|--------------|-----------------|
| compile | Expose new code, auto complete, intellicode, intellisense | Compile error due to naming ambiguity, run time error, NU1605 error |
| runtime | Let provide new runtime dependency | Run time error |
| build | Enable msbuild imports | Build fails due to property/target value change |
| analyzers | Code analyzers work | n/a |

Recall our table from earlier that shows which assets flow based on listing some asset in `IncludeAssets` and/or `PrivateAssets`. Below we add a 4th column that reveals the new flow behavior when the new behavior is activated:

IncludeAssets|PrivateAssets|Flows transitively (default)|Flows transitively (PrivateAssetIndependent=true)
--|--|--|--
☑️ | 🔲 | ✅ | ✅
☑️ | ☑️ | ❌ | ❌
🔲 | 🔲 | ❌ | ✅
🔲 | ☑️ | ❌ | ❌

Notice how transitive flow is controlled exclusively by the `PrivateAssets` value when `PrivateAssetIndependent` is set to `true`.

#### Examples

##### Case 1 for PackageReference

Package reference in csproj file.

```.net
  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
    <VersionSuffix>beta</VersionSuffix>
    <PrivateAssetIndependent>True</PrivateAssetIndependent>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Windows.CsWin32" Version="0.2.138-beta" PrivateAssets="none" IncludeAssets="build" />
  </ItemGroup>
```

Before change nuspec file:

```.net
    <dependencies>
      <group targetFramework=".NETStandard2.0">
        <dependency id="Microsoft.Windows.CsWin32" version="0.2.138-beta" exclude="Runtime,Compile,Native,Analyzers,BuildTransitive" />
      </group>
    </dependencies>
```

After change nuspec file:

```.net
    <dependencies>
      <group targetFramework=".NETStandard2.0">
        <dependency id="Microsoft.Windows.CsWin32" version="0.2.138-beta" include="All" />
      </group>
    </dependencies>
```

##### Case 2 for PackageReference

Package reference in csproj file.

```.net
  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
    <VersionSuffix>beta</VersionSuffix>
    <PrivateAssetIndependent>True</PrivateAssetIndependent>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Windows.CsWin32" Version="0.2.138-beta" PrivateAssets="none" IncludeAssets="none" />    
  </ItemGroup>
```

Before change nuspec file:

```.net
    <dependencies>
      <group targetFramework=".NETStandard2.0" />
    </dependencies>
```

After change nuspec file:

```.net
    <dependencies>
      <group targetFramework=".NETStandard2.0">
        <dependency id="Microsoft.Windows.CsWin32" version="0.2.138-beta" include="All" />
      </group>
    </dependencies>
```

##### Case for Project to Project reference

`ProjectReference` in parent `ClassLibrary1` csproj file:

```.net
  <PropertyGroup>
    <TargetFramework>net7.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\refissue\refissue.csproj" />
  </ItemGroup>
```

And `PackageReference` in `refissue.csproj` file:

```.net
  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
    <VersionSuffix>beta</VersionSuffix>
    <PrivateAssetIndependent>True</PrivateAssetIndependent>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.Windows.CsWin32" Version="0.2.138-beta" PrivateAssets="none" ExcludeAssets="all" />
  </ItemGroup>
```

Before changing, `Microsoft.Windows.CsWin32.props` file in `build` asset doesn't flow to ClassLibrary1.csproj.nuget.g.props file in obj folder.

After change, `Microsoft.Windows.CsWin32.props` file in `build` asset flow to ClassLibrary1.csproj.nuget.g.props file in obj folder.

### Technical explanation

We already have a [logic](hhttps://github.com/NuGet/NuGet.Client/blob/380415d812681ebf1c8aa0bc21533d4710514fc3/src/NuGet.Core/NuGet.Commands/CommandRunners/PackCommandRunner.cs#L577-L582) that combines `IncludeAssets/ExcludeAssets` options with `PrivateAssets` for pack operation, we just make logic depending on opt-in property.

## Drawbacks

<!-- Why should we not do this? -->
- Might break some consuming projects, that is why it's opt-in feature. See table in #functional-explanation above for more details.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
- We could make it opt-in option in `nuget.config` file, but it doesn't give customer to option to opt in/out for per project level.

```.net
   <config>
    <add key="PrivateAssetIndependent" value="true" />
  </config>
```

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
