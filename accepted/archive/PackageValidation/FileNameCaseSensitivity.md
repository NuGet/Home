
# Error on improper file name case

* Status: [Implemented](https://github.com/NuGet/NuGet.Client/pull/3754)
* Author(s): [David Maas](https://github.com/PathogenDavid)
* Issue: [9817](https://github.com/NuGet/Home/issues/9817) NU5030 license file existence check should always use a case-sensitive comparison

## Problem Background

Presently when you pack a NuGet package on Windows, it is possible to specify diferent casing for the filename for `PackageLicenseFile`/`PackageIcon`. For instance, you can pack a file named `License.txt` and specify `<PackageLicenseFile>LICENSE.txt</PackageLicenseFile>` in the NuSpec and the package will pack without errors.

However, this package is malformed because NuGet packages are zip files and zip files use case-sensitive paths internally. As a consequence, the package cannot be uploaded to NuGet.org:

![Screenshot of NuGet.org upload page with error: "The license file 'LICENSE.txt' does not exist in the package."](https://user-images.githubusercontent.com/278957/87859778-464db400-c8fd-11ea-9d19-230c87285e92.png)

If you attempt to put the package in a local feed (or another feed which does not perform this check), you'll get an error:

![Screenshot of Visual Studio error message: "Unknown problem loading the file 'LICENSE.txt'."](https://user-images.githubusercontent.com/278957/87859796-7ac17000-c8fd-11ea-8953-64fc9606c831.png)

## Who are the customers

This primarily affects package authors who may be unknowingly packing malformed packages.

## Goals

* Prevent package authors from making this mistake.
* Avoid breaking packages which exhibit this problem.
  * Not all package feeds can or will verify the license or icon file exists. (IE: Local package feeds, Nexus Repository)
* Fix the behavioral inconsistency between packing on Windows/macOS vs Linux.

## Non-Goals

Changing the behavior of packing on Linux is a non-goal.

## Solution

Expand the scope of existing errors to cover attempting to pack a package with improper casing on the `PackageLicenseFile`/`PackageIcon`:

```
NU5030: The license file 'LICENSE.txt' does not exist in the package. (Did you mean 'License.txt'?)
NU5046: The icon file 'Icon.png' does not exist in the package. (Did you mean 'icon.png'?)
```

As shown above, in the situation NuGet will give a hint to the user with the correct casing.

## Future Work

A warning is specified to avoid breaking packages which previously packed successfully even though they were malformed. In a future .NET SDK release, this warning could become an error by default similar to [NU1605](https://github.com/dotnet/sdk/blob/bc5c514a45a1a900b71d39a3541196bc2cf1bb0d/src/Tasks/Microsoft.NET.Build.Tasks/targets/Microsoft.NET.Sdk.CSharp.props#L19).

## Open Questions

None.

## Considerations

It was considered to make the issue a warning, but this would expose the user to a pit of failure.

It was considered to make new error codes for this case, but was deemed unecessary.

It was considered that packing could silently update `PackageLicenseFile` to the correct value, but this behavior seems like it has the potential to be confusing.

If this were to be a warning, it was considered changing the behavior on Linux to use a case-insensitive string comparison as well in order to make these malformed packages packable there, but that was deemed unecessary. (And it turns what is an error today into a warning.)

It was considered that when the file was found but in a different directory that the hint could appear in that situation too, but this situation was deemed to be out of scope.

### References

The source of the issue:

* [PackageBuilder.cs:588](https://github.com/NuGet/NuGet.Client/blob/1f1213960012d6452b63a267607d1e237318025e/src/NuGet.Core/NuGet.Packaging/PackageCreation/Authoring/PackageBuilder.cs#L588) ([Introduced in 2018](https://github.com/NuGet/NuGet.Client/pull/2450/files#diff-7d862ed9e52e34d5ee39d6ccbf6f8a7cR494))
* [PackageBuilder.cs:613](https://github.com/NuGet/NuGet.Client/blob/0b178b9d10f7876fc7daa18487844f28d6bfea6b/src/NuGet.Core/NuGet.Packaging/PackageCreation/Authoring/PackageBuilder.cs#L613) ([Introduced in 2019](https://github.com/NuGet/NuGet.Client/commit/c05f9afa9c2fcee7fbe10754521b3f6424bee128))

Zip files are always case-sensitive, so the use of `GetStringComparisonBasedOnOS` in both instances is incorrect.

------------

A modified NuGet samples exhibiting the issue:

* [PackageLicenseFileExample](https://github.com/PathogenPlayground/Samples/blob/31f2ea7047a2c90058a73407eee618a068d03107/PackageLicenseFileExample/PackageLicenseFileExample.csproj)
* [PackageIconExample](https://github.com/PathogenPlayground/Samples/blob/31f2ea7047a2c90058a73407eee618a068d03107/PackageIconExample/PackageIconExample.csproj)
