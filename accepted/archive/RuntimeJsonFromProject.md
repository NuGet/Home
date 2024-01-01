# Runtime Identifier Graph From Project

* Status: **Reviewing**
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)

## Issue

[7342](https://github.com/NuGet/Home/issues/7351) - Mechanism for supplying runtime.json outside of a package

## Background

In Core 3.0, the platform will not be represented as a traditional NuGet package. As such, there's no obvious place for the RID graph to be provided to NuGet.
The SDK now makes Targeting & Runtime pack decisions prior to restore and provides them through PackageDownload. Due to that it needs to use the same runtime identifier graph as NuGet. 

## Who are the customers

All .NET Core customers.

## Requirements

* A mechanism for the SDK to deliver NuGet the Runtime Identifier Graph

## Solution

```xml
    <PropertyGroup>
        <RuntimeIdentifierGraphPath>full/path/to/runtime.json</RuntimeIdentifierGraphPath>
    </PropertyGroup>
```

The MSBuild recommendation is that files are usually represented as MSBuild items. However we would like to avoid updating the nomination API for this small change.
The property is one per framework, meaning that different frameworks can have a different runtime identifier graph.

## Runtime.Json in assets file

An update to the runtime.json file in the project should cause restore to reevaluate as the resolved graph might be affected. As such the runtime.json path needs to be included in the project section of the assets file. 

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
          },
          "runtimeIdentifierGraphPath": "C:\\Program Files\\dotnet\\sdk\\3.0.100\\runtime.json",
      }
    }
  }
```

There will be no additional changes to the assets file.

### Nomination Updates

There will not be any updates to the nomination API. 
The IVSTargetFrameworkInfo contains a property bag where in the information will be provided. 

[Example](https://github.com/NuGet/NuGet.Client/blob/e8890282d9225d2aeb63deba3ae111f87cfc5673/src/NuGet.Clients/NuGet.SolutionRestoreManager.Interop/IVsTargetFrameworkInfo.cs):

```cs
    [ComImport]
    [Guid("9a1e969a-3e1e-4764-a48b-b823fe716fab")]
    public interface IVsTargetFrameworkInfo
    {
        /// <summary>
        /// Target framework name in full format.
        /// </summary>
        string TargetFrameworkMoniker { get; }

        /// <summary>
        /// Collection of project references.
        /// </summary>
        IVsReferenceItems ProjectReferences { get; }

        /// <summary>
        /// Collection of package references.
        /// </summary>
        IVsReferenceItems PackageReferences { get; }

        /// <summary>
        /// Collection of project level properties evaluated per each Target Framework,
        /// e.g. PackageTargetFallback.
        /// </summary>
        IVsProjectProperties Properties { get; }
    }
```

## Pack scenarios

There are no pack scenarios. These are framework assets and should not be packaged.

### Validation

NuGet will do the same validations for the runtime graph as is does from the package. Currently those are limited. An improvement to this will be done orthogonally to this effort.
No special validation will be added for the project provided runtime.json and no preference is given to either project or package provided runtime.json.
If the path provided to NuGet does not exist, NuGet will raise a coded error.

## Considerations

### Why not make the runtime identifier graph path an item

The concern here are implementational difficulty. We would prefer to avoid another nomination API change for something as little as this. There are no scenarios where more than just the path needs to be provided to NuGet. 

### Will we ever need to provide more than one runtime identifier graph

There is no such scenario at this point. The same information could be provided in 1 runtime.json. If needed later, we can extend this design to accept a `;` delimited list of paths.
