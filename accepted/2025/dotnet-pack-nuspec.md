# Allow dotnet pack to pack .nuspec files without needing csproj

- Author Name: [kfikadu](https://github.com/kfikadu), [martinrrm](https://github.com//martinrrm)
- GitHub Issue: [Issue #4254](https://github.com/NuGet/Home/issues/4254)

## Summary

`dotnet pack` currently does not support packing a .nuspec file without a corresponding .csproj file.
As a result, developers are forced to either use `nuget.exe` (which is Windows-only) or create a dummy .csproj file solely for packaging purposes.
This creates friction for cross-platform workflows, disrupts legacy systems that rely on .nuspec-only packaging, and undermines modular packaging strategies.
This proposal aims to add support for .nuspec-only packaging in dotnet pack, eliminating the need for a .csproj file and improving developer experience across platforms.

## Motivation

Customers have been requesting the functionality of packing using a .nuspec file when using the command `dotnet pack` in files or non-sdk-style projects.

## Explanation

### Functional explanation

Currently, arguments for `dotnet pack` are [\<PROJECT\>|\<SOLUTION\>].
This feature will enable customers to also use a .nuspec to pack files.
`dotnet pack` is available for projects that are using the SDK-style format.
Adding the ability to use a .nuspec path instead will enable customers to pack projects or files that aren't SDK-style.
In these cases, `dotnet pack` with a nuspec will not run `NuGet.Build.Tasks.Pack.targets` and instead use the current implementation of `nuget.exe` [pack commands](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Clients/NuGet.CommandLine/Commands/PackCommand.cs).
This runs `PackCommandRunner` which manages the packaging process in the `dotnet pack` command. It collects inputs, processes them, and generates NuGet packages. 
This component supports packing from .nuspec files, enhancing cross-platform workflows and eliminating the need for a .csproj file. 

### Technical explanation

#### Option 1: .nuspec file path as an argument dotnet pack [\<PROJECT\>|\<SOLUTION\>|\<NUSPEC\>]

Currently, dotnet pack options and nuget.exe pack options are very different, meaning that we will need to add new options that would not apply when packing an SDK project.
There are a couple that are shared but the main difference is that when using nuget.exe you can use the option -Properties to do token replacement in the .nuspec (ex. \$variable\$).
All new options and existing ones will need to have a check to see if they are applicable to the user scenario.
This implementation doesn't require us to create a new comand or subcommand, making the command look cleaner and customer won't need to learn a new command.
This would be the ideal implementation.

#### Option 2: New subcommand dotnet pack nuspec [\<NUSPEC\>]

This new subcommand will help us add all current nuget.exe pack options more easily and don't worry about existing pack options.

#### Example Comparison

|Scenario|Option 1: .nuspec as Argument to `dotnet pack`|Option 2: New Subcommand `dotnet pack nuspec`|
|--------|----------------------------------------------|---------------------------------------------|
| Basic Usage | `dotnet pack MyPackage.nuspec --output ./artifacts` | `dotnet pack nuspec MyPackage.nuspec --output ./artifacts` |
| Example with Property Replacement | `dotnet pack MyPackage.nuspec --property Version=1.2.3 --property Configuration=Release --output ./artifacts` | `dotnet pack nuspec MyPackage.nuspec --property Version=1.2.3 --property Configuration=Release --output ./artifacts` |
| Relative Path| `dotnet pack ../MyPackage.nuspec --output ./artifacts` | `dotnet pack nuspec ../MyPackage.nuspec --output ./artifacts` |

### Options Relevant to `.nuspec`-only Support in `dotnet pack`

| Option / Flag                  | Description                                                      | Notes / Status for .nuspec-only                                 | Comparison (`nuget pack -h` / `dotnet pack -h`)                |
|------------------------------- |------------------------------------------------------------------|-----------------------------------------------------------------|---------------------------------------------------------------|
| `--property` / `-p:`           | Set or override a property for token replacement in `.nuspec`.   | Reused; interpret for token replacement, not just MSBuild.       | `-Properties` in `nuget pack`, `--property` in `dotnet pack`   |
| `--output`                     | Specifies the output directory for the generated package.         | Reused; already available.                                       | `-OutputDirectory` in `nuget pack`, `--output` in `dotnet pack`|
| `--basepath`                   | Specifies the base path for resolving relative file paths.        | New; needed for file path resolution in `.nuspec`.               | `-BasePath` in `nuget pack`, not present in `dotnet pack`      |
| `--version-suffix` / `--version` | Sets the version or version suffix for the package.             | Reused/Clarify; clarify how it applies to `.nuspec` versioning.  | `-Version` in `nuget pack`, `--version-suffix` in `dotnet pack`|
| `--exclude`                    | Exclude specific files or patterns from the package.              | New; needed for file exclusion support.                          | `-Exclude` in `nuget pack`, not present in `dotnet pack`       |
| `--nologo`                     | Suppresses display of the startup banner and copyright.           | Reused; already available.                                       | `-NoLogo` in `nuget pack`, `--nologo` in `dotnet pack`         |
| `--min-client-version`         | Sets the minimum NuGet client version required to install the package. | Consider; may need to add.                                 | `-MinClientVersion` in `nuget pack`, not in `dotnet pack`      |
| `--no-package-analysis`        | Skips package analysis after building the package.                | Consider; may need to add.                                       | `-NoPackageAnalysis` in `nuget pack`, not in `dotnet pack`     |
| `--no-default-excludes`        | Disables default file exclusion patterns.                         | Consider; may need to add.                                       | `-NoDefaultExcludes` in `nuget pack`, not in `dotnet pack`     |
| `--serviceable`                | Marks the package as serviceable.                                 | Consider; may need to add or clarify.                            | `-Serviceable` in `nuget pack`, `--serviceable` in `dotnet pack`|
| `--interactive`                | Enables interactive prompts during packing.                      | Consider; may need to add.                                       | `-Interactive` in `nuget pack`, not in `dotnet pack`           |

> **Note:**  
> This table focuses on options that are new, reused with modified behavior, or require special handling for `.nuspec`-only support.
> Project-specific and unrelated options (like `--configuration`, `--no-build`, etc.) are omitted for clarity and relevance.

## Prior Art

Previously, in 4.0.0-rc2, you were able to pack a .nuspec file without a csproj file by using `dotnet nuget pack (nuspec)` file.
This was removed in 4.0.0-rc3. Here is the [PR](https://github.com/NuGet/NuGet.Client/pull/1065) that removed this functionality.
 
