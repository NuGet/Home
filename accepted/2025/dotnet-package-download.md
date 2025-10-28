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
  --interactive                 Enables interactive authentication if required.
  -o, --output <path>           Directory where the package will be placed. Defaults to the current working directory.
  --prerelease                  Allows downloading prerelease versions.
  -s --source <package source>     Specifies the NuGet package source to use.
  -v --verbosity <level>           Set the verbosity level of the command Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
```

## Default Behavior

By default `dotnet package download` just like `nuget.exe install`:

* Download to the **current working directory** unless an output option (`--output`) is specified.
* Select the **latest version** of a package if no version is provided.

However, they differ in a few key areas:

| **Aspect**                | **`dotnet package download`**                                                               | **`nuget.exe install`**                                                  | Why different                                                                                                                                    |
| ------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Dependency resolution** | Downloads **only the explicitly requested package** (no transitive dependencies).           | Downloads the requested package **and all its dependencies** by default. | Current discussions in [NuGet/Home#12513](https://github.com/NuGet/Home/issues/12513) indicate no clear need for transitive dependency downloads. |
| **Folder layout**         | Creates a folder per **package ID**, with **version subfolders** (e.g., `Contoso/13.0.3/`). | Creates a folder per **package-version pair** (e.g., `Contoso.13.0.3/`). | The new layout allows multiple versions to coexist cleanly and aligns with the global packages folder structure.                                  |

#### Example Layout

```ps1
<output-directory>/
  Contoso/
    13.0.3/
    12.0.3/
```

This layout allows multiple versions of the same package to coexist while remaining easy to locate: consistent with the **global packages folder** design used by modern .NET tools.

The design of dotnet package download was guided by feedback captured in [NuGet/Home#12513](https://github.com/NuGet/Home/issues/12513).
Rather than replicating the full feature set of nuget.exe install, the new command intentionally focuses on simply addressing the specific needs of automation, CI/CD, and scripting scenarios.

### Version Resolution

Package versions are specified as part of the `PackageId` argument using the syntax `Package@Version`.
You can specify one or more packages in a single command. For example, to download multiple packages:

```bash
dotnet package download contoso@1.0.0 contoso@2.5.1
```

* **Package** — the name of the package.
* **Version** — the exact version number to download.

Version ranges and floating versions are **not supported**.
If no version is specified, the command downloads the **latest available version** from the configured sources.
When the `--prerelease` option is enabled, pre-release versions are also included when determining the latest version.

### Audit

Audit functionality is **not supported** for the `dotnet package download` command by design.

* **No dependency graph** – The command downloads only explicitly requested packages and does not resolve transitive dependencies. Auditing is most meaningful when hidden or transitive dependencies are involved, which this command does not process
* **Reliability in restricted environments** – For users that run this command in controlled or offline settings (for example, behind firewalls or without access to NuGet.org) avoiding network calls for vulnerability data ensures the command runs predictably without unexpected warnings or errors.
* **Typical usage scenarios** – In CI/CD pipelines and automation systems, packages are often sourced from internal or validated feeds rather than NuGet.org, making external vulnerability checks less relevant.

### Source Selection and Package Source Mapping

The `dotnet package download` command supports both **explicit source selection** (`--source`) and **package source mapping** configured in `nuget.config`.

**Source precedence:**

1. **`--source` specified**

   * When `--source <packageSource>` is provided, it **replaces** all sources defined in configuration files.
   * The value is first resolved as a **named source** from `nuget.config`; if no match is found, it is treated as a **direct URI**.
   * In this mode, **package source mapping is ignored**, and the command only uses the explicitly provided sources.

2. **No `--source` specified**

   * When no `--source` is provided, the command reads all configured sources from the active `nuget.config`.
   * If **package source mapping** is enabled, the command uses the mapping rules to determine which source(s) to query for each package ID.
   * This ensures the correct source is chosen automatically based on patterns defined in the configuration file.

#### Exit Codes

The command follows standard exit code conventions:

* **0** – The package was successfully downloaded, or the requested version was already present.
* **1** – The download failed, network errors, requested package version not found, parsing of the command arguments failed, all other errors during the command operation.

#### Supported options in nuget.exe install but not this command

The following options are currently supported in `nuget.exe install` but are not supported in the `dotnet package download` command.
This decision is intentional — the initial implementation focuses on solving the key user scenarios outlined in [#12513](https://github.com/NuGet/Home/issues/12513).

Future iterations may introduce these options based on customer feedback and demand.
Users are encouraged to share feedback if their workflows depend on any of these arguments.

* `-DependencyVersion`: Not applicable. This command never resolves transitive dependencies.
* `-DirectDownload`
* `-DisableParallelProcessing`
* `-x | -ExcludeVersion`: Not applicable. Packages are stored in id/version/ structure; version-less folders do not apply.
* `-FallbackSource`
* `-ForceEnglishOutput`
* `-Framework`
* `-NoHttpCache`
* `-PackageSaveMode`
* `-RequireConsent`
* `-SolutionDirectory`

For more information on these options, see the [`nuget.exe install` documentation](https://learn.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-install).

## Rationale and alternatives

* **Dummy projects**: Today, developers must create fake projects just to restore packages. This is cumbersome, error-prone, and requires extra cleanup.
* **nuget.exe install**: Still widely used but Windows-centric and requires Mono on non-Windows platforms.

## Prior Art

* **`nuget.exe install`**: legacy but widely used.
* The `Package@Version` is a design that is supported in dotnet commands like `package add`, `package update`.