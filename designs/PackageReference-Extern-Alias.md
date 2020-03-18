# Extern alias with PackageReference

* Status: In Review
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)
* Issue: [4989](https://github.com/NuGet/Home/issues/4989) Extern alias support for NuGet package references
* Type: Feature

## Problem Background

In the PackageReference world there is no way to add assembly specific metadata.
Sometimes multiple packages might carry the same type, and in those cases the solution is use the alias feature, but there's no native way to do that in PackageReference.
In contrast to packages.config, one can add the extra metadata to the assembly include.

## Who are the customers

All PackageReference customers

## Requirements

* A feature or guidance to allow the customers to specify an alias for an assembly.

## Goals

* Define an approach to define alias for assemblies from a specific package.

## Non-Goals

* Define an approach for defining additional assembly metadata.
* Define an approach for defining aliases or any other assembly metadata for packages brought in transitively.

## Solution

The problem of assembly metadata for assemblies is not unique unique to aliasing only, but it's definitely the most common one. 
In PackageReference all customizations are on the PackageReference item itself. For example, `IncludeAssets`, `PrivateAssets`, `GeneratePathProperty` etc. 
As such the proposed approach is the following: 

```xml
<ItemGroup>
    <PackageReference Include="NuGet.Contoso.Library.Signed"  Version="1.26.0" Aliases="signed" />
</ItemGroup>
```

* Applies to all the compile time assemblies.
* Does not apply to transitive dependencies.
* More than one alias is allowed in an equivalent fashion to [ProjectReference.Aliases](https://docs.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.projectreference.aliases?). Specifically to define more than alias, specify `first,second`.

The limitation of this approach is that it does not allow per assembly granularity. 
However the intuitiveness of this approach as it's analogous to [ProjectReference.Aliases](https://docs.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.projectreference.aliases?), and the fact that a large majority of public packages have only 1 assembly per package (per framework), were the deciding factor to adopt this approach.

### Solution - Technical details

TODO NK - the specification. 
TODO NK - implementation.

## Future Work

* Package metadata for transitive package references will be considered in the future. 

## Open Questions

* None

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

```xml
<ItemGroup>
    <PackageReference Include="StackExchange.Redis.StrongName.Signed" Version="1.26.0" Aliases="signed" />
</ItemGroup>
```

For transitive packages we could introduce a new item type, where customers could provide the transitive package alias/NoWarn at some point in the future. 

```xml
<ItemGroup>
    <TransitivePackageReference Include="StackExchange.Redis.StrongName.Signed" Aliases="signed" NoWarn="NU1701" />
</ItemGroup>
```

This approach drastically increases the scope of this work, but given that it's additive. 
Given that we are not confident that this is how we want to address the transitive package metadata problems this is just listed here for completeness.

### References

* https://github.com/NuGet/Home/issues/4989
* https://github.com/NuGet/Home/issues/5740
* https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/extern-alias
* https://docs.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.projectreference.aliases?view=roslyn-dotnet

