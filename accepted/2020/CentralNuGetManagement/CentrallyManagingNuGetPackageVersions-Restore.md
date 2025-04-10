# Centrally managing NuGet package versions - Restore Design Spec

* Status: **In Review**
* Author(s): [Cristina Manu](https://github.com/cristinamanum)

## Feature Spec

[Centrally managing NuGet package versions](https://github.com/NuGet/Home/wiki/Centrally-managing-NuGet-package-versions) - Support for download only packages scenario

## Problem Background
NuGet users cannot easily express the intention of using centralized package versions for a Visual Studio solution or a repository. [MSBuild SDK](https://github.com/microsoft/MSBuildSdks/tree/master/src/CentralPackageVersions) currently enables this support, however the users need to be aware of this feature and to integrate it in their development pipelines. The goal is to enable the support for centralized package version management in NuGet.

## Who are the customers

All .NET customers that have PackageReference projects and need to manage the versions of the packages at a central level.

## Goals

Define and document the changes that need to be done to integrate Central Package Version management with the Restore (nuget restore, MsBuild restore and VS) flows.

## Non - Goals

1. This spec will not contain changes needed to support the new Visual Studio UI experiences (Edit, Consolidation etc).
2. This spec will not contain the design of the new / updated DotNet CLI commands.

## Scenarios

The following scenarios will be enabled when the proposed design changes will be completed.

1. Given an well formatted CPVM file `msbuild /t:restore`and `nuget.exe restore` will respect the package versions defined in the Directory.Packages.props.
2. The restore from Visual Studio will correctly use the information from CPVM file.
3. The support for Visual Studio experience will be co-owned with the Project System team. For the first phase the package reference read only experience should not be degraded.


## Requirements

The requirements are defined in the [feature spec](https://github.com/NuGet/Home/wiki/Centrally-managing-NuGet-package-versions). A summary of the requirements targeted only at this design are below.


* For a project that is opted in to CPVM, it should not be possible to specify PackageReference with Version metadata at the project level. Otherwise an error is raised.
* There will be an opt-in/opt-out switch for projects to opt-in CPVM. [Default: Opt-in]
* The Private Assets and the other PackageReference metadata except Version need to be defined at the PackageReference level.
* The Package versions defined in the Central Package Versions file are respected for direct and transitive dependencies.
* Pack command will pack the transitive dependencies if pinned through CPVM.
* The goal is to not regress Restore performance - performance data needs to be provided to make an informed decision before release.

## Solution

Introduce a new `PackageVersion` MSBuild item type that will be used to set the Central Package Version information.

``` xml

<PackageVersion Include="Newtonsoft.Json Version="12.0.2" />

```

### Dependency graph spec changes

1. The direct package dependency versions will be the versions defined in the CPVM.
2. The Package spec will contain the list of the CPVM defined versions (snapshot below). Any direct dependency resolved through CPVM will not be included in the `centraldependencies` list.

``` json
   "frameworks": {
      "netcoreapp2.2": {
        "dependencies": {
          "EntityFramework": {
            "target": "Package",
            "version": "[6.2.0, )"
          },
          "Microsoft.NETCore.App": {
            "suppressParent": "All",
            "target": "Package",
            "version": "[2.2.0, )",
            "autoReferenced": true
          },
          "ParentLibTestCM1": {
            "target": "Package",
            "version": "[3.0.0, )"
          }
        },
         "centraldependencies": {
          "Newtonsoft.Json": "[12.0.2, )",
          "NUnit": "[3.12.0, )"
        }

```

### project.assets.json changes

1. The project spec changes mentioned above will be applied to the project.assets.json
2. It will be new element added to track the central defined packages that were transitively pinned. The information will be used by the pack command to include the pinned transitive packages as dependencies to the new nuspec.
Snapshot of the new element below. In this example Newtonsoft.Json is a transitive dependency that was pinned. The transitive dependency included assets will be restricted on the dependency chain. For example in the example below the Newtonsoft.Json was added through dependencies that had `... exclude="Runtime,Build,Analyzers">`

``` json
   "centrallyManagedTransitiveDependencyGroups": {
      "frameworks": {
         "netcoreapp2.2": {
         "Newtonsoft.Json": {
         "include": "Compile, Native, BuildTransitive",
         "target": "Package",
         "version": "[12.0.2, )"
        }
      }
    }
```

### NuGet.targets

1. There will be a 'CollectCentralPackageVersions` target that will collect the central defined PackageVersion items.
2. The NuGet MsBuild task (`GetRestorePackageReferencesTask`) will be updated to process the central PackageVersion items.
3. The targets will include the below sequence for enabling the Update of current project PackageReference. The functionality depends on a [new feature](https://mseng.visualstudio.com/1ES/_workitems/edit/1649689) to be added in MsBuild. This is necessary to support the Legacy projects.

``` xml
<ItemGroup Condition="'$(UsingMicrosoftNETSdk') != 'true' AND '$(DisableCentralPackageVersions)' != 'true'">
  <!--
    Update PackageReference items for legacy project system 
    Only copy Version metadata in case user specified some other metadata
  -->
  <PackageReference Update="@(PackageVersion)" Version="%(Version)" />
</ItemGroup>

```

**[Note]** The update above will work on the SDK style projects as well. In that case the merge of the two sets (planned to be done on the NuGet side) will be done automatically through MsBuild. However the MsBuild approach could be slower.

4. There will be a new task (name to be decided) with the purpose of warning in case of the legacy projects in case that a central transitive dependency was not honored.

### Implementation

#### MsBuild / NuGet Restore

Flow of the central package information through NuGet types.

![RestoreFlow](https://user-images.githubusercontent.com/16580006/69378663-ad7a7200-0c63-11ea-89a7-e469e0c33bd9.png)
Figure 1

##### TargetFrameworkInformation

PackageSpec definition depends on TargetFrameworkInformation. TargetFrameworkInformation will have a new property added that will store the central packages dependencies.

``` C#
   public IList<CentralDependency> CentralDependencies { get; set; }
```

``` C#
   public class CentralDependency : IEquatable<CentralDependency>, IComparable<CentralDependency>
      {
          public string Name { get; }

          public VersionRange VersionRange { get; }

          public CentralDependency(
              string name,
              VersionRange versionRange)
          {
              Name = name;
              VersionRange = versionRange;
          }

           ....
      }
```

The PackageSpec reader/writer will be updated to serialize / de-serialize the new information.

##### Restore Task

RestoreTask creates the dependency spec based on the MSBuild information. The NuGet.Commands.MSBuildRestoreUtility will be updated with new APIs that:

1. Will merge the central package reference information with the project defined package reference information.
2. Will collect all the central defined package references and use it to the create the PackageSpec with the new information added to the list of TargetFrameworks.

**[Note]** A new restore task will be created for the new performance improvements design changes. The DGSpec creation will need to be updated to include the central PackageVersion information.

##### RemoteWalkContext

A new property will be added to keep the central dependencies. This information will be used by the `RemoteDependencyWalker` while creating the restore graph to swap any node information with the information from the central package version if present.

``` C#
public Dictionary<NuGetFramework, List<LibraryDependency>> CentralDependencies { get; set; } ;
```

##### RemoteDependencyWalker

RemoteDependencyWalker creates the restore graph. This type will not have any new properties added but the GraphItems will include new information as explained in the `GraphItem`below.

**RemoteDependecyWalker.CreateGraphNode** method will check the current node and if a transitive dependency is found the current node version will be swapped with the transitive version. The Figure 1 above attempts to offer a visual representation.

##### GraphItem

A GraphNode in the RestoreGraph has the GraphItem type storing information for the current package in the graph.
GraphItem is the type used for the restore graph item nodes. It will be updated to include information regarding with the current node library being hijacked by the central package information.

The new properties are:

``` C#

      //It will be not null if the node was hijacked by a central dependency
      public LibraryDependency CentralDependency { get; set; }
      //The parent package may have a set of Included flags. Keep this information for pack command usage.
      public LibraryIncludeFlags InheritedLibraryIncludeFlags { get; set; }
      public bool EnforcedFromCentralVersion { get { return CentralDependency != null; } }

```

##### LockFile

The LockFile corresponds with the project.assets.json. It will have a new property added to represent the list of `ProjectFileTransitiveDependencyGroup'.
This list will be not empty only if there are transitive dependencies enforced by central package definition.

``` C#
public IList<ProjectFileTransitiveDependencyGroup> ProjectTransitiveDependencyGroups { get; set; };
```

##### LockFileFormat / LockFileBuilder

These types build read and write the project.assets.json. they will be updated to handle the new `projectFileTransitiveDependencyGroups` list.

#### Visual Studio Restore

Visual Studio Project System communicates with NuGet through four interfaces:

* `IVsSolutionRestoreService3`
* `IVsProjectRestoreInfo2`
* `IVsTargetFrameworks2`
* `IVsTargetFrameworkInfo2`

To support the new item type(`PackageVersion`) a interface need to be added;

``` C#

    public interface IVsTargetFrameworkInfo3 : IVsTargetFrameworkInfo2
    {
        /// <summary>
        /// Collection of central package versions.
        /// </summary>
        IVsReferenceItems CentralPackageVersions { get; }
    }

```

The flow of metadata through NuGet in Visual Studio

![image](https://user-images.githubusercontent.com/16580006/69378774-ea466900-0c63-11ea-8b5f-ba9f36c8c13f.png)

To enable this flow in addition to the mentioned above interfaces it will be needed to update the VsSolutionRestoreService to

1. Implement IVsSolutionRestoreService3
2. Update the ToDependencyGraphSpec to consume the CentralPackage version information and create the correct graph.
3. Possibly validate the nomination data.

#### Import of CPVM props file

Currently NuGet does not have a path on the props import. CPVM file will be imported following the same pattern as Directory.build.props.


#### Pack

1. The `PackTaskLogic` will need to be updated to consume the transitive dependencies.
2. Switch for opt-out of packing the transitive dependencies will need to be added.


### Error handling

1. A package dependency downgrade will be treated as an error with a new error code.
2. If projects will define PackageReferences with versions an error will be generated at the restore time. The validation logic will be done at the NuGet api logic.

### Telemetry

Telemetry events will need to provide enough information to answer to the questions below:

1. How many projects use CPVM?
2. How many projects had transitive dependencies that were pinned?
3. How many projects got the downgraded error because of transitive pinning?

**[Note]** Restore performance events are already in place they can be correlated with the above data to answer perf questions.  
**[Note]** Solution - project mapping is already possible through VS telemetry. It should be enough to get statistics regarding solutions with projects that use CPVM or opted-out CPVM.

### Future work

* dotnet CLI commands
* Visual Studio UI

### Alternative approaches considered

#### Use of Update MsBuild Item attribute

MSBuild SDK already provides a solution for centralized package version following a design using the MsBuild item Update attribute.
The same approach could not be followed because the need to support the pinning of transitive dependencies.  

#### CPVM file import

##### Import path

CPVM import can be done on the props path (before the project import) or targets path (after the project is imported).
While in a solution based on usage of the `Update` attribute the import needs to be done on the targets path in the current design there is not a need to import it on pros or targets. The MsBuild guidelines/recommendations is to import .props on the props path and targets on the targets path. In this context the decision was made to import the CPVM on the props path.

##### Directory.build.props

Directory.build.props is imported on the props path the same as CPVM file will be. Tools could automatically update the CPVM file and this is not a scenario desired for Directory.build.props.

#### Pinning of transitive dependencies

The users today can add direct dependencies to their projects if they need to force a specific version. Auto pinning of transitive dependencies was a feature desired by partner teams.

## References

* https://github.com/NuGet/Home/wiki/Centrally-managing-NuGet-package-versions
* https://github.com/microsoft/MSBuildSdks/tree/master/src/CentralPackageVersions

## Appendix 1 : Additional options for persistence of the central dependencies.
The central dependencies will be persisted in the dgspec and in consequence in the project.assets.json files. They need to be persisted in the dgspec as the dgspec is the input for the restore. If not persisted there the "nuget restore" will not work. NuGet restore design follows the following pattern:

1. Call *** msbuild task to write the dgspec to a temp folder
2. Read the information from the temp dgspec and proceed with restore. 
If the central package information is not save in the temp dgspec the information will not be available to restore in step 2. 

Two alternate approaches(below) were discussed. The decision was to go with the main approach and profile for performance. 

**Alternate approach 1**

Change nuget.exe restore to use msbuild /t:restore instead of the above two steps approach. With the current support of package config from msbuild the approach could be feasible.  
Pros: Consolidation of the restore paths.  
Cons: The nuget restore command support a large set of options. It may not be possible to implement all of them in msbuild /t:restore. Engineering cost.
        

**Alternate approach 2**
Two dgspec writers. The MsBuild task will use a writer that will write more data than the writer that writes to the obj folder.

Pros: Less data added to the dgspec.  
Cons: Inconsistency between the dgspecs. Complexity.

The decision was to move ahead with the documented approach and execute performance profiling.

