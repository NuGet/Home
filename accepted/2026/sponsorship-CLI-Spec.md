# NuGet.Client CLI Sponsorship Support

- Author: [@kalebfik](https://github.com/kalebfik)
- GitHub Issue: [NuGet/NuGetGallery#10703](https://github.com/NuGet/NuGetGallery/issues/10703)

## Summary

Add sponsorship reporting to the NuGet CLI for installed packages.

The command surface will be presented as `dotnet package list --sponsor`

It will reuse the same metadata-fetch and rendering pipeline, with:

- A `Sponsor` column in console output
- A `sponsorshipUrls` array in JSON output

## Explanation

### Technical explanation

`dotnet package list --sponsor` extends the exsisting list-package report pipeline with a new report type. 

Planned updates:

- Add `--sponsor` handling in `ListPackageCommand`, `ListPackageArgs`, and `ReportType`, executed through `ListPackageCommandRunner`
- Flow `sponsorshipUrls` through: `IPackageSearchMetadata`, `PackageSearchMetadata`, `LocalPackageSearchMetadata`, `PackageSearchMetadataV2Feed`, `PackageSearchMetadataBuilder`, `RegistrationIndex`, and `PackageMetadataResourceV3`
- Preserve sponsorship data through `InstalledPackageReference` and `ListReportPackage`.
- Render console sponsorship output through `ListPackageConsoleRenderer` and `ProjectPackagesPrintUtility`.
- Render JSON sponsorship output through `ListPackageJsonRenderer`.

#### Data assumptions

- The client reads optional `sponsorshipUrls` as `IReadOnlyList<string>`.
- A status message will be shown in the json reflecting whether sponsorship information is `available`, `none`, or `unsupported`.
- Console output uses `(none)`; JSON output uses `[]`.
- Multiple URLs preserve server order and show as extra rows directly under the previous sponsorship link. 
- At this time, there is a maximum of 10 URLs shown. 
This is due to nuget.orgs current policy cap; client will not be validating urls, it will only show what the server provides. 

**Example json:**

```json
{
  "version": 1,
  "parameters": "--sponsor",
  "sources": [
    "https://api.nuget.org/v3/index.json"
  ],
  "projects": [
    {
      "path": "/path/to/Contoso.App.csproj",
      "sponsorablePackages": [
        {
          "id": "Contoso.Forms",
          "status": "available",
          "urls": [
            "https://sponsordomain.com/sponsors/contoso",
          ]
        },
        {
          "id": "Contoso.Utilities",
          "status": "none",
          "urls": []
        },
        {
          "id": "Contoso.Internal.Shared",
          "status": "unsupported",
          "urls": []
        }
      ]
    }
  ]
}
```

**Example Registration Index:**

```json
{ 
  "@id": "https://api.nuget.org/v3/registration5-gz-semver2/Contoso/index.json",
  "@type": [
    "catalog:CatalogRoot", 
    "PackageRegistration", 
    "catalog:Permalink"
  ],
  "commitId": "afa91af1-9505-41b8-ad75-eab8e613db14",
  "commitTimeStamp": "2026-04-10T00:15:25.1492389+00:00",
  "count": 2,
  // ** Start of proposal ** //
  "sponsorshipUrls": [
    "https://sponsordomain/sponsors/user"
  ]
  // ** End of proposal ** //
  // ... additional information
}  
```

#### Source transport dependency and client abstraction

This proposal assumes the CLI consumes sponsorship data from the Registration API.
This document defines client behavior only when that data is available.

#### Testing strategy

- Validate command output for packages with no sponsorship information, a single sponsorship URL, and multiple sponsorship URLs.
- Verify sponsorship rendering behavior in console output.
- Verify JSON output for empty, single, and multiple sponsorship URL scenarios while preserving URL order.
- Validate sponsorship metadata is correctly applied during package metadata enrichment.
- Verify partial-result scenarios where sponsorship metadata retrieval succeeds for some package sources and fails for others.

#### Extending to NuGet.exe

`NuGet.exe` does not have a project-level installed-package reporting command equivalent to `dotnet package list`.

- `NuGet.exe list` is marked `[DeprecatedCommand(typeof(SearchCommand))]`.
- `NuGet.exe list` and `NuGet.exe search` query sources for available packages, rather than reading a project's installed package graph.

`SearchCommand.cs` uses `PackageSearchResourceV3` via V3 Search endpoints, not `PackageMetadataResourceV3` / `RegistrationsBaseUrl`. 
As a result, sponsorship data arriving only via Registration API does not automatically appear in NuGet.exe search/list output.

Supporting NuGet.exe on this feature would likely require the Search index/response path to also publish `sponsorshipUrls`.

## Drawbacks

- nuget.exe will need seperate implementation
- Need to confirm feasability of status implementation

## Rationale and alternatives


## Prior Art

- [2023 community sponsor-link proposal](https://github.com/NuGet/Home/blob/sponsor-link/proposed/2023/sponsor-link.md)
- [`npm fund`](https://docs.npmjs.com/cli/v10/commands/npm-fund/)
- Existing report-style CLI surfaces: `--deprecated`, `--vulnerable`, `--outdated`
- PM UI's existing package link surfaces (project/license/report abuse)
- [nuget/home#14739](https://github.com/nuget/home/issues/14739) (PM UI sponsorship button request)

## Unresolved Questions

none at this time

## Future Possibilities

- Phase 2: Visual Studio Package Manager UI sponsorship hyperlinks, following existing PM UI link patterns and addressing [nuget/home#14739](https://github.com/nuget/home/issues/14739).
- Phase 3: CLI link-out to a NuGet.org-hosted sponsorship destination (for example, `nuget.org/.../{id}/sponsor`) for richer provider-specific experiences.
