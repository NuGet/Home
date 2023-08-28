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

Ability to use new `--format` option for all `dotnet list package` commands to ensure formatted(json, text) output is emitted to the console.

```dotnetcli
dotnet list [<PROJECT>|<SOLUTION>] package [--config <SOURCE>]
    [--deprecated]
    [--framework <FRAMEWORK>] [--highest-minor] [--highest-patch]
    [--include-prerelease] [--include-transitive] [--interactive]
    [--outdated] [--source <SOURCE>] [-v|--verbosity <LEVEL>]
    [--vulnerable]
    [--format <FORMAT>]
    [--output-version <VERSION>]
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
  "parameters": "",
  "projects": [
    {
      "path": "src/lib/MyProjectA.csproj",
      "frameworks": [
        {
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
      ]
    },
    {
      "path": "src/lib/MyProjectB.csproj",
      "frameworks": [
        {
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
  ]
}
```

#### `> dotnet list package`
Project with an auto-referenced package.

```dotnetcli
Project 'MyProjectF' has the following package references
   [netstandard2.0]:
   Top-level Package             Requested   Resolved
   > NETStandard.Library   (A)   [2.0.3, )   2.0.3

(A) : Auto-referenced package.
```

#### `> dotnet list package --format json`
Project with an auto-referenced package.

```json
{
  "version": 1,
  "parameters": "",
  "projects": [
    {
      "path": "src/lib/MyProjectF.csproj",
      "frameworks": [
        {
          "framework": "netstandard2.0",
          "topLevelPackages": [
            {
              "id": "NETStandard.Library",
              "requestedVersion": "[2.0.3, )",
              "resolvedVersion": "2.0.3",
              "autoReferenced": "true"
            }
          ]
        }
      ]
    }
  ]
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
  "parameters": "--outdated",
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ],
  "projects": [
    {
      "path": "src/lib/MyProjectA.csproj",
      "frameworks": [
        {
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
      ]
    },
    {
      "path": "src/lib/MyProjectB.csproj",
      "frameworks": [
        {
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
  ]
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
  "parameters": "--deprecated",
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ],
  "projects": [
    {
      "path": "src/lib/MyProjectA.csproj",
      "frameworks": [
        {
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
      ]
    },
    {
      "path": "src/lib/MyProjectB.csproj",
      "frameworks": [
        {
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
  ]
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
  "parameters": "--vulnerable",
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ],
  "projects": [
    {
      "path": "src/lib/MyProjectA.csproj",
      "frameworks": [
        {
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
      ]
    },
    {
      "path": "src/lib/MyProjectB.csproj",
      "frameworks": [
        {
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
  ]
}
```

#### `> dotnet list package --vulnerable`
There's no vulnerable package in a project.

```dotnetcli
The following sources were used:
   https://api.nuget.org/v3/index.json
   https://apidev.nugettest.org/v3-index/index.json

The given project `MyProjectC` has no vulnerable packages given the current sources.
```

### `> dotnet list package --vulnerable --format json`
There's no vulnerable package in a project.

```json
{
  "version": 1,
  "parameters": "--vulnerable",
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ],
  "projects": [
    {
      "path": "src/lib/MyProjectC.csproj",
      "frameworks": [
        {
          "framework": "netcoreapp3.1",
          "topLevelPackages": [
            ]
        },
        {
          "framework": "net5.0",
          "topLevelPackages": [
            ]
        }
      ]
    }
  ]
}
```

#### `> dotnet list package --vulnerable`
For multi-target framework a project only 1 framework has a vulnerability.

```dotnetcli
The following sources were used:
   https://api.nuget.org/v3/index.json
   https://apidev.nugettest.org/v3-index/index.json

Project `MyProjectC` has the following vulnerable packages
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

   [net5.0]: No vulnerable packages for this framework.
```

### `> dotnet list package --vulnerable --format json`
For multi-target framework a project only 1 framework has a vulnerability.

```json
{
  "version": 1,
  "parameters": "--vulnerable",
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ],
  "projects": [
    {
      "path": "src/lib/MyProjectC.csproj",
      "frameworks": [
        {
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
          "framework": "net5.0",
          "topLevelPackages": [
           ]
        }
      ]
    }
  ]
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
  "parameters": "--include-transitive",
  "projects": [
    {
      "path": "src/lib/MyProjectA.csproj",
      "frameworks": [
        {
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
      ]
    },
    {
      "path": "src/lib/MyProjectB.csproj",
      "frameworks": [
        {
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
  ]
}
```


