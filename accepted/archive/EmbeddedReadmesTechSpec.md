# Embedded Readmes Technical Spec

* Status: Implementing
* Author(s): [Advay Tandon](https://github.com/advay26)
* Issue: [6873](https://github.com/NuGet/Home/issues/6873) README.md (markdown description) support for NuGet packages

## Problem Background

Users of NuGet want to be able to include Readme files as part of the package when they `pack` and `push` their project through the commandline. The [design document](https://github.com/NuGet/Home/wiki/Embedding-and-displaying-NuGet-READMEs) outlines the work needed for this feature and the intended results.

## Who are the customers

NuGet customers that use the commandline to publish their packages, and want to be able to include Readme files through the `pack` process, rather than having to do it manually after the package has been published.

## Goals

* Implement the Client side functionality for Embedded Readmes:
    * `nuget pack` support
    * `dotnet pack` support
    * `msbuild /t:pack` support
    * Validation of readme files

## Non-Goals

* Server side functionality
* Parsing the readme as a valid markdown file on the Client side
* Enabling readme selection through the VS Project Properties UI (Project System)

## Solution

**NOTE:** To see the code described in this section, you can look at the edited files [here](https://github.com/NuGet/NuGet.Client/pull/3575/files).

First, we need to add a `readme` string element to the [*nuspec* schema](https://github.com/NuGet/NuGet.Client/blob/64ed0cb4054226f6060752757d29c50287b312b3/src/NuGet.Core/NuGet.Packaging/compiler/resources/nuspec.xsd) to ensure that the readme property is recognized and parsed from the *nuspec* file. We also need to ensure that the `PackageReadmeFile` property is parsed from a *csproj* file by editing [NuGet.Build.Tasks.Pack.targets](https://github.com/NuGet/NuGet.Client/blob/64ed0cb4054226f6060752757d29c50287b312b3/src/NuGet.Core/NuGet.Build.Tasks.Pack/NuGet.Build.Tasks.Pack.targets#L198) to include this line:

```
Readme="$(PackageReadmeFile)"
```

Further, a `GetReadme` method must be added to the [NuspecReader.cs](https://github.com/NuGet/NuGet.Client/blob/fa61e76d296b4b37ef4226277e77f7f227e878d9/src/NuGet.Core/NuGet.Packaging/NuspecReader.cs#L20) file to facilitate the reading of the Readme element from a nuspec file.

Next, we need to add `Readme` member variables to multiple relevant classes and interfaces, and ensure that the Readme property is transmitted from one class to another when `pack` is called. These are:
* [IPackTaskRequest](https://github.com/NuGet/NuGet.Client/blob/fa61e76d296b4b37ef4226277e77f7f227e878d9/src/NuGet.Core/NuGet.Build.Tasks.Pack/IPackTaskRequest.cs#L16)
* [PackTask](https://github.com/NuGet/NuGet.Client/blob/fa61e76d296b4b37ef4226277e77f7f227e878d9/src/NuGet.Core/NuGet.Build.Tasks.Pack/PackTask.cs#L14)
* [PackTaskRequest](https://github.com/NuGet/NuGet.Client/blob/fa61e76d296b4b37ef4226277e77f7f227e878d9/src/NuGet.Core/NuGet.Build.Tasks.Pack/PackTaskRequest.cs#L10)
* [IPackageMetadata](https://github.com/NuGet/NuGet.Client/blob/fa61e76d296b4b37ef4226277e77f7f227e878d9/src/NuGet.Core/NuGet.Packaging/PackageCreation/Authoring/IPackageMetadata.cs#L11)
* [ManifestMetadata](https://github.com/NuGet/NuGet.Client/blob/fa61e76d296b4b37ef4226277e77f7f227e878d9/src/NuGet.Core/NuGet.Packaging/PackageCreation/Authoring/ManifestMetadata.cs#L18)
* [PackageBuilder](https://github.com/NuGet/NuGet.Client/blob/fa61e76d296b4b37ef4226277e77f7f227e878d9/src/NuGet.Core/NuGet.Packaging/PackageCreation/Authoring/PackageBuilder.cs#L25)

In order to transmit the `Readme` value from the source file (*nuspec* or *csproj*) to the final output *nuspec* file, the appropriate assignment statements are needed at the relevant locations.

After this, a `ManifestMetadata` object is used to create the output *nuspec* file that is included in the nupkg. For this step, we need to edit the [ToXElement](https://github.com/NuGet/NuGet.Client/blob/fa61e76d296b4b37ef4226277e77f7f227e878d9/src/NuGet.Core/NuGet.Packaging/PackageCreation/Xml/PackageMetadataXmlExtensions.cs#L32) method in PackageMetadataXmlExtensions.cs to include this line:

```
AddElementIfNotNull(elem, ns, "readme", metadata.Readme);
```

**Validation and Errors**

To validate the Readme property and the corresponding file when `pack` is called, the ValidateReadmeFile method in [PackageBuilder.cs](https://github.com/NuGet/NuGet.Client/blob/0f8ad8263539cb9bc69c441569453c1da98fb4cc/src/NuGet.Core/NuGet.Packaging/PackageCreation/Authoring/PackageBuilder.cs) checks that:
* The file extension matches a Markdown file
* The file specified in the Readme property exists in the package's files
* The file is not empty

Each of these errors has a corresponding log code and error message defined in [NuGetLogCode.cs](https://github.com/NuGet/NuGet.Client/blob/0f8ad8263539cb9bc69c441569453c1da98fb4cc/src/NuGet.Core/NuGet.Common/Errors/NuGetLogCode.cs) and [NuGetResources.resx](https://github.com/NuGet/NuGet.Client/blob/0f8ad8263539cb9bc69c441569453c1da98fb4cc/src/NuGet.Core/NuGet.Packaging/PackageCreation/Resources/NuGetResources.resx) respectively, and the appropriate support must be added in [NuGetResources.Designer.cs](https://github.com/NuGet/NuGet.Client/blob/0f8ad8263539cb9bc69c441569453c1da98fb4cc/src/NuGet.Core/NuGet.Packaging/PackageCreation/Resources/NuGetResources.Designer.cs).

**NOTE:** The Server team will parse and validate the markdown contents of the Readme file when it is uploaded.

## Future Work

* Adding readme support through the VS Project Properties UI (Project System) - [dotnet/project-system#6457](https://github.com/dotnet/project-system/issues/6457)
* Adding a `View README` link in the PM UI that points to the package's readme file - [NuGet/Home#9890](https://github.com/nuget/home/issues/9890)

## Open Questions

* Are there any other validation checks to do when packing a Readme?

## Considerations

### 1. Should we warn users if the Readme property is empty?

Based on feedback from both the NuGet team and customers, we should not do this. The goal of encouraging user adoption of Embedded Readmes can be pursued as part of a separate Package Quality endeavor.

### 2. Automatically packing a Readme file from the base directory

Similar to the above point, this functionality is not something that we will look to add right now. Relying on explicit user input for the metadata is more desirable, and avoids springing any surprises on customers.

### 3. Enforcing a size limit on Readme files on `pack`

Originally, we intended to enforce a 1 MB size limit on Embedded Readme files both while running `pack` on the Client-side and while using `push` to upload to NuGet.org. However, since we do not want to impose such size restrictions on users looking to upload packages to private or local feeds, we decided against throwing an error for this on `pack`. Now, the user can run `pack` to create packages with Readme files over 1 MB, but will receive an error if they try to upload such a package to NuGet.org, which enforces a strict 1 MB limit.

### References

[Embedding and displaying NuGet READMEs](https://github.com/NuGet/Home/wiki/Embedding-and-displaying-NuGet-READMEs)
