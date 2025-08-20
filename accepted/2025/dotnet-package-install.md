# Dotnet Package Install Command

* Author: [Nigusu](https://github.com/Nigusu-Allehu)
* GitHub Issues: [#12513](https://github.com/NuGet/Home/issues/12513), [#14491](https://github.com/NuGet/Home/issues/14491)

## Summary

This document proposes adding a `dotnet package install` command to the .NET CLI.
The command would bring parity with `nuget.exe install`, enabling package download and extraction scenarios without requiring a project file.

## Motivation

Developers often need to download NuGet packages outside of a project context:

* Populating internal or offline feeds.
* Security scanning of packages.
* CI/CD workflows that consume `.nupkg` artifacts directly.

Currently, the only way is either using `nuget.exe` or creating dummy projects with `dotnet restore`.

A `dotnet package install` improves developer productivity.

## Explanation

### Functional explanation

The new command lives under `dotnet package`.

`dotnet package` will then be the natural home for **search -> install -> add/remove** since it unifies all package-related workflows under one surface.

Here is what `dotnet package` would look like

```ps1
Description:

Usage:
  dotnet package [command] [options]

Options:
  -?, -h, --help  Show command line help.

Commands:
  search <SearchTerm>    Searches one or more package sources for packages that match a search term. If no sources are specified, all sources defined in the NuGet.Config are used.
  add <PACKAGE_ID>       Add a NuGet package reference to the project.
  install <PACKAGE_ID>   Install a NuGet package (and dependencies) to a folder, without modifying a project.
  list                   List all package references of the project or solution.
  remove <PACKAGE_NAME>  Remove a NuGet package reference from the project.
```

`dotnet package install <packageId> [options]`

**Supported options:**

* `--version <semver>`: A version (eg. 13.0.1).
If omitted, the highest version is chosen from the available sources.
* `--source <package source>`: Specifies one or more package sources to install from.
When not specified the command searches all sources defined in hierarchical selected `NuGet.config` or passed via `--configfile`.
It can also be used to specify a package source key that is found in a config file.
* `--output-directory <path>`: Sets the directory where packages will be downloaded.
The default is the global packages folder.
* `--exclude-version`: Omits version number from the package folder name.
* `--prerelase`: Allows pre-release packages to be considered when resolving versions.
By default only stable versions are selected.
* `--framework <tfm>`: Specifies the target framework.
* `--download-only`: Downloads the `.nupkg` file to the output directory without extracting it.
No dependencies are downloaded either.
* `--no-http-cache`: Prevents the usage of http cached packages.
* `--direct-download`: download directly without populating any caches with metadata.
* `--configfile <path>`: Used to specify a NuGet.Config file to use instead of the default configuration hierarchy.
* `--dependency-version <policy>`: Controls how versions of dependencies are selected when a version range is specified.
Values: Lowest(default), HighestPatch, HighestMinor, and Highest.
* `--no-audit`: opts out of vulnerability auditing. Be default it is on.
* `--allow-insecure-connections`: allows downloading from http sources(insecure).

### Technical explanation

The `NuGet.CommandLine.XPlat` project currently exposes `dotnet package search` and `dotnet package update` in `Program.cs`.
The upcoming `install` sub‑command fits naturally alongside these operations.

### Algorithm: `dotnet package install <packageId> [options]`

1. **Parse inputs**

   * Extract `<packageId>` (required).
   * Read all supported options:

     * `--version <semver>`
     * `--source <package source>`
     * `--output-directory <path>`
     * `--exclude-version`
     * `--prerelease`
     * `--framework <tfm>`
     * `--download-only`
     * `--no-http-cache`
     * `--direct-download`
     * `--configfile <path>`
     * `--dependency-version <policy>`
     * `--no-audit`
     * `--allow-insecure-connections`

1. **Load configuration**

   * If `--configfile` is provided, load settings from that file.
   * Otherwise, use the default `NuGet.Config` hierarchy.

1. **Resolve package sources**

   * If `--source` is specified, resolve those sources (it could be a url or a source key defined in a config file).
   * Else, use all enabled sources from settings.

1. **Http source usage check**

    * If any of the sources are HTTP but do not have`allowInsecureConnections` set to true, log an error and stop the command execution.

1. **Determine output directory**

   * If `--output-directory` is specified, use it.
   * Otherwise, default to the global packages folder.

1. **Configure folder layout**

   * If `--exclude-version` is set, package folders are named `<id>` only.
   * Otherwise, use `<id>.<version>` layout.

1. **Handle target framework**

   * If `--framework` is provided, constrain resolution to that TFM.
   * Otherwise, default to an unconstrained folder project.

1. **Set dependency resolution behavior**

   * Map `--dependency-version` to a policy:

     * `Lowest`, `HighestPatch`, `HighestMinor`, or `Highest`.
   * Configure prerelease handling:

     * If `--prerelease` is set, allow prerelease versions.
     * Else, restrict to stable versions.

1. **Configure caching and download behavior**

   * If `--no-http-cache` is set, disable reading from HTTP cache.
   * If `--direct-download` is set, bypass local/global caches.
   * Always build a `PackageDownloadContext` with these flags.

1. **Determine package identity**

    * If `--version` is given, use that exact version.
    * Otherwise, query sources for the latest version (respecting `--prerelease`).

1. **Audit packages**

   * If `--no-audit` is *not* set, enable vulnerability auditing on the resolved graph.

1. **Check for `--download-only`**

    * If set:

      * Download only the `.nupkg` for the resolved identity into the output directory.
      * Do not extract or install dependencies.
      * Exit.

1. **Report success**

    * Print installed package identity and location.

## Rationale and alternatives

Alternatives:

* Force users to create dummy projects: cumbersome and error-prone.

## Prior Art

* **`nuget.exe install`**: legacy but widely used.
