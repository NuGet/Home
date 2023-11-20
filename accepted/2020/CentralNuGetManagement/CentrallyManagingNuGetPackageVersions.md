![image](https://user-images.githubusercontent.com/14800916/71850448-29e8d900-3089-11ea-95d3-3c275711e933.png)
Note: This feature is in development and is not yet complete. Limited functionality is available as a preview.

| | |
|:-- |:--
| Author(s) | [Anand Gaurav](https://github.com/anangaur) ([@adgrv](https://twitter.com/adgrv)), [Cristina Manu](https://github.com/cristinamanum)|

### Issue
 [#6764](https://github.com/NuGet/Home/issues/6764)

### Solution Details

To get started, you will need to create an MSBuild props file at the root of the solution named `Directory.Packages.props` that declares the centrally defined packages' versions.

In this example, packages like `Newtonsoft.Json` are set to version `10.0.1`.  The `PackageReference` in the projects would not specify the version information. All projects that reference this package will refer to version `10.0.1` for `Newtonsoft.json`.

*Directory.Packages.props*
```xml
<Project>
  <ItemGroup>
    <PackageVersion Include="MSTest.TestAdapter" Version="1.1.0" />
    <PackageVersion Include="MSTest.TestFramework" Version="1.1.18" />
    <PackageVersion Include="Newtonsoft.Json" Version="10.0.1" Pin="true" />
  </ItemGroup>
</Project>
```

*SampleProject.csproj*
```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Newtonsoft.Json" />
  </ItemGroup>
</Project>
```

#### Opt-in **Central Package Version Management**

If a Directory.Packages.props file exists, all projects in that directory tree are automatically opted in to central package version management.  To opt-out a specific project, set the following property in that project file: 

```xml
<ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally>
```

In addition only specific types of projects will be supported for **Central Package Version Management**. Refer to [this](#what-is-currently-not-supported-in-central-package-version-management) to see the exclusions.

Note: While this feature is in preview, the default will be opt-out, and customers will need to opt-in explicitly to use it, by setting `<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>` in their project file.

**Transitive dependencies**: The versions for the packages defined in the Directory.Packages.props will win for direct and transitive dependency resolution.

### DotNet CLI Experience

The dotnet commands `dotnet add` and `dotnet remove` will work without any changes if the project is opt-out **Central Package Version Management**. For the cases when a project is opt-in **Central Package Version Management** the following rules apply.

#### dotnet add
**`> dotnet add [PROJECT] package [PACKAGE_NAME] [-h|--help] [-f|--framework] [--interactive] [-n|--no-restore] [--package-directory] [-s|--source] [-v|--version] [--force-version-update]`[(*)](#naming)**

##### Description

It will add a package reference to the project. The Package version will be added only to the Directory.Packages.props file. To update the version in the Directory.Packages.props file use the *--force-version-update*[(*)](#naming) option.

##### Arguments

```
PROJECT
```

Specifies the project file. If not specified, the command searches the current directory for one.

```
PACKAGE_NAME
```

The package reference to add.

##### Options

``` 
-f|--framework
```

The framework information will be ignored when projects' versions are centrally managed. The following information will be added to the Directory.Packages.props file.

``` xml
<ItemGroup>
    <PackageVersion Include="MyPackage" Version="11.0.1" />
</ItemGroup>
```

The project file will be updated as well.

``` xml
  <ItemGroup>
    <PackageReference Include="MyPackage" />
  </ItemGroup>
```

``` 
-v|--version
```

Adds the specific version of the package to the Directory.Packages.props file.
The command will fail if there is a conflict between this version and a version of the same package specified in the Directory.Packages.props file.

``` 
--force-version-update
```

Adds the specific version of the package to the Directory.Packages.props file. The command will override any existent package version in the Directory.Packages.props file. 


##### Examples

###### `dotnet add` when the PackageReference for `Newtonsoft.Json` exists in the Directory.Packages.props file

```bash
ProjectA> dotnet add package newtonsoft.json
Successfully added package 'Newtonsoft.Json' to ProjectA. The central package version is '12.0.1'.
```

A new PackageReference will be added to the ProjectA.csproj. The new PackageReference will not have a Version attribute.

###### `dotnet add` when PackageReference for `Newtonsoft.Json` does not exist in the Directory.Packages.props file

```bash
ProjectA> dotnet add package newtonsoft.json 
Successfully added package 'Newtonsoft.Json' to ProjectA. Successfully added version 12.0.2 for package Newtonsoft.Json in '<path>\Directory.Packages.props'.  
```

A new PackageReference will be added to the Directory.Packages.props file. The entry will contain the '12.0.1' version.  
A new PackageReference will be added to the ProjectA.csproj. The new PackageReference will not have a Version attribute.


###### `dotnet add --version` when the PackageReference for `Newtonsoft.Json` exists in the Directory.Packages.props file.

```bash
//  Fails on version conflict
ProjectA> dotnet add package newtonsoft.json --version 11.0.1
error: '<path>\Directory.Packages.props' already contains a reference to `Newtonsoft.Json` version 12.0.2. To force the version update use 'dotnet add package newtonsoft.json --version 11.0.1 --force-version-update'. To add a reference to the existent `Newtonsoft.Json` version 12.0.2 use 'dotnet add package newtonsoft.json '
```

```bash
//  Success on --force-version-update
ProjectA> dotnet add package newtonsoft.json --version 11.0.1 --force-version-update
Successfully added package 'Newtonsoft.Json' to ProjectA. Successfully updated package 'Newtonsoft.Json' version from 12.0.2 to 11.0.1.
```


#### dotnet remove 
**`> dotnet remove [PROJECT] package [PACKAGE_NAME] [-h|--help]`**

##### Description 

Removes a package reference from a project. It does not remove the package reference from the Directory.Packages.props.

##### Arguments

```
PROJECT
```

Specifies the project file. If not specified, the command searches the current directory for one.
```
PACKAGE_NAME
```

##### Examples 

``` bash
ProjectA> dotnet remove package newtonsoft.json
Successfully removed package 'Newtonsoft.Json' from ProjectA. The Directory.Packages.props was not changed. To clean not used package references from the Directory.Packages.props use 'dotnet nuget prune' command.  
```

The ProjectA.csproj will have the package reference for `Newtonsoft.Json` removed.
No change will be applied to Directory.Packages.props file.  

#### dotnet nuget prune 

**`> dotnet nuget prune [SOLUTION_PROJECT] [-h|--help] [--dry-run]`**

[Note] Other suggestions for the command

**`> dotnet nuget versions [SOLUTION_PROJECT] [-h|--help] [--gc] [--dry-run]`**

**`> dotnet nuget clean [SOLUTION_PROJECT] [-h|--help] [--dry-run]`**

**`> dotnet nuget versions clean [SOLUTION_PROJECT] [-h|--help] [--dry-run]`**

##### Description 

It evaluates the packages used by the projects specified in [SOLUTION_PROJECT] and removes any not used PackageVersion elements from Directory.Packages.props file. If the PackageVersion elements are pinned in the central file the elements are not removed.

``` xml
<PackageVersion Include="Newtonsoft.Json" Version="10.0.1" Pin="true"/>
``` 


##### Arguments


```
SOLUTION_PROJECT
```

A solution or a project file. If not specified, the command searches the current directory for a solution or a project file. If multiple are found the command will error.

##### Options

``` 
--dry-run
```

It will print the items that will be removed from the Directory.Packages.props file. 


##### Examples 

``` bash
ProjectA> dotnet nuget prune MySolution1.sln --dry-run
4 not used packages will be removed from [path]\Directory.Packages.props.
PackageId : 'Newtonsoft.Json' Version:"12.0.0"  
PackageId : 'XUnit' Version: "2.4.0"  
PackageId : 'NUnit' Version: "3.9.0"  
PackageId : 'EnityFramework' Version: "6.2.0"  

3 packages were pinned and they will not be removed.
PackageId : 'NuGet.Packaging' Version:"5.3.0". The Package is not a direct or a transitive dependency.
PackageId : 'NuGet.Common' Version:"5.2.0". The Package is a direct dependency for projects: ProjectA.
PackageId : 'System.Threading' Version:"4.0.11". The Package is a transitive dependency for projects: ProjectB, ProjectC.
```

``` bash
ProjectA> dotnet nuget prune MySolution1.sln 
4 not used packages were removed from [path]\Directory.Packages.props.
PackageId : 'Newtonsoft.Json' Version:"12.0.0"  
PackageId : 'XUnit' Version: "2.4.0"  
PackageId : 'NUnit' Version: "3.9.0"  
PackageId : 'EnityFramework' Version: "6.2.0"  
```

### Visual Studio Experience

> Only for SDK Style projects install/unistall/update package references will be supported in Visual Studio. For the Package Reference legacy style projects the updates need to be manually performed.

> For a project that is opt-out from **Central Package Version Management** the install/unistall/update of package versions will work as currently. 

#### The Directory.Packages.props file exists at the solution level and projects are not opt-out from **Central Package Version Management**.

##### Project PMUI Experience

###### Install a package in the project, with a specific version already used in the solution

The UI will present the version installed in the Directory.Packages.props file.
The other versions wil be available as currently.
![image](https://user-images.githubusercontent.com/16580006/65453347-dfa05c80-ddf7-11e9-8669-3c7a17a6c113.png)

a. User chooses the Recommended version and install.  
Result: A new entry ```<PackageReference Include="EntityFramework" />``` is added to the project's file.

b. The user does not select the recommended version but a different version.

Result:
The user will be presented with the confirmation window.
_Confirmation dialog while updating a package version:_
![image](https://user-images.githubusercontent.com/14800916/41008158-5d4bd230-68de-11e8-8110-84400a86aa2b.png)

After the confirmation:

* A new entry ```<PackageReference Include="EntityFramework" />``` is added to the project's file
* The version in the Directory.Packages.props is updated.

###### Install a package in the project that was not installed in the Directory.Packages.props

The UI will be as currently. User can select the version desired and chose to install.
Result:

* A new entry ```<PackageReference Include="EntityFramework" />``` is added to the project's file
* A new entry ```<PackageVersion Include="EntityFramework" Version="6.0.2"/>``` is added to Directory.Packages.props file.

###### Update a package version

On version update:

* If the project had a PackageReference element with a version, the Version metadata will be removed.
* The reference in the Directory.Packages.props is updated to the new version.


###### UnInstall a package

On uninstall

* The entry ```<PackageReference Include="EntityFramework" />``` is removed from the project's file
* No change is applied to the Directory.Packages.props  file.

###### Install/Update/Uninstall for legacy PackageReference projects opted-in **Central Package Version Management**

The user will be presented with an info dialog when trying to access "Manage NuGet packages" and the update is not possible.

###### Install/Update/Uninstall for projects opted-out **Central Package Version Management**

The experience is unchanged. The 'Version' value of the PackageReference element at the project level will be updated/added/removed.


##### Solution PMUI Experience

###### Install a package in the project, with a specific version already used in the solution

The UI will be similar with the current UI but the  Centrally Managed package versions are marked.
![image](https://user-images.githubusercontent.com/16580006/65454795-c056fe80-ddfa-11e9-80aa-6a9eeec4c124.png)

a. User chooses the Centrally managed pacakge version to be installed.

Result: A new entry ```<PackageReference Include="EntityFramework" />``` is added to the project's file.

b. The user does not select the recommended version but a different version.

Result:
The user will be presented with a confirmation window that will inform that the version will be changed for the set of projects.
_Confirmation dialog while updating a package version:_
![image](https://user-images.githubusercontent.com/14800916/41008158-5d4bd230-68de-11e8-8110-84400a86aa2b.png)

After the confirmation:

* A new entry ```<PackageReference Include="EntityFramework" />``` is added to the project's file.
* The version in the Directory.Packages.props is updated.

###### Install a package in the project that was not installed in the Directory.Packages.props

The UI will be as currently. User can select the version desired and chose to install.
Result:

* A new entry ```<PackageReference Include="EntityFramework" />``` is added to the project's file.
* A new entry ```<PackageVersion Include="EntityFramework" Version="6.0.2"/>``` is added to Directory.Packages.props file.

###### UnInstall a package

On uninstall

* The entry ```<PackageReference Include="EntityFramework" />``` is removed from the projects' file.
* There is not any modification applied to the Directory.Packages.props file. 


###### Install/Update/Uninstall for legacy PackageReference projects opted-in **Central Package Version Management**

The Solution PMUI will grey out the boxes for the Legacy Projects opted-in **Central Package Version Management**

###### Install/Update/Uninstall for projects opted-out **Central Package Version Management**

The experience is unchanged. The 'Version' value of the PackageReference element at the project level will be updated/added/removed. 

### What is currently not supported in Central Package Version Management

#### Project types not supported

Central Package Managed Version is supported only for "Package Reference" projects types.

#### Dual feature opt-in and opt-out

A project opted-in **Central Package Version Management** cannot be used in a Visual Studio solution that is not opted-in **Central Package Version Management**.

#### Tooling

* `Visual Studio` and `DotNet CLI` support only SDK style projects. For Legacy ProjectReference style projects all the updates need to be manually applied.

* The initial Directory.Packages.props will be created only through dotnet.exe not Visual Studio.


### FAQ

#### How a project can opt-out from **Central Package Version Management**?

Individual projects can opt-out of **Central Package Version Management** by using the ManagePackageVersionsCentrally MsBuild property as below.

```xml
<ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally> 
```

By default projects are opted-out from **Central Package Version Management**.


#### How do I transform my existing projects to use this functionality?

Manually create the Directory.Packages.props and remove the version information from the project files.


#### Will a central defined Package version influence transitive dependency resolution?

Yes. If a package version is mentioned in the Directory.Packages.props any transitive dependency will be resolved to the central defined version. 

For example in the scenario below PackageB depends on PackageC version 2.0.0. PackageC version 3.0.0 is added to the Directory.Packages.props file. The PackageC reference resolution for SampleProject will be 3.0.0.

*Directory.Packages.props*
```xml
<Project>
  <ItemGroup>
    <PackageVersion Include="PackageA" Version="1.0.0" />
    <PackageVersion Include="PackageB" Version="1.0.0" />
    <PackageVersion Include="PackageC" Version="3.0.0" />
  </ItemGroup>
</Project>
```

*SampleProject.csproj*
```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="PackageB" />
  </ItemGroup>
</Project>
```

#### Will be changes in the `pack` command ?
If a project had a transitive dependency enforced through central definition the dependency it is added to the list of package direct dependencies.

#### Where are `PrivateAssets`/`ExcludeAssets`/`IncludeAssets` defined?

These are per project properties and should be defined in the PackageReference nodes in the project file.

#### How does restore NoOp work i.e. when does NuGet try to actually restore or choose not to restore?

The current logic is used except that the package versions are referenced from the Directory.Packages.props file.

#### Can I use my custom version of Directory.Packages.props?

This will not be supported in the first feature version. 

#### Can I use the **Central Package Version Management** and still preserve the Version metadata?

No, an error will be generated if the Version attribute is present at the project PackageReference elements.

#### Can I add .NET SDK implicitly defined packages to the **Central Package Version Management** file?

No, an error will be generated if an implicitly defined package is added to the **Central Package Version Management** file.

#### Can I have a given set of package versions for all the projects but a different set for a specific project?

To override the global packages' version constraints for a specific project, you can define `Directory.Packages.props` file in the project root directory. This will override the global settings from the solution `Directory.Packages.props` file.


#### What happens when there are multiple `Directory.Packages.props` file available in a project's context?

In order to remove any confusion, the `Directory.Packages.props` nearest to the project will override all others. At a time only one `Directory.Packages.props` file is evaluated for a given project.

E.g. in the below scenario

```
Repo
 |-- Directory.Packages.props
 |-- Solution1
     |-- Directory.Packages.props
     |-- Project1
 |-- Solution2
     |-- Project2
```

In the above scenario:

* Project1 will refer to only `Repo\Solution1\Directory.Packages.props``
* Project2 will refer to only `Repo\Directory.Packages.props`

#### Can I specify NuGet sources in the Directory.Packages.props file?

This is not part of the spec/feature but specifying sources in the Directory.Packages.props file seems like a good idea.

#### Can I change my repo to use the **Central Package Version Management** and use old tools later?

No. Because the Version will be removed from the projects' level the old tools cannot be used to build the repo.

### Next Steps (post MVP)

1. New command to support migration scenarios. It will create the Directory.Packages.props file.
Few options for the new command:
**`> dotnet nuget versions [SOLUTION_PROJECT] [-h|--help] [--consolidate/centralize] [--dry-run]`**
**`> dotnet nuget consolidate/centralize [SOLUTION_PROJECT] [-h|--help] [--dry-run]`**

2. Allow custom file for the central packages file.
``` xml
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <CentralPackagesFile>$(MSBuildThisFileDirectory)MyPackageVersions.props</CentralPackagesFile>
  </PropertyGroup>
</Project>
```

### Naming

The name is not definitive and we are looking for better name pattern.