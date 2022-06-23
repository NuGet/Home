# Adding Dotnet CLI add package command support to projects onboarded with Central Package Management

- Author: [Pragnya Pandrate](https://github.com/pragnya17), [Kartheek Penagamuri](https://github.com/kartheekp-ms)
- Issue: [11807](https://github.com/NuGet/Home/issues/11807)
- Status: In Review

## Problem Background

The dotnet add package command allows users to add or update a package reference in a project file through the Dotnet CLI. However, when this command is used in a project that has been onboarded to Central Package Management (CPM), it poses an issue as this error is thrown: `error: NU1008: Projects that use central package version management should not define the version on the PackageReference items but on the PackageVersion items: [PackageName]`.

Projects onboarded to CPM use a `Directory.packages.props` file in the root of the repo where package versions are defined centrally. Ideally, when the `dotnet add package` command is used, the package version should only be added to the corresponding package in the `Directory.packages.props` file. However, currently the command attempts to add the package version to the `<PackageReference />` in the project which conflicts with the CPM requirements that package versions must only be in the `Directory.packages.props` file.

## Goals

The main goal is to add support for `dotnet add package` to be used with projects onboarded onto CPM. Regardless of whether the package has already been added to the project or not, the command should allow users to add packages or update the package version in the `Directory.packages.props` file.

## Customers

Users wanting to use CPM onboarded projects and dotnet CLI commands.

## Solution

When `dotnet add package` is executed in a project onboarded to CPM (meaning that the `Directory.packages.props` file exists) there are a few scenarios that must be considered.

| Scenario # | PackageReference exists? | VersionOverride exists? | PackageVersion exists? | Is Version specified from the commandline | New behavior in dotnet CLI | In Scope for V1?|
| ---- |----- | ----- | ---- |---- | ----- | ---- |
| 1 | ❌ | ❌ | ❌ | ❌ | Add PackageReference to the project file. Add PackageVersion to the Directory.Packages.Props file. Use latest version from the package sources. | ✔️ |
| 2 | ❌ | ❌ | ❌ | ✔️ | Add PackageReference to the project file. Add PackageVersion to the Directory.Packages.Props file. Use version specified in the commandline. | ✔️ |
| 3 | ❌ | ❌ | ✔️ | ❌ |  Add PackageReference to the project file. No changes to the Directory.Packages.Props file. Basically we are reusing the version defined centrally for this package. | ✔️ |
| 4 | ❌ | ❌ | ✔️ | ✔️ | Add PackageReference to the project file. Update PackageVersion in the Directory.Packages.Props file.  | ✔️ |
| 5 | ❌ | ✔️ | ❌ | ❌ | Not a valid scenario because a VersionOverride can't exist without PackageReference. | ❌ |
| 6 | ❌ | ✔️ | ❌ | ✔️ | Not a valid scenario because a VersionOverride can't exist without PackageReference. | ❌ |
| 7 | ❌ | ✔️ | ✔️ | ❌ | Not a valid scenario because a VersionOverride can't exist without PackageReference. | ❌ |
| 8 | ❌ | ✔️ | ✔️ | ✔️ | Not a valid scenario because a VersionOverride can't exist without PackageReference. | ❌ |
| 9 | ✔️ | ❌ | ❌ | ❌ | Emit an error -OR- Remove Version from PackageReference, Add PackageVersion to the Directory.Packages.Props file. Use Version from PackageReference if it exists otherwise use latest version from the package sources. | ✔️ |
| 10 | ✔️ | ❌ | ❌ | ✔️ | Emit an error -OR- Remove Version from PackageReference, Add PackageVersion to the Directory.Packages.Props file. Use Version passed to the commandline. | ✔️ |
| 11 | ✔️ | ❌ | ✔️ | ❌ | No-op -OR- Update PackageVersion in the Directory.Packages.Props file,  use latest version from the package sources. | ✔️ |
| 12 | ✔️ | ❌ | ✔️ | ✔️ | Update PackageVersion in the Directory.Packages.Props file, use version specified in the commandline. | ✔️ |
| 13 | ✔️ | ✔️ |❌  | ❌ | Update VersionOverride in the existing PackageReference item, use latest version from the package sources. | ✔️ |
| 14 | ✔️ | ✔️ | ❌ | ✔️ | Update VersionOverride in the existing PackageReference item, use version specified in the commandline. | ✔️ |
| 15 | ✔️ | ✔️ | ✔️ | ❌ | Update VersionOverride in the existing PackageReference item, use latest version from the package sources. | ✔️ |
| 16 | ✔️ | ✔️ | ✔️ | ✔️ | Update VersionOverride in the existing PackageReference item, use version specified in the commandline. | ✔️ |

> [!NOTE]
> Scenarios with multiple Directory.Packages.props are out of scope for now.

### 1. The package reference does not exist

If the package does not already exist, it should be added along with the appropriate package version to `Directory.packages.props`. The package version should either be the latest version or the one specified in the CLI command. Only the package name (not the version) should be added to `<PackageReference>` in the project file.

#### Before `add package` is executed

The props file:

```xml
<Project>
    <PropertyGroup>
        <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    </PropertyGroup>
    <ItemGroup>
    </ItemGroup>
</Project>
```

The .csproj file:

```xml
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup>
        <TargetFramework>net6.0</TargetFramework>
        <ImplicitUsings>enable</ImplicitUsings>
        <Nullable>enable</Nullable>
    </PropertyGroup>

    <ItemGroup>
    </ItemGroup>
</Project>
```

#### After `add package` is executed

`dotnet add ToDo.csproj package Newtonsoft.Json -v 13.0.1`

The props file:

```xml
<Project>
    <PropertyGroup>
        <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    </PropertyGroup>
    <ItemGroup>
    <PackageVersion Include="Newtonsoft.Json" Version="13.0.1"/>
    </ItemGroup>
</Project>
```

The .csproj file:

```xml
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup>
        <TargetFramework>net6.0</TargetFramework>
        <ImplicitUsings>enable</ImplicitUsings>
        <Nullable>enable</Nullable>
    </PropertyGroup>

    <ItemGroup>
        <PackageReference Include="Newtonsoft.Json"/>
    </ItemGroup>
</Project>
```

In case there are multiple `Directory.packages.props` files in the repo, the props file that is closest must be considered.

```xml
Repository
 |-- Directory.Packages.props
 |-- Solution1
    |-- Directory.Packages.props
    |-- Project1
 |-- Solution2
    |-- Project2
```

In the above example, the following scenarios are possible:

1. Project1 will evaluate the Directory.Packages.props file in the Repository\Solution1\ directory.
2. Project2 will evaluate the Directory.Packages.props file in the Repository\ directory.

***Sourced from <https://devblogs.microsoft.com/nuget/introducing-central-package-management/>

### 2. The package reference does exist

If the package already exists in `Directory.packages.props` the version should be updated in `Directory.packages.props`. The package version should either be the latest version or the one specified in the CLI command. The `<PackageReference>` in the project file should not change.

#### Before `add package` is executed
The props file:

```xml
<Project>
    <PropertyGroup>
        <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    </PropertyGroup>
    <ItemGroup>
    <PackageVersion Include="Newtonsoft.Json" Version="12.0.1"/>
    </ItemGroup>
</Project>
```

The .csproj file:

```xml
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup>
        <TargetFramework>net6.0</TargetFramework>
        <ImplicitUsings>enable</ImplicitUsings>
        <Nullable>enable</Nullable>
    </PropertyGroup>

    <ItemGroup>
        <PackageReference Include="Newtonsoft.Json"/>
    </ItemGroup>
</Project>
```

#### After `add package` is executed

`dotnet add ToDo.csproj package Newtonsoft.Json -v 13.0.1`

No changes should be made to the `Directory.Packages.Props` file. Add `VersionOverride` attribute to the existing `PackageReference` item in .(cs/vb)proj file. If `VersionOverride` is already specified then the value should be updated.

The .csproj file:

```xml
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup>
        <TargetFramework>net6.0</TargetFramework>
        <ImplicitUsings>enable</ImplicitUsings>
        <Nullable>enable</Nullable>
    </PropertyGroup>

    <ItemGroup>
        <PackageReference Include="Newtonsoft.Json" VersionOverride="13.0.1"/>
    </ItemGroup>
</Project>
```

### 3. The package reference does exist with an VersionOverride

If the package already exists in `Directory.packages.props` the version should be updated in `Directory.packages.props`. The package version should either be the latest version or the one specified in the CLI command. The `<PackageReference>` in the project file should not change.

#### Before `add package` is executed

```xml
<Project>
    <PropertyGroup>
        <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    </PropertyGroup>
    <ItemGroup>
    <PackageVersion Include="Newtonsoft.Json" Version="11.0.1"/>
    </ItemGroup>
</Project>
```

```xml
<Project>
    <PropertyGroup>
        <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    </PropertyGroup>
    <ItemGroup>
    <PackageVersion Include="Newtonsoft.Json" VersionOverride="12.0.1"/>
    </ItemGroup>
</Project>
```

#### After `add package` is executed

- No changes should be made to the `Directory.packages.props` file. 
- The version specified in the `VersionOverride` atribute value of `PackageReference` element in the project file should be updated.

`dotnet add ToDo.csproj package Newtonsoft.Json -v 13.0.1`

```xml
<Project>
    <PropertyGroup>
        <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    </PropertyGroup>
    <ItemGroup>
    <PackageVersion Include="Newtonsoft.Json" VersionOverride="13.0.1"/>
    </ItemGroup>
</Project>
```
