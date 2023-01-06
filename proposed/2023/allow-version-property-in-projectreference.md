# Allow users to define version ranges for ProjectReferences

- [Martin Ruiz](https://github.com/martinrrm)
- Start Date (2023-01-01)
- [5556](https://github.com/NuGet/Home/issues/5556)

# Summary

Add a `Version` to `ProjectReference` tag in CSPROJ, to allow customers to specify the referenced project version in the `.nupkg` and `nuspec` files when doing a pack command.

# Motivation

When using `ProjectReference` there is no option to define a Version to the reference like in `PackageReference` and the version will always be defined as `>= ProjectVersion`, this results in customers manually modifying the nuspec file if they want to declare a different version than the project version.

# Explanation

Currently when adding a `ProjectReference` to a project, there is no property to specify which version(s) of it to be used when doing a pack. 
When doing a pack to a package with a `ProjectRefernce` it will always be added as a range, where the minumum version will be the ProjectReference version and with an open maximum version.

```
<ItemGroup>
    <ProjectReference Include="../MyReferencedPackage/MyReferencedPackage.csproj" />
</ItemGroup>
```

Add a `Version` property to `ProjectReference` and store that value in the assets file when doing a restore so we can retrieve that information when doing a `pack command.

If there is no `Version` information then the behavior should be the current one.

## Example

### .CSPROJ file
```
<ItemGroup>
    <PackageReference Include="Newtonsoft.Json" Version="[9.0.0, 13.0.2)" />
    <ProjectReference Include="../MyReferencedPackage/MyReferencedPackage.csproj" Version="[1.0.0, 2.0.0)" />
</ItemGroup>
```

### assets file
```
"frameworks": {
    "net6.0": {
        "targetAlias": "net6.0",
        "projectReferences": {
            "C:\\Users\\mruizmares\\source\\repos\\ConsoleApp1\\MyReferencedPackage\\MyReferencedPackage.csproj": {
                "projectPath": "C:\\Users\\mruizmares\\source\\repos\\ConsoleApp1\\MyReferencedPackage\\MyReferencedPackage.csproj",
                "version": "[1.0.0, 2.0.0)"
            }
        }
    }
},
```

### nuspec file
```
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2012/06/nuspec.xsd">
  <metadata>
    <id>ConsoleApp1</id>
    <version>1.2.4</version>
    <authors>ConsoleApp1</authors>
    <description>Package Description</description>
    <dependencies>
      <group targetFramework="net6.0">
        <dependency id="MyReferencedPackage" version="[1.0.0, 2.0.0)" exclude="Build,Analyzers" />
        <dependency id="Newtonsoft.Json" version="[9.0.0, 13.0.2)" exclude="Build,Analyzers" />
      </group>
    </dependencies>
  </metadata>
  <files>
    <file src="C:\Users\mruizmares\source\repos\ConsoleApp1\ConsoleApp1\bin\Debug\net6.0\ConsoleApp1.runtimeconfig.json" target="lib\net6.0\ConsoleApp1.runtimeconfig.json" />
    <file src="C:\Users\mruizmares\source\repos\ConsoleApp1\ConsoleApp1\bin\Debug\net6.0\ConsoleApp1.dll" target="lib\net6.0\ConsoleApp1.dll" />
  </files>
</package>
```

### nupkg
```
Metadata:
  id: ConsoleApp1
  version: 1.2.4
  authors: ConsoleApp1
  description: Package Description
Dependencies:
  net6.0:
    MyReferencedPackage: '>= 1.0.0 && < 2.0.0'
    Newtonsoft.Json: '>= 9.0.0 && < 13.0.2'

Contents:
  - File:    _rels/.rels
  - File:    [Content_Types].xml
  - File:    ConsoleApp1.nuspec
  - File:    lib/net6.0/ConsoleApp1.dll
  - File:    lib/net6.0/ConsoleApp1.runtimeconfig.json
  - File:    package/services/metadata/core-properties/a638a18cb3b1449185ce67e16a13ebaf.psmdcp
```

# Drawbacks

I don't think there are drawbacks to this implementation when doing a `pack` command. For restore I'm not sure if adding a new propert to the assets file can affect the performance.

# Rationale and alternatives

# Unresolved Questions

# Future Possibilities