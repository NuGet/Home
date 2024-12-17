# dotnet package update command

- [Olia Gavrysh](https://github.com/OliaG/)
- Start Date (2024-11-11)
- [#13372](https://github.com/NuGet/Home/issues/13372)
- [#4103](https://github.com/NuGet/Home/issues/4103)

## Summary

<!-- One-paragraph description of the proposal. -->
The `dotnet package update` feature is designed to enhance the user experience by enabling .NET developers to address security vulnerabilities, deprecated packages, and outdated versions of their NuGet dependencies with a single command.
This improvement will, in turn, bolster the overall security and reliability of .NET applications. The feature will build upon the existing NuGet Audit functionality.

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
dotnet

CLI

- Has a means to show outdated packages
- Has a means to show deprecated/vulnerable packages
- Has a means to update a single package
- Does not have means to update multiple packages at once

### Gaps in CLI experience

- No means to update to all latest packages on the CLI
- No means for update heuristics, such as, update my vulnerable packages

This proposal is focused on bringing the CLI experience up to funcional parity with the experience in Visual Studio and make developers more productive by providing a single command to update all packages to the latest version and a way to update all vulnerable packages.

## User experience

### Updating all packages to the latest version

When users want to ensure their NuGet dependencies are up to date, they can run a command in .NET CLI `dotnet package update` for a project or a solution.

```CLI
C:\> dotnet package update [<SOLUTION_PATH>|<PROJECT_PATH_>]

Fixing outdated packages in ContosoUniversity.sln
 ContosoLibrary:
  Updated UmbracoForms 8.4.1 to 8.7.1
  Updated Newtonsoft.Json 11.0.1 to 13.0.3

 ContosoApp:
  Updated UmbracoForms 8.4.0 to 8.7.1
    
Updated 3 packages in 36 scanned packages.
```

### Fixing vulnerabilities

When users run `dotnet build` or `dotnet restore` commands in CLI, if they see any warnings related to vulnerabilities in their project’s NuGet dependencies, they can run `dotnet package update --vulnerable` CLI command to try to remediate all the vulnerabilities. This includes both direct and transitive.

```CLI
C:\ContosoApp\> dotnet package update --vulnerable

Fixing vulnernable packages in ContosoUniversity.sln
 ContosoLibrary:
  Upgrading UmbracoForms 8.4.1 to 8.7.1

 ContosoApp:
  Updated UmbracoForms 8.4.0 to 8.7.1
    
Fixed 2 packages in 36 scanned packages.
```

In the future this can be extended to fix deprecated versions.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

#### dotnet package update

The `dotnet package update` command will update all the NuGet dependencies to the latest versions.

```CLI
C:\> dotnet package update --help
dotnet package update [<PROJECT>|<SOLUTION>] [--vulnerable] [--mode <MODE>] [-v|--verbosity <LEVEL>] [--json] 
```

#### --vulnerable

This flag will try to update only packages that have direct or transitive vulnerabilities. The remediation is calculated with an implicit dotnet audit to then apply directly to a resulting package graph. It can add packages, remove packages, and update packages depending on the problem it's attempting to resolve. It does not take into consideration downgrading to a compatible version if a higher one has already been specified.
The algorithm of the fixing process will have the following steps:

1. Identify  vulnerabilities in the graph
1. Distinguish which are top level, transitive level, etc.,
1. Resolve any compatibility conflicts
1. Apply the patch/update/fix
1. Restore dependencies
1. Verify that issues were resolved  . Provide the report to the user.
1. If the issues were not resolved or were partially resolved, we will still commit the fixes and notify users about what was and was not fixed and what are the recommended manual steps with links to documentation.

Example:

```CLI
C:\ContosoApp\> dotnet package update --vulnerable

Fixing vulnernable packages in ContosoUniversity.sln
 ContosoLibrary:
  Upgrading UmbracoForms 8.4.1 to 8.7.1

 ContosoApp:
  Updated UmbracoForms 8.4.0 to 8.7.1
    
Fixed 2 packages in 36 scanned packages.
```

Another option for the output with more information (will review with CLI team to decide which one to pick):

```CLI
C:\> dotnet package update --vulnerable [<SOLUTION_PATH>|<PROJECT_PATH_>]

Fetching package metadata from: 'https://api.nuget.org/v3/index.json'
Loaded 23 security advisories from 'https://api.nuget.org/v3/index.json'
Scanning ContosoUniversity.sln (36 NuGet dependencies)

error: Vulnernable packages found!
[net5.0]:
Top-level Package     Requested Resolved Severity Advisory URL
> UmbracoForms      8.4.1  8.4.1  Moderate https://github.com/advisories/GHSA-8m73-w2r2-6xxj

Transitive Package  Resolved Severity Advisory URL
> Microsoft.Data.OData 5.2.0  Moderate https://github.com/advisories/GHSA-mv2r-q4g5-j8q5

Found 1 top-level Moderate severity vulnerability & 1 transtive Moderate severity vulnerability package(s) in 36 scanned packages.

Fixing vulnernable packages in ContosoUniversity.sln
 Upgrading UmbracoForms 8.4.1 to 8.7.1

Fixed 2 packages in 36 scanned packages.
```

#### --mode

Priority: P1 for `promote`; P2 for `closest` and switching the default to `closest`.

| Mode | Explanation |
|------|-------------|
| `promote` | the algorithm will always promote transitive packages to top level. This is an easy to implement feature that we will release in MVP. |
| `closest` | the algorithm will try to upgrade the direct package reference, and if that doesn't work, it will walk the graph one dependency level at a time trying to upgrade that, until it gets to the package with the known vulnerability. Once this mode is implemented, it should be set to be the default one. |

#### --format json

Priority: P2

Provides a detailed report in a JSON format:

```json
  "added": [
    {
      "name": "Microsoft.AspNetCore.MVC",
      "version": "2.2.0"
    }
  ],
  "removed": [
      {
        "name": "anurse.testing.TestDeprecatedPackage",
        "version": "1.0.0"
      }
  ],
  "updated": [
    {
      "name": "UmbracoForms",
      "version": "8.7.1",
      "previousVersion": "8.4.1"
    }
  ],
  "failures": [],
  "warnings": []
```

In the "failures" and "warnings" should be the information about what projects were not updated due to failed pipeline or different reassons like no solution was found, the format of the project file is not supported, etc.

##### Exit Codes

Priority: P1

- 0 - The command will exit with a 0 exit code if no vulnerabilities or outdated packages were found and no changes were made.
- 1 - The command will exit with a 1 exit code if changes were successful and the PR is submitted.
- 2 - The command will exit with a 2 exit code if any error has occurred, PR will not be submitted.

##### Endpoints

NuGet will use existing endpoints to optimize the speed of audit results.

- [Vulnerability](https://docs.microsoft.com/en-us/nuget/api/registration-base-url-resource#vulnerabilities)
- Outdated - no existing endpoint, will need to call a source.
- [Deprecation](https://docs.microsoft.com/en-us/nuget/api/registration-base-url-resource#package-deprecation) for future possible improvements.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

### Alternatives considrered

We could enable the option for the users to pick if they want only direct vulnerabilities to be resolved or direct and transitive. We decided to not do so and implement the resolution of all vulnerabilities as we believe that better corresponds to our goal of increasing security across all .NET applications. 

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevent to this proposal? -->
- [snyk](https://snyk.io/)
- [npm audit](https://docs.npmjs.com/cli/v7/commands/npm-audit)
- [cargo audit](https://github.com/RustSec/cargo-audit)
- [dotnet outdated](https://github.com/dotnet-outdated/dotnet-outdated)
- [dotnet retire](https://github.com/retirenet/dotnet-retire)
- [NuGet Defense](https://github.com/digitalcoyote/NuGetDefense)
  
## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

- In the future the basic algorithm could check for breaking changes in fixed versions.
- This functionality may be reused to implement a one-click fix in the Visual Studio UI experience.
- Enable fixes for deprecations and outdated versions as well together with an option for the users to choose what they want to fix (vulnerabilities, depreciation, outdated versions).
