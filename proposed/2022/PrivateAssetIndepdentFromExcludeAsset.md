# Opt-in `PrivateAssets` asset flow control option precedence over `IncludeAssets/ExcludeAssets` option

- Author Name <https://github.com/erdembayar>
- Start Date 2022-12-07
- GitHub Issue <https://github.com/NuGet/Home/issues/6938>
- GitHub PR <https://github.com/NuGet/NuGet.Client/pull/4976>

## Summary

<!-- One-paragraph description of the proposal. -->
Currently `IncludeAssets/ExcludeAssets` options take precedence over `PrivateAssets` asset control option when creating package, so in many cases `IncludeAssets/ExcludeAssets` options completely eclipse the `PrivateAssets` option so doesn't let assets flow to consuming parent project. This proposal introduces new a `PackPrivateAssetsFlow` opt-in property so it let `PrivateAssets` asset control option takes precedence over `IncludeAssets/ExcludeAssets` options to enable asset flow to consuming parent projects.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
A package author should be able control which asset flow to parent consuming projects when this project is consumed as package. It enables parent projects to consume transitive packages without having to directly reference them, therefore it reduces the number of packages developers need to keep track of.
We couldn't make this default experience because it'll break customers who rely on current behavior.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
The new ` PackPrivateAssetsFlow` property only affects pack operation (more specifically nuspec in nupkg file), but doesn't affect restore experience for current project so there would be no change in `project.assets.json` lock file.
Experience for parent consuming project would be affected by which asset from `compile, runtime, contentFiles, build, buildMultitargeting, buildTransitive, analyzers, native` are flowing into them.

For the following table assume `PackPrivateAssetsFlow` is set `true` when creating package, iterating possible scenarios (not full list) for consuming parent project.

| Asset flowing to parent project | New feature enabled | Possible downside |
|-----------------------|--------------|-----------------|
| compile | Expose new code, auto complete, intellicode, intellisense | Compile error due to naming ambiguity, run time error, NU1605 error |
| runtime | Let provide new runtime dependency | Run time error |
| build | Enable source generator work | Build fails due to property/target value change |
| analyzers | Code analyzers work | n/a |

### Examples

#### Case 1

Before change nuspec file:

```.net
    <dependencies>
      <group targetFramework=".NETStandard2.0">
        <dependency id="Microsoft.Windows.CsWin32" version="0.2.138-beta" exclude="Runtime,Build,Native,Analyzers,BuildTransitive" />
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

**Case 2.**

```.net
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

### Technical explanation

We already have a [logic](hhttps://github.com/NuGet/NuGet.Client/blob/380415d812681ebf1c8aa0bc21533d4710514fc3/src/NuGet.Core/NuGet.Commands/CommandRunners/PackCommandRunner.cs#L577-L582) that combines `IncludeAssets/ExcludeAssets` options with `PrivateAssets`, we just change precedence on that logic depending on opt-in property.

## Drawbacks

<!-- Why should we not do this? -->
- Might break some consuming projects, that is why it's opt-in feature. See table above for more details.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
- We could make it per package level control metadata. But could be hard to use if the customer want to opt-in for all package references in current project.

`<PackageReference Include="contoso" Version="1.1.1" PackPrivateAssetsFlow="true"/>`

- We could make it opt-in option in nuget.config file, but it doesn't give customer to option to opt in/out for per project level.

```.net
   <config>
    <add key="PackPrivateAssetsFlow" value="true" />
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
