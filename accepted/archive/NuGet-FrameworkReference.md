# FrameworkReference in NuGet

* Status: **Implemented**
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)

## Issue

[7342](https://github.com/NuGet/Home/issues/7342) - Represent FrameworkReferences in NuGet - pack & restore support

## Background

Starting with .NET Core 3.0 the traditional package based approach for .NET Core like target frameworks is changing as described in the following dotnet [design](https://github.com/dotnet/designs/pull/50).
Shared frameworks like ASP.NET & .NETCore App will no longer be represented as a PackageReference, rather as a FrameworkReference in the project file, like below.

```xml
<ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App"/>
</ItemGroup>
```

This spec discusses the NuGet handling of FrameworkReference in projects and packages.

## Who are the customers

All .NET Core customers.

## Requirements

* FrameworkReference are part of the representation of a library/app, and as such NuGet will need to represent them in packages.
* FrameworkReference are transitive, both project to project and project to package. Restore will need to represent that in the assets file.

## Solution

## FrameworkReference in the package

The nuspec schema will be changed as following:

```xml
<xs:complexType name="frameworkReference">
    <xs:attribute name="name" type="xs:string" use="required" />
</xs:complexType>

<xs:complexType name="frameworkReferenceGroup">
    <xs:sequence>
    <xs:element name="frameworkReference" minOccurs="0" maxOccurs="unbounded" type="frameworkReference" />
    </xs:sequence>
    <xs:attribute name="targetFramework" type="xs:string" use="required" />
</xs:complexType>

...
    <metadata>
        ...
        <xs:element name="frameworkReferences" maxOccurs="1" minOccurs="0">
            <xs:complexType>
                <xs:sequence>
                    <xs:element name="group" minOccurs="0" maxOccurs="unbounded" type="frameworkReferenceGroup" />
                </xs:sequence>
            </xs:complexType>
        </xs:element>
        ...
    </metadata>
...
```

This schema mimics the handling of the dependencies section.
Note the `targetFramework` attribute on the frameworkReferenceGroup is required compared to dependency where it's not. This is an evolution the product as the huge number of targetFrameworks would lead to NuGet silently ignoring compatibility problems.

A nuspec would look like below:

```xml
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">
  <metadata>
    <id>LibraryA</id>
    <version>1.0.0</version>
    <authors>Microsoft</authors>
    <owners>Microsoft</owners>
    <dependencies>
      <group targetFramework=".NETCoreApp3.0">
        <dependency id="LibraryB" version="1.0.0" exclude="Build,Analyzers" />
      </group>
    </dependencies>
    <frameworkReferences>
      <group targetFramework=".NETCoreApp3.0">
          <dependency name="Microsoft.WindowsDesktop.App|WPF"/>
      </group>
    </frameworkReferences>
  </metadata>
</package>


```

## FrameworkReference in assets file

As FrameworkReference are transitive in project-to-project and project-to-package scenarios, the FrameworkReference will be a part of the NuGet identifiable project information or commonly referred as the PackageSpec. A restore for the project requires knowledge of it's transitive project dependencies which include the FrameworkReferences.

The package spec in the json will be updated as follows.

```json
"project": {
    "version": "1.0.0",
    "restore": {
      "projectUniqueName": "F:\\FrameworkReference\\LibraryA\\LibraryA.csproj",
      "projectName": "LibraryA",
      "projectPath": "F:\\FrameworkReference\\LibraryA\\LibraryA.csproj",
      "packagesPath": "F:\\FrameworkReference\\globalPackagesFolder",
      "outputPath": "F:\\FrameworkReference\\LibraryA\\obj\\",
      "projectStyle": "PackageReference",
      "fallbackFolders": [
        "C:\\Program Files\\dotnet\\sdk\\NuGetFallbackFolder"
      ],
      "configFilePaths": [
        "C:\\Users\\User\\AppData\\Roaming\\NuGet\\NuGet.Config",
        "C:\\Program Files (x86)\\NuGet\\Config\\Microsoft.VisualStudio.Offline.config"
      ],
      "originalTargetFrameworks": [
        "netcoreapp3.0"
      ],
      "sources": {
        "C:\\Program Files (x86)\\Microsoft SDKs\\NuGetPackages\\": {},
        "https://api.nuget.org/v3/index.json": {}
      },
      "frameworks": {
        "netcoreapp3.0": {
          "projectReferences": {}
        }
      },
      "warningProperties": {
        "warnAsError": [
          "NU1605"
        ]
      }
    },
    "frameworks": {
      "netcoreapp3.0": {
          "frameworkReferences": {
            "Microsoft.WindowsDesktop.App|WPF" : {
              "privateAssets" : "none"
          }
      }
    }
  }
```

### FrameworkReference Project-to-Project restore

The targets section of the assets file contains the information about all the selected assets from a package/project.
The FrameworkReference information will be added there.

```json
"NETCoreApp,Version=v3.0": {
      "LibraryA/1.0.0": {
        "type": "project",
        "framework": ".NETFramework,Version=v4.6",
        "compile": {
          "bin/placeholder/LibraryA.dll": {}
        },
        "runtime": {
          "bin/placeholder/LibraryA.dll": {}
        },
        "frameworkReferences": [
          "Microsoft.WindowsDesktop.App|WPF"
        ]
      }
    }
```

### FrameworkReference Project-to-Package restore

Similar to the project-to-project case, the targets section will be updated to include FrameworkReference information if needed.

```json
"NETCoreApp,Version=v3.0": {
    "LibraryA/1.0.0": {
    "type": "package",
    "compile": {
        "lib/netcoreapp3.0/LibraryA.dll": {}
    },
    "runtime": {
        "lib/netcoreapp3.0/LibraryA.dll": {}
    },
    "frameworkReferences": [
        "Microsoft.WindowsDesktop.App|WPF"
    ]
    }
},
```

The `LockFileTargetLibrary` model will be extended with a list of framework references.

```cs
        public IList<string> FrameworkReferences { get; }
```

### Controling the transitivity flow in project-to-project FrameworkReferences

The `FrameworkReference` item supports the `PrivateAssets` attribute.
In contrast to `PackageReference`, the only applicable values for `PrivateAssets` here are `all` or `none`. 

```xml
<FrameworkReference Include="Microsoft.NetCore.App" PrivateAssets="all"/>
```

When all is specified, the FrameworkReference does not flow transitively or get packed. 

### Nomination Updates

Since the project-system is how NuGet gets all of it's information about projects in VS, the API will be updated to support FrameworkReference. As they'll be released together, the same API that adds support for `PackageDownload` will add support for FrameworkReference.

[Example](https://github.com/NuGet/NuGet.Client/blob/e8890282d9225d2aeb63deba3ae111f87cfc5673/src/NuGet.Clients/NuGet.SolutionRestoreManager.Interop/IVsTargetFrameworkInfo2.cs):

```cs
    [ComImport]
    [Guid("451ACBA6-FE6A-4412-99D2-3882790BF338")]
    public interface IVsTargetFrameworkInfo2 : IVsTargetFrameworkInfo
    {
        /// <summary>
        /// Collection of package downloads.
        /// </summary>
        IVsReferenceItems PackageDownloads { get; }

        /// <summary>
        /// Collection of FrameworkReferences
        /// </summary>
        IVsReferenceItems FrameworkReferences { get; }
    }
```

## Pack scenarios

The NuGet.Build.Tasks.Pack will consider the FrameworkReference item and pack accordingly.
The csproj will usually not contain the FrameworkReference item declarations explicitly as they'll be wired in by the SDK as detailed in their [design](https://github.com/dotnet/designs/pull/50).
The packing of a specific FrameworkReference can also be disabled by specifying `PrivateAssets="all"`.

```xml
<FrameworkReference Include="Microsoft.NetCore.App" PrivateAssets="all"/>
```

The `Microsoft.NetCore.App` is not an optional framework reference so the SDK will always specify with `PrivateAssets="all"`. NuGet will not account for that.

The nuspec pack will work similarly, validating the standard target framework validation.

### Validation

NuGet will treat the framework references as case insensitive strings. NuGet will not do any further validation during pack or restore.

The SDK will handle `not applicable` FrameworkReference errors. [Task](https://github.com/dotnet/sdk/issues/3011)

## Considerations

### Why not re-use the framework assembly representation in packages

To refer from the [design](https://github.com/dotnet/designs/pull/50), a `FrameworkReference` is a new MSBuild item that represents a reference to a well-known *group* of framework assemblies that are versioned with the project's `TargetFramework`.
NuGet can already handle framework assemblies by reading the `Reference` item and representing it in the [nuspec](https://docs.microsoft.com/en-us/nuget/reference/nuspec#frameworkassemblies).
The weakness in this approach is not having the ability to conditionally include a framework reference for only a certain set of framework ranges.

Take the following example:

```xml
<frameworkAssemblies>
    <frameworkAssembly assemblyName="Microsoft.WindowsDesktop.App|WinForms"  targetFramework="netcoreapp3.0" />
    <frameworkAssembly assemblyName="Microsoft.WindowsDesktop.App|WPF" targetFramework="netcoreapp3.0" />
</frameworkAssemblies>
```

There is no way to say, I want those 2 references for `netcoreapp3.0`, but for `netcoreapp4.0` I don't want `Microsoft.WindowsDesktop.App|WPF`. We could potentially introduce some sort of a special targetFramework value but that could break old readers. Introducing a new attribute would have the same effect.

The solution to the above is to use groups similar to the way dependencies are handled.

Furthermore we need to distinguish between true FrameworkReference and framework assemblies. We could introduce a special character that signals a framework reference but that seems like an error prone solution.

Pack is anyways going to get updates to read FrameworkReference, and I don't see any major drawbacks from having a complete solution.

### What happens in the future if/when FrameworkReference are added to other frameworks

Would there be *framework* specific *FrameworkReference*s? Notable that cross framework family transitivity is not an issue because .NET Core is not a dependant of any framework family in the frameworks matrix.
Say .NET Standard becomes non monolithic and we add optional shared frameworks such as WPF. Every implementer will need to support the shared frameworks that the standard declares. The scenario becomes more complex when the frameworks in question are not the standard + implementer. And while there’s no plans for this changing it’s worth considering now so if needed we can account for it early.

### How does the fact that NuGet does not understand compatibility between FrameworkReference and a framework affect Package Applicability

This means that certain packages could fail during build time but not at restore time.
It could be solved by eventually having the SDK pass a mapping from TFM -> FrameworkReference
