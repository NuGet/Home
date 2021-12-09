# Machine readable JSON output for dotnet list package

* Status: **In Review**
* Author: [Erick Yondon](https://github.com/erdembayar)
* GitHub Issue [7752](https://github.com/NuGet/Home/issues/7752)

## Problem background
<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Many organization are required by [regulation](https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/) to audit packages that they're using in repository.
Currently there's no easy way produce Software Bill of Material (SBOM) output which can be consumed by another auditing system or historic keeping.

* Parse-friendly output. Other PMP like Npm already have it(`npm ls --parseable` and `npm ls --json`).
* Useful for CI/CD auditing(compliance, security ..)
  * Produce Software Bill of Material (SBOM) (compliance, historic keeping)
  * Enhancing Software Supply Chain Security
    * check any vulnerable packages
    * check any deprecated packages
    * Check any outdated packages
  * Check license compliance
  * Resolve dependency issue (detect duplicate packages, detect new dependency introduced or existing one removed etc ..)
  * Making the output machine-readable unlocks additional tooling and automation scenarios in CI/CD pipeline above scenarios.

## Who are the customers

Anyone (government/private enterprises, security experts, individual contributors) who wants to consume `dotnet list package` output for auditing tool or historic keeping, CI/CD orchestrating.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

### --json option

Ability to use new `--json` option for all `dotnet list package` commands to ensure JSON-formatted output is emitted to the console.

```dotnetcli
dotnet list [<PROJECT>|<SOLUTION>] package [--config <SOURCE>]
    [--deprecated]
    [--framework <FRAMEWORK>] [--highest-minor] [--highest-patch]
    [--include-prerelease] [--include-transitive] [--interactive]
    [--outdated] [--source <SOURCE>] [-v|--verbosity <LEVEL>]
    [--vulnerable]
    [--json]

dotnet list package -h|--help
```

### dotnet list package

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

### dotnet list package --json

```json
{
  "version": 1,
  "MyProjectA": [
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
  ],
  "MyProjectB": [
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
```

### dotnet list package --outdated

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

### dotnet list package --outdated --json

```json
{
  "version": 1,
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ], 
  "MyProjectA": [
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
  ],
  "MyProjectB": [
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
```

### dotnet list package --deprecated

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

### dotnet list package --deprecated --json

```json
{
  "version": 1,
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ],
  "MyProjectA": [
    {
      "framework": "netcoreapp3.1",
      "topLevelPackages": [
        {
          "id": "EntityFramework.MappingAPI",
          "requestedVersion": "*",
          "resolvedVersion": "6.2.1",
          "reasons": ["Legacy"],
          "alternativePackage": {
            "id": "Z.EntityFramework.Extensions",
            "versionRange": "[0.0.0,)"
          }
        },
        {
          "id": "NuGet.Core",
          "requestedVersion": "2.13.0",
          "resolvedVersion": "2.13.0",
          "reasons": ["Legacy"],
          "alternativePackage": null
        }
      ]
    }
  ],
  "MyProjectB": [
    {
      "framework": "netcoreapp3.1",
      "topLevelPackages": [
        {
          "id": "NuGet.Core",
          "requestedVersion": "2.13.0",
          "resolvedVersion": "2.13.0",
          "reasons": ["Legacy"],
          "alternativePackage": null
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
          "reasons": ["Legacy"],
          "alternativePackage": null
        }
      ]
    }
  ]
}
```

### dotnet list package --vulnerable

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

### dotnet list package --vulnerable --json

```json
{
  "version": 1,
   "sources": [
    "https://api.nuget.org/v3/index.json",
    "https://apidev.nugettest.org/v3-index/index.json"
  ],
  "MyProjectA": [
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
  ],
  "MyProjectB": [
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
```

### dotnet list package --include-transitive

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

### dotnet list package --include-transitive --json

```json
{
  "version": 1,
  "MyProjectA": [
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
  ],
  "MyProjectB": [
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
```

### --flatten option

Ability to use new `--flatten` option conjunction with `--json` option for all `dotnet list package` commands to ensure JSON-formatted output is emitted to the console for multiproject solution(including multitarget projects)and all projects and target frameworks are flattened. Same package with multiple version entry is possible. It's useful more for SBOM than single `--json` option.

```dotnetcli
dotnet list [<PROJECT>|<SOLUTION>] package [--config <SOURCE>]
    [--deprecated]
    [--framework <FRAMEWORK>] [--highest-minor] [--highest-patch]
    [--include-prerelease] [--include-transitive] [--interactive]
    [--outdated] [--source <SOURCE>] [-v|--verbosity <LEVEL>]
    [--vulnerable]
    [--json]
    [--flatten]

dotnet list package -h|--help
```

### dotnet list package

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

### dotnet list package --json --flatten

```json
{
  "version": 1,
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
```

### dotnet list package --deprecated

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

### dotnet list package --deprecated --json --flatten

```json
{
  "version": 1,
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
```

### dotnet list package --include-transitive

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

### dotnet list package --include-transitive --json --flatten

```json
{
  "version": 1,
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
        {
            "id": "Microsoft.NETCore.Targets",
            "resolvedVersion": "1.1.0"
        }
...
    ]
}
```

### Compatibility

 We start with `version 1`, as long as we don't remove or rename then it'll be backward compatible. In case [we change version](https://stackoverflow.com/a/13945074) just add new properties, keep old ones even it's not used.

### Out-of-scope

* To avoid disk I/O, we won't support saving the machine-readable output to disk as part of this spec. The work-around is for the consumer to read from the console's stdout stream.
* At this point, no other CLI commands (e.g. dotnet list reference) will be within scope for this feature.
"--parsable" option needs separate spec.
* Currently license info is not emitted from any cli command, it could be quite useful, we should consider in the future.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevent to this proposal? -->

* https://github.com/NuGet/Home/blob/dotnet-audit/proposed/2021/DotNetAudit.md#dotnet-audit---json

* https://github.com/NuGet/Home/wiki/%5BSpec%5D-Machine-readable-output-for-dotnet-list-package
