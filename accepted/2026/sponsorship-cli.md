# **Proposal to Surface Sponsorship Information in the CLI**

- Author: [@kalebfik](https://github.com/kalebfik)
- GitHub Issue: [10703](https://github.com/NuGet/NuGetGallery/issues/10703)

## Summary

This spec proposes surfacing sponsorship links in the command line using the command `dotnet package list --sponsor`, so that users are able to see what packages they use are looking for funding. 
This feature is opt-in, and it reports sponsorship information throughout a project. 

## Motivation

Package maintainers can already add sponsorship links (GitHub Sponsors, Patreon, Open Collective, etc.) to their packages on nuget.org [See here for more information](https://learn.microsoft.com/en-us/nuget/nuget-org/package-sponsorship-on-nuget-org). 
Developers only see this today if they visit the package's nuget.org page. 
As a result, consumers who primarily use the command line to navigate their packages may not know that the dependencies they rely on are seeking support. 
The maintainers of those packages receive limited visibility for sponsorship links they may have provided on the website.

The CLI is an appropriate place to add sponsorship information because there is already a way to review current dependencies, using `dotnet package list`.
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
Sponsorship information is not something that is required to resolve builss or install packages, so retrieving that information during the restore process could add additional network costs to a performance-sensitive operation, without providing adequate justification for the extra cost. 
Keeping it opt-in through the `--sponsor` flag ensures that it is retrieved only when the user is explicitly asking for it. 

**Who this affects**

- **Package consumers** get a way to discover, from the command line, which of their dependencies are seeking sponsorship — without having to visit nuget.org for every package individually.
- **Package authors** who've already added sponsorship links to their packages get more visibility for those links, since consumers can now see them as part of a workflow (`dotnet package list --sponsor`), not just on the package's web page.
- **Repository/org admins** have an easier way to see sponsorship status alongside the other package information they already manage day-to-day (versions, licenses, vulnerabilities).

## Explanation

### Functional Explanation

**Proposed Experience** 

When a user runs `dotnet package list --sponsor`, output is grouped by project and includes sponsorship links for each matching package:

**One Sponsorship Link** 

```text
Top-level Package        Sponsor
> Contoso.Tools          https://github.com/sponsors/username
> Contoso.Utility        https://domain.com/sponsor
                         
```
**Ten Sponsorship Links** (matching nuget.org's current policy cap)

```text
Top-level Package        Sponsor
> Contoso.Utility        https://domain1.com/user
                         https://domain1.com/user2
                         https://domain2.com/user
                         https://domain2.com/user2
                         https://domain2.com/user3
                         https://domain3.com/sponsors/user
                         https://domain3.com/sponsors/user2
                         https://domain4.com/123
                         https://domain4.com/456
                         https://domain4.com/789
```

Sponsorship information is applied to the Package ID rather than the version of a package, which is why they are listed once per package. 
When a package has multiple sponsorship links, the CLI will display the links in the order returned by nuget.org.

Both top-level and transitive packages will be included by default when using `--sponsor`. 
This behavior will be documented in the command's help description. 

The command also supports `dotnet package list --sponsor --format json`, and will produce an output such as: 

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

**Source that doesn't support sponsorships/Packages without sponsorship links**

Because nuget.org is hardcoded in this proposal, sponsorship information that cannot be retrieved from either a source or a package that does not have sponsorship information will be treated the same. 

When nuget.org is a configured source or is specified with `--source` and no installed packages provide sponsorship data, the console will display: 

```text
There are no sponsorship details found at https://api.nuget.org/v3/index.json
```

```json
{
  "version": 1,
  "parameters": "--sponsor",
  "problems": [
  {
    "level": "warning",
    "text": "There are no sponsorship details found at https://api.nuget.org/v3/index.json"
  }
]
}
```

When nuget.org is not configured as a source and is not specified using '--source`, the console will display a message:

```text
For sponsorship details, configure nuget.org as a package source, or allow access to nuget.org by specifying `--source https://api.nuget.org/v3/index.json`
```

```json
{
  "version": 1,
  "parameters": "--sponsor",
  "problems": [
  {
    "level": "warning",
    "text": "There are no sponsorship details found at https://api.nuget.org/v3/index.json"
  }
]
}
```

**Package Sources and Package Source Mapping**

For the initial implementation of this feature, nuget.org will be the only source used to retrieve sponsorship information. 
While the design for the server is intended to be extensible to other feeds, we don't know when or if other feeds will implement sponsorship, so to not complicate logic in client, multi-feeds won't be merged. 

The proposed implementation does not apply Package Source Mapping (PSM).
When PSM is configured, the command will not make sponsorship metadata requests unless nuget.org is stated using `--source https://api.nuget.org/v3/index.json`.

| Scenario | Who this represents | Behavior |
|---|---|---|
| **NuGet.org only enabled; no PSM** | A developer using the default public NuGet ecosystem. | Query NuGet.org for every package ID. |
| **NuGet.org and other sources enabled; no PSM** | A developer or organization using NuGet.org with private or third-party feeds. | Query only NuGet.org for every package ID. Ignore other sources and do not merge results. |
| **NuGet.org not configured; no PSM** | A developer or organization using only private or third-party feeds. | Perform no lookup unless NuGet.org is explicitly supplied using `--source https://api.nuget.org/v3/index.json`. |
| **NuGet.org not configured; PSM enabled** | An organization mapping package IDs to private or third-party feeds. | PSM is not applied. Perform no lookup unless NuGet.org is explicitly supplied using `--source https://api.nuget.org/v3/index.json`; then query NuGet.org for every package ID. |

### Technical Explanation

The CLI will retrieve sponsorship information through the Registration API, similar to how other package metadata is passed to the CLI (PackageID level Metadata in Registration Spec)[https://github.com/NuGet/Home/issues/15038]. 
The difference is that sponsorship information will be scoped by PackageID-only, whereas other metadata is scoped by its PackageID + version. 

A successful nuget.org response with one or more URLs (maximum 10 URLs per server enforcement) will appear in the report, while packages with no sponsorship URLs will be absent. 

The client will display the URLs exactly how nuget.org returns them.
There is no validation, ranking, or prioritization done on the client side. 

A package source will indicate sponsorship support through a sponsorshipUrls field on the registration index: 

**Example registration root entry with `sponsorshipUrls` added:**

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
  "metadata":
    "sponsorshipUrls": [
      "https://github.com/sponsors/contoso"
      ]
  // ** End of proposal **//
}
```

- **Scope:** solution-wide across all projects.
- **Transitive packages:** Included by default; When using `dotnet package list -help`, the description will include that transitive packages are included by default.
- **Multiple sponsorship URLs:** The CLI displays sponsorship URLs in the order received from the package source.
- **Empty state:** When a project has no sponsorable packages, display a per-project message indicating none were found.

A detailed implementation proposal can be found [here](https://github.com/NuGet/Home/blob/dev-kalebfika-sponsorTechSpec/accepted/2026/sponsorship-CLI-Spec.md).

## Drawbacks
- Currently only implemented by nuget.org, which means that customers using other package sources will not see sponsorship information, even if those packages have sponsorship links on nuget.org.
- Package Source Mapping is not enabled on this feature, so users are required to use https://api.nuget.org/index.json for sponsorship information. 

## Rationale and Alternatives

Why `dotnet package list --sponsor`? Why not `dotnet package sponsor` or `dotnet package fund`?

```bash
dotnet package sponsor
```

This approach treats sponsorships similarly to npm's `npm fund` command (see appendix). 

A dedicated command could provide a clearer and more focused intent, while also supporting future interactive experiences. 
That said, the intent for the proposed experience is to report package metadata, and not to provide actions like selecting a provider or processing a sponsorship. 
If sponsorship grows into a bigger feature, a dedicated command could be revisited. 


## Prior Art/Related

- [**Package sponsorships on nuget.org**](https://learn.microsoft.com/en-us/nuget/nuget-org/package-sponsorship-on-nuget-org): Packages can already be set on nuget.org.
- [**Companion server spec**](https://devdiv.visualstudio.com/DevDiv/_git/NuGet.Services/pullrequest/763096?_a=files&iteration=2&base=1): Proposes implementation for supporting PackageID level metadata in the Registration API (internal link).
- **[`npm fund`](https://docs.npmjs.com/cli/v10/commands/npm-fund/)**: `npm fund` provides precedent for this pattern. The `funding` field lives in package metadata, and npm's guidance suggests keeping funding links at the package or author level. 
npm notes that funding information can be noisy in the CLI and stale information could be problematic.
- **[Gallery UI Sponsorship Implementation](https://github.com/NuGet/Engineering/blob/prabora-needs-sponsorship-feature/Server.Specs/2025/NeedsSponsorship.md)**: companion server-side proposal for surfacing sponsorship needs directly in the nuget.org Gallery UI; relevant precedent/parallel effort for surfacing the same underlying sponsorship data.
- **`--deprecated`/`--vulnerable`**: precedent for opt-in report-style information that consumers already use and understand, informing this proposal's output/UX conventions.
- **PM UI's existing project/license/report-abuse links**: precedent for Phase 2 — PM UI already shows package-supplied links to consumers using an established, low-risk pattern.
- **[`nuget/home#14739`](https://github.com/nuget/home/issues/14739)**: Open issue for PM UI sponsorship button

## Unresolved Questions

- If future implementation extends to other sources, how should packages with no sponsorship information and sources that don't provide sponsorships be differentiated? 

## Future Possibilities

- **Multiple package sources:** Allow other feeds to provide sponsorship information 
- **Dedicated sponsorship command:** Introduce a `dotnet package sponsor` or `dotnet package fund` command if sponsorships develop into a larger workflow
- **Interactive CLI experience:** Allow users to navigate a package's sponsorship links using their arrow keys and open one in their native browser
- **Filter top-level and transitive packages**
- **VS Package Manager UI hyperlinks** for sponsorship links, directly addressing [nuget/home#14739](https://github.com/nuget/home/issues/14739).
- **AI agent integration**: Make sponsorship information available to package-management agents. 
See [Issue 14738](https://github.com/NuGet/Home/issues/14738)

## Appendix
NPM Fund Comparison

NPM provides a dedicated `npm fund` command that helps developers discover funding opportunities for packages they depend on.
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
  },
}
```

When a package containing funding metadata is installed, npm displays a summary message: 

```text
Added 342 packages in 4s

3 packages are looking for funding 
  run `npm fund` for details
```

After running `npm fund`, they receive this output: 

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
- Funding discovery has dedicated command surface (`npm fund`).

**Comparison with Proposed Approach**

NPM: Funding information is directly embedded in package metadata and distributed throughout the npm ecosystem.

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

1. Sponsorship information needs to be queried from the package source, rather than embedded within the package. 
2. Sponsorship discovery follows existing NuGet resolution behavior 
3. Restore output remains unchanged to avoid additional noise.
4. Users explicitly opt into sponsorship discovery instead of receiving sponsorship messaging during restore operations. 
