## Machine-readable output for `dotnet list package`

* Status: **Reviewing**
* Authors: [Xavier Decoster](https://github.com/xavierdecoster)

## Issue

[#7752](https://github.com/NuGet/Home/issues/7752) - dotnet list package is difficult to parse

## Problem

Having a machine-readable output for `dotnet list package` would be very convenient, especially when `--outdated` and `--deprecated` come into the picture. Making the output machine-readable unlocks additional tooling and automation scenarios.

This spec is based on today's (and planned) console output for the `dotnet list package` command. During review, I'd love to capture feedback/input and make sure we understand what data and format would be desired for this machine-readable output.

## Who is the customer?

Everyone who uses `dotnet.exe list package` command to query for installed, outdated or deprecated package information.

## Key Scenarios

* Ability to use new `--json` option for all `dotnet list package` commands to ensure JSON-formatted output is emitted to the console.

## Out-of-scope

* To avoid disk I/O, we won't support saving the machine-readable output to disk as part of this spec. The work-around is for the consumer to read from the console's `stdout` stream.
* At this point, no other CLI commands will be within scope for this feature.

## Solution

A new `--json` command option will be added to the `dotnet list package` command. This command option needs to be forwarded from dotnet CLI to NuGet XPlat.

### Help

The CLI `--help` output should be updated to include the new `--json` command help.

```
Usage: dotnet list <PROJECT | SOLUTION> package [options]

Arguments:
  <PROJECT | SOLUTION>   The project or solution file to operate on. If a file is not specified, the command will search the current directory for one.

Options:
  -h, --help                                Show command line help.
  --json                                    Output machine-readable JSON to the console.
  --outdated                                Lists packages that have newer versions.
  --deprecated                              Lists packages that have been deprecated.
  --framework <FRAMEWORK | FRAMEWORK\RID>   Chooses a framework to show its packages. Use the option multiple times for multiple frameworks.
  --include-transitive                      Lists transitive and top-level packages.
  --include-prerelease                      Consider packages with prerelease versions when searching for newer packages. Requires the '--outdated' or '--deprecated' option.
  --highest-patch                           Consider only the packages with a matching major and minor version numbers when searching for newer packages. Requires the '--outdated' option.
  --highest-minor                           Consider only the packages with a matching major version number when searching for newer packages. Requires the '--outdated' option.
  --config <CONFIG_FILE>                    The path to the NuGet config file to use. Requires the '--outdated' or '--deprecated' option.
  --source <SOURCE>                         The NuGet sources to use when searching for newer packages. Requires the '--outdated' or '--deprecated' option.
```

### dotnet list package --json

```
{
  "installed": [
    {
      "framework": "netcoreapp2.0",
      "topLevelPackages": [
        {
          "id": "My.Legacy.Package",
          "resolvedVersion": "2.0.0"
        },
        {
          "id": "My.Buggy.Package",
          "resolvedVersion": "1.1.0"
        },
        {
          "id": "My.CompletelyBroken.Package",
          "resolvedVersion": "0.9.0"
        }
      ],
      "transitivePackages": null
    }
  ]
}
```

### dotnet list package --json --outdated

```
{
  "outdated": [
    {
      "framework": "netcoreapp2.0",
      "topLevelPackages": [
        {
          "id": "NuGet.Common",
          "requestedVersion": "4.8.0-preview1.5146",
          "resolvedVersion": "4.8.0-preview1.5146",
          "latestVersion": "4.9.1-zlocal.52990"
        }
      ],
      "transitivePackages": [
        {
          "id": "NuGet.Frameworks",
          "requestedVersion": "4.8.0-preview3.5278",
          "latestVersion": "4.9.1-zlocal.52990"
        }
      ]
    }
  ]
}
```

### dotnet list package --json --deprecated

```
{
  "deprecated": [
    {
      "framework": "netcoreapp2.0",
      "topLevelPackages": [
        {
          "id": "My.Legacy.Package",
          "resolvedVersion": "2.0.0",
          "reasons": ["Legacy"],
          "alternativePackage": {
            "id": "My.Awesome.Package",
            "versionRange": "[3.0.0,)"
          }
        },
        {
          "id": "My.Buggy.Package",
          "resolvedVersion": "1.1.0",
          "reasons": ["Critical Bugs"],
          "alternativePackage": {
            "id": "My.NotBuggy.Package",
            "versionRange": "*"
          }
        },
        {
          "id": "My.CompletelyBroken.Package",
          "resolvedVersion": "0.9.0",
          "reasons": ["Legacy", "Critical Bugs"],
          "alternativePackage": null
        }
      ],
      "transitivePackages": null
    }
  ]
}
```