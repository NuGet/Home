# `dotnet nuget license`

- Author Name [Aaron Powell](https://github.com/aaronpowell)
- Start Date (2021-05-11)
- GitHub Issue N/A
- GitHub PR TBC

## Summary

This command will allow someone to inspect all the licenses that are specified for the referenced packages, as well as transient packages, of a project.

## Motivation

The motivation is to give people more insights into the licenses that are used in a project, ensuring they can stay compliant with the licenses.

## Explanation

### Functional explanation

On the new project you're building, there are dependencies on NuGet packages from a remote feed, and those packages in turn have their own dependencies. This has resulted in an opaque view of what licenses are being consumed by the project.

Your companies legal department has outlined a list of open source licenses that it is comfortable consuming and others that it wants to avoid using.

To avoid accidentally consuming an unsupported license we need a way to view the list and ideally fail builds when we use one of these licenses.

#### Local scenario

You have just added a new NuGet dependency into the project and want to ensure it doesn't bring in any unsupported licenses.

From the command line you run the license command:

```bash
$> dotnet nuget license
```

This outputs a human readable view of the license information:

```
Project dotnet-delice
License Expression: MIT
├── There are 10 occurances of MIT
├─┬ Conformance:
│ ├── Is OSI Approved: true
│ ├── Is FSF Free/Libre: true
│ └── Included deprecated IDs: false
└─┬ Packages:
  ├── FSharp.Core
  ├── Microsoft.NETCore.App
  ├── Microsoft.NETCore.DotNetAppHost
  ├── Microsoft.NETCore.DotNetHostPolicy
  ├── Microsoft.NETCore.DotNetHostResolver
  ├── Microsoft.NETCore.Platforms
  ├── Microsoft.NETCore.Targets
  ├── NETStandard.Library
  ├── Newtonsoft.Json
  └── System.ComponentModel.Annotations
```

Satisfied with the licenses, you continue on with the task at hand.

#### Blocking builds

It's time to update our build pipeline to avoid releasing anything changes that introduce unsupported licenses. A new step is added to the pipeline YAML:

```yml
- name: Validate Licenses
  runs: |
    LICENSES=$(dotnet nuget license --json | jq '<query for allowed licenses>')
    if ($LICENSES) then
        exit 0
    fi
```

This (pseduocode version) will dump the licenses to a JSON structure that can be parsed with a tool such as [jq](https://stedolan.github.io/jq/) and inspected for invalid licenses. If any are found an error code is returned, stopping the build from completing successfully.

### Technical explanation

The first technical challenge for this is the inconsistent nature of which licenses are provided by NuGet packages. While the [`licenseUrl` field was deprecated](https://github.com/NuGet/Announcements/issues/32) a large number of packages still haven't adopted the new format, making it difficult to determine what the license of a project is.

The next challenge is how to detect licenses from license files. The ideal approach would be to mirror GitHub's approach, which uses [Licensee](https://licensee.github.io/licensee/) [for detection](https://help.github.com/en/articles/licensing-a-repository#detecting-a-license) (but naturally a dotnet implementation). Essentially this uses [Sørensen–Dice coefficient](https://en.wikipedia.org/wiki/S%C3%B8rensen%E2%80%93Dice_coefficient) with a threshold for what is the acceptable level of comparison between the provided license and license template.

The technical workflow for license detection would follow:

- If a `license` field is in the nuspec, check if it's a SPDX ID, if so, return. If it's a file, use Sørensen–Dice coefficient to compare it to a known list
- If a `licenseUrl` is provided, attempt to download the license from the endpoint and compare with the known list
- Fallback to looking at the package feed and see if it provides license information

It may also be worth having the facility to cache the SPDX license information from https://spdx.org/licenses/licenses.json to improve lookup performance

#### `$> dotnet nuget license [folder, sln, csproj, fsproj] [OPTIONS]`

##### Commands

- `-?|-h|--help` Boolean. Show help.
- `-j|--json` Boolean. Output results as JSON rather than pretty-print.
- `--json-output [path]` String. Path to file that the JSON should be written to. Note: Only in use if you use `-j|--json`.
- `--check-github` Boolean. If the license URL (for a legacy package) points to a GitHub hosted file, use the GitHub API to try and retrieve the license type.
- `--github-token <token>` String. A GitHub Personal Access Token (PAT) to use when checking the GitHub API for license types. This avoids being [rate limited](https://developer.github.com/v3/#rate-limiting) when checking a project.
- `--check-license-content` Boolean. When provided the contents of the license file will be compared to known templates.
- `--refresh-spdx` Boolean. When provided the tool will also refresh the SPDX license cache used for conformance information.

##### Output

- Project Name
  - The name of the project that was checked
- License Expression
  - A license expression found when parsing references
  - Some packages may result in an undetermined license
- Packages
  - The name(s) of the packages found for that license

## Drawbacks

Not having functionality to do this will result in users having to rely on third-party tooling, manually resolving the information themselves or being unaware they may break license restrictions.

## Rationale and alternatives

The rationale is to give people as much information as possible about the OSS that they rely on, ensuring they can make the most informed decisions on the dependencies they have and the legal requirements they are to be held to.

## Prior Art

I have created a dotnet global tool that does this, [`dotnet-delice`](https://github.com/aaronpowell/dotnet-delice). This does prove that it is a technical possibility to implement such a solution.

There is a [similar proposal for npm](https://github.com/npm/rfcs/pull/182), created by the author who inspired `dotnet-delice`.

## Unresolved Questions

- ❔ How do we handle packages that don't use the `license` field? Especially if they are outdated versions a package.
- ❔ Should there be a common output approach with the npm solution to support interop?

## Future Possibilities

N/A