#### `> dotnet list package --include-transitive --outdated --framework net5.0`

```dotnetcli
The following sources were used:
   https://api.nuget.org/v3/index.json
   https://apidev.nugettest.org/v3-index/index.json

No packages were found for the project `MyProjectA` given the specified frameworks.
Project `MyProjectB` has the following updates to its packages
   [net5.0]:
   Top-level Package      Requested             Resolved              Latest
   > NuGet.Commands       4.8.0-preview3.5278   4.8.0-preview3.5278   6.0.0
   > Text2Xml.Lib         1.1.2                 1.1.2                 1.1.4

   Transitive Package                                                                   Resolved              Latest
   > Microsoft.CSharp                                                                   4.0.1                 4.7.0
   > Microsoft.NETCore.Platforms                                                        1.1.0                 6.0.1
   > Microsoft.NETCore.Targets                                                          1.1.0                 5.0.0
```

#### `> dotnet list package --include-transitive --outdated --framework net5.0 --format json`

```json
{
  "version": 1,
  "parameters": "-include-transitive --outdated --framework net5.0",
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ],
  "projects": [
    {
      "path": "src/lib/MyProjectA.csproj",
      "frameworks": [
      ]
    },
    {
      "path": "src/lib/MyProjectB.csproj",
      "frameworks": [
        {
          "framework": "net5.0",
          "topLevelPackages": [ 
              {
                "id": "NuGet.Commands",
                "requestedVersion": "4.8.0-preview3.5278",
                "resolvedVersion": "4.8.0-preview3.5278",
                "latestVersion": "6.0.0",
              },
              {
                "id": "Text2Xml.Lib",
                "requestedVersion": "1.1.2",
                "resolvedVersion": "1.1.2",
                "latestVersion": "1.1.4",
              }
            ],
            "transitivePackages": [
              {
                "id": "Microsoft.CSharp",
                "resolvedVersion": "4.0.1",
                "latestVersion": "4.7.0",
              }
      ...
            ]
        }
      ]
    }
  ]
}
```

#### `> dotnet list package --include-transitive --deprecated --framework net5.0`

```dotnetcli
The following sources were used:
   https://api.nuget.org/v3/index.json
   https://apidev.nugettest.org/v3-index/index.json

No packages were found for the project `MyProjectA` given the specified frameworks.
Project `MyProjectB` has the following deprecated packages
   [net5.0]:
   Top-level Package      Requested   Resolved   Reason(s)   Alternative
   > NuGet.Core           2.13.0      2.13.0     Legacy

   Transitive Package          Resolved              Reason(s)   Alternative
   > NuGet.Packaging.Core      4.8.0-preview3.5278   Legacy      NuGet.Packaging >= 0.0.0
```

#### `> dotnet list package --include-transitive --deprecated --framework net5.0 --format json`

```json
{
  "version": 1,
  "parameters": "-include-transitive --outdated --framework net5.0",
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ],
  "projects": [
    {
      "path": "src/lib/MyProjectA.csproj",
      "frameworks": [
      ]
    },
    {
      "path": "src/lib/MyProjectB.csproj",
      "frameworks": [
        {
          "framework": "net5.0",
          "topLevelPackages": [ 
              {
                "id": "NuGet.Core",
                "requestedVersion": "2.13.0",
                "resolvedVersion": "2.13.0",
                "deprecationReasons": ["Legacy"]
              }
            ],
            "transitivePackages": [
              {
                "id": "Microsoft.CSharp",
                "resolvedVersion": "4.0.1",
                "deprecationReasons": ["Legacy"],
                "alternativePackage": {
                  "id": "NuGet.Packaging",
                  "versionRange": "[0.0.0,)"
                }
              }
      ...
            ]
        }
      ]
    }
  ]
}
```

#### `> dotnet list package --vulnerable --include-transitive`
For multi-target framework a project only 1 framework has a vulnerability.

