# Dotnet Package Download Command

* Author: [Nigusu](https://github.com/Nigusu-Allehu)
* GitHub Issues: [#12513](https://github.com/NuGet/Home/issues/12513), [#14491](https://github.com/NuGet/Home/issues/14491)

## Summary

This document proposes adding a `dotnet package download` command to the .NET CLI.
The command would enable package download to a local folder scenarios without requiring a project file.

## Motivation

Developers often need to download NuGet packages outside of a project context:

* Populating internal or offline feeds.
* CI/CD workflows that consume `.nupkg` artifacts directly.
* **Cross-platform builds** where many customers today rely on `nuget.exe install` in CI scripts running on Linux or macOS, forcing them to install Mono just to get this functionality.

Providing `dotnet package download` improves developer productivity, simplifies pipelines, and ensures a cross-platform experience within the .NET CLI.

## Explanation

### Command Overview

```ps1
Description:
  Downloads a NuGet package to a local folder without requiring a project file.

Usage:
  dotnet package download <PackageId> [options]

Arguments:
  PackageId    Package in the form of a package identifier (e.g. 'Newtonsoft.Json') 
               or identifier and version separated by '@' (e.g. 'Newtonsoft.Json@13.0.3').

Options:
  -?, -h, --help                Show command line help.
  --allow-insecure-connections  Allows downloading from HTTP sources.
  --configfile <path>           Path to a NuGet.config to use.
  --download-only               Download only the .nupkg file without extraction.
  --interactive                 Enables interactive authentication if required.
  --no-audit                    Skips vulnerability auditing of downloaded packages.
  --output-directory <path>     Directory where the package will be placed. Defaults to the current working directory.
  --prerelease                  Allows downloading prerelease versions.
  --source <package source>     Specifies the NuGet package source to use.
  --verbosity <level>           Set the verbosity of the command. Allowed values: quiet, normal, detailed.
```

### Default Behavior

By default, `dotnet package download`:

* Downloads **only the explicitly requested package** (no dependencies).
* Places the package in the **current working directory** unless `--output-directory` is specified.
* Stores each package in its **own folder named after the package ID**, with subfolders for each version.

Example:

```ps1
<output-directory>/
  Contoso/
    13.0.3/
    12.0.3/
```

This layout allows multiple versions of the same package to coexist and makes it easy for scripts or tools to locate the correct version.

#### **Deferred (Not in MVP)**

* Download a package with its dependencies too
* `--framework <tfm>` : target framework handling
* `--no-http-cache` : ignore cached packages
* `--dependency-version <policy>` : control dependency resolution strategy
* **Manifest file support** : install multiple packages from a single manifest

## Rationale and alternatives

* **Dummy projects**: Today, developers must create fake projects just to restore packages. This is cumbersome, error-prone, and requires extra cleanup.
* **nuget.exe install**: Still widely used but Windows-centric and requires Mono on non-Windows platforms.

## Prior Art

* **`nuget.exe install`**: legacy but widely used.
