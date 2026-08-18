# Implementing NuGet.Client CLI Sponsorship Support

- Author: [@kalebfik](https://github.com/kalebfik)
- GitHub Issue: [NuGet/NuGetGallery#10703](https://github.com/NuGet/NuGetGallery/issues/10703)

## Summary

Add sponsorship reporting to the NuGet CLI for installed packages.

The command surface will be presented as `dotnet package list --sponsor`

It will reuse the same metadata-fetch and rendering pipeline, with:

- A `Sponsor` column in console output
- A `sponsorablePackages` array in JSON output

## Explanation

### Functional Explanation

When a user runs `dotnet package list --sponsor`, the CLI will examine the projects/solutions packages and retrieve sponsorship links from nuget.org. 
The results are then grouped by project and displayed in the console, and optionally in JSON format. 
Packages that have multiple links are returned in the order received by nuget.org

The current proposal will receive sponsorship information from nuget.org. 
The new `metadata` and `sponsorshipUrls` property (shown in technical explanation) do not automatically propagate in other sources, resulting in those sources not receiving sponsorship information.   

Sponsorship information is currently queried from nuget.org
In debug builds only, the environment variable `NUGET_SPONSOR_ENDPOINT_OVERRIDE` can be configured to https://apidev.nugettest.org/v3/index.json (for DEV) and https://apiint.nugettest.org/v3/index.json (INT).
The command resolves packages from NuGet configuration and --source. 
Packages that do not contain sponsorship links or sources that don't support sponsorship data will be omitted from the report. 

The console will display:

```text
There are no sponsorship details found at https://api.nuget.org/v3/index.json
```

When nuget.org is not configured as a source and the command is used, the console will display a message:

```text
For sponsorship details, configure nuget.org as a package source, or allow access to nuget.org by specifying `--source https://api.nuget.org/v3/index.json`
```
The JSON output will include an empty `sponsorablePackages` array for those projects.

The default console output will add a `Sponsor` column. 
The first URL will appear besides the package ID and each additional URL appears below the previous one. 
When using `--format json`, those same packages are returned in JSON format, identified by `sponsorablePackages` and with links stored in each package's `urls` array. 

`dotnet package list --sponsor` output: 

```text
Top-level Package        Sponsor
> Contoso.Tools          https://github.com/sponsors/username
> Contoso.Utility        https://github.com/sponsors/username
                         https://domain.com/sponsor
```

`dotnet package list --sponsor --format json` output: 

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
          "urls": [
            "https://sponsordomain.com/sponsors/contoso",
          ]
        },
        {
          "id": "Contoso.Utility",
          "urls":[
            "https://github.com/sponsors/username",
            "https://domain.com/sponsor"
          ]
        }
      ]
    }
  ]
}
```

**Package Source Mapping and using `--source`**

The proposed implementation does not apply Package Source Mapping (PSM).
When PSM is configured, the command will not make sponsorship metadata requests unless nuget.org is stated using `--source https://api.nuget.org/v3/index.json`.

### Technical explanation

`dotnet package list --sponsor` extends the existing package-list report pipeline with a new report type. 

Planned updates:

- Add `--sponsor` handling in `ListPackageCommand`, `ListPackageArgs`, and `ReportType`, executed through `ListPackageCommandRunner`
- Deserialize `sponsorshipUrls` through `RegistrationIndex`, and propagate them to `PackageSearchMetadataRegistration` in `PackageMetadataResourceV3`
- Preserve sponsorship data through `InstalledPackageReference` and `ListReportPackage`.
- Render console sponsorship output through `ListPackageConsoleRenderer` and `ProjectPackagesPrintUtility`.
- Render JSON sponsorship output through `ListPackageJsonRenderer`.

#### Data assumptions

- The client reads optional `sponsorshipUrls` as `IReadOnlyList<string>`.
- Only packages with one or more sponsorship urls are included. 
- URLs preserve the order that is returned by nuget.org in both the console and JSON.
- At this time, nuget.org enforces a maximum of 10 URLs shown per package.; client will not be validating URLs, it will only show what the server provides. 

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
  "metadata":
    // ** Start of proposal ** //
    "sponsorshipUrls": [
      "https://github.com/sponsors/contoso"
      ]
    // ** End of proposal **//
}
```

#### Source transport dependency and client abstraction

This proposal assumes the CLI consumes sponsorship data from the Registration API.
Missing or empty `sponsorshipUrls` use the empty-result behavior.

#### Testing strategy

- Validate command output for packages with no sponsorship information, a single sponsorship URL, and multiple sponsorship URLs.
- Verify top-level and transitive packages are included by default.
- Verify sponsorship rendering behavior in console output.
- Verify JSON output for single and multiple sponsorship URL scenarios while preserving URL order.
- Validate sponsorship metadata is propagated from the Registration index and consumed by the command runner.

## Drawbacks



## Rationale and alternatives

`dotnet package list --sponsor` keeps sponsorship as a read-only package metadata report alongside `--deprecated`, `--vulnerable`, and `--outdated`. 
A dedicated `dotnet package sponsor` command was considered, but this experience reports information and does not perform a sponsorship action.
A dedicated command can be reconsidered if interactive sponsorship workflows are added later.

## Prior Art

- [2023 community sponsor-link proposal](https://github.com/NuGet/Home/blob/sponsor-link/proposed/2023/sponsor-link.md)
- [`npm fund`](https://docs.npmjs.com/cli/v10/commands/npm-fund/)
- Existing report-style CLI surfaces: `--deprecated`, `--vulnerable`, `--outdated`

## Unresolved Questions

If future versions support multiple sponsorship sources, how should results be merged, and how should “no sponsorship URLs” be distinguished from “source does not support sponsorship”?

## Future Possibilities

- Visual Studio Package Manager UI sponsorship hyperlinks, following existing PM UI link patterns and addressing [nuget/home#14739](https://github.com/nuget/home/issues/14739).
- CLI link-out to a nuget.org-hosted sponsorship destination (for example, `nuget.org/.../{id}/sponsor`) for richer provider-specific experiences.