# Specifying Versions for Transitive Dependencies
Central Package Version Management (CPVM) is a feature set in NuGet that allows you to manage package versions in one place.  Consider the following packages are available:

| Id | Version | Dependencies |
|-----:|:---------|-----|
| PackageA | 1.0.0 | PackageC >= 3.0.0 |
| PackageB | 2.0.0 | PackageC >= 4.0.0 |
| PackageC | 3.0.0 |  |
| PackageC | 4.0.0 |  |
| PackageC | 5.0.0 |  |

## Referencing packages without CPVM
This section explains how to specify a different version of a transitive dependency when using the standard mechanism for referencing packages and specifying versions.

**`ClassLibrary1.csproj`**
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net5.0</TargetFramework>
    <GeneratePackageOnBuild>true</GeneratePackageOnBuild>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="PackageA" Version="1.0.0" />
    <PackageReference Include="PackageB" Version="2.0.0" />
  </ItemGroup>
</Project>
```

`PackageA` and `PackageB` both transitively depend on `PackageC` but different versions, `3.0.0` and `4.0.0` respectively.  NuGet will unify this to the minimum version that satisifies the requirements which is **`4.0.0`**.

During Pack, the resulting package will have the top-level dependencies on `PackageA` and `PackageB` and the transitive dependencies of `PackageC` will be resolved by the consumer:

**`ClassLibrary1.nuspec`**
```xml
<dependencies>
  <group targetFramework="net5.0">
    <dependency id="PackageA" version="1.0.0" exclude="Build,Analyzers" />
    <dependency id="PackageB" version="2.0.0" exclude="Build,Analyzers" />
  </group>
</dependencies>
```
Since version `4.0.0` of `PackageC` was used in this scenario, it is okay for the generated package to transitively depend on `4.0.0` since consumers of this library will end up using hte same version of `PackageC` that was used by this package.

### Overriding transitive versions
If a user wants to override the transitive version of `PackageC`, they must add an explicit `PackageReference` item:
```diff
<ItemGroup>
  <PackageReference Include="PackageA" Version="1.0.0" />
  <PackageReference Include="PackageB" Version="2.0.0" />
+ <PackageReference Include="PackageC" Version="5.0.0" />
</ItemGroup>
```

This eclipses the transitive version of `PackageC` since it is newer which results in referencing `PackageC` version **`5.0.0`**.  This affects the restored packages, reference assemblies passed to the compiler, files copied to the output directory, and dependencies in used during package creation.

```diff
<dependencies>
  <group targetFramework="net5.0">
    <dependency id="PackageA" version="1.0.0" exclude="Build,Analyzers" />
    <dependency id="PackageB" version="2.0.0" exclude="Build,Analyzers" />
+   <dependency id="PackageC" version="5.0.0" exclude="Build,Analyzers" />
  </group>
</dependencies>
```
Note that since **`PackageC` is no longer considered transitive, it must now be elevated to be a top-level dependency of my package**.  This is because `ClassLibrary1` was built against version `5.0.0` of `PackageC` so the transitive dependencies of `PackageA` and `PackageB` are no longer accurate.  The act of "pinning" a version of a transitive dependency effectively transformed it into an explicit dependency.

## Referencing packages with CPVM

To manage the package versions in one location, the `Version` metadata is removed from `PackageReference` items in the project:

**`ClassLibrary1.csproj`**
```diff
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net5.0</TargetFramework>
    <GeneratePackageOnBuild>true</GeneratePackageOnBuild>
  </PropertyGroup>
  <ItemGroup>
-   <PackageReference Include="PackageA" Version="1.0.0" />
+   <PackageReference Include="PackageA" />
-   <PackageReference Include="PackageB" Version="2.0.0" />
+   <PackageReference Include="PackageB" />
  </ItemGroup>
</Project>
```

And a `Directory.Packages.props` file is created with the following content:

**`Directory.Packages.props`**
```xml
<Project>
  <ItemGroup>
    <PackageVersion Include="PackageA" Version="1.0.0" />
    <PackageVersion Include="PackageB" Version="2.0.0" />
  </ItemGroup>
</Project>
```

All projects in the repository that reference `PackageA` or `PackageB` explicitly will use the specified value in a corresponding `PackageVersion` item.

If a user wants to override the transitive version of `PackageC`, they must add an explicit `PackageReference` item:
```diff
<ItemGroup>
  <PackageReference Include="PackageA" />
  <PackageReference Include="PackageB" />
+ <PackageReference Include="PackageC" />
</ItemGroup>
```

And add a corresponding `PackageVersion` item to Directory.Packages.props:
```diff
<ItemGroup>
  <PackageVersion Include="PackageA" Version="1.0.0" />
  <PackageVersion Include="PackageB" Version="2.0.0" />