```dotnetcli
The following sources were used:
   https://api.nuget.org/v3/index.json

Project `MyProjectE` has the following vulnerable packages
   [netcoreapp3.1]:
   Top-level Package      Requested             Resolved              Severity   Advisory URL
   > DotNetNuke.Core      6.0.0                 6.0.0                 High       https://github.com/advisories/GHSA-g8j6-m4p7-5rfq
                                                                      Moderate   https://github.com/advisories/GHSA-v76m-f5cx-8rg4
                                                                      Critical   https://github.com/advisories/GHSA-x8f7-h444-97w4
                                                                      Moderate   https://github.com/advisories/GHSA-5c66-x4wm-rjfx
                                                                      High       https://github.com/advisories/GHSA-x2rg-fmcv-crq5
                                                                      High       https://github.com/advisories/GHSA-j3g9-6fx5-gjv7
                                                                      High       https://github.com/advisories/GHSA-xx3h-j3cx-8qfj
                                                                      Moderate   https://github.com/advisories/GHSA-5whq-j5qg-wjvp
   > NuGet.Commands       4.8.0-preview3.5278   4.8.0-preview3.5278   Moderate   https://github.com/advisories/GHSA-3885-8gqc-3wpf

   Transitive Package                    Resolved   Severity   Advisory URL
   > Newtonsoft.Json                     9.0.1      High       https://github.com/advisories/GHSA-5crp-9r3c-p9vr
   > System.Net.Http                     4.3.0      High       https://github.com/advisories/GHSA-7jgj-8wvc-jh57
   > System.Text.RegularExpressions      4.3.0      Moderate   https://github.com/advisories/GHSA-cmhx-cq75-c4mj
```

### `> dotnet list package --vulnerable --include-transitive --format json`
For multi-target framework a project only 1 framework has a vulnerability.

```json
{
  "version": 1,
  "parameters": "--vulnerable",
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ],
  "projects": [
    {
      "path": "src/lib/MyProjectC.csproj",
      "frameworks": [
        {
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
            ],
            "transitivePackages": [
              {
                "id": "Newtonsoft.Json",
                "resolvedVersion": "9.0.1",
                "vulnerabilities" : [
                  {
                      "severity":"High",
                      "advisoryurl":"https://github.com/advisories/GHSA-5crp-9r3c-p9vr"
                  }
                ]
              },
              {
                "id": "System.Net.Http",
                "resolvedVersion": "4.3.0",
                "vulnerabilities" : [
                  {
                      "severity":"High",
                      "advisoryurl":"https://github.com/advisories/GHSA-7jgj-8wvc-jh57"
                  }
                ]
              }
      ...
            ]
        },
        {
          "framework": "net5.0",
          "topLevelPackages": [
           ]
        }
      ]
    }
  ]
}
```

#### `> dotnet list package --format json --output-version 1`

Outputs json for format version 1, if it's not specified then latest version'll be used by default.

```json
{
  "version": 1,
  "parameters": "",
  "projects": [
    {
      "path": "src/lib/MyProjectA.csproj",
      ...
    }
  ]
}
```

### Error/Warning handling

In case of an `error` it would be written into `problems` section and return non-0 error exit code if there is any `error` to indicate there had been some error to help scripting use case. Note: `Warnings` in `problems` section are not considered as `error`.

| # | Scenario | Behavior in dotnet cli | Exit code
|---|---|---|---|
| 1 | Missing .net sdk/runtime installion| No json output, show missing .net sdk/runtime installation error in console | ?
| 1 | Runtime error | No json output, because it needs all the data for json output, normal error stack output in console| 1
| 1 | Parameter/options typo error | May defaults back to console output instead of json output, for example: `dotnet list package -include-transitive --format json` (here `-include-transitive` is missing another `-` in front), because that option/parameter validation for `-include-transitive` happen way before `list package` code execution | 1
| 1 | Passing unsupported targetframe | `dotnet list package -framework net9.0` wouldn't fail even though `net9.0` is not valid framework at this moment, it would simply return empty result.  | 0
| 1 | Asset file missing | Error would be in problems section of json, see below. | 1
| 1 | Non-existing csproj file path | Error would be in problems section of json, see below. | 1
| 1 | Package.config project | Error would be in problems section of json, see below. | 1
| 1 | Incompatible option combination | Warning would be in problems section of json, see below. | 0
| 1 | Use of not secure http source | Warning would be in problems section of json, see below. | 0
| 1 | Unsupported output format | Defaults back to console output, for example: `dotnet list package --format yaml` | 1
| 1 | Unsupported output version | if it's for json output then no json output, error out unsupported output version , see below | 1
| 1 | Unsupported output version | if it's for console output then error out unsupported output version , see below | 1

#### `> dotnet list package`

