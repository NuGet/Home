# CPVM Project Package Version Override

Users have indicated that Central Package Version Management (CPVM) needs a mechanism to override the centrally managed versions of packages on a project-by-project basis. Project Package Version Override allows individual projects to import different versions of NuGet packages organized in the same, centralized location.

# Design Goals

1. Even though package versions need to be specified for specific projects, keep the package versions centralized. Avoid situations where solution-level and project-level package version management are mixed in the same repository.
2. Provide a means for organizing multiple package versions together.
3. Manage the package versions of transitive dependencies alongside direct dependencies.
4. Follow the MSBuild approach with minimal changes to existing XML patterns.

# Feature Behavior

- All `<PackageVersion>` should be defined within `Directory.Packages.props`, and `Version` may not be defined on `<PackageReference>` within projects.
    - Specifying a `Version` on a `<PackageReference>` will throw a build error.
    - Specifying a `<PackageVersion>` within a project file is an anti-pattern, and it will generate a build time warning. It will not throw an error, and a developer may choose to suppress the warning by specifying `<AllowProjectPackageVersion>true</AllowProjectPackageVersion>` within a `<PropertyGroup>`.
- A `<PackageVersion>` may have a `CentralManagementGroup` defined which allows a `<PackageReference>` to refer to this version using the `CentralManagementGroup` attribute.
    - When a `Version` to be imported by a `<PackageReference>` needs to be different than the global group defined in `Directory.Packages.props`, a `CentralManagementGroup` can be specified on both the `<PackageReference>` in a project file and a corresponding `<PackageVersion>` in `Directory.Packages.props` that specifies the needed `Version`.
    - A `<PackageReference>` may only have one `CentralManagementGroup` defined.
    - A project can include references to multiple `CentralManagementGroup`.
    - When `CentralManagementGroup` is not specified, both `<PackageVersion>` and `<PackageReference>` reference a global `CentralManagementGroup` that is automatically created.
