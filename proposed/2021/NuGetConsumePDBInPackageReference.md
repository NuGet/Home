# Consuming pdb support with PackageReference

* Status: Reviewed
* Author(s): [Heng Liu](https://github.com/heng-liu)
* Issue: [5926](https://github.com/NuGet/Home/issues/5926) Consume pdbs from packages in PackageReference - add Debug Symbols to LockFileTargetLibrary
* Type: Feature

## Problem Background

In the PackageReference world, the packages are consumed from the global-packages folder, .pdb, .xml files from lib and runtime folder are not copied into the build output folder.
However, in some cases, consuming .pbd, .xml files are needed to support certain features, like source link ( see issue [1458](https://github.com/dotnet/sdk/issues/1458)).
But .NET SDK could not consume those files, as it needs [LockFileTargetLibrary](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.ProjectModel/LockFile/LockFileTargetLibrary.cs) to tell what those asset files are, and NuGet doesn't have any reference to .pdb, .xml asset files in LockFileTargetLibrary for now.

In comparison, in packages.config, .pdb, .xml files are automatically copied from lib and runtime folder into the build output folder. So there is no such problem in packages.config.

## Who are the customers

Partner team(.NET SDK) who needs to consume .pdb, .xml files for their features in PackageReference world.

## Requirements

* A feature to allow the .NET SDK to consume .pdb, .xml files.

## Goals

* Define an approach to make .NET SDK be able to consume .pdb, .xml files.

## Non-Goals

* ~~Define an approach for defining additional assembly metadata.~~
* ~~Adding metadata such `PrivateAssets`, `GeneratePathProperty` etc. is still csproj XML only, no UI exeperience will be added.~~
* ~~Define an approach for defining aliases or any other assembly metadata for packages brought in transitively.~~

## Solution

For any given assembly under lib and runtime folder, if there are files next to it that differ only by extension, NuGet will add a "related" property underneath the assembly in targets section of assets file, listing the extensions of these files.

* Applies to all the compile time assemblies and runtime assemblies.
* Apply to transitive dependencies.
* Apply to both package reference and project reference type.


### Solution - Technical details

#### Package reference:
For example, one project has a package reference of PackageA. Supppose in folder ./PackageA/1.0.0/lib/netstandard2.0, there are PackageA.pdb, PackageA.xml file besides PackageA.dll.
Currently, the targets section in assets file is:

```json
{
  "version": 3,
  "targets": {
    ".NETCoreApp,Version=v5.0": {
      "PackageA/1.0.0": {
        "type": "package",
        "compile": {
           "lib/netstandard2.0/PackageA.dll": {}
        },
        "runtime": {
           "lib/netstandard2.0/PackageA.dll": {}
      }
    }
  },
```
When this solution is applied, the targets section in assets file will be:

```json
{
  "version": 3,
  "targets": {
    ".NETCoreApp,Version=v5.0": {
      "PackageA/1.0.0": {
        "type": "package",
        "compile": {
           "lib/netstandard2.0/PackageA.dll": {
              "related": "pdb,xml"
           }
        },
        "runtime": {
           "lib/netstandard2.0/PackageA.dll": {
              "related": "pdb,xml"
           }
      }
    }
  },
```
#### Project reference:
For example, one project has a project reference of ProjectA. Supppose in folder ./ProjectA/lib/netstandard2.0, there are PackageA.pdb, PackageA.xml file besides ProjectA.dll.
Currently, the targets section in assets file is:

```json
{
  "version": 3,
  "targets": {
    ".NETCoreApp,Version=v5.0": {
        "ClassLibrary1/1.0.0": {
        "type": "project",
        "framework": ".NETCoreApp,Version=v5.0",
        "compile": {
          "bin/placeholder/ClassLibrary1.dll": {}
        },
        "runtime": {
          "bin/placeholder/ClassLibrary1.dll": {}
        }
      }
    },
```
When this solution is applied, the targets section in assets file will be:

```json
{
  "version": 3,
  "targets": {
    ".NETCoreApp,Version=v5.0": {
        "ClassLibrary1/1.0.0": {
        "type": "project",
        "framework": ".NETCoreApp,Version=v5.0",
        "compile": {
          "bin/placeholder/ClassLibrary1.dll": {
            "related": "pdb,xml"
          }
        },
        "runtime": {
          "bin/placeholder/ClassLibrary1.dll": {
            "related": "pdb,xml"
          }
        }
      }
    },
```
On the library side there are no changes. 

The (LockFileItem)[https://github.com/NuGet/NuGet.Client/blob/4fef99532f4022504feec5f68c8501cbeadd3aed/src/NuGet.Core/NuGet.ProjectModel/LockFile/LockFileItem.cs] type which represents an element in the compile list already has a collection of properties. 

Specifically:

```cs
  public string Path { get; }

  public IDictionary<string, string> Properties { get; } = new Dictionary<string, string>();
```

There is no need for a change here. 

The value provided in the Aliases attribute will be passed through as far as NuGet is concerned. NuGet will not validate that the value provided is a valid alias, that will be done at build time. 

The implementation of this feature spans multiple components. 
Specifically the work items as follows: 

* [dotnet/sdk/10947](https://github.com/dotnet/sdk/issues/10947) The build tasks for .NET Core SDK  [code](https://github.com/dotnet/sdk/blob/master/src/Tasks/Microsoft.NET.Build.Tasks/ResolvePackageAssets.cs)
* [dotnet/NuGet.BuildTasks/7](https://github.com/dotnet/NuGet.BuildTasks/issues/70) The build tasks for non-SDK based PackageReference [code](https://github.com/dotnet/NuGet.BuildTasks/blob/master/src/Microsoft.NuGet.Build.Tasks/ResolveNuGetPackageAssets.cs).
* [dotnet/project-system/6011](https://github.com/dotnet/project-system/issues/6011) Nomination updates on project-system side [code](https://github.com/dotnet/project-system/blob/master/src/Microsoft.VisualStudio.ProjectSystem.Managed/ProjectSystem/Rules/Dependencies/PackageReference.xaml).

## Future Work

* Package metadata for transitive package references will be considered in the future. For now the recommendation is to elevate that PackageReference to a direct dependency. 

## Open Questions

* In which version will this functionality be ready?
* When there is no other extensions, shall NuGet provide empty string `"related": ""`, or just skip adding `"related": ""` in assets file?
* Shall NuGet list not only .pdb and .xml, but all [AllowedReferenceRelatedFileExtensions](https://github.com/dotnet/msbuild/blame/main/src/Tasks/Microsoft.Common.CurrentVersion.targets#L621-L627) if there is any? (.pdb, .xml, .pri, .dll.config, .exe.config)
* Is it necessary to apply `related` to project reference type? Or only package reference type is needed.
* The impact on the cache side.

## Considerations

In addition to the proposed approach, 2 of other solutions were considered. 

### Do nothing - Recommend the customers use the custom target workaround

The workaround that allows per assembly granularity is the following:

```xml
  <Target Name="AddCustomAliases" BeforeTargets="FindReferenceAssembliesForReferences;ResolveReferences">
    <ItemGroup>
      <ReferencePath Condition="'%(FileName)' == '$AssembleFileName$' AND '%(ReferencePath.NuGetPackageId)' == '$PackageId$'">
        <Aliases>$Alias$</Aliases>
      </ReferencePath>
    </ItemGroup>
  </Target>
```

Pros:

* A very powerful solution, that covers both direct and transitive dependencies.
* Allows per file granularity, if multiple assemblies are brought in by a package, each can have(or not) their own alias.

Cons:

* Important enough feature that deserves an out of the box solution.
* The workaround recommends taking a dependency on tasks and targets that are best not depended on by customers. Goes against the policy of minimizing the size of the project files.
* Not obvious, unnecessarily exposes the customers to restore/build internals.  

### References

* NoWarn does not apply transitively [5740](https://github.com/NuGet/Home/issues/5740)
* Extern alias language [docs](https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/extern-alias)
* ProjectReference.Aliases [docs](https://docs.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.projectreference.aliases?view=roslyn-dotnet)
* [dotnet/sdk/10947](https://github.com/dotnet/sdk/issues/10947) The build tasks on (.NET Core SDK side)
* [dotnet/NuGet.BuildTasks/7](https://github.com/dotnet/NuGet.BuildTasks/issues/70) The build tasks for the non-SDK based PackageReference
* [dotnet/project-system/6011](https://github.com/dotnet/project-system/issues/6011) Nomination updates on project-system side.