`MyProjectB.csproj` was not restored.

```dotnetcli
Project 'MyProjectA' has the following package references
   [netcoreapp3.1]:
   Top-level Package                      Requested             Resolved
   > Microsoft.Extensions.Primitives      [1.0.0, 5.0.0]        1.0.0
   > NuGet.Commands                       4.8.0-preview3.5278   4.8.0-preview3.5278
   > Text2Xml.Lib                         [1.1.2, 2.0.0)        1.1.2

No assets file was found for `C:\Users\userA\repos\MainApp\src\lib\MyProjectB.csproj`. Please run restore before running this command.
```

#### `> dotnet list package --format json`

```json
{
  "version": 1,
  "parameters": "",
  "problems": [
    {
        "level" : "error",
        "project": "src/lib/MyProjectB.csproj",
        "text": "No assets file was found for `C:/Users/userA/repos/MainApp/src/lib/MyProjectB.csproj`. Please run restore before running this command."
    }
  ],
  "projects": [
    {
      "path": "src/lib/MyProjectA.csproj",
      "frameworks": [
        {
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
      ]
    }
  ]
}
```

#### `> dotnet list NonExisting.csproj package`

`NonExisting.csproj` doesn't exist or wrong path.

```dotnetcli
Could not find file or directory 'C:\Users\userA\repos\MainApp\src\lib\NonExisting.csproj'.
```

#### `> dotnet list package --format json`

```json
{
  "version": 1,
  "parameters": "",
  "problems": [
    {
        "level" : "error",
        "project": "src/lib/NonExisting.csproj",
        "text": "Could not find file or directory 'C:/Users/userA/repos/MainApp/src/lib/NonExisting.csproj'"
    }
  ]
}
```

#### `> dotnet list package`

`MyProjectB` is package.config type project, so it's not supported.

```dotnetcli
Project 'MyProjectA' has the following package references
   [netcoreapp3.1]:
   Top-level Package                      Requested             Resolved
   > Microsoft.Extensions.Primitives      [1.0.0, 5.0.0]        1.0.0
   > NuGet.Commands                       4.8.0-preview3.5278   4.8.0-preview3.5278
   > Text2Xml.Lib                         [1.1.2, 2.0.0)        1.1.2

The project `C:\Users\userA\repos\MainApp\src\lib\MyProjectB.csproj` uses package.config for NuGet packages, while the command works only with package reference projects.
```

#### `> dotnet list package --format json`

```json
{
  "version": 1,
  "parameters": "",
  "problems": [
    {
        "level" : "error",
        "project": "src/lib/MyProjectB.csproj",
        "text": "The project `C:/Users/userA/repos/MainApp/src/lib/MyProjectB.csproj`` uses package.config for NuGet packages, while the command works only with package reference projects."
    }
  ],
  "projects": [
    {
      "path": "src/lib/MyProjectA.csproj",
      "frameworks": [
        {
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
      ]
    }
  ]
}
```

#### `> dotnet list package --highest-minor`

Given '--include-prerelease', '--highest-minor', and '--highest-patch' options are only designed to use together with `--outdated` argument it would output `The command option(s) '--include-prerelease', '--highest-minor', and '--highest-patch' are ignored by this command.` warning.

```dotnetcli
The command option(s) '--include-prerelease', '--highest-minor', and '--highest-patch' are ignored by this command.
Project 'MyProjectC' has the following package references
   [netcoreapp3.1]:
   Top-level Package      Requested   Resolved
   > DotNetNuke.Core      6.0.0       6.0.0
   > Newtonsoft.Json      13.0.1      13.0.1

   [net5.0]: No packages were found for this framework.
```

#### `> dotnet list package --highest-minor --format json`

Json output for above case.

```json
{
  "version": 1,
  "parameters": "--highest-minor",
  "problems": [
    {
        "level" : "warning",
        "text": "The command option(s) '--include-prerelease', '--highest-minor', and '--highest-patch' are ignored by this command."
    }
  ],
  "projects": [
  ]
}
```

#### `> dotnet list package --vulnerable`

Warning for `Http source used` in printed.

```dotnetcli
The following sources were used:
   http://apidev.nugettest.org/v3-index/index.json

