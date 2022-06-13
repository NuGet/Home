# Adding Dotnet CLI add package command support to projects onboarded with Central Package Management

Author: Pragnya Pandrate <br>
Issue: https://github.com/NuGet/Home/issues/11807 <br>
Status: In Review <br>

## Problem Background
The dotnet add package command allows users to add or update a package reference in a project file through the Dotnet CLI. However, when this command is used in a project that has been onboarded to Central Package Management (CPM), it poses an issue as this error is thrown: `error: NU1008: Projects that use central package version management should not define the version on the PackageReference items but on the PackageVersion items: [PackageName]`.

Projects onboarded to CPM use a `Directory.packages.props` file in the root of the repo where package versions are defined centrally. Ideally, when the `dotnet add package` command is used, the package version should only be added to the corresponding package in the `Directory.packages.props` file. However, currently the command attempts to add the package version to the `<PackageReference />` in the project which conflicts with the CPM requirements that package versions must only be in the `Directory.packages.props` file. 

## Goals
The main goal is to add support for `dotnet add package` to be used with projects onboarded onto CPM. Regardless of whether the package has already been added to the project or not, the command should allow users to add packages or update the package version in the `Directory.packages.props` file.

## Customers
Users wanting to use CPM onboarded projects and dotnet CLI commands.

## Solutions
When `dotnet add package` is executed in a project onboarded to CPM (meaning that the `Directory.packages.props` file exists) there are a few scenarios that must be considered.

### 1. The package reference does not exist
If the package does not already exist, it should be added along with the appropriate package version to `Directory.packages.props`. The package version should either be the latest version or the one specified in the CLI command. Only the package name (not the version) should be added to `<PackageReference>` in the project file.

#### Before `add package` is executed:<br>

The props file: <br>
```xml
<Project>
    <PropertyGroup>
        <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    </PropertyGroup>
    <ItemGroup>
    </ItemGroup>
</Project>
```
The .csproj file: <br>
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

#### After `add package` is executed:<br>

The props file: <br>
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
The .csproj file: <br>
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

***Sourced from https://devblogs.microsoft.com/nuget/introducing-central-package-management/

### 2. The package reference does exist
If the package already exists in `Directory.packages.props` the version should be updated in `Directory.packages.props`. The package version should either be the latest version or the one specified in the CLI command. The `<PackageReference>` in the project file should not change.

#### Before `add package` is executed:<br>
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

#### After `add package` is executed:<br>
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

In case there are multiple `Directory.packages.props` files in the repo, all of them should be searched for a matching package reference. Once a matching package reference is found, its package version can be updated appropriately. 

### Other Scenarios that can be considered

While the above cases must be considered to solve the issue, there are a few other cases that can be considered to make the product more usable:

1. If the project has the `<ManagePackageVersionsCentrally>` set to true, but the `Directory.packages.props` file has not been created yet the file should be created. At this point, package references can be updated according to the cases discussed above.
2. If the `Directory.packages.props` file has been created but the `<ManagePackageVersionsCentrally>` property has not been set to true, it should be set to true.
3. If the project has the `<ManagePackageVersionsCentrally>` set to false, the project should not be considered as onboarded to CPM. Therefore the `Directory.packages.props` file should be deleted if it exists and only `.csproj` files should be modified.
4. If there are `Directory.packages.props` files that inherit other props files, all inherited files should be considered when `add package` is executed.
5. If the project has a `VersionOverride` attribute defined in the `csproj` file and the `add package` command is run in order to update a package version, then the `VersionOverride` attribute should be updated with the appropriate package version.
