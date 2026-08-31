# **Proposal to Surface Sponsorship Information in the CLI**

- Author: [@kalebfik](https://github.com/kalebfik)
- GitHub Issue: [10703](https://github.com/NuGet/NuGetGallery/issues/10703)
- [Accompanying Technical Implementation Spec](https://github.com/NuGet/Home/blob/dev-kalebfika-sponsorTechSpec/accepted/2026/implementing-sponsorship-in-cli.md)

## Summary

This spec proposes surfacing sponsorship links in the command line using the command `dotnet package list --sponsor`, so that users are able to see which packages they use are looking for funding.
This feature is opt-in and reports sponsorship information throughout a project.

## Motivation

Package maintainers can already add sponsorship links (GitHub Sponsors, Patreon, Open Collective, etc.) to their packages on nuget.org. [See the package sponsorship documentation for more information](https://learn.microsoft.com/en-us/nuget/nuget-org/package-sponsorship-on-nuget-org).
Developers only see this today if they visit the package's nuget.org page.
As a result, consumers who primarily use the command line to navigate their packages may not know that the dependencies they rely on are seeking support.
The maintainers of those packages receive limited visibility for sponsorship links they may have provided on the website.

The CLI is an appropriate place to add sponsorship information because there is already a way to review current dependencies using `dotnet package list`.
This is the most relevant workflow to implement sponsorship information.

## Goals

- Make sponsorship information discoverable through the CLI using `dotnet package list --sponsor`
- Help consumers and organizations identify packages seeking financial support
- Increase visibility for sponsorship links provided by package maintainers
- Keep the experience explicit and separate from restore

## Non-Goals

- Process sponsorship payments
- Management of sponsorship links from the CLI
- Display sponsorship features during restore
- Validation of sponsorship links
- Ranking or prioritizing sponsorship links from the CLI

**Why not restore?**

Restore is a process that is used frequently during builds and other background IDE operations.
Sponsorship information is not required to resolve builds or install packages, so retrieving that information during the restore process could add network costs to a performance-sensitive operation without providing adequate justification for the extra cost.
Keeping it opt-in through the `--sponsor` flag ensures that it is retrieved only when the user is explicitly asking for it.

**Who this affects**

- **Package consumers** get a way to discover, from the command line, which of their dependencies are seeking sponsorship — without having to visit nuget.org for every package individually.
- **Package authors** who've already added sponsorship links to their packages get more visibility for those links, since consumers can now see them as part of a workflow (`dotnet package list --sponsor`), not just on the package's web page.
- **Repository/org admins** have an easier way to see sponsorship status alongside the other package information they already manage day-to-day (versions, licenses, vulnerabilities).

## Explanation

### Functional Explanation

**Proposed Experience**

When a user runs `dotnet package list --sponsor`, output is grouped by project and the source used, and includes sponsorship links for each matching package:

`dotnet package list --sponsor` output:

```text
// sample response
Project 'Contso.App' has the following sponsorable packages
Top-level Package        Sponsor
> Contoso.Tools          Source: https://api.example.org/v3/index.json
                           https://github.com/sponsors/contoso
Transitive Package
> Contoso.Utility        Source: https://api.example.org/v3/index.json
                           https://github.com/sponsors/contoso
                         Source: https://www.myget.org/F/contoso/api/v3/index.json
                           https://buymeacoffee.com/contoso
```

Sponsorship information is applied to the package ID rather than the version of a package.
Therefore, sponsorship information remains the same for a package regardless of what version package is published, as long as those links have not been changed.
When a package has multiple sponsorship links, the CLI will display the links in the order returned by nuget.org.

Both top-level and transitive packages will be included by default when using `--sponsor`.
This behavior will be documented in the command's help description.

The command also supports `dotnet package list --sponsor --format json` and will produce output such as:

```json
{
  "version": 1,
  "parameters": "--sponsor --format json",
  "sources": [
    "https://api.example.org/v3/index.json",
    "https://www.myget.org/F/contoso/api/v3/index.json"
  ],
  "packages": [
    {
      "id": "Contoso.Tools",
      "projects": [
        {
          "path": "/path/to/Contoso.App.csproj",
          "relationship": "topLevel"
        }
      ],
      "sponsorships": [
        {
          "sources": [
            "https://api.example.org/v3/index.json"
          ],
          "urls": [
            "https://github.com/sponsors/contoso"
          ]
        }
      ]
    },
    {
      "id": "Contoso.Utility",
      "projects": [
        {
          "path": "/path/to/Contoso.App.csproj",
          "relationship": "transitive"
        }
      ],
      "sponsorships": [
        {
          "sources": [
            "https://api.example.org/v3/index.json"
          ],
          "urls": [
            "https://github.com/sponsors/contoso"
          ]
        },
        {
          "sources": [
            "https://www.myget.org/F/contoso/api/v3/index.json"
          ],
          "urls": [
            "https://buymeacoffee.com/contoso"
          ]
        }
      ]
    }
  ]
}
```

Each package source is listed once, with the projects where it is used and its top-level or transitive relationships recorded.
If multiple sources return the same ordered URL list, the JSON represents the list once and includes all sources in the same `sponsorships` entry.
If multiple sources return different URL lists, they are represented in separate `sponsorships` entries.

**No Sponsorship Details Returned**

The command selects enabled package sources from NuGet configuration.
When a source is specified using `--source <SOURCE>`, only that source is queried for sponsorship information.
A successful Registration response with a missing or empty `sponsorshipUrls` field is treated as a successful empty result.

Console output includes only sources that return one or more sponsorship URLs.
If none of the selected sources return sponsorship details for a project, the CLI displays:

```text
// sample response
No sponsorship details were returned using the following package sources:
  https://api.example.org/v3/index.json

Consider specifying an additional package source that provides sponsorship metadata, for example: `--source https://api.nuget.org/v3/index.json`.
```

A source that does not support sponsorships will have a separate message:

```text
These sources do not provide sponsorship support:
  C:/Program Files (x86)/Microsoft SDKs/NuGetPackages/
```

The JSON output includes every selected source in the top-level `sources` list, which includes supported and unsupported sources, along with local sources.
Only packages that have at least one sponsorship URL will appear in `packages`.
For an empty report, `packages` is empty, and `problems` contains one warning per empty or unsupported source.

```json
{
  "version": 1,
  "parameters": "--sponsor --format json",
  "sources": [
    "https://api.example.org/v3/index.json",
    "C:/Program Files (x86)/Microsoft SDKs/NuGetPackages/"
  ],
  "problems": [
    {
      "level": "warning",
      "text": "There are no sponsorship details found at https://api.example.org/v3/index.json"
    },
    {
      "level": "warning",
      "text": "This source does not provide sponsorship support: C:/Program Files (x86)/Microsoft SDKs/NuGetPackages/"
    }
  ],
  "packages": []
}
```

**Package Sources, Package Source Mapping (PSM), and `--source`**

A package source advertises sponsorship support through a new version of the Registration resource.
The exact Registration version will be finalized with the server implementation.

```json
{
  "@id": "https://api.nuget.org/v3/registration5-semver1/",
  "@type": "RegistrationsBaseUrl/<NEW_VERSION>",
  "comment": "Base URL of Azure storage where NuGet package registration info is stored. This base URL does not include SemVer 2.0.0 packages."
}
```

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

PSM is intended to ensure each package is accessed only through package sources that are explicitly mapped in a user's configuration.
Using `--source` replaces the configured source selection and could select a source that is not represented by those mappings.
Instead of bypassing or ignoring PSM, the command fails before making any requests.
A user must add the desired source and package mappings to NuGet configuration or use a configuration without PSM.

A mapped source that is successfully queried but returns an empty `sponsorshipUrls` property produces the same empty-source behavior present in the JSON above.
This includes sources that do not propagate sponsorship metadata from an upstream source.

| Scenario | Who this represents | Behavior |
|---|---|---|
| **NuGet.org only; no PSM** | A developer using the default public NuGet ecosystem. | Query every top-level and transitive package ID against NuGet.org. |
| **NuGet.org and other sources; no PSM** | A developer or organization using public and private feeds. | Query every package ID against each selected sponsorship-capable source; retain unsupported selected sources as warnings in JSON. Group results by source. |
| **Only private or third-party sources; no PSM** | A developer or organization not using NuGet.org directly. | Query every package ID against each selected sponsorship-capable source. Report other selected sources as unsupported. |
| **PSM enabled** | An organization restricting package IDs to configured sources. | Query each package ID only against its mapped, sponsorship-capable configured sources. |
| **PSM enabled with `--source`** | A user attempting to override configured source selection while mappings are active. | Fail before any sponsorship request and explain that PSM cannot be combined with `--source`. |

### Technical Explanation

The CLI will retrieve sponsorship information through the Registration API, similar to how other package metadata is passed to the CLI ([package ID-level metadata in the Registration API](https://github.com/NuGet/Home/issues/15038)).
The difference is that sponsorship information will be scoped by package ID only, whereas other metadata is scoped by package ID and version.

A successful nuget.org response with one or more URLs will appear in the report, while packages with no sponsorship URLs will be absent.

The client will display the URLs exactly as each source returns them.
There is no validation, ranking, or prioritization done on the client side.

A package source will indicate sponsorship support through a `metadata.sponsorshipUrls` field on the Registration index root:

**Example registration root entry with `metadata` and `sponsorshipUrls` added:**

```jsonc
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
  }
  // ** End of proposal **//
}
```

- **Scope:** solution-wide across all projects.
- **Transitive packages:** Included by default; when using `dotnet package list --help`, the description will state that transitive packages are included by default.
- **Multiple sponsorship URLs:** The CLI displays sponsorship URLs in the order received from the package source.
- **nuget.org URL limit:** nuget.org currently enforces a maximum of 10 URLs per package.
- **Empty state:** A missing, null, or empty `sponsorshipUrls` value is treated as a successful empty result.

A detailed implementation proposal can be found [here](https://github.com/NuGet/Home/blob/dev-kalebfika-sponsorTechSpec/accepted/2026/sponsorship-CLI-Spec.md).

## Drawbacks

- At this time, nuget.org is the only source that supports sponsorship details in the Registration index root.
  - Other sources will produce a message saying that source does not support sponsorship reporting.
  - Sponsorship details from an Azure Artifacts upstream source are not shown unless that source exposes those details through its own Registration response.

## Rationale and Alternatives

Why `dotnet package list --sponsor`? Why not `dotnet package sponsor` or `dotnet package fund`?

```bash
dotnet package sponsor
```

This approach treats sponsorships similarly to npm's `npm fund` command (see the appendix).

A dedicated command could provide a clearer and more focused intent while also supporting future interactive experiences.
That said, the intent for the proposed experience is to report package metadata, not to provide actions like selecting a provider or processing a sponsorship.
If sponsorship grows into a bigger feature, a dedicated command could be revisited.

## Prior Art/Related

- [**Package sponsorships on nuget.org**](https://learn.microsoft.com/en-us/nuget/nuget-org/package-sponsorship-on-nuget-org): Package sponsorships can already be configured on nuget.org.
- [**Companion server spec**](https://devdiv.visualstudio.com/DevDiv/_git/NuGet.Services/pullrequest/763096?_a=files&iteration=2&base=1): Proposes implementation for supporting package ID-level metadata in the Registration API (internal link).
- **[`npm fund`](https://docs.npmjs.com/cli/v10/commands/npm-fund/)**: `npm fund` provides precedent for this pattern. The `funding` field lives in package metadata, and npm's guidance suggests keeping funding links at the package or author level.
  npm notes that funding information can be noisy in the CLI and that stale information could be problematic.
- **[Gallery UI Sponsorship Implementation](https://github.com/NuGet/Engineering/blob/prabora-needs-sponsorship-feature/Server.Specs/2025/NeedsSponsorship.md)**: companion server-side proposal for surfacing sponsorship needs directly in the nuget.org Gallery UI; relevant precedent/parallel effort for surfacing the same underlying sponsorship data.
- **`--deprecated`/`--vulnerable`**: precedent for opt-in report-style information that consumers already use and understand, informing this proposal's output/UX conventions.
- **PM UI's existing project/license/report-abuse links**: precedent for Phase 2 — PM UI already shows package-supplied links to consumers using an established, low-risk pattern.
- **[`nuget/home#14739`](https://github.com/nuget/home/issues/14739)**: Open issue for a PM UI sponsorship button.

## Unresolved Questions

None at this time.

## Future Possibilities

- **Multiple package sources:** Other sources adopt the new Registration resource version and can report sponsorship details.
- **Dedicated sponsorship command:** Introduce a `dotnet package sponsor` or `dotnet package fund` command if sponsorships develop into a larger workflow.
- **Interactive CLI experience:** Allow users to navigate a package's sponsorship links using their arrow keys and open one in their native browser.
- **Filter top-level and transitive packages.**
- **VS Package Manager UI hyperlinks** for sponsorship links, directly addressing [nuget/home#14739](https://github.com/nuget/home/issues/14739).
- **AI agent integration:** Make sponsorship information available to package-management agents. See [Issue 14738](https://github.com/NuGet/Home/issues/14738).

## Appendix

### npm Fund Comparison

npm provides a dedicated `npm fund` command that helps developers discover funding opportunities for packages they depend on.
Package authors specify funding information directly in their package metadata using the `funding` field.

```json
{
  "funding": {
    "type": "individual",
    "url": "http://example/donate"
  },

  "funding": {
    "type": "patreon",
    "url": "https://domain/my-account"
  }
}
```

When a package containing funding metadata is installed, npm displays a summary message:

```text
Added 342 packages in 4s

3 packages are looking for funding
  run `npm fund` for details
```

After running `npm fund`, users receive this output:

```text
my-project
├── https://domain/sponsors/user
│   └── express@4.21.2
├── https://domain/user
│   └── @babel/core@7.28.0
└── https://domain/sponsors/user
    └── p-limit@7.1.1
```

**Characteristics of npm's approach**

- Funding information is stored within package metadata.
- Funding information is distributed through the package ecosystem.
- Funding discovery has a dedicated command surface (`npm fund`).

**Comparison with Proposed Approach**

npm: Funding information is directly embedded in package metadata and distributed throughout the npm ecosystem.

```bash
npm fund
```

Dedicated funding workflow.

NuGet: Sponsorship information is retrieved from the selected package source and surfaced through client tooling.

```bash
dotnet package list --sponsor
```

Report-style experience aligned with existing commands.

**Why not mirror npm exactly?**

1. Sponsorship information needs to be queried from the package source rather than embedded within the package.
2. Sponsorship discovery follows existing NuGet resolution behavior.
3. Restore output remains unchanged to avoid additional noise.
4. Users explicitly opt into sponsorship discovery instead of receiving sponsorship messaging during restore operations.
