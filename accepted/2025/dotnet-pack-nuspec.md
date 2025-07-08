# Allow dotnet pack to pack .nuspec files without needing csproj

- Author Name: [kfikadu](https://github.com/kfikadu), [martinrrm](https://github.com//martinrrm)
- GitHub Issue: [Issue #4254](https://github.com/NuGet/Home/issues/4254)

## Summary

`dotnet pack` currently does not support packing a .nuspec file without a corresponding .csproj file.
As a result, developers are forced to either use `nuget.exe` (which is Windows-only) or create a dummy .csproj file solely for packaging purposes.
This creates friction for cross-platform workflows, disrupts legacy systems that rely on .nuspec-only packaging, and undermines modular packaging strategies.
This proposal aims to add support for .nuspec-only packaging in dotnet pack, eliminating the need for a .csproj file and improving developer experience across platforms.
The two main options for implementation are: (1) allowing `.nuspec` as a direct argument to `dotnet pack`, and (2) introducing a new subcommand such as `dotnet pack nuspec`.

## Motivation

Customers have been requesting the functionality of packing using a .nuspec file when using the command `dotnet pack` in files or non-SDK-style projects.

## Proposed Approach: [\<PROJECT\>|\<SOLUTION\>|\<NUSPEC\>]

The recommended approach is to allow `dotnet pack` to accept a .nuspec file as an argument, enabling the command to pack files without requiring a .csproj file.
This would allow users to run `dotnet pack <nuspec>` directly, without needing to create a dummy .csproj file.

## Explanation

### Functional explanation

Currently, arguments for `dotnet pack` are [\<PROJECT\>|\<SOLUTION\>].
This feature will enable customers to also use a .nuspec to pack files.
`dotnet pack` is available for projects that are using the SDK-style format.
Adding the ability to use a .nuspec path instead will enable customers to pack projects or files that aren't SDK-style.
In these cases, `dotnet pack` with a .nuspec will not run `NuGet.Build.Tasks.Pack.targets` and will instead use the current implementation of `nuget.exe` [pack commands](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Clients/NuGet.CommandLine/Commands/PackCommand.cs).
This runs `PackCommandRunner`, which manages the packaging process in the `dotnet pack` command.
It collects inputs, processes them, and generates NuGet packages.
This component supports packing from .nuspec files, enhancing cross-platform workflows and eliminating the need for a .csproj file.

### Technical explanation

Currently, dotnet pack options and nuget.exe pack options are very different, meaning that we will need to add new options that would not apply when packing an SDK project.
Some options, such as `--property` (or `-p:`), are already supported in MSBuild, `dotnet pack`, and `nuget.exe pack` for setting build properties.
For .nuspec-only support, `--property` will be reused and interpreted for token replacement in the `.nuspec` file, similar to how `nuget.exe pack -Properties` works.
Other options, such as `--output`, are already standard in the dotnet CLI and will be reused for .nuspec-only support, with clarified behavior where necessary.
All new options and existing ones will need to be checked to see if they are applicable to the user scenario.
This implementation does not require a new command or subcommand, making the command look cleaner and ensuring customers won't need to learn a new command.
This is the ideal implementation.

#### Example: Packing a .nuspec File with `dotnet pack`

| Scenario                        | Option 1: .nuspec as Argument to `dotnet pack`                                 |
|----------------------------------|--------------------------------------------------------------------------------|
| Basic Usage                      | `dotnet pack MyPackage.nuspec --output ./artifacts`                             |
| Example with Property Replacement| `dotnet pack MyPackage.nuspec --property Version=1.2.3 --property Configuration=Release --output ./artifacts` |
| Relative Path                    | `dotnet pack ../MyPackage.nuspec --output ./artifacts`                          |

### Options Relevant to .nuspec-only Support in `dotnet pack`

| Option / Flag        | Description                                                        | Notes / Status for .nuspec-only support                        | Comparison (`nuget pack -h` / `dotnet pack -h`)                |
|----------------------|--------------------------------------------------------------------|---------------------------------------------------------------|---------------------------------------------------------------|
| `--property` / `-p:` | Set or override a property for token replacement in `.nuspec`.     | Reused; interpret for token replacement, not just MSBuild.     | `-Properties` in `nuget pack`, `--property` in `dotnet pack`   |
| `--version`          | Specifies the version of the package.                               | Reused; overrides <version> in .nuspec if both are specified.   | `-Version` in `nuget pack`, `--version` in `dotnet pack`       |

> **Note:**  
> This table focuses on options that are new, reused with modified behavior, or require special handling for .nuspec-only support.
> Project-specific and unrelated options (like `--no-build`) are omitted for clarity and relevance.
> Options that are standard in the dotnet CLI, such as `--configuration` and `--output`, will be reused without modification.

## Limitations

- Only a subset of options are exposed as CLI flags for .nuspec-only packaging.
- Most .nuspec metadata, including advanced fields like `<serviceable>`, must be set directly in the .nuspec file.
- For dynamic or automated scenarios, use token replacement in the .nuspec and pass values via `--property`.
- `--no-package-analysis`: Skips package analysis after building the package. This is not currently supported in .nuspec-only scenarios. As a result, this flag will not be available for .nuspec-only support.

## Rationale and Alternatives

This approach maintains simplicity and consistency with existing CLI patterns, as users are already accustomed to passing project or solution files directly to `dotnet pack`.
By extending the pattern to support .nuspec files, the command remains easy to use.

This design also helps improve discoverability and adoption.
Users exploring the CLI or referencing documentation will see that .nuspec files are supported the same way as projects and solutions, making the feature easier to find and use.

Additionally, adding this feature minimizes disruption to existing workflows.
Scripts, automation, and tooling that already use `dotnet pack` can be easily updated to support .nuspec files without significant changes.

Lastly, supporting .nuspec as a direct argument aligns with the goal of reducing friction for cross-platform and non-SDK-style packaging scenarios.
It allows developers to leverage the modern, cross-platform .NET CLI for packaging without being forced to create dummy project files or rely on Windows-only tools.

### Alternatives Considered

#### Option 2: Introducing a New Subcommand (`dotnet pack nuspec`)

An alternative approach is to introduce a new subcommand, such as `dotnet pack nuspec`, specifically for packing .nuspec files.
While this approach would allow for a clear separation of .nuspec-specific logic, it introduces drawbacks that outweigh its potential benefits.

First, introducing a new subcommand would increase the command surface area and add complexity to the CLI, which moves away from the established `dotnet` CLI pattern where arguments are typically project, solution, or file paths.
This would require users to learn and remember a new subcommand, which would reduce both discoverability and adoption, especially for those already familiar with the standard `dotnet pack` workflow.

Additionally, this approach fragments the packaging experience between SDK-style and non-SDK-style projects, making the CLI less cohesive and potentially confusing for users who work with both project types.
Although isolating .nuspec-specific logic in a command might simplify the implementation, the trade-off in user experience and CLI consistency is not justified.

Option 1 achieves the same goal of supporting .nuspec files while maintaining a unified and consistent command structure.

#### Example: Packing a .nuspec File with `dotnet pack nuspec`

| Scenario                        | Option 2: New Subcommand `dotnet pack nuspec`                                 |
|----------------------------------|--------------------------------------------------------------------------------|
| Basic Usage                      | `dotnet pack nuspec MyPackage.nuspec --output ./artifacts`                     |
| Example with Property Replacement| `dotnet pack nuspec MyPackage.nuspec --property Version=1.2.3 --property Configuration=Release --output ./artifacts` |
| Relative Path                    | `dotnet pack nuspec ../MyPackage.nuspec --output ./artifacts`                  |

## Prior Art

Previously, in 4.0.0-rc2, you were able to pack a .nuspec file without a csproj file by using `dotnet nuget pack (nuspec)` file.
This was removed in 4.0.0-rc3. Here is the [PR](https://github.com/NuGet/NuGet.Client/pull/1065) that removed this functionality.

## Future Possibilities

The following options are not currently supported in .nuspec-only scenarios, but could be considered for future enhancements:

- **`--exclude`**: This option would allow users to specify files or patterns to exclude from the package via the command line. Currently, the `<files>` element in the .nuspec file is required to control which files are included or excluded. Adding `--exclude` in the future could provide a more convenient, CLI-driven way to manage file selection, especially for dynamic or automated scenarios.

- **`--no-default-excludes`**: This flag would disable default file exclusion patterns. It is not currently supported, but if default exclusions are added in the future, this flag could be introduced to give users more granular control over file inclusion.

