# Global Package Reference for Central Package Management

- [Jeff Kluge](https://github.com/jeffkl)
- 2022-05-05
- [[Feature]: CPVM equivalent of GlobalPackageReference? (#10159)](https://github.com/NuGet/Home/issues/10159)
- GitHub PR (GitHub PR link)

## Summary
<!-- One-paragraph description of the proposal. -->
A common pattern in repositories is to have every project in the tree reference packages that are used for build purposes only.  This includes
packages that provide assembly versioning, signing, code analysis, etc.  We want to provide a built-in mechanism for users to define packages that
are used by every project but only for build purposes.

## Motivation 
<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Users can manually reference the package in a common import like `Directory.Build.props` but there is no built-in safe guards to ensure that they don't
accidentally consume more assets than just build-related assets.  For example, you don't want to have a package's compile-time assets be referenced by
every assembly in your repository.  Instead, individual projects should express their build time dependencies and project references should receive
them transitively.  But you should not need to add a package reference in order to have your whole tree use code analysis or assembly versioning.

## Explanation

### Functional explanation
<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
We'll introduce a new MSBuild item group named `<GlobalPackageReference />` which will define packages that every project should reference but has
default metadata to ensure that only package assets related to build purposes are used.

**NOTE:** This functionality will only be enabled if a user has opt-ed into [Central Package Management (CPM)](https://docs.microsoft.com/nuget/consume-packages/central-package-management).

```xml
<Project>
  <ItemGroup>
    <GlobalPackageReference Include="Nerdbank.GitVersioning" Version="1.0.0" />
  </ItemGroup>
</Project>
```

### Technical explanation
<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->
`<GlobalPackageReference />` will just be syntactical sugar for a `<PackageReference />` with the following metadata:

* IncludeAssets = `runtime; build; native; contentfiles; analyzers`
* PrivateAssets = `All`

This ensures that when these repository-wide packages are consumed, they don't flow to downstream dependencies and only include assets related to
build.

This will be achieved by copying the `GlobalPackageReference` items to `PackageReference` and `PackageVersion` items:
```xml
<Target Name="CollectCentralPackageVersions" Returns="@(PackageVersion)">
  <ItemGroup Condition="'$(ManagePackageVersionsCentrally)' == 'true' And '$(RestoreEnableGlobalPackageReference)' != 'false'">
    <!--
      Add GlobalPackageReference items to the PackageVersion item group with the version.  The PackageReference items are added
      in the CollectPackageReferences target.
    -->
    <PackageVersion Include="@(GlobalPackageReference)" Version="%(Version)" />
  </ItemGroup>
</Target>

<Target Name="CollectPackageReferences" Returns="@(PackageReference)" >
  <ItemGroup Condition="'$(ManagePackageVersionsCentrally)' == 'true' And '$(RestoreEnableGlobalPackageReference)' != 'false'">
    <!--
      Add GlobalPackageReference items to the PackageReference item group with no version.  The PackageVersion items are added
      in the CollectCentralPackageVersions target.

      Global package references only include the same assets as a development dependency (runtime; build; native; contentfiles; analyzers)
      because those kind of packages are the best candidate for a global package reference.  They are generally packages that
      extend the build.

      Global package references have all assets private because central package references are generally packages that provide
      versioning, signing, etc and should not flow to downstream dependencies.  Also, central package references are already
      referenced by every project in the tree so they don't need to be transitive.
    -->
    <PackageReference Include="@(GlobalPackageReference)"
                      Version=""
                      IncludeAssets="runtime; build; native; contentfiles; analyzers"
                      PrivateAssets="All" />
  </ItemGroup>
</Target>
```

The following MSBuild properties can be set to change the functionality:

| Property Name | Function | Default value|
|---|---|---|
| `ManagePackageVersionsCentrally` | Enables or disables central package management and all dependent features | `false` |
| `RestoreEnableGlobalPackageReference` | Enables or disables just the concept of `GlobalPackageReference` | `true` |

## Drawbacks
<!-- Why should we not do this? -->
There is a lot of "magic" with this implementation but good documentation should make things clear to customers.  This is also another support load
since the concept is brand new to a lot of users.  A decent amount of repositories are already doing some form of this though so it shouldn't be
entirely suprising to them when its introduced.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

## Prior Art
<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->
* `Microsoft.Build.CentralPackageVersions` has this concept today which is why we want to build it into our implementation of central package management
  https://github.com/microsoft/MSBuildSdks/tree/main/src/CentralPackageVersions#global-package-references

* Other repositories just place `<PackageReference />` items in a common import with `PrivateAssets="All"`
  https://github.com/dotnet/roslyn/blob/bac2055c0e30333facda79889e5c14d478f1d718/eng/targets/Settings.props#L122-L126

## Unresolved Questions
<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->
We need to determine if we can re-use the existing item group named `GlobalPackageReference`.  There may be conflicts with existing usage that could
cause build breaks.  The latest version of `Microsoft.Build.CentralPackageVersions` does disable itself if using the built-in NuGet CPM but users
could be on an older version.  However, we don't really need to support a repository that is using both.  The more concerning issue would be a
repository **not** using `Microsoft.Build.CentralPackageVersions` since NuGet would now be doing things with these items when it didn't before.
The solution would be to come up with a new item name that no one is using.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
