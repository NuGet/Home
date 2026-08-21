# Implementing NuGet.Client CLI Sponsorship Support

- Author: [@kalebfik](https://github.com/kalebfik)
- GitHub Issue: [NuGet/NuGetGallery#10703](https://github.com/NuGet/NuGetGallery/issues/10703)
- [Accompanying Funcational Spec](https://github.com/NuGet/Home/blob/dev-kalebfika-sponsorCliSpec/accepted/2026/sponsorship-cli.md)

## Summary

Add sponsorship reporting to the NuGet CLI for installed packages.

The command surface will be presented as `dotnet package list --sponsor`.

It will reuse the same metadata-fetch and rendering pipeline, with:

- A `Sponsor` column in console output.
- A `sponsorablePackages` array in JSON output.

## Explanation

### Functional Explanation

When a user runs `dotnet package list --sponsor`, the CLI will examine the projects' or solutions' packages and retrieve sponsorship links from the selected package sources.
The results are then grouped by the source that provided the sponsorship details.
For packages returned from a source, URLs preserve the order returned by that source.

Sponsorship details are read from the proposed `sponsorshipUrls` property within `metadata` in each source's Registration response.
Each selected source will contribute the sponsorship details that reflect its own Registration API; the client does not assume that the property propagates through upstream sources.

The command selects enabled package sources from NuGet configuration.
When a source is specified using `--source <SOURCE>`, only that source is queried for sponsorship information.
A successful Registration response with a missing or empty `sponsorshipUrls` field is treated as a successful empty result.

Console output includes only sources that return one or more sponsorship URLs.
If none of the selected sources return sponsorship details for a project, the CLI displays:

```text
//sample response
No sponsorship details were returned using the following package sources:
  https://api.example.org/v3/index.json

Consider specifying another package source with `--source <SOURCE>`.
```

A source that does not support sponsorships will have a separate message:

```text
These sources do not provide sponsorship support:
  https://packages.contoso.com/v3/index.json
```

The JSON output includes every selected source for each project. 
For sources that return no sponsorship details, the `sponsorablePackages` field remains empty as such: 

```json
{
  "version": 1,
  "parameters": "--sponsor --format json",
  "problems": [
    {
      "project": "/path/to/Contoso.App.csproj",
      "level": "warning",
      "text": "No sponsorship details were returned by https://api.example.org/v3/index.json"
    },
    {
      "project": "/path/to/Contoso.App.csproj",
      "level": "warning",
      "text": "This source does not provide sponsorship support: https://packages.contoso.com/v3/index.json"
    }
  ],
  "projects": [
    {
      "path": "/path/to/Contoso.App.csproj",
      "sources": [
        {
          "source": "https://api.example.org/v3/index.json",
          "sponsorablePackages": []
        },
        {
          "source": "https://packages.contoso.com/v3/index.json",
          "sponsorablePackages": []
        }
      ]
    }
  ]
}
```

The default console output will add a `Sponsor` column.
Within the `Sponsor` column, each source that returns a sponsorship URL is identified using a `Source:` label, followed by the sponsorship links.
URLs preserve the order returned by each source.
Sources that return no sponsorship URLs are omitted from the CLI output.

`dotnet package list --sponsor` output:

```text
Top-level Package        Sponsor
> Contoso.Tools          Source: https://api.example.org/v3/index.json
                           https://github.com/sponsors/contoso

> Contoso.Utility        Source: https://api.example.org/v3/index.json
                           https://github.com/sponsors/contoso
                         Source: https://www.myget.org/F/contoso/api/v3/index.json
                           https://buymeacoffee.com/contoso
```

When using `--format json`, those same packages are returned in JSON format, grouped first by their project and then by their source.
Each source contains its `sponsorablePackages`.
Sources that return no sponsorship details are still present in the JSON but are left empty with a warning.

`dotnet package list --sponsor --format json` output:

```json
{
  "version": 1,
  "parameters": "--sponsor --format json",
  "problems": [
    {
      "project": "/path/to/Contoso.App.csproj",
      "level": "warning",
      "text": "No sponsorship details were returned by https://packages.contoso.com/v3/index.json."
    }
  ],
  "projects": [
    {
      "path": "/path/to/Contoso.App.csproj",
      "sources": [
        {
          "source": "https://api.example.org/v3/index.json",
          "sponsorablePackages": [
            {
              "id": "Contoso.Tools",
              "urls": [
                "https://github.com/sponsors/contoso"
              ]
            },
            {
              "id": "Contoso.Utility",
              "urls": [
                "https://github.com/sponsors/contoso"
              ]
            }
          ]
        },
        {
          "source": "https://www.myget.org/F/contoso/api/v3/index.json",
          "sponsorablePackages": [
            {
              "id": "Contoso.Utility",
              "urls": [
                "https://buymeacoffee.com/contoso"
              ]
            }
          ]
        },
        {
          "source": "https://packages.contoso.com/v3/index.json",
          "sponsorablePackages": []
        }
      ]
    }
  ]
}
```

**Package Source Mapping and using `--source`**

Registration requests may disclose package IDs to package sources; therefore, sponsorship reporting will honor Package Source Mapping (PSM).
When PSM is disabled, each package is queried against all configured sources.
When PSM is enabled, the client queries only sources that are mapped to that package.

The command displays an informational message when using the command with PSM enabled:

```text
Package Source Mapping is enabled. Sponsorship details will be requested from sources mapped to packages.
```

Users will encounter an error if PSM is combined with `--source`.
The command stops before making any sponsorship requests, and the CLI will produce an error message:

```text
Package Source Mapping is enabled and cannot be combined with `--source` for sponsorship reporting.
```

A mapped source that is successfully queried but returns an empty `sponsorshipUrls` property produces the same empty-source behavior present in the JSON above.
This includes sources that do not propagate sponsorship metadata from an upstream source.

### Technical explanation

`dotnet package list --sponsor` extends the existing package-list report pipeline with a new report type.

Planned updates:

- Add `--sponsor` handling in `ListPackageCommand`, `ListPackageArgs`, and `ReportType`, executed through `ListPackageCommandRunner`.
- Load PSM from the NuGet settings used by the command.
  - For each package ID, `ListPackageCommandRunner` queries only the selected sources whose configured source name matches that package's source mappings.
- Add `RegistrationIndexMetadata` for the optional root `metadata` object.
  - The first property is the ordered `sponsorshipUrls` string collection.
  - Add optional `metadata` property to `RegistrationIndex`.
- Expose root index metadata through a new `RegistrationResourceV3`.
  - Future package-level properties added to the root `metadata` object can use the same abstraction.
- Add sponsorship-specific query path in `ListPackageCommandRunner`.
  - Query each `(source, package ID)` pair once and retain the source with the ordered sponsorship URLs.
- Extend `ListPackageProjectModel` to retain each source and its query results.
  - Extend `ListReportPackage` with grouped sponsorship details.
- Render console sponsorship output through `ListPackageConsoleRenderer` and `ProjectPackagesPrintUtility`.
- Render JSON sponsorship output through `ListPackageJsonRenderer`.

#### Data assumptions

- Proposed contract is an optional array of strings on the package's Registration index root exposed as an ordered `IReadOnlyList<string>`.
- Sources that support sponsorships will need to have an updated Registration resource version.
- Only packages with one or more sponsorship URLs are included.
- URLs preserve the order that is returned by a selected source in both the console and JSON.
- The client will not validate URLs; it will only show what the server provides.
  - For example, nuget.org currently enforces a maximum of 10 URLs per package, which will be the maximum number of links shown in the CLI output for package's that come from nuget.org.

**Example Registration Index:**

```json
{
  "@id": "https://api.nuget.org/v3/registration5-gz-semver2/contoso.webapi.client/index.json",
  "@type": [
    "catalog:CatalogRoot",
    "PackageRegistration",
    "catalog:Permalink"
  ],
  "commitId": "afa91af1-9505-41b8-ad75-eab8e613db14",
  "commitTimeStamp": "2026-04-10T00:15:25.1492389+00:00",
  "count": 2,
  // ** Start of proposal ** //
  "metadata": {
    "sponsorshipUrls": [
      "https://github.com/sponsors/contoso"
    ]
    // ** End of proposal ** //
  }
}
```

#### Sponsorship Data Source

This proposal assumes the CLI consumes sponsorship data from the Registration API.
It also depends on each selected package source exposing sponsorship details through the `metadata.sponsorshipUrls` property at the root of its package Registration index.

Root Registration metadata is exposed through `RegistrationResourceV3`, allowing future package-level properties added to the root `metadata` object to use that same abstraction.
A source that does not expose Registration or has authentication, network, or protocol failures uses the same list-package failure behavior.

#### Testing strategy

- Validate output for packages with no sponsorship information, a single sponsorship URL, and multiple sponsorship URLs in the CLI and JSON.
- Verify top-level and transitive packages are included by default.
- Cover missing or null `metadata` and `sponsorshipUrls` behavior, along with empty arrays or malformed JSON.
- Verify enabled configured source selection including packages mapped to one source, multiple sources, and sources excluded by `--source`.
- Validate sponsorship metadata is propagated from the Registration index and consumed by the command runner.

## Drawbacks

- At this time, nuget.org is the only source that supports sponsorship details in the Registration index root.
  - Other sources will produce a message saying that source does not support sponsorship reporting.
  - Sponsorship details from an upstream source are not shown unless that source exposes those details through its own Registration response.

## Rationale and alternatives

Using `dotnet package list --sponsor` keeps sponsorship as a read-only package metadata report alongside `--deprecated`, `--vulnerable`, and `--outdated`.
A dedicated `dotnet package sponsor` command was considered, but after considering other report-type flags, we want to remain consistent for the first implementation of the feature.
A dedicated command can be reconsidered if interactive sponsorship workflows are added later.

## Prior Art

- [2023 community sponsor-link proposal](https://github.com/NuGet/Home/blob/sponsor-link/proposed/2023/sponsor-link.md)
- [`npm fund`](https://docs.npmjs.com/cli/v10/commands/npm-fund/)
- Existing report-style CLI surfaces: `--deprecated`, `--vulnerable`, `--outdated`

## Unresolved Questions

None at this time.

## Future Possibilities

- Visual Studio Package Manager UI sponsorship hyperlinks, following existing PM UI link patterns and addressing [nuget/home#14739](https://github.com/nuget/home/issues/14739).
- CLI link-out to a nuget.org-hosted sponsorship destination (for example, `nuget.org/.../{id}/sponsor`) for richer provider-specific experiences.