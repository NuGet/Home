# Machine readable JSON output for dotnet list package

* Status: **In Review**
* Author: [Erick Yondon](https://github.com/erdembayar)
* GitHub Issue [7752](https://github.com/NuGet/Home/issues/7752)

## Problem background
<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Many organizations are required by [regulation](https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/) to audit packages that they're using in a repository.

Currently there's no easy way to produce a [Software Bill of Material (SBOM)](https://blog.sonatype.com/what-is-a-software-bill-of-materials) output which can be consumed by another auditing system or kept for records.

* Parse-friendly output. Other package managers like [NPM already have it](https://docs.npmjs.com/cli/v7/commands/npm-ls) (`npm ls --parseable` and `npm ls --json`).
* Useful for CI/CD auditing(compliance, security ..)
  * Produce Software Bill of Material (SBOM) (compliance, historic keeping)
  * Enhancing Software Supply Chain Security
    * Check any vulnerable packages
    * Check any deprecated packages
    * Check any outdated packages
  * Check license compliance
  * Resolve dependency issues (detect duplicate packages, newly introduced dependencies, dependency removals, etc.)
  * Making the output machine-readable unlocks additional tooling and automation scenarios in CI/CD pipeline above scenarios.

## Who are the customers

Anyone (government/private enterprises, security experts, individual contributors) who wants to consume `dotnet list package` output for auditing tool or historic keeping, CI/CD orchestrating.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

#### `--format` option

Ability to use new `--format` option for all `dotnet list package` commands to ensure formatted(json, text, csv etc) output is emitted to the console.

```dotnetcli
dotnet list [<PROJECT>|<SOLUTION>] package [--config <SOURCE>]
    [--deprecated]
    [--framework <FRAMEWORK>] [--highest-minor] [--highest-patch]
    [--include-prerelease] [--include-transitive] [--interactive]
    [--outdated] [--source <SOURCE>] [-v|--verbosity <LEVEL>]
    [--vulnerable]
    [--format <FORMAT>]

dotnet list package -h|--help
```

#### `> dotnet list package`

```dotnetcli
Project 'MyProjectA' has the following package references
   [netcoreapp3.1]:
   Top-level Package                      Requested             Resolved
   > Microsoft.Extensions.Primitives      [1.0.0, 5.0.0]        1.0.0
   > NuGet.Commands                       4.8.0-preview3.5278   4.8.0-preview3.5278
   > Text2Xml.Lib                         [1.1.2, 2.0.0)        1.1.2

Project 'MyProjectB' has the following package references
   [netcoreapp3.1]:
   Top-level Package      Requested             Resolved
   > NuGet.Commands       4.8.0-preview3.5278   4.8.0-preview3.5278
   > Text2Xml.Lib         1.1.2                 1.1.2

   [net5.0]:
   Top-level Package      Requested             Resolved
   > NuGet.Commands       4.8.0-preview3.5278   4.8.0-preview3.5278
   > Text2Xml.Lib         1.1.2                 1.1.2
```

#### `> dotnet list package --format json`

```json
{
  "version": 1,
  "projects": {
    "MyProjectA": [
      {
        "Path": "src/tool/MyProjectA.csproj",
        "framework": "netcoreapp3.1",
        "topLevelPackages": [
          {
            "id": "Microsoft.Extensions.Primitives",
            "requestedVersion": "[1.0.0, 5.0.0]",
            "resolvedVersion": "1.0.0"
          },
          {
            "id": "NuGet.Commands",
            "requestedVersion": "4.8.0-preview3.5278",
            "resolvedVersion": "4.8.0-preview3.5278"
          },
          {
            "id": "Text2Xml.Lib",
            "requestedVersion": "[1.1.2, 2.0.0)",
            "resolvedVersion": "1.1.2"
          }
        ]
      }
    ],
    "MyProjectB": [
      {
        "Path": "src/lib/MyProjectB.csproj",
        "framework": "netcoreapp3.1",
        "topLevelPackages": [
          {
            "id": "NuGet.Commands",
            "requestedVersion": "4.8.0-preview3.5278",
            "resolvedVersion": "4.8.0-preview3.5278"
          },
          {
            "id": "Text2Xml.Lib",
            "requestedVersion": "1.1.2",
            "resolvedVersion": "1.1.2"
          }
        ]
      },
      {
        "Path": "src/lib/MyProjectB.csproj",
        "framework": "net5.0",
        "topLevelPackages": [ 
          {
            "id": "NuGet.Commands",
            "requestedVersion": "4.8.0-preview3.5278",
            "resolvedVersion": "4.8.0-preview3.5278"
          },
          {
            "id": "Text2Xml.Lib",
            "requestedVersion": "1.1.2",
            "resolvedVersion": "1.1.2"
          }
        ]
      }
    ]
  }
}
```

#### `> dotnet list package --outdated`

```dotnetcli

The following sources were used:
   https://api.nuget.org/v3/index.json
   https://apidev.nugettest.org/v3-index/index.json

Project `MyProjectA` has the following updates to its packages
   [netcoreapp3.1]:
   Top-level Package                      Requested             Resolved              Latest
   > Microsoft.Extensions.Primitives      [1.0.0, 5.0.0]        1.0.0                 6.0.0
   > NuGet.Commands                       4.8.0-preview3.5278   4.8.0-preview3.5278   6.0.0
   > Text2Xml.Lib                         [1.1.2, 2.0.0)        1.1.2                 1.1.4

Project `MyProjectB` has the following updates to its packages
   [netcoreapp3.1]:
   Top-level Package      Requested             Resolved              Latest
   > NuGet.Commands       4.8.0-preview3.5278   4.8.0-preview3.5278   6.0.0
   > Text2Xml.Lib         1.1.2                 1.1.2                 1.1.4

   [net5.0]:
   Top-level Package      Requested             Resolved              Latest
   > NuGet.Commands       4.8.0-preview3.5278   4.8.0-preview3.5278   6.0.0
   > Text2Xml.Lib         1.1.2                 1.1.2                 1.1.4
```

#### `> dotnet list package --outdated --format json`

```json
{
  "version": 1,
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ],
  "projects": {
    "MyProjectA": [
      {
        "Path": "src/tool/MyProjectA.csproj",
        "framework": "netcoreapp3.1",
        "topLevelPackages": [
          {
            "id": "Microsoft.Extensions.Primitives",
            "requestedVersion": "[1.0.0, 5.0.0]",
            "resolvedVersion": "1.0.0",
            "latestVersion": "6.0.0",
          },
          {
            "id": "NuGet.Commands",
            "requestedVersion": "4.8.0-preview3.5278",
            "resolvedVersion": "4.8.0-preview3.5278",
            "latestVersion": "6.0.0",
          },
          {
            "id": "Text2Xml.Lib",
            "requestedVersion": "[1.1.2, 2.0.0)",
            "resolvedVersion": "1.1.2",
            "latestVersion": "1.1.4"
          }
        ]
      }
    ],
    "MyProjectB": [
      {
        "Path": "src/tool/MyProjectB.csproj",
        "framework": "netcoreapp3.1",
        "topLevelPackages": [
          {
            "id": "NuGet.Commands",
            "requestedVersion": "4.8.0-preview3.5278",
            "resolvedVersion": "4.8.0-preview3.5278",
            "latestVersion": "6.0.0"
          },
          {
            "id": "Text2Xml.Lib",
            "requestedVersion": "1.1.2",
            "resolvedVersion": "1.1.2",
            "latestVersion": "1.1.4"
          }
        ]
      },
      {
        "Path": "src/tool/MyProjectB.csproj",
        "framework": "net5.0",
        "topLevelPackages": [ 
          {
            "id": "NuGet.Commands",
            "requestedVersion": "4.8.0-preview3.5278",
            "resolvedVersion": "4.8.0-preview3.5278",
            "latestVersion": "6.0.0"
          },
          {
            "id": "Text2Xml.Lib",
            "requestedVersion": "1.1.2",
            "resolvedVersion": "1.1.2",
            "latestVersion": "1.1.4"
          }
        ]
      }
    ]
  }
}
```

#### `> dotnet list package --deprecated`

```dotnetcli
The following sources were used:
   https://api.nuget.org/v3/index.json
   https://apidev.nugettest.org/v3-index/index.json

Project `MyProjectA` has the following deprecated packages
   [netcoreapp3.1]:
   Top-level Package                 Requested   Resolved   Reason(s)   Alternative
   > EntityFramework.MappingAPI      *           6.2.1      Legacy      Z.EntityFramework.Extensions >= 0.0.0
   > NuGet.Core                      2.13.0      2.13.0     Legacy

Project `MyProjectB` has the following deprecated packages
   [netcoreapp3.1]:
   Top-level Package      Requested   Resolved   Reason(s)   Alternative
   > NuGet.Core           2.13.0      2.13.0     Legacy

   [net5.0]:
   Top-level Package      Requested   Resolved   Reason(s)   Alternative
   > NuGet.Core           2.13.0      2.13.0     Legacy
```

#### `> dotnet list package --deprecated --format json`

```json
{
  "version": 1,
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ],
  "projects": {

    "MyProjectA": [
      {
        "Path": "src/tool/MyProjectA.csproj",
        "framework": "netcoreapp3.1",
        "topLevelPackages": [
          {
            "id": "EntityFramework.MappingAPI",
            "requestedVersion": "*",
            "resolvedVersion": "6.2.1",
            "deprecationReasons": ["Legacy"],
            "alternativePackage": {
              "id": "Z.EntityFramework.Extensions",
              "versionRange": "[0.0.0,)"
            }
          },
          {
            "id": "NuGet.Core",
            "requestedVersion": "2.13.0",
            "resolvedVersion": "2.13.0",
            "deprecationReasons": ["Legacy"],
          }
        ]
      }
    ],
    "MyProjectB": [
      {
        "Path": "src/lib/MyProjectB.csproj",
        "framework": "netcoreapp3.1",
        "topLevelPackages": [
          {
            "id": "NuGet.Core",
            "requestedVersion": "2.13.0",
            "resolvedVersion": "2.13.0",
            "deprecationReasons": ["Legacy"],
          }
        ]
      },
      {
        "Path": "src/lib/MyProjectB.csproj",
        "framework": "net5.0",
        "topLevelPackages": [ 
          {
            "id": "NuGet.Core",
            "requestedVersion": "2.13.0",
            "resolvedVersion": "2.13.0",
            "deprecationReasons": ["Legacy"],
          }
        ]
      }
    ]
  }
}
```

#### `> dotnet list package --vulnerable`

```dotnetcli
The following sources were used:
   https://api.nuget.org/v3/index.json
   https://apidev.nugettest.org/v3-index/index.json

Project `MyProjectA` has the following vulnerable packages
   [netcoreapp3.1]:
   Top-level Package      Requested   Resolved   Severity   Advisory URL
   > DotNetNuke.Core      6.0.0       6.0.0      High       https://github.com/advisories/GHSA-g8j6-m4p7-5rfq
                                                 Moderate   https://github.com/advisories/GHSA-v76m-f5cx-8rg4
                                                 Critical   https://github.com/advisories/GHSA-x8f7-h444-97w4
                                                 Moderate   https://github.com/advisories/GHSA-5c66-x4wm-rjfx
                                                 High       https://github.com/advisories/GHSA-x2rg-fmcv-crq5
                                                 High       https://github.com/advisories/GHSA-j3g9-6fx5-gjv7
                                                 High       https://github.com/advisories/GHSA-xx3h-j3cx-8qfj
                                                 Moderate   https://github.com/advisories/GHSA-5whq-j5qg-wjvp
   > DotNetZip            1.0.0       1.0.0      High       https://github.com/advisories/GHSA-7378-6268-4278

Project `MyProjectB` has the following vulnerable packages
   [netcoreapp3.1]:
   Top-level Package      Requested   Resolved   Severity   Advisory URL
   > DotNetNuke.Core      6.0.0       6.0.0      High       https://github.com/advisories/GHSA-g8j6-m4p7-5rfq
                                                 Moderate   https://github.com/advisories/GHSA-v76m-f5cx-8rg4
                                                 Critical   https://github.com/advisories/GHSA-x8f7-h444-97w4
                                                 Moderate   https://github.com/advisories/GHSA-5c66-x4wm-rjfx
                                                 High       https://github.com/advisories/GHSA-x2rg-fmcv-crq5
                                                 High       https://github.com/advisories/GHSA-j3g9-6fx5-gjv7
                                                 High       https://github.com/advisories/GHSA-xx3h-j3cx-8qfj
                                                 Moderate   https://github.com/advisories/GHSA-5whq-j5qg-wjvp

   [net5.0]:
   Top-level Package      Requested   Resolved   Severity   Advisory URL
   > DotNetNuke.Core      6.0.0       6.0.0      High       https://github.com/advisories/GHSA-g8j6-m4p7-5rfq
                                                 Moderate   https://github.com/advisories/GHSA-v76m-f5cx-8rg4
                                                 Critical   https://github.com/advisories/GHSA-x8f7-h444-97w4
                                                 Moderate   https://github.com/advisories/GHSA-5c66-x4wm-rjfx
                                                 High       https://github.com/advisories/GHSA-x2rg-fmcv-crq5
                                                 High       https://github.com/advisories/GHSA-j3g9-6fx5-gjv7
                                                 High       https://github.com/advisories/GHSA-xx3h-j3cx-8qfj
                                                 Moderate   https://github.com/advisories/GHSA-5whq-j5qg-wjvp
```

### `> dotnet list package --vulnerable --format json`

```json
{
  "version": 1,
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ],
  "projects": {
    "MyProjectA": [
      {
        "Path": "src/lib/MyProjectA.csproj",
        "framework": "netcoreapp3.1",
        "topLevelPackages": [
          {
            "id": "DotNetNuke.Core",
            "requestedVersion": "6.0.0",
            "resolvedVersion": "6.0.0",
            "vulnerabilities" : [
              {
                  "severity":"High",
                  "advisoryurl":"https://github.com/advisories/GHSA-g8j6-m4p7-5rfq"
              },
              {
                  "severity":"Moderate",
                  "advisoryurl":"https://github.com/advisories/GHSA-v76m-f5cx-8rg4"
              },
  ...
              ]
          }
        ]
      }
    ],
    "MyProjectB": [
      {
        "Path": "src/lib/MyProjectB.csproj",
        "framework": "netcoreapp3.1",
        "topLevelPackages": [
          {
            "id": "DotNetNuke.Core",
            "requestedVersion": "6.0.0",
            "resolvedVersion": "6.0.0",
            "vulnerabilities" : [
              {
                  "severity":"High",
                  "advisoryurl":"https://github.com/advisories/GHSA-g8j6-m4p7-5rfq"
              },
              {
                  "severity":"Moderate",
                  "advisoryurl":"https://github.com/advisories/GHSA-v76m-f5cx-8rg4"
              },
  ...
              ]
          }
        ]
      },
      {
        "Path": "src/lib/MyProjectB.csproj",
        "framework": "net5.0",
        "topLevelPackages": [ 
          {
            "id": "DotNetNuke.Core",
            "requestedVersion": "6.0.0",
            "resolvedVersion": "6.0.0",
            "vulnerabilities" : [
              {
                  "severity":"High",
                  "advisoryurl":"https://github.com/advisories/GHSA-g8j6-m4p7-5rfq"
              },
              {
                  "severity":"Moderate",
                  "advisoryurl":"https://github.com/advisories/GHSA-v76m-f5cx-8rg4"
              },
  ...
              ]
          }
        ]
      }
    ]
  }
}
```

#### `> dotnet list package --include-transitive`

```dotnetcli
Project 'MyProjectA' has the following package references
   [netcoreapp3.1]:
   Top-level Package                      Requested             Resolved
   > Microsoft.Extensions.Primitives      [1.0.0, 5.0.0]        1.0.0
   > NuGet.Commands                       4.8.0-preview3.5278   4.8.0-preview3.5278
   > Text2Xml.Lib                         [1.1.2, 2.0.0)        1.1.2

   Transitive Package                                                                   Resolved
   > Microsoft.CSharp                                                                   4.0.1
   > Microsoft.NETCore.Platforms                                                        1.1.0
   > Microsoft.NETCore.Targets                                                          1.1.0
...

Project 'MyProjectB' has the following package references
   [netcoreapp3.1]:
   Top-level Package      Requested             Resolved
   > NuGet.Commands       4.8.0-preview3.5278   4.8.0-preview3.5278
   > Text2Xml.Lib         1.1.2                 1.1.2

   Transitive Package                                                                   Resolved
   > Microsoft.CSharp                                                                   4.0.1
   > Microsoft.NETCore.Platforms                                                        1.1.0
   > Microsoft.NETCore.Targets                                                          1.1.0
   > Microsoft.Win32.Primitives                                                         4.3.0
...

   [net5.0]:
   Top-level Package      Requested             Resolved
   > NuGet.Commands       4.8.0-preview3.5278   4.8.0-preview3.5278
   > Text2Xml.Lib         1.1.2                 1.1.2

   Transitive Package                                                                   Resolved
   > Microsoft.CSharp                                                                   4.0.1
   > Microsoft.NETCore.Platforms                                                        1.1.0
   > Microsoft.NETCore.Targets                                                          1.1.0
...

```

#### `> dotnet list package --include-transitive --format json`

```json
{
  "version": 1,
  "projects": {
    "MyProjectA": [
      {
        "Path": "src/lib/MyProjectA.csproj",
        "framework": "netcoreapp3.1",
        "topLevelPackages": [
          {
            "id": "Microsoft.Extensions.Primitives",
            "requestedVersion": "[1.0.0, 5.0.0]",
            "resolvedVersion": "1.0.0"
          },
          {
            "id": "NuGet.Commands",
            "requestedVersion": "4.8.0-preview3.5278",
            "resolvedVersion": "4.8.0-preview3.5278"
          },
          {
            "id": "Text2Xml.Lib",
            "requestedVersion": "[1.1.2, 2.0.0)",
            "resolvedVersion": "1.1.2"
          }
        ],
        "transitivePackages": [
          {
            "id": "Microsoft.CSharp",
            "resolvedVersion": "4.0.1"
          },
          {
            "id": "Microsoft.NETCore.Platforms",
            "resolvedVersion": "1.1.0"
          },
  ...
        ]
      }
    ],
    "MyProjectB": [
      {
        "Path": "src/lib/MyProjectB.csproj",
        "framework": "netcoreapp3.1",
        "topLevelPackages": [
          {
            "id": "NuGet.Commands",
            "requestedVersion": "4.8.0-preview3.5278",
            "resolvedVersion": "4.8.0-preview3.5278"
          },
          {
            "id": "Text2Xml.Lib",
            "requestedVersion": "1.1.2",
            "resolvedVersion": "1.1.2"
          }
        ],
        "transitivePackages": [
          {
            "id": "Microsoft.CSharp",
            "resolvedVersion": "4.0.1"
          },
          {
            "id": "Microsoft.NETCore.Platforms",
            "resolvedVersion": "1.1.0"
          },
  ...
        ]
      },
      {
        "Path": "src/lib/MyProjectB.csproj",
        "framework": "net5.0",
        "topLevelPackages": [ 
          {
            "id": "NuGet.Commands",
            "requestedVersion": "4.8.0-preview3.5278",
            "resolvedVersion": "4.8.0-preview3.5278"
          },
          {
            "id": "Text2Xml.Lib",
            "requestedVersion": "1.1.2",
            "resolvedVersion": "1.1.2"
          }
        ],
        "transitivePackages": [
          {
            "id": "Microsoft.CSharp",
            "resolvedVersion": "4.0.1"
          },
          {
            "id": "Microsoft.NETCore.Platforms",
            "resolvedVersion": "1.1.0"
          },
  ...
        ]
      }
    ]
  }
}
```

## Compatibility

 We start with `version 1`, as long as we don't remove or rename then it'll be backward compatible. In case [we change version](https://stackoverflow.com/a/13945074) just add new properties, keep old ones even it's not used.

## Out-of-scope

* We won't support saving the machine-readable output to disk as part of this spec. The work-around is for the consumer to read from the console's stdout stream.
* At this point, no other CLI commands (e.g. dotnet list reference) will be within scope for this feature.
"--parsable" option needs separate spec.
* Currently license info is not emitted from any cli command, it could be quite useful, we should consider in the future.

## Rationale and alternatives
Currently, no other `dotnet command` implemented this, this is the 1st time dotnet command implementing `json`(etc) output, so it could become example for others next time they implement.
Please note, except "tab completion" (for dotnet) part all changes would be inside NuGet.Client repo(under NuGet.Core), and risk of introducing regression is low.(`--format text` refactoring related changes only come into my mind.), no impact on dotnet sdk.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevent to this proposal? -->

* https://github.com/NuGet/Home/blob/dotnet-audit/proposed/2021/DotNetAudit.md#dotnet-audit---futjson There're some overlaps, but current spec is one more focused on SBOM and CI/CD actions, while `dotnet audit fix` is more focused detecting/fixing dependencies manually. Current spec already include ideas from this spec like `json format`.

* https://github.com/NuGet/Home/wiki/%5BSpec%5D-Machine-readable-output-for-dotnet-list-package Basic idea from this spec is still same here and I extended from it. In current spec more orient to `dotnet style syntax` and cover more uses cases like `dotnet list package --vulnerable --format json` and `--include-transitive`, also json schema improved to include project name/identifier for multi-project scenario which would most likely use case.

* https://docs.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-counters One idea we can take from `dotnet counter` is we can specify output file with `-o`, `--output` option. So instead of writing output into console, it allows output directly saved into file. It allows both `csv` and `json` formats, currently saved file doesn't have version concept.

## Unresolved Questions

* Donnie: When I want to create archival records, will I want something more unique than the project name?
Adding the path, repo, commit ID, etc seems complex. [r766920783](https://github.com/NuGet/Home/pull/11446#discussion_r766920783)
  * `name/relative path to solution` could be solution here.

* Donnie: How can we record in the output that --include-transitive wasn't used here?
In other words, if I look at this output years from now, how would I know whether any transitives were in this project? [r766924390](https://github.com/NuGet/Home/pull/11446#discussion_r766924390)
  * packages.lock.json format could be used here.  

* Loïc : How would this format evolve if we add another "package pivot" in addition to top level and transitive packages? For example, what if we add new package kinds for source generators, Roslyn analyzers, etc...? [r767026799](https://github.com/NuGet/Home/pull/11446#discussion_r767026799)

>> Out of scope from MVP, this schema can evolve over time, by the time we have necessity to do change we can make more educated decision.

* Could we use existing packages.lock.json format? [sample](https://gist.github.com/erdembayar/4894b66bde227147b60e60997d20df41)
  * Direct/top level packages point to dependency packages.
  * Content hash. >> out of scope for now. Tracking issue https://github.com/NuGet/Home/issues/11552

## Future Possibilities

* Show resolution tree for transitive dependencies and constraint for dependency [resolved version](https://github.com/NuGet/Home/pull/11446/files#r777233006), tracking issue: https://github.com/NuGet/Home/issues/11553

* Return different exit codes if any vulnerabilities, deprecations, outdated package is [detected](https://github.com/NuGet/Home/blob/dotnet-audit/proposed/2021/DotNetAudit.md#dotnet-audit-exit-codes).

* `--all` option for dotnet list package [r766860629](https://github.com/NuGet/Home/pull/11446#discussion_r766860629), tracking issue https://github.com/NuGet/Home/issues/11551

* Include-transitive dependencies by default [r766924390](https://github.com/NuGet/Home/pull/11446#discussion_r766924390), tracking issue https://github.com/NuGet/Home/issues/11550

* Include hash + source for package, because same package ID+version might have different hash. It can be used to detect [dependency confusion attack](https://github.com/NuGet/Home/pull/11446#discussion_r767030495), tracking issue: https://github.com/NuGet/Home/issues/11552