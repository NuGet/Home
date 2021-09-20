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

* 

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

The [LockFileItem](https://github.com/NuGet/NuGet.Client/blob/4fef99532f4022504feec5f68c8501cbeadd3aed/src/NuGet.Core/NuGet.ProjectModel/LockFile/LockFileItem.cs) type which represents an element in the compile list already has a collection of properties. 

Specifically:

```cs
  public string Path { get; }

  public IDictionary<string, string> Properties { get; } = new Dictionary<string, string>();
```

There is no need to change any code references LockFileItem. 

But when generating the targets section of assets file, NuGet needs to go through the runtime and compile time folder for the files with specific extensions and add those as the `related` property.  
NuGet will not use the `related` property after it's generated, it will be consumed at build time. 

In order to consume the `related` property, the .NET SDK will need to make change in the following part: 

* [dotnet/sdk/10947](https://github.com/dotnet/sdk/issues/10947) The build tasks for .NET Core SDK  [code](https://github.com/dotnet/sdk/blob/master/src/Tasks/Microsoft.NET.Build.Tasks/ResolvePackageAssets.cs)

## Future Work


## Open Questions

* In which version will this functionality be ready?

* When there is no other extensions, shall NuGet provide empty string `"related": ""`, or just skip adding `"related": ""` in assets file?

* Shall NuGet list not only .pdb and .xml, but also all the extensions in [AllowedReferenceRelatedFileExtensions](https://github.com/dotnet/msbuild/blame/main/src/Tasks/Microsoft.Common.CurrentVersion.targets#L621-L627) if there is any? (.pdb, .xml, .pri, .dll.config, .exe.config)

* Is it necessary to add `related` to project reference type node in targets section? Or only adding `related` to package reference type node in targets section?

* If there is a change in `related` property, will it make any difference in restore? For a package reference, there should be no change in `related` property if it's referencing the same package. For a project reference, should manually adding/removing .pdb, .xml file trigger restore? Does it make any difference compared with previous behavior?

## Considerations

In addition to the proposed approach, 2 of other solutions were considered. 

### Do nothing - Recommend the customers use the custom target workaround

Pros:

Cons:

### Add as LockFileItem, but not a property of LockFileItem
Pros:

Cons:

### References

