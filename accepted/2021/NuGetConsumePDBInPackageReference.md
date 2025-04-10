# Consuming pdb support with PackageReference

* Status: Reviewing
* Author(s): [Heng Liu](https://github.com/heng-liu)
* Issue: [5926](https://github.com/NuGet/Home/issues/5926) Consume pdbs from packages in PackageReference - add Debug Symbols to LockFileTargetLibrary
* Type: Feature

## Problem Background

In the PackageReference world, the packages are consumed from the global-packages folder, .pdb, .xml files from lib and runtime folder are not copied into the build output folder.
In some cases, consuming .pdb, .xml files are needed to support certain features, like debugging ( see issue [1458](https://github.com/dotnet/sdk/issues/1458)).
The established design for consuming files out of packages is that NuGet tells the .NET SDK which files are important through the assets file, or to be specific, the [LockFileTargetLibrary](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.ProjectModel/LockFile/LockFileTargetLibrary.cs). 
Currently, NuGet does not select pdb or xml files.

In comparison, in packages.config, .pdb, .xml files are automatically copied from lib folder into the build output folder because of the [ResolveAssemblyReference](https://github.com/dotnet/msbuild/blob/main/src/Tasks/AssemblyDependency/ResolveAssemblyReference.cs#L75) task. So there is no such problem in packages.config.

## Who are the customers

Partner team(.NET SDK) who needs to consume .pdb, .xml files for their features in PackageReference world. 

Take debugging as an example. When a NuGet package includes a .pdb file in its lib folder, in order to debug into the NuGet package, it needs the .pdb file to be copied to the build output folder of the project which references the NuGet package.

## Requirements

* A feature to allow the .NET SDK to consume .pdb, .xml files.

## Goals

* Define an approach to make .NET SDK be able to consume .pdb, .xml files.

## Non-Goals

* .NET SDK side change to consume .pdb or .xml.

## Solution

For any given assembly under lib and runtime folder from a package reference, if there are files next to it that differ only by extension, NuGet will add a "related" property underneath the assembly in targets section of assets file, listing the extensions of these files, seperated by `;`.

* Applies to all the compile time assemblies and runtime assemblies.
* Apply to transitive dependencies.
* Only apply to package reference. Will not apply to project reference.


### Solution - Technical details

#### Package reference:
For example, one project has a package reference of PackageA. Suppose in folder ./PackageA/1.0.0/lib/netstandard2.0, there are PackageA.pdb, PackageA.xml file besides PackageA.dll.
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
              "related": "pdb;xml"
           }
        },
        "runtime": {
           "lib/netstandard2.0/PackageA.dll": {
              "related": "pdb;xml"
           }
      }
    }
  },
```

#### Project reference:
For example, one project has a project reference to ProjectA. Supppose in folder ./ProjectA/lib/net5.0, there are PackageA.pdb, PackageA.xml file besides ProjectA.dll.
Since the [ResolveAssemblyReference](https://github.com/dotnet/msbuild/blob/main/src/Tasks/AssemblyDependency/ResolveAssemblyReference.cs#L75) task will copy the related files, there will be no change in the assets file for project references.

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

On the library side there are no changes. This solution is adding a `related` property in [LockFileItem](https://github.com/NuGet/NuGet.Client/blob/4fef99532f4022504feec5f68c8501cbeadd3aed/src/NuGet.Core/NuGet.ProjectModel/LockFile/LockFileItem.cs). The [LockFileItem](https://github.com/NuGet/NuGet.Client/blob/4fef99532f4022504feec5f68c8501cbeadd3aed/src/NuGet.Core/NuGet.ProjectModel/LockFile/LockFileItem.cs) type which represents an element in the compile list already has a collection of properties.

Specifically:

```cs
  public string Path { get; }

  public IDictionary<string, string> Properties { get; } = new Dictionary<string, string>();
```

So there is no need to change any code references LockFileItem. 

When generating the targets section of assets file, NuGet needs to go through the runtime and compile time folder for the files with specific extensions and add those as the `related` property.  

After it's generated, NuGet will not use the `related` property. It will be consumed at build time by .NET SDK. 

In order to consume the `related` property, the .NET SDK will need to make change in the following part: 

[dotnet/sdk#10947](https://github.com/dotnet/sdk/issues/10947) The build task in the .NET SDK  [ResolvePackageAssets task](https://github.com/dotnet/sdk/blob/80e801ed0ef8027b7894ebd4a8af4fc9afc21ac8/src/Tasks/Microsoft.NET.Build.Tasks/ResolvePackageAssets.cs).


## Considerations

### 1. When there is no other extensions, shall NuGet provide empty string `"related": ""`, or just skip adding `"related": ""` in assets file?
NuGet tends to not adding `"related": ""` if it's there is no other extension. The assets file can get very large. So a general rule is to not write more than absolutely necessary. 

### 2. Will NuGet list not only .pdb and .xml, but also all the extensions in [AllowedReferenceRelatedFileExtensions](https://github.com/dotnet/msbuild/blame/main/src/Tasks/Microsoft.Common.CurrentVersion.targets#L621-L627) if there is any? (.pdb, .xml, .pri, .dll.config, .exe.config)
NuGet will check and add all extension, no matter the extension is in [AllowedReferenceRelatedFileExtensions](https://github.com/dotnet/msbuild/blame/main/src/Tasks/Microsoft.Common.CurrentVersion.targets#L621-L627) or not. So if there is a `a.random`, NuGet will add `random` into the `related` property.

### 3. Will having `related` property make any difference in No-op restore? 
For a package reference, there should be no change in `related` property unless we change to reference a different package/version. So there is no difference in No-op restore when having `related` property.

### 4. In addition to the proposed approach, 2 of other solutions were considered. 

#### **Do nothing - Recommend the customers use the custom target workaround**

The workaround that copying .pdb and .xml file into build output folder(.NET Framework) is as following:
```xml
 <Target Name="_ResolveCopyLocalNuGetPackagePdbsAndXml" 
          Condition="$(CopyLocalLockFileAssemblies) == true" 
          AfterTargets="ResolveReferences">
    <ItemGroup>
      <ReferenceCopyLocalPaths 
        Include="@(ReferenceCopyLocalPaths->'%(RootDir)%(Directory)%(Filename).pdb')" 
        Condition="'%(ReferenceCopyLocalPaths.NuGetPackageId)' != ''
                    and Exists('%(RootDir)%(Directory)%(Filename).pdb')" />
      <ReferenceCopyLocalPaths 
        Include="@(ReferenceCopyLocalPaths->'%(RootDir)%(Directory)%(Filename).xml')" 
        Condition="'%(ReferenceCopyLocalPaths.NuGetPackageId)' != ''
                    and Exists('%(RootDir)%(Directory)%(Filename).xml')" />
    </ItemGroup>
  </Target>
```
Pros:
* It works (in certain condition).

Cons:
* It only works for .NET Framework. For .NET Core, it needs to be adjusted.
* It only copies .pdb and .xml file to build output. If publish output path is different from build output path, it needs to be adjusted to publish .pdb and .xml.


#### **Add as LockFileItem, but not a property of LockFileItem**

Instead of adding existing extension as a property of LockFileItem, adding each exsisting file as a property as a LockFileItem.
So the targets section in assets file is as following:
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
        },
        "symbol": {
           "lib/netstandard2.0/PackageA.pdb": {}
        },
        "xml": {
           "lib/netstandard2.0/PackageA.xml": {}
        },
    }
  },
```
Pros:
* It's as powerful as adding existing extension as a property of LockFileItem.

Cons:
* It's not an open ended solution as the proposed solution.
* NuGet caches all LockFileItem across projects. Since NuGet performs the asset selection for individual package for each framework and runtime combination, for large solutions, the memory allocations for the cache can go large. So NuGet would like to add as less things as possible into the targets section. 

## References
* [dotnet/sdk/1458](https://github.com/dotnet/sdk/issues/1458)
* [Controlling dependency assets](https://docs.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files#controlling-dependency-assets)
* [Customized targets example in Github issue comment](https://github.com/dotnet/sdk/issues/1458#issuecomment-420456386)
* [The performance impact analysis for assets selection path](https://github.com/NuGet/NuGet.Client/pull/3934#issuecomment-875837433)

