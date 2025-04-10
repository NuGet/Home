# Extern alias support with PackageReference

* Status: Reviewed
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)
* Issue: [4989](https://github.com/NuGet/Home/issues/4989) Extern alias support for NuGet package references
* Type: Feature

## Problem Background

In the PackageReference world there is no way to add assembly specific metadata.
Sometimes multiple packages might carry the same type, and in those cases the solution is to use the alias feature. However, there's no native way to do that in PackageReference.
In comparison, in packages.config, one can add the extra metadata to the assembly included because all the assembly references are written in the project file. 

## Who are the customers

All PackageReference customers

## Requirements

* A feature or guidance to allow the customers to specify an alias for an assembly.

## Goals

* Define an approach to define alias for assemblies from a specific package.

## Non-Goals

* Define an approach for defining additional assembly metadata.
* Adding metadata such `PrivateAssets`, `GeneratePathProperty` etc. is still csproj XML only, no UI exeperience will be added. 
* Define an approach for defining aliases or any other assembly metadata for packages brought in transitively.

## Solution

The problem of assembly metadata for assemblies is not unique unique to aliasing only, but it's definitely the most common one. 
In PackageReference all customizations are on the PackageReference item itself. For example, `IncludeAssets`, `PrivateAssets`, `GeneratePathProperty` etc. 
As such the proposed approach is the following: 

```xml
<ItemGroup>
    <PackageReference Include="NuGet.Contoso.Library.Signed"  Version="1.26.0" Aliases="signed" />
    <PackageReference Include="NuGet.Contoso.Other.Library"  Version="1.26.0" Aliases="first,second" />
</ItemGroup>
```

* Applies to all the compile time assemblies.
* Does not apply to transitive dependencies.
* More than one alias is allowed in an equivalent fashion to [ProjectReference.Aliases](https://docs.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.projectreference.aliases?). Specifically to define more than alias, specify `first,second`.

The limitation of this approach is that it does not allow per assembly granularity. 
However the intuitiveness of this approach as it's analogous to [ProjectReference.Aliases](https://docs.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.projectreference.aliases?), and the fact that a large majority of public packages have only 1 assembly per package (per framework), were the deciding factor to adopt this approach.

### Solution - Technical details

In PackageReference, everything about packages is in the assets file, as such the changes are the following: 

In the csproj the specification is: 

```xml
<ItemGroup>
    <PackageReference Include="NuGet.Contoso.Library.Signed"  Version="5.6.0" Aliases="signed" />
</ItemGroup>
```

In the targets section of the assets file, where the compile items are listed out: 
```json
  "targets": {
    ".NETCore,Version=v.3.0": {
      "NuGet.Contoso.Library.Signed/5.6.0": {
        "type": "package",
        "compile": {
          "lib/netstandard2.0/NuGet.Contoso.Library.Signed.dll": {
            "Aliases" : "signed"
          }
        },
        "runtime": {
          "lib/netstandard2.0/NuGet.Contoso.Library.Signed.dll": {}
        }
      }
    },
```

NuGet will not interpret this string. If multiple aliases were provided, it will look like: 

```json
  "targets": {
    ".NETCore,Version=v.3.0": {
      "NuGet.Contoso.Other.Library/5.6.0": {
        "type": "package",
        "compile": {
          "lib/netstandard2.0/NuGet.Contoso.Other.Library.dll": {
            "Aliases" : "first,second"
          }
        },
        "runtime": {
          "lib/netstandard2.0/NuGet.Contoso.Other.Library.dll": {}
        }
      }
    },
```

Note that only the compile items have the additional properties. 

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

### Support `Aliases` as a PackageReference property & provide a way to address transitively dependency out of the box

A future evolution of the current approach could be the addition of metadata for transitive packages. 

For transitive packages we could introduce a new item type, where customers could provide the transitive package alias/NoWarn at some point in the future. 

```xml
<ItemGroup>
    <TransitivePackageReference Include="NuGet.Contoso.Library.Signed" Aliases="signed" NoWarn="NU1701" />
</ItemGroup>
```

This approach drastically increases the scope of this work, but given that it's additive. 
Given that we are not confident that this is how we want to address the transitive package metadata problems this is just listed here for completeness.

### References

* NoWarn does not apply transitively [5740](https://github.com/NuGet/Home/issues/5740)
* Extern alias language [docs](https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/extern-alias)
* ProjectReference.Aliases [docs](https://docs.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.projectreference.aliases?view=roslyn-dotnet)
* [dotnet/sdk/10947](https://github.com/dotnet/sdk/issues/10947) The build tasks on (.NET Core SDK side)
* [dotnet/NuGet.BuildTasks/7](https://github.com/dotnet/NuGet.BuildTasks/issues/70) The build tasks for the non-SDK based PackageReference
* [dotnet/project-system/6011](https://github.com/dotnet/project-system/issues/6011) Nomination updates on project-system side.