- Transitive dependencies are resolved based on finding a common level of specificity between direct imports.
    - If a transitive dependency is imported by a package defined within the global group, then the `<PackageVersion>` for the transitive dependency from the global group applies.
    - If a transitive dependency is imported by a package in multiple `CentralManagementGroup` that both include a `<PackageVersion>` for that transitive dependency, then the `<PackageVersion>` for the transitive dependency from the global group applies.
    - If a transitive dependency is imported by a `<PackageReference>` with a `CentralManagementGroup` specified, then the `<PackageVersion>` for the transitive dependency from the `CentralManagementGroup` applies. If the transitive dependency does not have a matching `<PackageVersion>` within the same `CentralManagementGroup`, then the global group applies.
    - If a transitive dependency is initiated by multiple packages within multiple, different `CentralManagementGroup` but **only one** of the `CentralManagementGroup` specifies a `<PackageVersion>` for the transitive dependency, then that version is used.
    - If a transitive dependency is initiated by multiple packages within multiple, different `CentralManagementGroup` and multiple `CentralManagementGroup` specify **the same** `<PackageVersion>` for the transitive dependency, then the common version is used.
    - If a transitive dependency is initiated by multiple packages within multiple, different `CentralManagementGroup` and multiple `CentralManagementGroup` specify **different** `<PackageVersion>` for the transitive dependency, then the project will throw a build error due to a [cousin dependency](https://docs.microsoft.com/en-us/nuget/concepts/dependency-resolution#cousin-dependencies) conflict.

# Examples

*Directory.Packages.props* for Examples

```xml
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <!-- When CentralManagementGroup is unspecified for a <PackageVersion>, the <PackageVersion> is part of the default global group. -->
    <ItemGroup>
        <PackageVersion Include="Serilog" Version="2.9.0" />
        <PackageVersion Include="Newtonsoft.Json" Version="12.0.2" />
        <PackageVersion Include="foo" Version="1.1.1" />
    </ItemGroup>
    <!-- Each <PackageVersion> within this <ItemGroup> belongs to the "A" group as specified in their CentralManagementGroup attributes. -->
    <ItemGroup>
        <PackageVersion Include="Newtonsoft.Json" Version="11.0.2" CentralManagementGroup="A" />
        <PackageVersion Include="foo" Version="2.2.2" CentralManagementGroup="A" />
        <PackageVersion Include="qux" Version="2.0.0" CentralManagementGroup="A" />
        <PackageVersion Include="xyzzy" Version="2.0.0" CentralManagementGroup="A" />
        <!-- bar has a dependency on foo 202.0.0 -->
        <!-- bar has a dependency on qux 202.0.0 -->
        <!-- bar has a dependency on xyzzy 202.0.0 -->
        <PackageVersion Include="bar" Version="20.0.0" CentralManagementGroup="A" />
    </ItemGroup>
    <!-- Each <PackageVersion> within this <ItemGroup> belongs to the "B" group as specified in their CentralManagementGroup attributes. -->
    <ItemGroup>
        <PackageVersion Include="foo" Version="3.3.3" CentralManagementGroup="B" />
        <PackageVersion Include="qux" Version="3.0.0" CentralManagementGroup="B" />
        <!-- baz has a dependency on foo 303.0.0 -->
        <!-- baz has a dependency on qux 303.0.0 -->
        <!-- baz has a dependency on xyzzy 303.0.0 -->
        <PackageVersion Include="baz" Version="30.0.0" CentralManagementGroup="B" />
    </ItemGroup>
</Project>
```

In this `Directory.Packages.props` file, there are three `CentralManagementGroup` of `<PackageVersion>` defined.

1. The global `CentralManagementGroup` is automatically created, and all `<PackageVersion>` that do not have the `CentralManagementGroup` attribute defined belong to this group.
2. `CentralManagementGroup="A"` defines a `CentralManagementGroup` with `<PackageVersion>` for 5 packages.
3. `CentralManagementGroup="B"` defines a `CentralManagementGroup` with `<PackageVersion>` for 3 packages.

*Example Package to Demonstrate Version Override*

There are two `<PackageVersion>` defined for `Newtonsoft.Json` to demonstrate using both the global and a named `CentralManagementGroup`.

- If a `<PackageReference>` does not specify a `CentralManagementGroup`, it will import version 12.0.2 from the global group.
- If `CentralManagementGroup=A` is defined, it will import 11.0.2 from group A.

*Example Packages to Demonstrate Transitive Import Behavior*

Package `foo` has three `<PackageVersion>` defined.

- `foo` is defined in both the global group and two named `CentralManagementGroup`.
- `foo` is a transitive dependency of `bar` and `baz` which are defined in two different `CentralManagementGroup`.

Package `qux` has two `<PackageVersion>` defined in two different `CentralManagementGroup`.

- `qux` **is not** defined in the global group.
- `qux` is a transitive dependency of `bar` and `baz` which are defined in two different `CentralManagementGroup`.

Package `xyzzy` is only defined within one named `CentralManagementGroup`.

- `xyzzy` **is not** defined in the global group.
- `xyzzy` is a transitive dependency of `bar` which is defined in the same group.
- `xyzzy` is a transitive dependency of `baz`, but it does not have a `<PackageVersion>` defined in the same group as `baz`.

### Sample Project 1: Global Group

*1.csproj*

```xml
<Project>
  <ItemGroup>
    <!-- global group -->
    <!-- Version 2.9.0 -->
    <PackageReference Include="Serilog" />
    <!-- global group -->
    <!-- Version 12.0.2 -->
    <PackageReference Include="Newtonsoft.Json" />
    <!-- global group -->
    <!-- Version 1.1.1 -->
    <PackageReference Include="foo" />
  </ItemGroup>
</Project>
```

This project file represents the simple case where all `<PackageReference>` use versions from the global `CentralManagementGroup`.

There are no project package version overrides necessary for this project.

### Sample Project 2: Single Named Group

*2.csproj*

```xml
<Project>
  <ItemGroup>
    <!-- global group -->
    <!-- Version 2.9.0 -->
    <PackageReference Include="Serilog"/>
    <!-- "A" group -->
    <!-- Version 11.0.2 -->
    <PackageReference Include="Newtonsoft.Json" CentralManagementGroup="A" />
    <!-- "A" group -->
    <!-- Version 2.2.2 -->
    <PackageReference Include="foo" CentralManagementGroup="A" />
    <!-- "A" group -->
    <!-- Version 2.0.0 -->
    <PackageReference Include="qux" CentralManagementGroup="A" />
    <!-- "A" group -->
    <!-- Version 2.0.0 -->
    <PackageReference Include="xyzzy" CentralManagementGroup="A" />
    <!-- "A" group -->
    <!-- Version 20.0.0 -->
    <PackageReference Include="bar" CentralManagementGroup="A" />
  </ItemGroup>
</Project>
```

This project uses two  `CentralManagementGroup`, `"A"` and the global group.

All `<PackageReference>` dependencies are included in this `CentralManagementGroup` and are directly imported.

### Sample Project 3: Transitive Dependency Resolution A

3*.csproj*

```xml
<Project>
  <ItemGroup>
    <!-- "A" group -->
    <!-- Version 20.0.0 -->
    <PackageReference Include="bar" CentralManagementGroup="A" />
  </ItemGroup>
</Project>
```

This project uses a single `CentralManagementGroup="A"`.

`bar` has three dependencies. These are transitive dependencies for the project.

- `foo` is imported with version 2.2.2 from `CentralManagementGroup="A"` because `foo` has a `<PackageVersion>` defined for group `"A"`.
- `qux` is imported with version 2.0.0 from `CentralManagementGroup="A"` because `qux` has a `<PackageVersion>` defined for group `"A"`.
- `xyzzy` is imported with version 2.0.0 from `CentralManagementGroup="A"` because `xyzzy` has a `<PackageVersion>` defined for group `"A"`.

### Sample Project 4: Transitive Dependency Resolution B

4*.csproj*

```xml
<Project>
  <ItemGroup>
    <!-- "B" group -->
    <!-- Version 30.0.0 -->
    <PackageReference Include="baz" CentralManagementGroup="B" />
  </ItemGroup>
</Project>
```

This project uses a single `CentralManagementGroup="B"`.

`baz` has three dependencies. These are transitive dependencies for the project.

- `foo` is imported with version 3.3.3 from `CentralManagementGroup="B"` because `foo` has a `<PackageVersion>` defined for group `"B"`.
- `qux` is imported with version 3.0.0 from `CentralManagementGroup="B"` because `qux` has a `<PackageVersion>` defined for group `"B"`.
- `xyzzy` is imported with version 303.0.0 because `baz` has a direct dependency on `xyzzy` version 303.0.0. There is no `<PackageVersion>` defined for `xyzzy` in group `"B"`.

### Sample Project 5: Single Named Group with Transitive Dependencies

5*.csproj*

```xml
<Project>
  <ItemGroup>
    <!-- global group -->
    <!-- Version 2.9.0 -->
    <PackageReference Include="Serilog"/>
    <!-- "A" group -->
    <!-- Version 11.0.2 -->
    <PackageReference Include="Newtonsoft.Json" CentralManagementGroup="A" />
    <!-- "A" group -->
    <!-- Version 20.0.0 -->
    <PackageReference Include="bar" CentralManagementGroup="A" />
  </ItemGroup>
</Project>
```

This project uses two  `CentralManagementGroup`, `"A"` and the global group.

`bar` has three dependencies. These are transitive dependencies for the project.

- `foo` is imported with version 2.2.2 from `CentralManagementGroup="A"` because `bar` is imported from the same group.
- `qux` is imported with version 2.0.0 from `CentralManagementGroup="A"` because `bar` is imported from the same group.
- `xyzzy` is imported with version 2.0.0 from `CentralManagementGroup="A"` because `bar` is imported from the same group.

### Sample Project 6: Multiple Named Groups

6*.csproj*

```xml
<Project>
  <ItemGroup>
    <!-- global group -->
    <!-- Version 2.9.0 -->
    <PackageReference Include="Serilog"/>
    <!-- "A" group -->
    <!-- Version 11.0.2 -->
    <PackageReference Include="Newtonsoft.Json" CentralManagementGroup="A" />
    <!-- "B" group -->
    <!-- Version 3.3.3 -->
    <PackageReference Include="foo" CentralManagementGroup="B" />
  </ItemGroup>
</Project>
```

This project uses three  `CentralManagementGroup`, `"A",` `"B"`, and the global group.

All `<PackageReference>` dependencies are included between these `CentralManagementGroup` and are directly imported.

### Sample Project 7: Multiple Named Groups with Transitive Dependencies

7*.csproj*

```xml
<Project>
  <ItemGroup>
    <!-- global group -->
    <!-- Version 2.9.0 -->
    <PackageReference Include="Serilog"/>
    <!-- "A" group -->
    <!-- Version 11.0.2 -->
    <PackageReference Include="Newtonsoft.Json" CentralManagementGroup="A" />
    <!-- "A" group -->
    <!-- Version 20.0.0 -->
    <PackageReference Include="bar" CentralManagementGroup="A" />
    <!-- "B" group -->
    <!-- Version 3.3.3 -->
    <PackageReference Include="foo" CentralManagementGroup="B" />
  </ItemGroup>
</Project>
```

This project uses three  `CentralManagementGroup`, `"A",` `"B"`, and the global group.

`bar` has three dependencies. These are transitive dependencies for the project.

- `foo` is imported with version 3.3.3 from `**CentralManagementGroup="B"` because `foo` is directly imported**.
- `qux` is imported with version 2.0.0 from `CentralManagementGroup="A"` because `bar` is imported from the same group.
- `xyzzy` is imported with version 2.0.0 from `CentralManagementGroup="A"` because `bar` is imported from the same group.

### Sample Project 8: Multiple Named Groups with Transitive Dependency Conflicts

*8.csproj*

```xml
<Project>
  <ItemGroup>
    <!-- global group -->
    <!-- Version 2.9.0 -->
    <PackageReference Include="Serilog"/>
    <!-- "A" group -->
    <!-- Version 11.0.2 -->
    <PackageReference Include="Newtonsoft.Json" CentralManagementGroup="A" />
    <!-- "A" group -->
    <!-- ❗ Throws an Error - Project Will Not Build ❗ -->
    <PackageReference Include="bar" CentralManagementGroup="A" />
    <!-- "B" group -->
    <!-- ❗ Throws an Error - Project Will Not Build ❗ -->
    <PackageReference Include="baz" CentralManagementGroup="B" />
  </ItemGroup>
</Project>
```

This project uses three  `CentralManagementGroup`, `"A",` `"B"`, and the global group.

`bar` and `baz` both have three dependencies. These are transitive dependencies for the project.

- `foo` is imported with version 1.1.1 from the global `CentralManagementGroup.`
    - `bar` and `baz` are in two different `CentralManagementGroup` that both have a `<PackageVersion>` for `foo`.
    - Because both groups have `<PackageVersion>` for `foo`, the conflict is resolved by fallback to the global group which has a `<PackageVersion>` defined for `foo`.
- `xyzzy` is imported with version 2.0.0 from `CentralManagementGroup="A"`.
    - There is no `<PackageVersion>` defined for `xyzzy` in `CentralManagementGroup="B"` that `baz` belongs to.
    - Because a `<PackageVersion>` is defined in only one group, that `CentralManagementGroup` can be resolved.
    - Because `bar` is imported from `CentralManagementGroup="A"` where there is a `<PackageVersion>` for `xyzzy`, version 2.0.0 is resolved.
- `qux` would throw a build error.
    - A `<PackageVersion>` for `qux` is defined in both `CentralManagementGroup` `"A"` and `"B"`.
    - No `<PackageVersion>` is defined for `qux` in the global group to resolve the conflict.
    - `bar` has a direct dependency on `qux` version 202.0.0 and `baz` has a direct dependency on `qux` version 303.0.0. An error would be thrown due to a [cousin dependency](https://docs.microsoft.com/en-us/nuget/concepts/dependency-resolution#cousin-dependencies) conflict.

### Sample Project 9: Undefined CentralManagementGroup Member

9*.csproj*

```xml
<Project>
  <ItemGroup>
    <!-- No entry for Newtonsoft.Json in the "B" group -->
    <!-- ❗ Throws an Error - Project Will Not Build ❗ -->
    <PackageReference Include="Newtonsoft.Json" CentralManagementGroup="B" />
  </ItemGroup>
</Project>
```

Because there is no entry for `Newtonsoft.Json` in `CentralManagementGroup="B"`, the project will throw an error and fail to build.

### Sample Project 10: Project Package Version Override Without Modifying Directory.Packages.props

> Note:
This is an anti-pattern, but it is described here for the benefit of developers who are unable to modify the Directory.Packages.props for their solution. Once the package version discrepancy is resolved or the Directory.Packages.props file can be updated, this implementation should be removed from your project.

*10.csproj*

```xml
<Project>
	<PropertyGroup>
    <AllowProjectPackageVersion>
        true
    </AllowProjectPackageVersion>
  </PropertyGroup>

  <ItemGroup>
		<!-- Remove version defined in Directory.Packages.props, if any --> 
    <PackageVersion Remove="Newtonsoft.Json" /> 
    <!-- Define PackageVersion which applies only to this project --> 
    <PackageVersion Include="Newtonsoft.Json" Version="12.0.3" />
    <!-- Version 12.0.3 -->
    <PackageReference Include="Newtonsoft.Json" />
  </ItemGroup>
</Project>
```

Including a `<PackageVersion>` outside of the `Directory.Packages.props` file will ordinarily throw a build warning.

By specifying `<AllowProjectPackageVersion>true</AllowProjectPackageVersion>` within the `<PropertyGroup>`, this example will build without a warning.

# Example Usage with Multi-Targeting

*Directory.Packages.props*

```xml
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <ItemGroup>
        <!-- When CentralManagementGroup is unspecified for a <PackageVersion>, the <PackageVersion> is part of the default global group. -->
        <PackageVersion Include="foo" Version="1.1.1" />
        <!-- These three CentralManagementGroup's are used for multi-targeting. -->
        <PackageVersion Include="foo" Version="2.2.2" CentralManagementGroup="A" />
        <PackageVersion Include="foo" Version="3.3.3" CentralManagementGroup="Anetcoreapp3.1" />
        <PackageVersion Include="foo" Version="4.4.4" CentralManagementGroup="Anet472" />
    </ItemGroup>
</Project>
```

In this `Directory.Packages.props` file, there are four `CentralManagementGroup` of `<PackageVersion>` defined.

- The global `CentralManagementGroup` is defined automatically and applies to version 1.1.1 of `foo` where no `CentralManagementGroup` is specified.
- `"A"`, `"Anetcoreapp3.1"`, `"Anet472"` are three different `CentralManagementGroup`. They are named similarly as a convention, but they remain three independent groups. MSBuild does not understand any relationship between these groups.

### Sample Project 11: Inline Multi-Targeting

*11.csproj*

```xml
<Project>
  <ItemGroup>
    <PackageReference Include="foo" CentralManagementGroup="Anetcoreapp3.1" Condition="'$(TargetFramework)' == 'netcoreapp3.1'" />
    <PackageReference Include="foo" CentralManagementGroup="Anet472" Condition="'$(TargetFramework)' == 'net472'" />
  </ItemGroup>
</Project>
```

During a build with .NET Core 3.1, `foo` will be imported with version 3.3.3.

During a build with .NET Framework 4.7.2, `foo` will be imported with version 4.4.4.

### Sample Project 12: <PropertyGroup> Multi-Targeting

*12.csproj*

```xml
<Project>
	<PropertyGroup Condition="'$(TargetFramework)' == 'netcoreapp3.1'">
		<FooPackageGroup>Anetcoreapp3.1</FooPackageGroup>
	</PropertyGroup>
	<PropertyGroup Condition="'$(TargetFramework)' == 'net472'">
		<FooPackageGroup>Anet472</FooPackageGroup>
	</PropertyGroup>

  <ItemGroup>
    <PackageReference Include="foo" CentralManagementGroup="$(FooPackageVersion)" />
  </ItemGroup>
</Project>
```

During a build with .NET Core 3.1, `foo` will be imported with version 3.3.3.

During a build with .NET Framework 4.7.2, `foo` will be imported with version 4.4.4.