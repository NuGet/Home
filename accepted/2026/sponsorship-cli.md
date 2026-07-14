# **Surface Package Sponsorship Links to Developers**

- Author: [@kalebfik](https://github.com/kalebfik)
- GitHub Issue: [10703](https://github.com/NuGet/NuGetGallery/issues/10703)

## Summary

Package maintainers can already add sponsorship links (GitHub Sponsors, Patreon, Open Collective, etc.) to their packages on nuget.org. Developers only see this today if they visit the package's nuget.org page. 
This proposal brings that existing data into developer tooling — starting with a new `--sponsor` flag on `dotnet list package` — so developers can discover which dependencies are seeking sponsorship without leaving their workflow.

## Motivation

Sponsorship links already exist and are maintained by package owners on nuget.org — the data is real and current, it's just invisible outside the website. 
The core problem is getting existing nuget.org sponsorship data into developer tooling

This proposal adds a non-disruptive, opt-in way to surface sponsorship information, and is scoped as the first of three phases:

1. **Phase 1 (this proposal): CLI** — `dotnet list package --sponsor`.
2. **Phase 2: Visual Studio Package Manager UI** — surfacing sponsorship links using the same hyperlink pattern PM UI already uses for project/license/report-abuse URLs, directly addressing the demand in [nuget/home#14739](https://github.com/nuget/home/issues/14739).
3. **Phase 3: CLI popup link-out** — opening a nuget.org-hosted sponsorship page (`nuget.org/.../{id}/sponsor`) directly from the CLI, so developers get a richer, always-current destination without the CLI needing to hardcode or format every payment provider's link itself.

Providing sponsor links from nuget.org to the client is the key motivation for this proposal. 

### Why not restore?

Restore runs on every build; adding informational (non-actionable) content there, even opt-in, risks alarm fatigue and encourages developers to disable the feature entirely rather than engage with it. 
Restore is also performance-sensitive: checking sponsorship requires reaching out over the network for every package, and doing so as part of restore would slow down builds and add repeated network calls to the frequent background restores that happen automatically while editing code (e.g., to keep IntelliSense/autocomplete up to date), not just when a developer explicitly builds.

Combining sponsorship into an existing report flag would blur `--sponsor`'s informational nature with report flags that call out actionable problems (deprecations, vulnerabilities), for limited benefit over a dedicated flag.

## Who this affects

- **Package consumers** get a way to discover, from the command line, which of their dependencies are seeking sponsorship — without having to visit nuget.org for every package individually.
- **Package authors** who've already added sponsorship links to their packages get more visibility for those links, since consumers can now see them as part of a workflow they already use (`dotnet list package`), not just on the package's web page.
- **Repository/org admins** have an easier way to see sponsorship status alongside the other package information they already manage day-to-day (versions, licenses, vulnerabilities).

## Explanation

This proposal adds `--sponsor` to `dotnet list package`, following the same opt-in report pattern as `--deprecated`, `--outdated`, and `--vulnerable`.
Adding a new `dotnet sponsor` verb would cost more than introducing a new flag, and it would be inconsistent with how consumers already discover `--deprecated`, `--outdated`, and `--vulnerable`.

When you run `dotnet list package`, it restores the project and lists package dependencies:

```text
Top-level Package       Requested           Resolved
<PACKAGE_NAME>          <REQUESTED_VERSION> <RESOLVED_VERSION>
```

With `--sponsor`, output is grouped by project and includes sponsorship links for each matching package:

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
dotnet list package --sponsor --source https://api.nuget.org/v3/index.json
```

`--sponsor` also supports JSON output via `--format json`, following the same base envelope as other report types (`version`, `parameters`, `sources`, `problems`). Since sponsorship is a per-package-ID concept independent of target framework, sponsored packages are listed per-project under `sponsoredPackages`, rather than nested under `frameworks` like `--deprecated`/`--outdated`/`--vulnerable`:

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
      "sponsoredPackages": [
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
- **Empty state:** if a project has no sponsored packages, show a per-project message indicating none were found.

## Drawbacks

- **No link priority/reorder support** The CLI will display sponsorship information in the same order as the queried package source, not performing any sorting of its own 
- **CLI-only scope.** PM UI (Phase 2), popup link-out (Phase 3), Copilot/IDE, and NuGet.org/PM UI Search surfaces are deferred.
- **Freshness is cache-policy dependent.** Sponsorship data is fetched through the local HTTP cache, which currently has a fixed 30 minute TTL (time to live) 


## Rationale and alternatives

1. **Command alternatives**
- New `dotnet sponsor` verb: higher cost than adding a report flag, and inconsistent with how consumers already discover `--deprecated`/`--outdated`/`--vulnerable` information.

2. **Display alternatives**
- a default JSON-only output: inconsistent with existing report UX that consumers already expect from `dotnet list package`. **`--format json`** will be supported.

3. **Restore-time messaging**
- Restore is a noise-sensitive surface run on every build; An explicit, per-invocation `--sponsor` flag keeps this information fully opt-in without polluting the default build/restore loop.

**Impact of not doing this:** sponsorship links remain visible only on the nuget.org website; there is no way for `dotnet list package`, PM UI, or other client tooling to programmatically surface which dependencies are seeking sponsorship, limiting discoverability for package authors relying on this signal for funding.

## Prior Art

- **[`sponsor-link.md` (2023 community proposal)](https://github.com/NuGet/Home/blob/sponsor-link/proposed/2023/sponsor-link.md)**: closest precedent for the overall idea — introduced the `--sponsor` flag concept, sponsor metadata authors could set, a Visual Studio UI link, and an opt-in restore-time summary message.
- **`--deprecated`/`--vulnerable`**: Direct precedent for opt-in report flags that consumers already use and understand. `--sponsor` will follow the same invocation pattern.
- **PM UI's existing project/license/report-abuse links**: precedent for Phase 2 — PM UI already shows package-supplied links to consumers using an established, low-risk pattern.
- **[`nuget/home#14739`](https://github.com/nuget/home/issues/14739)**: Open issue for PM UI sponsorship button

## Unresolved Questions

- Sponsorship lookups use NuGet's local disk cache (30-minute default TTL) with no way to force a refresh today — should a `--no-cache`-equivalent be wired into `--sponsor` for v1, or is that deferred?

## Future Possibilities

- **Phase 2: VS Package Manager UI hyperlinks** for sponsorship links, directly addressing [nuget/home#14739](https://github.com/nuget/home/issues/14739).
- **Phase 3: Compact link-out CLI display** using template-driven website links (`nuget.org/.../{id}/sponsor`) once sponsor popup URLs are independently addressable.
- **Search and Browse Visibility** for PM UI Browse and nuget.org search experiences
- **Copilot/IDE surfaces**: See [Issue 14738](https://github.com/NuGet/Home/issues/14738)