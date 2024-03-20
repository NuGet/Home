# dotnet audit & dotnet audit fix

- [Jon Douglas](https://github.com/JonDouglas/)
- Start Date (2021-04-01)
- [#8087](https://github.com/NuGet/Home/issues/8087)

## Summary

<!-- One-paragraph description of the proposal. -->
`dotnet audit` & `dotnet audit fix` helps you find, fix, and monitor known security vulnerabilities, deprecated packages, and outdated versions in your .NET projects & solutions.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
.NET developers manage their dependencies on a daily basis. However, it's become more and more difficult to know exactly what dependencies in a software supply chain might be vulnerable, deprecated, or even outdated. All of these scenarios require a developers direct attention to resolve. Even knowing about a dependency that falls into one of these categories, there is then the question about what to do with said dependency such as:

- Removing it
- Replacing it
- Updating it
- Ignoring it

The goal of this proposal is to provide developers a single command to audit their dependencies, resolve them, and alert the user to manually take action towards a resolution if the tooling cannot.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

#### dotnet audit

The `dotnet audit` command will scan your project and solution's dependencies and look for known vulnerabilities, deprecations, and outdated packages. If any vulnerabilities, deprecations, or outdated packages are found, a remediation will be calculated to then `fix` which will be applied to the resulting package graph.

Example:

![dotnet audit](/meta/resources/dotnetaudit/dotnetaudit.png)

```
$ dotnet audit

Fetching package metadata from: 'https://api.nuget.org/v3/index.json'
Loaded 23 security advisories from 'https://api.nuget.org/v3/index.json'
Scanning ContosoUniversity.sln (36 NuGet dependencies)

error: Vulnerable packages found!
[net5.0]:
Top-level Package	    Requested	Resolved	Severity	Advisory URL
> UmbracoForms		    8.4.1		8.4.1		Moderate	https://github.com/advisories/GHSA-8m73-w2r2-6xxj

Transitive Package		Resolved	Severity	Advisory URL
> Microsoft.Data.OData	5.2.0		Moderate	https://github.com/advisories/GHSA-mv2r-q4g5-j8q5

Found 1 top-level Moderate severity vulnerability & 1 transtive Moderate severity vulnerability package(s) in 36 scanned packages.

Run 'dotnet audit fix' to fix them.

warning: Deprecated packages found!
[net5.0]:
Top-level Package						Requested	Resolved	Reason(s)	Alternative
> anurse.testing.TestDeprecatedPackage	1.0.0		1.0.0		Legacy		Microsoft.AspNetCore.Mvc > 0.0.0

Found 1 top-level Legacy deprecated package(s) in 36 scanned packages.

Run 'dotnet audit fix' to fix them.

warning: Outdated packages found!
[net5.0]:
Top-level Package						            Resolved	Latest
> anurse.testing.TestDeprecatedPackage	            1.0.0		2.0.0
> UmbracoForms							            8.4.1	    8.7.1

Found 2 top-level outdated package(s) in 36 scanned packages.

Run 'dotnet audit fix' to fix them.
```

##### Endpoints

NuGet will use existing endpoints to optimize the speed of audit results.

- [Deprecation](https://docs.microsoft.com/en-us/nuget/api/registration-base-url-resource#package-deprecation)
- [Vulnerability](https://docs.microsoft.com/en-us/nuget/api/registration-base-url-resource#vulnerabilities)
- Outdated - No existing endpoint, will need to call a source.

##### dotnet audit --json

To get a detailed audit report in a JSON format.

```
{
  "audit": {
    "vulnerabilities": {
      "low": "0",
      "moderate": "2",
      "high": "0",
      "critical": "0",
      "dependencies": [
        {
          "name": "UmbracoForms",
          "requestedVersion": "8.4.1",
          "resolvedVersion": "8.4.1",
          "vulnerabilitySeverity": "Moderate",
          "advisoryUrl": "https://github.com/advisories/GHSA-8m73-w2r2-6xxj",
          "transitiveDependencies": [
            {
              "name": "Microsoft.Data.OData",
              "resolvedVersion": "5.2.0",
              "severity": "Moderate",
              "advisoryUrl": "https://github.com/advisories/GHSA-mv2r-q4g5-j8q5"
            }
          ]
        }
      ]
    },
    "deprecations": {
      "legacy": "1",
      "critical-bugs": "0",
      "other": "0",
      "dependencies": [
        {
          "name": "anurse.testing.TestDeprecatedPackage",
          "requestedVersion": "1.0.0",
          "resolvedVersion": "1.0.0",
          "reason": "Legacy",
          "alternativeDependencies": [
            {
              "name": "Microsoft.AspNetCore.MVC",
              "version": "0.0.0"
            }
          ]
        }
      ]
    },
    "outdated": {
      "packages": "2",
      "dependencies": [
        {
          "name": "anurse.testing.TestDeprecatedPackage",
          "resolvedVersion": "1.0.0",
          "latestVersion": "2.0.0"
        },
        {
          "name": "UmbracoForms",
          "resolvedVersion": "8.4.1",
          "latestVersion": "8.7.1"
        }
      ]
    },
    "scannedDependencies": "36"
  }
}
```

##### dotnet audit Exit Codes

- 0 - The command will exit with a 0 exit code if no vulnerabilities, deprecations, or outdated packages were found.
- 1 - The command will exit with a 1 exit code if a vulnerability, deprecation, or outdated package was found.
- 2 - The command will exit with a 2 exit code if it unexpectedly failed.
- 3 - The command will exit with a 3 exit code if an unsupported project is detected.

#### dotnet audit fix

The `dotnet audit fix` command will provide a remediation that is calculated with an implicit `dotnet audit` to then apply directly to a resulting package graph. It can add packages, remove packages, and update packages depending on the problem it's attempting to resolve. It does not take into consideration downgrading to a compatible version if a higher one has already been specified.

![dotnet audit fix](/meta/resources/dotnetaudit/dotnetauditfix.png)

```
$ dotnet audit fix

Fixing vulnerable packages in ContosoUniversity.sln
	Upgrading UmbracoForms 8.4.1 to 8.7.1

Fixing deprecated packages in ContosoUniversity.sln
	Replacing anurse.testing.TestDeprecatedPackage 1.0.0 with Microsoft.AspNetCore.Mvc 2.2.0

Fixing outdated packages in ContosoUniversity.sln
	Packages are currently up-to-date.
    
Fixed 2 packages in 36 scanned packages.
```

##### dotnet audit fix --dry-run

Does a dry run to give an idea of what `audit fix` will do. Provides output, but does not commit the fix.

##### dotnet audit fix --json

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

##### dotnet audit fix Exit Codes

- 0 - The command will exit with a 0 exit code if no vulnerabilities, deprecations, or outdated packages were found *or* remediation was able to fix all issues.
- 1 - The command will exit with a 1 exit code if a vulnerability, deprecation, or outdated package was found *and* remediation is not able to fix all issues.
- 2 - The command will exit with a 2 exit code if it unexpectedly failed.
- 3 - The command will exit with a 3 exit code if an unsupported project is detected.

#### Vulnerabilities

When vulnerable packages are detected, an error is thrown by default.

#### Deprecation

When deprecated packages are detected, a warning is thrown by default.

#### Outdated

When outdated packages are detected, a warning is thrown by default.

#### CLI Usage

```
dotnet audit --help
dotnet audit [<PROJECT>|<SOLUTION>|<Directory.Packages.props>] [-v|--verbosity <LEVEL>] [--json] [--interactive]
```

```
dotnet audit fix --help
dotnet audit fix [<PROJECT>|<SOLUTION>|<Directory.Packages.props>] [-v|--verbosity <LEVEL>] [--dry-run] [--json] [--interactive]
```

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

<!-- Why should we not do this? -->
There's a number of [dotnet tools](https://github.com/natemcmaster/dotnet-tools) that exist to solve many of these painpoints. Much of the information to put together this experience exists within NuGet.org's Server API & could created as a dotnet tool.

There are a number of auditing tools in other ecosystems that are third-party / developed by the community. For other ecosystems, these features are built into the first-party CLI experiences.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
There already exists a dotnet CLI commands called `dotnet list package` with options such as `--vulnerable, --deprecated, --outdated` which will list any known vulnerabilities, deprecations, and outdated packages in a project or solution. These options currently cannot be combined. Although this provides valuable information to understand the state of your dependencies, there does not exist a tool that allows you to quickly audit a project/solution & provide a way to act further on.

When a developer is prompted with information such as a known vulnerability, deprecated package, or outdated version, they should have a clear understanding of how to best proceed with the information provided. In most cases, simply updating the dependency will suffice.

Additionally, there already exists many third-party solutions that try to solve this problem with varying degrees of success. Some solutions can help alert about known vulnerabilities and some can help alert about outdated packages. No single tool seems to check for a "healthy" dependency list & that's another reason why we're looking to combine these experiences into a single command.

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
  
## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->
- Should the command be named `audit` or `check`?
  - `audit` is the more consistent name for package manager tooling with other ecosystems.
  - `check` is the more consistent name with dotnet CLI.
- Should this command only audit `vulnerabilities`? Or should it audit & be proactive as to `vulnerabilities`, `deprecations`, and `outdated` packages?
- How much information should be present in the --json output?

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
- `dotnet audit` can be run on every `restore` which can throw warnings or errors to the user to take action against a vulnerable, deprecated, or outdated software supply chain.
- `dotnet audit` and `dotnet audit fix` output & resolutions can be extended by the .NET ecosystem to build tooling & new experiences around.
- `dotnet audit` and `dotnet audit fix` experiences can be extended into Visual Studio IDEs providing users with more visualizations of potential problems in their dependencies & ways to resolve them with a single click experience.
- `dotnet audit` can be added to CI/CD environments for an extra layer of monitoring such as a GitHub Action template.