warn : You are running the 'list package' operation with an 'HTTP' source, 'nugettest [http://apidev.nugettest.org/v3-index/index.json]'. Non-HTTPS access will be removed in a future version. Consider migrating to an 'HTTPS' source.
```

#### `> dotnet list package --vulnerable --format json`

Warning for `Http source used` is included in json.

```json
{
  "version": 1,
  "parameters": "--vulnerable",
  "problems": [
    {
      "level" : "warning",
      "text": "You are running the 'list package' operation with an 'HTTP' source, 'nugettest [http://apidev.nugettest.org/v3-index/index.json]'. Non-HTTPS access will be removed in a future version. Consider migrating to an 'HTTPS' source."
    }
  ],
  "projects": [
  ]
}
```

#### `> dotnet list package --format yaml`

Output format yaml is not supported, error out.

```dotnetcli
error: Invalid value yaml provided for output format. The accepted values are console, json.
```

#### `> dotnet list package --format json --output-version 3`

Output version `3` is not supported, error out instead of defaulting to any version, because defaulting to any version might give false negative which hides actual serious issue in report details.

```dotnetcli
error: Unsupported output format version 3 was requested.  The accepted format version value is 1.
```

#### `> dotnet list package --format console --output-version 3`

Output version `3` is not supported, error out instead of defaulting to any version, because defaulting to any version might give false negative which hides actual serious issue in report details.

```dotnetcli
error: Unsupported output format version 3 was requested.  The accepted format version value is 1.
```

## Compatibility

We start with `version 1`, as long as we don't remove or rename then it'll be backward compatible. In case [we change version](https://stackoverflow.com/a/13945074) just add new properties, keep old ones even it's not used.
By default `--format json` will output latest schema version of json, but we can set older version of output like `--output-version 1`, intention behind is we don't want to customer CI build script because sdk/nuget version is upgraded and keep it predictable.

## Out-of-scope

* Saving the output to disk.
* Any other additions, such as --parsable.
* Include license information [#11563)](https://github.com/NuGet/Home/issues/11563).

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

* https://github.com/NuGet/Home/wiki/Enable-repeatable-package-restore-using-lock-file It's very similar what we're doing here, and it has schema versioning. [sample](https://gist.github.com/erdembayar/4894b66bde227147b60e60997d20df41) Only major difference is json object are grouped under TFM unlike `dotnet list package` where items are grouped under projects. Below are possible takeaways.
  * Direct/top level packages point to dependency packages. >> Could be included, down side is duplicate information, increase json size. Also I feel https://github.com/NuGet/Home/issues/11553 addresses this issue better, because in the end who transitive dependency brought in is more important than what dependencies exist under each top package.
  * Content hash. >> It's very easy to include it, question is how about source? Related issue https://github.com/NuGet/Home/issues/11552

* [npm ls --json](https://gist.github.com/erdembayar/ddfbf9c160fbb8a0e31e3596f03ee906), [npm outdated -json](https://gist.github.com/erdembayar/12030f1db89ad9f2e206f2b6ff7d740f) Actually it's less sophisticated than what we have, because it doesn't have multi TFM and projects concept. In case of any error it adds it into `problems` section just as array of strings.

## Future Possibilities

If we address them in plain `dotnet list package` then we'll address in `json output` too.

* [Include source info for all  options](https://github.com/NuGet/Home/issues/11556).

* [Include hash + source for package](https://github.com/NuGet/Home/issues/11552), because same package ID+version might have different hash. It can be used to detect dependency confusion attack. Please note existing feature `lock files` is more appropriate for this.

* [Some outputs include source info](https://github.com/NuGet/Home/issues/11557). Maybe we should include package source mapping info into sources.

* [Show resolution tree for transitive dependencies](https://github.com/NuGet/Home/issues/11553) and constraint for dependency resolved version.

* [Include-transitive dependencies](https://github.com/NuGet/Home/issues/11550) by default, workaround pass `--include-transitive`.

* [--all option](https://github.com/NuGet/Home/issues/11551) for dotnet list package.

* Return [different exit codes](https://tldp.org/LDP/abs/html/exitcodes.html) if there is any error while rendering json output or if any vulnerabilities, deprecations, outdated package is [detected](https://github.com/NuGet/Home/blob/dotnet-audit/proposed/2021/DotNetAudit.md#dotnet-audit-exit-codes). It's important choose to the exit codes and provide easy ways to look up docs on each error code (see [example](https://github.com/dotnet/templating/blob/main/docs/Exit-Codes.md#106)). We could enhance `problems` section to include `errorCode` for easy lookup later.
