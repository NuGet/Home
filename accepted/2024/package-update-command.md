# dotnet package update command

- [Olia Gavrysh](https://github.com/OliaG/)
- [Andy Zivkovic](https://github.com/zivkan/)
- Start Date (2024-11-11)
- [#13372](https://github.com/NuGet/Home/issues/13372)
- [#4103](https://github.com/NuGet/Home/issues/4103)
- [#14304](https://github.com/NuGet/Home/issues/14304)

## Summary

<!-- One-paragraph description of the proposal. -->
The `dotnet package update` feature is designed to enhance the user experience by enabling .NET developers to address security vulnerabilities, deprecated packages, and outdated versions of their NuGet dependencies with a single command.
This improvement will, in turn, bolster the overall security and reliability of .NET applications.
The feature will build upon the existing NuGet Audit functionality.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Even though .NET developers now have the opportunity to learn about vulnerabilities and deprecated dependencies in their NuGet packages and addressing those issues, there are gaps in user experience, especially in the CLI workflows.

### Existing capabilities

Visual Studio

- Has a means to show outdated packages
- Has a means to show deprecate/vulnerable packages
- Has a means to update all packages to latest
- Has a means to update a single package to latest (which can be challenging)
- Has a vulnerability filter, which in turn can allow you to update all vulnerable packages to latest

CLI

- Has a means to show outdated packages
- Has a means to show deprecated/vulnerable packages
- Has a means to update a single package
- Does not have means to update multiple packages at once

### Gaps in CLI experience

- No means to update to all latest packages on the CLI
- No means for update heuristics, such as, update my vulnerable packages

This proposal is focused on bringing the CLI experience up to functional parity with the experience in Visual Studio and make developers more productive by providing a single command to update all packages to the latest version and a way to update all vulnerable packages.

## Explanation

### Functional explanation

The `dotnet package update -h` help text might look something like this:

```text
Description:
  Update referenced packages in a project or solution.

Usage:
  dotnet package update [<packages>...] [options]

Arguments:
  <packages>  Package reference in the form of a package identifier like 'Newtonsoft.Json' or package identifier and version separated by '@' like 'Newtonsoft.Json@13.0.3'.

Options:
  --dry-run                Output what changes would be made, but don't modify any files.
  --format <console|json>  Specifies the output format type.
  --mode <direct|promote>  The implementation will have a description here to explain the differences between direct and promote.
  --project                Path to a project or solution file, or a directory.
  --vulnerable             Update packages with a known vulnerability.
  -?, -h, --help           Show help and usage information
```

### Scenarios

#### Works with other features

This probably can go without saying, but it's expected that all `dotnet package update` commands work with all other Nuget features.

For example, projects that use Central Package Management should have versions updated in the Directory.Packages.props file.
Another example is when a nuget.config has enabled Package Source Mapping, the updated packages must take into account the versions available on the enabled sources, so that subsequent restores will be successful.

Similarly, since `dotnet package update` is part of the .NET SDK, it's only expected to work with projects that work with `dotnet build`.
Therefore, some Visual Studio projects will not work, where they can't be built with the dotnet CLI.

#### Updating all packages to the latest version

Running `dotnet package update` without specifying any packages, or options such as `--vulnerable`, will automatically update all packages to the highest version.

```text
C:\> dotnet package update

Fixing outdated packages in ContosoUniversity.sln
 ContosoLibrary:
  Updated UmbracoForms 8.4.1 to 8.7.1
  Updated Newtonsoft.Json 11.0.1 to 13.0.3

 ContosoApp:
  Updated UmbracoForms 8.4.0 to 8.7.1

Updated 3 packages in 36 scanned packages.
```

#### Fixing vulnerabilities

When users run `dotnet build` or `dotnet restore` commands in CLI, if they see any warnings related to vulnerabilities in their project’s NuGet dependencies, they can run `dotnet package update --vulnerable` CLI command to try to remediate all the vulnerabilities.
The `--mode` option can be used to choose between direct package references only, or to also update transitive packages.

```CLI
C:\ContosoApp\> dotnet package update --vulnerable

Fixing vulnernable packages in ContosoUniversity.sln
 ContosoLibrary:
  Upgrading UmbracoForms 8.4.1 to 8.7.1

 ContosoApp:
  Updated UmbracoForms 8.4.0 to 8.7.1
    
Fixed 2 packages in 36 scanned packages.
```

Using the `--vulnerable` option should update the package to the lowest version that is higher than the currently reference version, which does not have a known vulnerability.
For example, if `Contoso.Security` version 1.0.0 is currently referenced by the project, and the package source has versions 1.0.1 and 2.0.0 available, 1.0.1 should be selected.
This is in contrast to `dotnet package update Contoso.Security` which will update to the highest version of the package.

If package identifiers are provided in addition to the `--vulnerable` option, only those packages should be updated.
Any package provided that does not have a known vulnerability will be skipped.

The `--mode` option will allow customers to choose what strategy of resolving vulnerabilities will be used.
The `direct` mode would only look for direct package references with known vulnerabilities and upgrade them.
The `promote` mode would also check transitive packages (equivalent to restore's `<NuGetAuditMode>all`), and add a PackageReference to the package (therefore promoting it to a direct reference).
Later, more advanced modes can be added.
When a project is using CPM and transitive pinning is enabled, no PackageReference should be added, just the PackageVersion in the Directory.Packages.props file.

If multiple packages have vulnerability warnings, but `dotnet package update --vulnerable` is only able to resolve some, but not all, of the warnings, it should make the changes it can, but return an exit code showing an error.
This only applies when the command is run without specifying any package ids (so update all packages with known vulnerabilities), or if multiple package ids are provided on the command line, and the package vulnerability that cannot be resolved is one of the provided packages.

#### --format json

Priority: P2

A JSON schema will be decided closer to implementation.
A new design document will be created specifically for it, to avoid slowing down the approval of this design document and implementation of other features.

There is potential complexity with designing the schema, as the text output can be tailored to the command line arguments provided.
For example, `dotnet package update` to update all packages might update just the packages that were updated.
But `dotnet package update pkg1 pkg2 pkg3` might say pkg1 and pkg2 were updated, but pkg3 was already up to date.
Similarly, using `--vulnerable` could have vulnerability specific output.

Some consideration may be needed to decide how much of the same information should be reported in the json (particularly when packages are not updated), and if the json schema should be the same for all commands, or if `--vulnerable` should have a different output schema than without `--vulnerable`.

Please provide feedback at <https://github.com/NuGet/Home/issues/14360>

#### Exit Codes

Priority: P1

- 0 - The command will exit with a 0 exit code if at least one package was updated without any error.
- 1 - The command will exit with a 1 exit code if the CLI options are invalid.
- 2 - The command will exit with a 2 exit code if no packages were updated, but otherwise no error occurred.
- 3 - The command will exit with a 3 exit code if any error has occurred.

The dotnet CLI uses exit code 1 when the CLI parser detects an error before running the command action, so we can't modify this exit code.

Exit code 2 is probably the most controversial.
The convention is that success is zero and non-zero is a failure of some kind.
Whether no packages are updated is a success or failure depends on the scenario.
Some customers might want to just make sure that all the packages are already at the highest version, so they consider no updates needed as a success.
However, other customers will only run the command when they know they want a package to be updated, in which case a failure to find a higher version is an error.
Since the name of the command is update, exit code 2 is chosen, and customers will need to handle the non-zero exit code in their shell or CI scripts.

Examples are:

* If `dotnet package update Contoso@1..0` is run, the exit code will be 1 because `1..0` is not a valid NuGet version range, causing the CLI parser to fail.
* If `dotnet package update Contoso@3.2.1`  is run, but package version 3.2.1 does not exist, exit code 3 will be returned.
* If `dotnet package update Contoso` is run, but the package is already at the highest version available on all package sources, then exit code 2 is returned.
* If `dotnet package update Pkg1 Pkg2` is run and Pkg1 was updated to a newer version bu Pkg2 was already at the highest version, exit code 0 will be used since at least one update was found.
* If `dotnet package update` is run on a project using `TreatWarningsAsErrors`, and the preview restore has a warning (that is elevated to an error), exit code 3 will be used since `dotnet restore` would also have an error if the update was applied.
* If `dotnet package update Contoso.Shared` is run, but no project references that package, exit code 3 will be used.
* In any case where a project or solution file can't be found (or when a directory is provided and multiple are found), then exit code 3 will be used.
* If `dotnet package update --vulnerable` is run, but not all vulnerabilities could be automatically resolved, then exit code 3 will be used, but any packages whose vulnerabilities could be resolved will be applied.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

#### dotnet CLI integration

The dotnet CLI has many features, and are evolving while we implement this design.
So, there is a lot of additional scope for quality of life improvements.
But we should also adhere to general CLI design principals.

One example is that bad input should be handled in the command line parser.
For example, is a version string is expected, it should be validated in System.CommandLine's argument or option validator, or custom parser.
Don't do validation in the command runner's logic and then provide these input errors in a different user experience than other parser errors.

Another example, tab completion.
Not only of the command and its options, but if a package name is partially typed, tab completion could complete the full package name.
In the scope of `dotnet package update`, this likely means packages already installed in projects, whereas `dotnet package add` would check package sources for available packages.
Similarly for package versions.

In .NET 9, MSBuild enabled the Terminal Logger by default.
It's easiest if you test `dotnet build` and `dotnet build -tl:false` yourself on a solution with at least 10 projects (some of which can be built in parallel) to understand how it changes output.
But my short description is that it no longer treats the console as a forward-only output, but parallel work can be displayed one line per task and lines are updated to show progress.
Similarly, we should consider what output would give customers the best experience, especially when a large solution is being updated, so many projects and packages might be impacted, therefore taking some time before the command is complete.

Most of these improvements can be considered low priority enhancements after the initial feature set is implemented.
But easy opportunities to make quality-of-life improvements should be taken rather than delaying them as lower priority.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

### Alternatives considered

#### Extending dotnet package add

The existing `dotnet package add` command can already update a PackageReference to a newer version.
However, it would be unintuitive for `dotnet package add` without any arguments updated all packages to the highest version, given the verb is `add`.
Similarly, `dotnet package add --update` feels unusual, and something like `dotnet package add --vulnerable` to update already referenced packages don't feel right.
Therefore, a new `dotnet package update` command is more desirable.

#### A vulnerability specific command

Command names similar to `dotnet nuget fix`, `dotnet nuget audit fix`, `dotnet package audit` were considered, but while discussing with some stakeholders, we thought that `dotnet package update --vulnerable` would be the most intuitive, even if it does require more letters to be typed.

#### Considering `--version` option

The `dotnet package add` command had a `--version` option since it was first created.
Similarly, other commands such as `dotnet tool install` have `--version` options.
In the 9.0.300 .NET SDK, `dotnet add package` was extended to allow specifying the version in the package id string, using syntax `{package id}@{version}`, for example `NuGet.Protocol@6.10.0`.
Other dotnet CLI have also been updated to allow this `@` syntax.

Since the `@` syntax is new, it's probably not well known, so some people might expect a `--version` option.
But if the CLI help output explicitly mentions it, like `dotnet package add -h` does, then it should be easily discoverable.

Another scenario is when a customer wants to update multiple packages to the same version, they might like `dotnet package update pkg1 pkg2 --version 12.34.56`.

However, allowing this would raise questions like `dotnet package update pkg1@1.2.3 pkg2@2.3.4 pkg3 pkg4 --version 3.4.5`.
In this example, which packages does the version 3.4.5 apply to?
Personally, I find pkg3 and pkg4 the most intuitive.
Put another way, specifying `--version` could mean disabling "update to highest version".

Alternatively, we could not provide the `--version` option at all for new commands and embrace the `@` syntax.
The biggest downside to this is when multiple packages are updated to the same version, that version string needs to be repeated multiple times.
With the .NET Libraries team updating all of their packages every release, even when there are no code changes in a patch version (possibly only a dependency version update, but sometimes not even that), it will be a common scenario that multiple `System.*` and `Microsoft.*` packages will be updated at the same time to the same version.
But it avoids all ambiguity.

#### Specifying target frameworks

The `dotnet package add` command, as well as `dotnet build`, `dotnet test`, `dotnet run` commands, have a `--framework` option to specify which target framework the command should act on.

I chose not to add it to `dotnet package update` because this command is intended to update packages that are already installed, and the use case for build, test, publish, and run are different to package add or update.
It's a good option for `dotnet package add`.
But for update, the common scenario will be to update the package for all target frameworks that the package is installed in.

Additionally, if a package reference's condition does not match the command line's `--framework` provided, there is ambiguity if the package reference should have it's condition modified.
Doing so would make the project use different versions of the package for different target frameworks.
Not modifying the condition would change the package version for a target framework that was not specified on the command line.
Neither behavior is obviously preferred, causing the proposed option to have ambiguous results.

For the early versions of the command, we can say this is an advanced scenario, and as such, advanced scenarios need hand-editing without tooling support.
If we get sufficient customer feedback, we can revisit this.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevent to this proposal? -->

### [npm audit](https://docs.npmjs.com/cli/v7/commands/npm-audit)

NPM has audit built in, which runs automatically on `npm install`, and it has an `npm audit fix` command.
The docs say fix will upgrade to a compatible version (it doesn't specify what compatible means, my guess is the matching the version range requested), and `--force` can be used to allow it to pick any version.
NPM Audit sends the list of used packages to the package registry, which responds with which packages are vulnerable (and presumably what versions vulnerabilities are fixed with).

There is an `npm update` command, to update all packages to the latest version.
However, it appears to be constrained to the version ranges specified by each package in `package.json`, so in effect it just updates the lock file to the highest floating range requested.
The command `npm install` is used to install packages, but the docs don't specify the behavior if a different version of the package is already installed.
Neither command appears to have audit related functionality, or features to upgrade packages with known vulnerabilities, although audit runs by default on any install/update.

### [cargo audit](https://github.com/RustSec/cargo-audit)

Rust's cargo does not have audit functionality built in, and a crate must be installed, in addition to being run manually.
The `cargo-audit` crate supports both checking for vulnerabilities, as well as a fix command.
Cargo's audit appears to use a git repository as its data source.

### [pip audit](https://pypi.org/project/pip-audit/)

Python's pip does not appear to have an audit function built in, so it needs to be explicitly installed and run by customers who want to use it.
It has a `--fix` command, but the documentation doesn't provide any additional information.
The docs say that it gets advisory information from the PyPI JSON API, which appears to be a per-package details endpoint.

- [dotnet outdated](https://github.com/dotnet-outdated/dotnet-outdated)

The `dotnet-outdated` tool is a general package update tool for .NET projects on the CLI.
It does not appear to have functionality related to updating only packages with security advisories.

- [OWASP Dependency-Check (Maven)](https://owasp.org/www-project-dependency-check/)

Maven is a build tool for Java, including package management.
It supports plugins, and OWASP's Dependency-Check can be used as a plugin to detect packages with known vulnerabilities.
The docs don't mention any tooling to automatically update package versions to without vulnerabilities.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

- Some kind of `--force` or `--no-restore` or `--do-not-treat-warnings-as-errors`.
  All NuGet's existing install/upgrade gestures will do a preview restore and will not modify projects is the preview restore has any error.
  But when multiple packages have warnings causing errors, it becomes difficult to resolve the warnings one by one.
  There is still value in failing the update if there are "real" errors, so there should be a way to ignore `TreatWarningsAsErrors` for an update command.
- A new mode for `--vulnerable` that would walk the package graph for transitive packages with known vulnerabilities, and update the package closest to the direct reference.
  [See the NuGet Audit 2.0 blog post](https://devblogs.microsoft.com/dotnet/nugetaudit-2-0-elevating-security-and-trust-in-package-management/#recommended-way-to-resolve-warnings) for more details.
- When transitive packages are promoted to resolve a vulnerability warning, somehow mark the package reference (or package version, in case of CPM), so a later package update can remove the pinning when it's no longer needed.
- This functionality may be reused to implement a one-click fix in the Visual Studio UI experience.
- Enable fixes for deprecations with an option for the users to choose what they want to fix (vulnerabilities, depreciation, outdated versions).
- Modify the NuGet Audit warnings to specify that `dotnet package update --vulnerable` can be used to resolve the warnings.
  At this time it's not possible to modify restore warnings depending if restore is running on the command line or in Visual Studio, and we wouldn't want to tell customers using VS to use the CLI, so that would be a requirement before implementing a warning message update to instruct customers to use a CLI tool.