+ <PackageVersion Include="PackageC" Version="5.0.0" />
</ItemGroup>
```

The result is the same as before where the resolved `PackageC` is version **`5.0.0`** and affects the restored packages, reference assemblies passed to the compiler, files copied to the output directory, and dependencies in used during package creation.  The transitive dependency is no longer considered transitive and instead is an explicit dependency.

### Proposal to allow transitive version selection based on specified PackageVersion items
In the previous example, a user must specify an explicit `PackageReference` to a package to override the transitive version.  This elevates the reference from transitive to explicit and behaves as a user expects.  However, some users want a `PackageVersion` to automatically override a transitive version even without an explicit top-level `PackageReference`.  The reason for this feature request is for better **scale** and **performance**.

#### Addressing Scale
For larger repositories, requiring users to specify explicit `PackageReference` items in each project can become difficult.  This is because you may need to add it to dozens of projects in order to unify the version used across the repo.  Since CPVM is used to centralize package versions, it makes sense to have transitive reference version overrides to be implied when specifying a `PackageVersion`.  There are however at least two drawbacks of this approach:

1. **Confusion** about "pinning" a transitive version - Many users consider overriding a transitive version to be pinning that version in the graph.  In some cases they consider this gesture only part of Restore and Build.  But since they've overridden a transitive version, this also flows to Pack which affects the versions used as dependencies.  When transitive versions are are "pinned", they are really just elevated to top-level dependencies which causes this confusion.  We will need to educate users on how this feature works so they understand that it is not really just pinning a version but instead is actually making it an implicit reference.

3. How to opt out - If transitive version overrides are automatic when a `PackageVersion` is specified, there will need to be a way for a user to opt out of this behavior for one or more `PackageReference` items.  In previous versions of NuGet, a user could only opt into transitive version overrides by _adding_ a `PackageReference` item.  But to opt out of newer behavior, they will not have a `PackageReference` item to remove.  An MSBuild property could be used to opt an entire project out of transitive version overrides but that would not address a single `PackageReference` item.

Some ideas on this are the following:

**Metadata on a PackageReference to opt out**
```xml
<ItemGroup>
   <PackageReference Include="PackageC" Pin="false" />
</ItemGroup>
```
**Drawback**: A user has to _add_ a `PackageReference` to opt it out of behavior which is not a great user experience.

**Users follow a pattern to disable a PackageVersion item**

```diff
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    ...
+   <PinPackageC>false</PinPackageC>
  </PropertyGroup>
</Project>
```

**Directory.Packages.props**
```diff
<ItemGroup>
- <PackageVersion Include="PackageC" Version="5.0.0" />
+ <PackageVersion Include="PackageC" Version="5.0.0" Condition="'$(PinPackageC)' != 'false'" />
</ItemGroup>
```

**Drawbacks**: Requires users to follow a well documented convention which leaves a lot of room for error.

#### Addressing Performance
Users have provided feedback that overriding transitive versions improves the overall time of restore because it simplifies the graph by reducing the amount of walking performed by the resolution algorithm.  Obviously it would not scale for each and every project in a tree to specify all `PackageReference` items so it only makes sense for the central version file to contain all of the versions.  Large repositories would experience more benefit from this since smaller repositories generally have fast restore times.  One drawback of relying on transtiive package version overrides is that restore could get slow again as users add top-level packages but don't add new transitive dependencies or update the versions.  There would be nothing built-in to remind them that the restore graph has gotten more complex so they would be in a constant battle of updating all their versions.  This could be handled by tooling but it would be a better user experience if NuGet restore performance was made better across the board and the act of walking large graphs be made faster and more optimized.  This could be done by caching graph walks for subsequent restores or profiling and optimizing the algorithm.  If we improved the performance of restore, users would not need to rely on transitive package version overrides to get fast restore times.

### Other considerations

#### Respecting assets of transitive dependencies
Today when you set `IncludeAssets`, `ExcludeAssets`, or `PrivateAssets` on a top-level dependency, the values flow to transitive dependencies.  Also, a package itself can define what assets to consume.  For example, if a package's dependency specifies different assets than the default:

```xml
<dependencies>
  <group targetFramework="net5.0">
    <dependency id="PackageC" version="5.0.0" exclude="Build,Analyzers,Runtime" />
  </group>
</dependencies>
```

And a user overrides the transitive dependency version:

```xml
<ItemGroup>
  <PackageReference Include="PackageC" Version="6.0.0" />
</ItemGroup>
```
This overrides the consumed assets today.  If `PackageVersion` items override a version such as:
```xml
<Project>
  <ItemGroup>
    <PackageVersion Include="PackageC" Version="6.0.0" />
  </ItemGroup>
</Project>
```

Then the consumed assets will probably need to be set to whatever were defined in the package dependency rather than overriding them.  This is because `PackageVersion` is only there to override the version.

## Questions We Have

1. Are you confused about the transitive behavior of what "pinning" a reference does today? (i.e. promotes a transitive dependency to a top-level dependency implicitly).
2. Is it important to you to be able to optionally remove a single `PackageReference` from the same "pinning" behavior?
3. Would you expect `IncludeAssets`, `ExcludeAssets`, or `PrivateAssets` to be respected when overriding a dependency?
4. Do you understand that this feature is primarily designed for usability & maintainability of your packages in a central location? It does not guarantee any performance benefits with as your projects scale.