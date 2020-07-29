# Embedded Readmes Technical Spec

* Status: Implementing
* Author(s): [Advay Tandon](https://github.com/advay26)
* Issue: [6873](https://github.com/NuGet/Home/issues/6873) README.md (markdown description) support for NuGet packages

## Problem Background

Users of NuGet want to be able to include Readme files as part of the package when they `pack` and `push` their project through the commandline. The [design document](https://github.com/NuGet/Home/wiki/Packaging-READMEs-within-the-nupkg) outlines the work needed for this feature and the intended results.

## Who are the customers

NuGet customers that use the commandline to publish their packages, and want to be able to include Readme files through the `pack` process, rather than having to do it manually after the package has been published.

## Goals

* Implement the Client side functionality for Embedded Readmes:
    * nuget pack support
    * dotnet pack support
    * Validation of readme files

## Non-Goals

* Server side functionality
* Parsing the readme as a valid markdown file

## Solution

**NOTE:** To see the code described in this section, you can look at the edited files [here](https://github.com/NuGet/NuGet.Client/compare/dev-advay26-readme).

First, we need to add a `readme` string element to the [*nuspec* schema](https://github.com/NuGet/NuGet.Client/blob/64ed0cb4054226f6060752757d29c50287b312b3/src/NuGet.Core/NuGet.Packaging/compiler/resources/nuspec.xsd) to ensure that the readme property is recognized and parsed from the *nuspec* file. We also need to ensure that the `PackageReadmeFile` property is parsed from a *csproj* file by editing [NuGet.Build.Tasks.Pack.targets](https://github.com/NuGet/NuGet.Client/blob/64ed0cb4054226f6060752757d29c50287b312b3/src/NuGet.Core/NuGet.Build.Tasks.Pack/NuGet.Build.Tasks.Pack.targets#L198) to include this line:

```
Readme="$(PackageReadmeFile)"
```

Next, we need to add `Readme` member variables to multiple relevant classes and interfaces, and ensure that the Readme property is transmitted from one class to another when `pack` is called. These are:
* [IPackTaskRequest](https://github.com/NuGet/NuGet.Client/blob/64ed0cb4054226f6060752757d29c50287b312b3/src/NuGet.Core/NuGet.Build.Tasks.Pack/IPackTaskRequest.cs#L16)
* [PackTask](https://github.com/NuGet/NuGet.Client/blob/64ed0cb4054226f6060752757d29c50287b312b3/src/NuGet.Core/NuGet.Build.Tasks.Pack/PackTask.cs#L14)
* [PackTaskRequest](https://github.com/NuGet/NuGet.Client/blob/64ed0cb4054226f6060752757d29c50287b312b3/src/NuGet.Core/NuGet.Build.Tasks.Pack/PackTaskRequest.cs#L10)
* [IPackageMetadata](https://github.com/NuGet/NuGet.Client/blob/64ed0cb4054226f6060752757d29c50287b312b3/src/NuGet.Core/NuGet.Packaging/PackageCreation/Authoring/IPackageMetadata.cs#L11)
* [ManifestMetadata](https://github.com/NuGet/NuGet.Client/blob/64ed0cb4054226f6060752757d29c50287b312b3/src/NuGet.Core/NuGet.Packaging/PackageCreation/Authoring/ManifestMetadata.cs#L18)
* [PackageBuilder](https://github.com/NuGet/NuGet.Client/blob/64ed0cb4054226f6060752757d29c50287b312b3/src/NuGet.Core/NuGet.Packaging/PackageCreation/Authoring/PackageBuilder.cs#L25)

In order to transmit the `Readme` value from the source file (*nuspec* or *csproj*) to the final output *nuspec* file, the appropriate assignment statements are needed at the relevant locations.

After this, a `ManifestMetadata` object is used to create the output *nuspec* file that is included in the nupkg. For this step, we need to edit the [ToXElement](https://github.com/NuGet/NuGet.Client/blob/64ed0cb4054226f6060752757d29c50287b312b3/src/NuGet.Core/NuGet.Packaging/PackageCreation/Xml/PackageMetadataXmlExtensions.cs#L32) method in PackageMetadataXmlExtensions.cs to include this line:

```
AddElementIfNotNull(elem, ns, "readme", metadata.Readme);
```

**If no Readme property is present in the source file, but a readme.md file exists in the base directory**

Once the properties and files have been processed, if the PackageBuilder object's Readme property is null, we need to look through the base directory for a "readme.md" file. If such a file exists, we must include it in the package and and populate the Readme property with "readme.md".

```
public void CheckForReadme(string basePath)
{
    string readmeName = "readme.md";
    List<PhysicalPackageFile> searchFiles = ResolveSearchPattern(basePath, readmeName, string.Empty, false).ToList();

    if (searchFiles.Any())
    {
        Readme = readmeName;

        if (!Files.Contains(searchFiles[0]))
        {
            Files.Add(searchFiles[0]);
        }
    }
}
```

This CheckForReadme method in [PackageBuilder.cs](https://github.com/NuGet/NuGet.Client/blob/0f8ad8263539cb9bc69c441569453c1da98fb4cc/src/NuGet.Core/NuGet.Packaging/PackageCreation/Authoring/PackageBuilder.cs) is called [here](https://github.com/NuGet/NuGet.Client/blob/0f8ad8263539cb9bc69c441569453c1da98fb4cc/src/NuGet.Core/NuGet.Packaging/PackageCreation/Authoring/PackageBuilder.cs#L725) and [here](https://github.com/NuGet/NuGet.Client/blob/0f8ad8263539cb9bc69c441569453c1da98fb4cc/src/NuGet.Core/NuGet.Commands/CommandRunners/PackCommandRunner.cs#L726), based on whether the package is being built using a *nuspec* or *csproj* file.

**Validation and Errors**

To validate the Readme property and the corresponding file when `pack` is called, the ValidateReadmeFile method in [PackageBuilder.cs](https://github.com/NuGet/NuGet.Client/blob/0f8ad8263539cb9bc69c441569453c1da98fb4cc/src/NuGet.Core/NuGet.Packaging/PackageCreation/Authoring/PackageBuilder.cs) checks that:
* The file extension matches a Markdown file
* The file specified in the Readme property exists in the package's files
* The file can be opened
* The file size does not exceed 1 MB
* The file is not empty

Each of these errors has a corresponding log code (NU5038 - NU5042) and error message defined in [NuGetLogCode.cs](https://github.com/NuGet/NuGet.Client/blob/0f8ad8263539cb9bc69c441569453c1da98fb4cc/src/NuGet.Core/NuGet.Common/Errors/NuGetLogCode.cs) and [NuGetResources.resx](https://github.com/NuGet/NuGet.Client/blob/0f8ad8263539cb9bc69c441569453c1da98fb4cc/src/NuGet.Core/NuGet.Packaging/PackageCreation/Resources/NuGetResources.resx) respectively, and the appropriate support must be added in [NuGetResources.Designer.cs](https://github.com/NuGet/NuGet.Client/blob/0f8ad8263539cb9bc69c441569453c1da98fb4cc/src/NuGet.Core/NuGet.Packaging/PackageCreation/Resources/NuGetResources.Designer.cs).

## Future Work

* Adding readme support through the VS Project Properties UI
* Adding a `View Documentation` link to the package readme in the PM UI

## Open Questions

* Should we warn users if the Readme property is empty?
* Are there any other validation checks to do when packing a Readme?

## Considerations


### References

[Packaging READMEs within the nupkg](https://github.com/NuGet/Home/wiki/Packaging-READMEs-within-the-nupkg)
