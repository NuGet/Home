# **Surface Package Sponsorship Links to Developers**

- Author: [@kalebfik](https://github.com/kalebfik)
- GitHub Issue: [10703](https://github.com/NuGet/NuGetGallery/issues/10703)

## Summary

Package maintainers can already add sponsorship links (GitHub Sponsors, Patreon, Open Collective, etc.) to their packages on nuget.org. Developers only see this today if they visit the package's nuget.org page. 
This proposal brings that existing data into developer tooling — starting with a new `dotnet package sponsor` command — so developers can discover which dependencies are seeking sponsorship without leaving their workflow.

## Motivation

Sponsorship links already exist and are maintained by package owners on nuget.org — the data is real and current, it's just invisible outside the website. 
The core problem is getting existing nuget.org sponsorship data into developer tooling

This proposal adds a non-disruptive, opt-in way to surface sponsorship information, and is scoped as the first of three phases:

1. **Phase 1 (this proposal): CLI** — `dotnet package sponsor`.
2. **Phase 2: Visual Studio Package Manager UI** — surfacing sponsorship links using the same hyperlink pattern PM UI already uses for project/license/report-abuse URLs, directly addressing the demand in [nuget/home#14739](https://github.com/nuget/home/issues/14739).
3. **Phase 3: CLI popup link-out** — opening a nuget.org-hosted sponsorship page (`nuget.org/.../{id}/sponsor`) directly from the CLI, so developers get a richer, always-current destination without the CLI needing to hardcode or format every payment provider's link itself.

Providing sponsor links from nuget.org to the client is the key motivation for this proposal. 

### Why not restore?

Restore runs on every build; adding informational (non-actionable) content there, even opt-in, risks alarm fatigue and encourages developers to disable the feature entirely rather than engage with it. 
Restore is also performance-sensitive: checking sponsorship requires reaching out over the network for every package, and doing so as part of restore would slow down builds and add repeated network calls to the frequent background restores that happen automatically while editing code (e.g., to keep IntelliSense/autocomplete up to date), not just when a developer explicitly builds.

## Who this affects

- **Package consumers** get a way to discover, from the command line, which of their dependencies are seeking sponsorship — without having to visit nuget.org for every package individually.
- **Package authors** who've already added sponsorship links to their packages get more visibility for those links, since consumers can now see them as part of a workflow (`dotnet package sponsor`), not just on the package's web page.
- **Repository/org admins** have an easier way to see sponsorship status alongside the other package information they already manage day-to-day (versions, licenses, vulnerabilities).

## Explanation

This proposal adds a new `dotnet package sponsor` command, giving sponsorship discovery a dedicated and purpose-built surface. 

When you run `dotnet package sponsor`, output is grouped by project and includes sponsorship links for each matching package:

```text
Project 'Contoso.App' has the following sponsorship information:
   > Contoso.Forms
      https://github.com/sponsors/contoso
      https://patreon.com/sponsor/contoso-forms
      https://opencollective.com/contoso-forms
   > Contoso.Utilities
      https://opencollective.com/contoso-utilities
```

In the case that a source either supports sponsorships but has no packages looking for them or a source does not support sponsorships, a respective message will be shown: 

```text
// No packages looking for sponsorship
No packages in project 'Contoso.Tools' are looking for sponsors.
```

```text
// Source does not provide sponsorship information
Source 'X' does not provide sponsorship information
```

For private/internal feeds, users can explicitly query nuget.org sponsorship data:

```text
dotnet package sponsor --source https://api.nuget.org/v3/index.json
```

`dotnet package sponsor` also supports JSON output via `--format json`. 
Since sponsorship is a per-package-ID concept independent of target framework, sponsorsable packages are listed per-project under `sponsorablePackages`

```json
{
  "version": 1,
  "parameters": "dotnet package sponsor",
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
            "https://github.com/sponsors/contoso",
            "https://patreon.com/sponsor/contoso-forms",
            "https://opencollective.com/contoso-forms"
          ]
        },
        {
          "id": "Contoso.Utilities",
          "urls": [
            "https://opencollective.com/contoso-utilities"
          ]
        }
      ]
    }
  ]
}
```

### Sponsorship document format

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| packageId | string | yes | The package ID this document describes |
| sponsorshipUrls | array of objects | yes | The package's current sponsorship links |

Each `sponsorshipUrls` element:

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| url | string | yes | The sponsorship URL |
| timestamp | string | yes | When this URL was added, in ISO 8601 |

Sample response:

```json
{
  "packageId": "Contoso.Forms",
  "sponsorshipUrls": [
    {
      "url": "https://github.com/sponsors/contoso",
      "timestamp": "2025-01-15T00:00:00Z"
    }
  ]
}
```

- **Scope:** solution-wide across all projects.
- **Transitive packages:** respects `--include-transitive`; no sponsor-specific behavior is required.
- **Multiple sponsorship URLs:** The CLI will display the same sponsorship URLs that are received from NuGet.org
- **Empty state:** if a project has no sponsorable packages, show a per-project message indicating none were found.

## Drawbacks

- **No link priority/reorder support** The CLI will display sponsorship information in the same order as the queried package source, not performing any sorting of its own 
- **CLI-only scope.** PM UI (Phase 2), popup link-out (Phase 3), Copilot/IDE, and NuGet.org/PM UI Search surfaces are deferred.
- **Freshness is cache-policy dependent.** Sponsorship data is fetched through the local HTTP cache, which currently has a fixed 30 minute TTL (time to live) 


## Rationale and alternatives

1. **Command alternatives**
- New `dotnet package fund` verb: mirrors `npm fund` naming, kept as an alternative naming option to `dotnet package sponsor`

- `dotnet list package --sponsor`: Reuses existing report-flag pattern as `--vulnerabilities` or `--outdated`.


2. **Display alternatives**
- a default JSON-only output: inconsistent with existing report UX that consumers already expect from `dotnet list package`. **`--format json`** will be supported.

3. **Restore-time messaging**
- Restore is a noise-sensitive surface run on every build; an explicit, per-invocation command keeps this information fully opt-in without polluting the default build/restore loop.

4. **Bake sponsorship into package metadata**: `npm fund` has precedent for this.
- The `funding` field lives directly in package metadata.
- npm's own guidance suggests keeping funding links at the package or author level.
- Doing the same for NuGet could be noisy for the CLI, and stale sponsorship information could be an issue.

**Impact of not doing this:** sponsorship links remain visible only on the nuget.org website; there is no way for the CLI, PM UI, or other client tooling to programmatically surface which dependencies are seeking sponsorship, limiting discoverability for package authors relying on this signal for funding.

## Prior Art

- **[2023 community proposal](https://github.com/NuGet/Home/blob/sponsor-link/proposed/2023/sponsor-link.md)**: Initial community proposal for the overall idea — introduced the `--sponsor` flag concept, sponsor metadata authors could set, a Visual Studio UI link, and an opt-in restore-time summary message.
- **[`npm fund`](https://docs.npmjs.com/cli/v10/commands/npm-fund/)**:  `npm fund` has precedent for this.
`funding` field lives in metadata. 
NPM suggests to have funding links live on package or author level.
They also state that it is noisy to the CLI, and stale funding information could be an issue
- **[Gallery UI Sponsorship Implementation](https://github.com/NuGet/Engineering/blob/prabora-needs-sponsorship-feature/Server.Specs/2025/NeedsSponsorship.md)**: companion server-side proposal for surfacing sponsorship needs directly in the nuget.org Gallery UI; relevant precedent/parallel effort for surfacing the same underlying sponsorship data.
- **`--deprecated`/`--vulnerable`**: precedent for opt-in report-style information that consumers already use and understand, informing this proposal's output/UX conventions even though it uses a dedicated verb rather than a flag.
- **PM UI's existing project/license/report-abuse links**: precedent for Phase 2 — PM UI already shows package-supplied links to consumers using an established, low-risk pattern.
- **[`nuget/home#14739`](https://github.com/nuget/home/issues/14739)**: Open issue for PM UI sponsorship button

## Unresolved Questions

None at this time

## Future Possibilities

- **Phase 2: VS Package Manager UI hyperlinks** for sponsorship links, directly addressing [nuget/home#14739](https://github.com/nuget/home/issues/14739).
- **Phase 3: Compact link-out CLI display** using template-driven website links (`nuget.org/.../{id}/sponsor`) once sponsor popup URLs are independently addressable.
- **Search and Browse Visibility** for PM UI Browse and nuget.org search experiences
- **Copilot/IDE surfaces**: See [Issue 14738](https://github.com/NuGet/Home/issues/14738)