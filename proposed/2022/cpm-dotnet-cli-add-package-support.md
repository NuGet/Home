# Adding Dotnet CLI add package command support to projects onboarded with Central Package Management

- Author: [Pragnya Pandrate](https://github.com/pragnya17), [Kartheek Penagamuri](https://github.com/kartheekp-ms)
- Issue: [11807](https://github.com/NuGet/Home/issues/11807)
- Status: In Review

## Summary

The dotnet add package command allows users to add or update a package reference in a project file through the Dotnet CLI. However, when this command is used in a project that has been onboarded to Central Package Management (CPM), it poses an issue as this error is thrown: `error: NU1008: Projects that use central package version management should not define the version on the PackageReference items but on the PackageVersion items: [PackageName]`.

The main goal is to add support for `dotnet add package` to be used with projects onboarded onto CPM. Regardless of whether the package has already been added to the project or not, the command should allow users to add packages or update the package version in the `Directory.Packages.props` file.

## Motivation

Projects onboarded to CPM use a `Directory.Packages.props` file in the root of the repo where package versions are defined centrally. Ideally, when the `dotnet add package` command is used, the package version should only be added to the corresponding package in the `Directory.Packages.props` file. However, currently the command attempts to add the package version to the `<PackageReference />` in the project which conflicts with the CPM requirements that package versions must only be in the `Directory.Packages.props` file.

Users wanting to use CPM onboarded projects and dotnet CLI commands will be benefited.

## Explanation

### Functional explanation

When `dotnet add package` is executed in a project onboarded to CPM (meaning that the `Directory.Packages.props` file exists) there are a few scenarios that must be considered.

| Scenario # | PackageReference exists? | VersionOverride exists? | PackageVersion exists? | Is Version passed from the commandline? | New behavior in dotnet CLI | In Scope |
| ---- |----- | ----- | ---- |---- | ----- | ---- |
| 1 | ❌ | ❌ | ❌ | ❌ | Add `PackageReference` to the project file. Add `PackageVersion` to the `Directory.Packages.Props` file. Use latest version from the package sources. | ✔️ |
| 2 | ❌ | ❌ | ❌ | ✔️ | Add `PackageReference` to the project file. Add `PackageVersion` to the `Directory.Packages.Props` file. Use version specified in the commandline. | ✔️ |
| 3 | ❌ | ❌ | ✔️ | ❌ |  Add `PackageReference` to the project file. No changes to the `Directory.Packages.Props` file. Basically we are reusing the version defined centrally for this package. | ✔️ |
| 4 | ❌ | ❌ | ✔️ | ✔️ | Add `PackageReference` to the project file. Update `PackageVersion` in the `Directory.Packages.Props` file with the version specified in the commandline.  | ✔️ |
| 5 | ❌ | ✔️ | ❌ | ❌ | Not a valid scenario because a `VersionOverride` can't exist without `PackageReference`. | ❌ |
| 6 | ❌ | ✔️ | ❌ | ✔️ | Not a valid scenario because a `VersionOverride` can't exist without `PackageReference`. | ❌ |
| 7 | ❌ | ✔️ | ✔️ | ❌ | Not a valid scenario because a `VersionOverride` can't exist without `PackageReference`. | ❌ |
| 8 | ❌ | ✔️ | ✔️ | ✔️ | Not a valid scenario because a `VersionOverride` can't exist without `PackageReference`. | ❌ |
| 9 | ✔️ | ❌ | ❌ | ❌ | Emit an error. (The other considered option was: Remove `Version` from `PackageReference`, Add `PackageVersion` to the `Directory.Packages.Props` file. Use `Version` from `PackageReference` if it exists otherwise use latest version from the package sources. However, this might require more user research.) | ✔️ |
| 10 | ✔️ | ❌ | ❌ | ✔️ | Emit an error. (The other considered option was: Remove `Version` from `PackageReference`, Add `PackageVersion` to the `Directory.Packages.Props` file. Use `Version` passed in the commandline.  However, this might require more user research.) | ✔️ |
| 11 | ✔️ | ❌ | ✔️ | ❌ | No-op. (The other considered option was: Update `PackageVersion` in the `Directory.Packages.Props` file,  use latest version from the package sources. However, we decided it would be best to only update a version when the user explicitly passes in the commandline argument.) | ✔️ |
| 12 | ✔️ | ❌ | ✔️ | ✔️ | Update `PackageVersion` in the `Directory.Packages.Props` file, use version specified in the commandline. | ✔️ |
| 13 | ✔️ | ✔️ |❌  | ❌ | No-op. | ✔️ |
| 14 | ✔️ | ✔️ | ❌ | ✔️ | Update `VersionOverride` in the existing `PackageReference` item, use version specified in the commandline. | ✔️ |
| 15 | ✔️ | ✔️ | ✔️ | ❌ | No-op. | ✔️ |
| 16 | ✔️ | ✔️ | ✔️ | ✔️ | Update `VersionOverride` in the existing `PackageReference` item, use version specified in the commandline. | ✔️ |

### Technical explanation

The `dotnet add [package]` command generates a `{projectName}.nuget.dgspec.json` file that that maintains a project's top-level dependencies along with other metadata for `PackageReference` style projects. 
- The `dgspec.json` file will have `centralPackageVersionsManagementEnabled` property set to `true` for projects onboarded onto CPM.
- `dotnet add package` command currently access [`ProjectRestoreMetadata`](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.ProjectModel/ProjectRestoreMetadata.cs) to perform preview restore.
- [`ProjectRestoreMetadata.CentralPackageVersionsEnabled`](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.ProjectModel/ProjectRestoreMetadata.cs#L119) flag will be accessed while executing `dotnet add package` command to verify if the project has onboarded onto CPM. If yes, the scenarios listed in the functional explanation will be handled accordingly.
- Leverage the existing functionality in [`MSBuildAPIUtility.cs`](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.CommandLine.XPlat/Utility/MSBuildAPIUtility.cs) to modify the `PackageReference` items in project and `PackageVersion` items in the `Directory.Packages.Props` file.

    <details>
    <summary>Sample C# code snippet for working with MSBuild API to update the project and Directory.Packages.Props files</summary>

    Thanks to [Jeff Kluge](https://github.com/jeffkl) for sharing this code snippet with us.

    ```cs
    Project project = new Project(@"D:\Samples\CentralPackageManagementExample\src\ClassLibrary1\ClassLibrary1.csproj");
    string id = "Newtonsoft.Json2";
    string version = "2.0.0";
    // Find the last declared <PackageReference /> item with a matching the package ID
    ProjectItem packageReference = project.Items.LastOrDefault(i => i.ItemType == "PackageReference" && i.EvaluatedInclude.Equals(id));
    // Find the last declared <PackageVersion /> item with a matching the package ID
    ProjectItem packageVersion = project.Items.LastOrDefault(i => i.ItemType == "PackageVersion" &&  i.EvaluatedInclude.Equals(id));
    // Add a <PackageReference /> item if one does not already exist
    if (packageReference != null)
    {
        // Determine which <ItemGroup /> to add to by searching for the first one available:
        //   Find the first <PackageReference /> in the project so we know what ItemGroup to add to
        //   -or-
        //   Use the first first ItemGroup
        //   -or-
        //   Add a new ItemGroup
        ProjectItemGroupElement itemGroupElement = project.Xml.ItemGroups.FirstOrDefault(i => i.Items.Any(i => i.ItemType == "PackageReference"))
            ?? project.Xml.ItemGroups.FirstOrDefault()
            ?? project.Xml.AddItemGroup();
        // TODO: Add the item in sorted order
        // Add the <PackageReference /> item
        itemGroupElement.AddItem("PackageReference", id);
        // Save the main project
        project.Save();
    }
    // Add a <PackageVersion /> to Directory.Build.props if one does not already exist
    if (packageVersion == null)
    {
        // Technically the Directory.Package.props path is stored in an MSBuild property
        string directoryPackagesPropsPath = project.GetPropertyValue("DirectoryPackagesPropsPath");
        // Get the Directory.Build.props
        ProjectRootElement directoryBuildPropsRootElement = project.Imports.FirstOrDefault(i => i.ImportedProject.FullPath.Equals(directoryPackagesPropsPath)).ImportedProject;
        // Get the ItemGroup to add a PackageVersion to
        //   Find the first <ItemGroup /> that contains a <PackageVersion />
        //   -or-
        //   Find the first <ItemGroup />
        //   -or-
        //   Add an <ItemGroup />
        ProjectItemGroupElement packageVersionItemGroupElement = directoryBuildPropsRootElement.ItemGroups.FirstOrDefault(i => i.Items.Any(i => i.ItemType == "PackageVersion"))
            ?? directoryBuildPropsRootElement.ItemGroups.FirstOrDefault()
            ?? directoryBuildPropsRootElement.AddItemGroup();
        // Add a <PackageVersion /> item
        ProjectItemElement packageVersionItemElement = packageVersionItemGroupElement.AddItem("PackageVersion", id);
        // Set the Version attribute
        packageVersionItemElement.AddMetadata("Version", version, expressAsAttribute: true);
        directoryBuildPropsRootElement.Save();
    }
    // Only update <PackageVersion /> if it doesn't currently have the specified value
    else if (!packageVersion.GetMetadataValue("Version").Equals(version))
    {
        // Determine where the <PackageVersion /> item is decalred
        ProjectItemElement packageVersionItemElement = project.GetItemProvenance(packageVersion).LastOrDefault()?.ItemElement;
        if (packageVersionItemElement == null)
        {
            throw new Exception("Failed to find item provenance");
        }
        // Get the Version attribute
        ProjectMetadataElement versionAttribute = packageVersionItemElement.Metadata.FirstOrDefault(i => i.Name.Equals("Version"));
        if (versionAttribute != null)
        {
            // Set the Version
            versionAttribute.Value = version;
        }
        else
        {
            // Add the Version attribute
            packageVersionItemElement.AddMetadata("Version", version, expressAsAttribute: true);
        }
        packageVersionItemElement.ContainingProject.Save();
    }
    ```
</details>

## Unresolved Questions

- Scenarios with multiple `Directory.Packages.props` are out of scope for now. In case there are multiple `Directory.Packages.props` files in the repo, the props file that is closest must be considered.
    ```
    Repository
    |-- Directory.Packages.props
    |-- Solution1
        |-- Directory.Packages.props
        |-- Project1
    |-- Solution2
        |-- Project2
    ```
    In the above example, the following scenarios are possible:
    1. Project1 will evaluate the Directory.Packages.props file in the Repository\Solution1\ directory.
    2. Project2 will evaluate the Directory.Packages.props file in the Repository\ directory.    
    Sourced from <https://devblogs.microsoft.com/nuget/introducing-central-package-management/>

    Another potential solution would be to create a command line argument that takes in the `Directory.Packages.props` file's path that the user intends to update, rather than choosing the closest props file by deafult. 
- The absence of the `Directory.Packages.Props` file for CPM onboarded projects means that the project is not onboarded to CPM. As per [Jeff Kluge's](https://github.com/jeffkl) comment [on a GitHub issue](https://github.com/NuGet/Home/issues/11903#issuecomment-1161996051), `At this time, the customers must use a file named Directory.Packages.props or set an MSBuild property to indicate what file you want to use. Using other files and importing it manually is not a supported scenario.`. Therefore the tool will fall back to the current behavior that is adding/updating the `PackageReference` & `Version` in the project file.
    - If a user wants to onboard to CPM, they will have to create the `Directory.Packages.Props` explicitly through a CLI commandline argument/CLI command or manually. This will ensure that the file is created in the intended location. In any case, the `Directory.Packages.Props` file will not be implicitly created for the user.
- `dotnet add package` by design supports only `PackageReference` style projects. Hence `Packages.Config` style projects remain unsupported. If a user does try to use a `Packages.Config` style project with CPM, an error message should be displayed.
