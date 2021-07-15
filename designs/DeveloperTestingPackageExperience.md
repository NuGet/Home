# Developer Testing Package Experience

* Status: In Review
* Author(s): [Samuel Cragg](https://github.com/samcragg)
* Issue: [6579](https://github.com/NuGet/Home/issues/6579) Enhance the
  experience for the testing of packages in development

## Problem Background

As a NuGet package author, it would be nice to be able to test the package
locally before publishing to a NuGet feed.

As packages can include custom MsBuild targets, it's important to verify that
the generated package works as expected when restored into a project. Being able
to verify that locally (including on a CI server) will enable developers to spot
changes in behaviour sooner, enhancing the inner-loop performance for .NET
developers.

## Who are the customers

NuGet package authors (i.e. developers who create NuGet packages).

## Goals

The goal of this design is to enable a generated `nupkg` file to be used by a
project using the existing `PackageReference` functionality. The version of the
package may be an existing published version or that of a previously restored
local package (i.e. there is no requirement that the version is unique, as there
is with the current package publishing requirements), however, it is assumed
that the package ID will be unique to avoid conflict with other dependencies.

## Non-Goals

Custom feeds will not be supported by the solution - the solution is only
interested in folders containing `nupkg` files. The rationale for this is to
keep the design simple and to emphasise that it is not a replacement for other
package sources. Also, since the target audience is creating the packages, the
file would have been produced in order to publish it, so this limitation is not
perceived as an impediment.

## Solution Overview

In order to provide a solution, there are a few issues that need to be
highlighted with the current machinery with regards to installing of a package
in the context of trying to test a newly created package:

* NuGet caches packages by ID and version
* The order of multiple sources are searched through is non-deterministic
* If a version number is omitted, NuGet searches for the lowest applicable
  version

### `csproj` Additions

The proposed solution is to add an additional MsBuild property for the
[restore target](https://docs.microsoft.com/en-us/nuget/reference/msbuild-targets#restore-target)
as follows:

| Property              | Description  |
|-----------------------|--------------|
| RestoreOverrideFolder | Specifies a folder that contains `nupkg` files that take precedence over any other source and are not cached. |

This property can only be specified once and can only specify a single folder
(i.e. there cannot be multiple override folders to avoid ordering issues). Note
that file shares _should_ be supported, however.

Also, only a single version of a package (based on its ID) may exist in the
override folder (i.e. it would be an error to have
`generated.package.1.0.0.nupkg` and `generated.package.2.0.0.nupkg` in the
folder).

### Resolving Changes

When an override folder is specified, any packages found inside the folder
should be removed from the current cache (matching by ID and version) before any
further work is done (i.e. this would delete the folder from the global cache
or from the `PACKAGES_DIRECTORY` if specified in the
[restore options](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-restore#options)).

When a package that exists inside the overrides folder is referenced by the
project:

* If no version is specified, the version in the folder is used without
  searching any other sources.
* If a version is specified and that matches that in the override folder (taking
  into account the usual wildcard support), that package is used without
  searching any other sources.
* Otherwise, normal resolution happens.

When the override package is used, it is restored to the cache as normal (taking
into account if `--no-cache` has been specified, a different cache folder used
etc). This prevents changes to the rest of the restore process and doesn't
affect being able to publish a different package of the same version to the
override folder, as the version will be automatically cleaned during each
restore (i.e. although it's installed in the cache, it will be removed from it
again the next time the restore process starts).

## Test Strategy

Testing of the above can be automated by having two version of a package and
verifying which one is used; one can be installed in a local folder and included
in the test project via the `RestoreSources`, with the other version of the
package installed in the override folder.

## Open Questions

Would it be worthwhile to have a sample NuGet package that shows best practices
with regards to integration tests for package authors that want to verify their
created packages?

## Considerations

### References

* [#3676](https://github.com/NuGet/Home/issues/3676) No Way to Control Order of
  Sources with nuget sources
* [#9273](https://github.com/NuGet/Home/issues/9273) Need nuget package priority
  for local debugging/testing
* [#9366](https://github.com/NuGet/Home/issues/9366) Improve inner-loop testing
  for packages
* [#9375](https://github.com/NuGet/Home/issues/9375) Allow for a "Debug" or
  "Developer" mode of package
* [#9891](https://github.com/NuGet/Home/issues/9891) Feature request - Option to
  update user global packages folder automatically after successful pack
* [#10367](https://github.com/NuGet/Home/issues/10367) Online sources are always
  checked even when local exists
