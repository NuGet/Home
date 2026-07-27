# **Surface Package Sponsorship Links to Developers**

- Author: [@kalebfik](https://github.com/kalebfik)
- GitHub Issue: [10703](https://github.com/NuGet/NuGetGallery/issues/10703)

## Summary

Package maintainers can already add sponsorship links (GitHub Sponsors, Patreon, Open Collective, etc.) to their packages on nuget.org. Developers only see this today if they visit the package's nuget.org page. 
This proposal brings that existing data into developer tooling — starting with a new `dotnet package list --sponsor` command — so developers can discover which dependencies are seeking sponsorship without leaving their workflow.

## Motivation

Sponsorship links already exist and are maintained by package owners on nuget.org.
The data is real and current, it's just invisible outside the website. 

This proposal adds a non-disruptive, opt-in way to surface sponsorship information, and is scoped as the first of three phases:

1. **Phase 1 (this proposal): CLI** — `dotnet package list --sponsor`.
2. **Phase 2: Visual Studio Package Manager UI** — surfacing sponsorship links using the same hyperlink pattern PM UI already uses for project/license/report-abuse URLs, directly addressing the demand in [nuget/home#14739](https://github.com/nuget/home/issues/14739).
3. **Phase 3: CLI popup link-out** — opening a nuget.org-hosted sponsorship page (`nuget.org/.../{id}/sponsor`) directly from the CLI, so developers get a richer, always-current destination without the CLI needing to hardcode or format every payment provider's link itself.

Providing sponsor links from nuget.org to the client is the key motivation for this proposal. 

### Why not restore?

Restore runs on every build; adding informational (non-actionable) content there, even opt-in, risks alarm fatigue and encourages developers to disable the feature entirely rather than engage with it. 
Restore is also performance-sensitive: checking sponsorship requires reaching out over the network for every package, and doing so as part of restore would slow down builds and add repeated network calls to the frequent background restores that happen automatically while editing code (e.g., to keep IntelliSense/autocomplete up to date), not just when a developer explicitly builds.

## Who this affects

- **Package consumers** get a way to discover, from the command line, which of their dependencies are seeking sponsorship — without having to visit nuget.org for every package individually.
- **Package authors** who've already added sponsorship links to their packages get more visibility for those links, since consumers can now see them as part of a workflow (`dotnet package list --sponsor`), not just on the package's web page.
- **Repository/org admins** have an easier way to see sponsorship status alongside the other package information they already manage day-to-day (versions, licenses, vulnerabilities).

## Explanation

This proposal adds a new `dotnet package list --sponsor` command, giving sponsorship discovery a dedicated and purpose-built surface. 

When you run `dotnet package list --sponsor`, output is grouped by project and includes sponsorship links for each matching package:

**One Sponsorship Link** 

```text
Top-level Package        Sponsor
> Contoso.Tools          https://github.com/sponsors/username
```
**Ten Sponsorship Links** (matching NuGet.org's current policy cap)

```text
Top-level Package        Sponsor
> Contoso.Utility        https://patreon.com/user
                         https://patreon.com/user2
                         https://opencollective.com/user
                         https://opencollective.com/user2
                         https://opencollective.com/user3
                         https://github.com/sponsors/user
                         https://github.com/sponsors/user2
                         https://ko-fi.com/123
                         https://ko-fi.com/456
                         https://ko-fi.com/789
```

Two distinct empty states are possible, and they are given distinct per-package markers so a user scanning only the table (not the source-level footnotes) can't confuse "this package has no sponsors" with "this source can't tell us either way":

- `(none)` — the source supports sponsorship data and confirms this package has no active sponsorship links.
- `(unsupported)` — the source does not provide sponsorship data at all, so no package from that source can be evaluated; this is a source-level limitation, not information about the package itself.

**Zero Sponsorship Links** (source supports sponsorship data; package has none)

```text
Top-level Package        Sponsor
> Contoso.Tools          (none)
```

**Source doesn't provide sponsorship information** 

```text
Top-level Package        Sponsor
> Contoso.Tools          (unsupported)

Source 'X' does not provide sponsorship data
```

Users may explicity specify a package source using `--source`. 

```text
dotnet package list --sponsor --source https://api.nuget.org/v3/index.json
```

`dotnet package list --sponsor` also supports JSON output via `--format json`. 
Since sponsorship is a per-package-ID concept independent of target framework, sponsorable packages are listed per-project under `sponsorablePackages`

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
            "https://github.com/sponsors/contoso",
            "https://patreon.com/sponsor/contoso-forms",
            "https://opencollective.com/contoso-forms"
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

### Distinguishing "No Sponsors" from "Source does not Provide Sponsorship Information" 

For package sources implementing this proposal, the sponsorshipUrls field is expected to be present in registration documents. 

If sponsorshipUrls is present and contains values, sponsorship information is displayed. 

If sponsorshipUrls is present but empty, the package is considered to have no sponsorship links.

If sponsorshipUrls is absent, the client treats sponsorship information as unavailable from that source. 

**Sample registration index response using NewtonSoft.Json:**

```json
{ 
  "@id": "https://api.nuget.org/v3/registration5-gz-semver2/newtonsoft.json/index.json",
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
    "https://github.com/sponsors/JamesNK"
  ],
  // ** End of proposal **//
  "items": [
    {
      "@id": "https://api.nuget.org/v3/registration5-gz-semver2/newtonsoft.json/index.json#page/3.5.8/12.0.1-beta2",
      "@type": "catalog:CatalogPage",
      "commitId": "afa91af1-9505-41b8-ad75-eab8e613db14",
      "commitTimeStamp": "2026-04-10T00:15:25.1492389+00:00",
      "count": 64,
      "items": [
        {
          "@id": "https://api.nuget.org/v3/registration5-gz-semver2/newtonsoft.json/3.5.8.json",
          "@type": "Package",
          "catalogEntry": {
            // ... additional catalog entry details
          }
        }
      ]
    }
  ]
}
```

- **Scope:** solution-wide across all projects.
- **Transitive packages:** Included by default; users can use `--exclude-transitive` to exclude them.
- **Multiple sponsorship URLs:** The CLI displays sponsorship URLs in the order received from the package source.
- **Empty state:** When a project has no sponsorable packages, display a per-project message indicating none were found.

## Drawbacks

- **No link priority/reorder support:** The CLI will display sponsorship information in the same order as the queried package source, not performing any sorting of its own.
- **CLI-only scope:** PM UI (Phase 2), popup link-out (Phase 3), Copilot/IDE, and NuGet.org/PM UI Search surfaces are deferred.


## Rationale and Alternatives

Why `dotnet package list --sponsor`? Why not `dotnet package sponsor`?

```bash
dotnet package sponsor
```

This approach treats sponsorships similarly to npm's `npm fund` command. 

Benefits considered: 
- Clear intent and discoverability
- Provides room for future sponsorship-focused experiences. 
- Naturally supports interactive workflows if introduced in future implementations. 

**Selected Approach** 

```bash
dotnet package list --sponsor 
```

This was chosen because sponsorship information is currently treated as package metadata rather than a standalone workflow.

Rationale: 
- Aligns with existing package reporting patterns
- Sponsorhsip information is retrieved alongside other package metadata.
- Allows reuse of existing package discovery and reporting infrastructure

The current proposal focuses on displaying sponsorship information rather than providing sponsorship-specific actions. 

1. **Command alternatives**
   - New `dotnet package fund` verb: mirrors `npm fund` naming, kept as an alternative naming option to `dotnet package sponsor`

2. **Display alternatives**
   - JSON-only output: inconsistent with existing report UX that consumers already expect from `dotnet list package`. **`--format json`** will be supported.

3. **Restore-time messaging**
   - Restore is a noise-sensitive surface run on every build; an explicit, per-invocation command keeps this information fully opt-in without polluting the default build/restore loop.

4. **Bake sponsorship into package metadata**
   - `npm fund` has precedent for this; the `funding` field lives directly in package metadata.
   - npm's own guidance suggests keeping funding links at the package or author level.
   - Doing the same for NuGet could be noisy for the CLI, and stale sponsorship information would be problematic.

**Impact of not doing this:** Sponsorship links remain visible only on the nuget.org website. There would be no way for the CLI, PM UI, or other client tooling to programmatically surface which dependencies are seeking sponsorship, limiting discoverability for package authors relying on this signal for funding.

## Prior Art

- **[2023 community proposal](https://github.com/NuGet/Home/blob/sponsor-link/proposed/2023/sponsor-link.md)**: Initial community proposal for the overall idea — introduced the `--sponsor` flag concept, sponsor metadata authors could set, a Visual Studio UI link, and an opt-in restore-time summary message.
- **[`npm fund`](https://docs.npmjs.com/cli/v10/commands/npm-fund/)**: `npm fund` provides precedent for this pattern. The `funding` field lives in package metadata, and npm's guidance suggests keeping funding links at the package or author level. 
npm notes that funding information can be noisy in the CLI and stale information could be problematic.
- **[Gallery UI Sponsorship Implementation](https://github.com/NuGet/Engineering/blob/prabora-needs-sponsorship-feature/Server.Specs/2025/NeedsSponsorship.md)**: companion server-side proposal for surfacing sponsorship needs directly in the nuget.org Gallery UI; relevant precedent/parallel effort for surfacing the same underlying sponsorship data.
- **`--deprecated`/`--vulnerable`**: precedent for opt-in report-style information that consumers already use and understand, informing this proposal's output/UX conventions even though it uses a dedicated verb rather than a flag.
- **PM UI's existing project/license/report-abuse links**: precedent for Phase 2 — PM UI already shows package-supplied links to consumers using an established, low-risk pattern.
- **[`nuget/home#14739`](https://github.com/nuget/home/issues/14739)**: Open issue for PM UI sponsorship button

## Unresolved Questions

None at this time

## Future Possibilities

While `dotnet package list --sponsor` is the proposed experience, future iterations could expand functionality:

**Enhanced CLI Experiences:**
- Interactive sponsor selection experiences.
- Filtering, grouping, or prioritizing sponsorship opportunities.
- Additional ecosystem engagement scenarios inspired by commands like `npm fund`.

- **Phase 2: VS Package Manager UI hyperlinks** for sponsorship links, directly addressing [nuget/home#14739](https://github.com/nuget/home/issues/14739).
- **Phase 3: Compact link-out CLI display** using template-driven website links (`nuget.org/.../{id}/sponsor`) once sponsor popup URLs are independently addressable.
- **Search and Browse Visibility** for PM UI Browse and nuget.org search experiences
- **Copilot/IDE surfaces**: See [Issue 14738](https://github.com/NuGet/Home/issues/14738)

## Appendix
NPM Fund Comparison

NPM provides a dedicated `npm fund` command that helps developers discover funding opportunities for packages they depend on.
Package authors specify funding information directly in their package metadata using the `funding` field. 

```json
{
  "funding": {
    "type": "individual",
    "url": "http://example.com/donate"
  },

  "funding": {
    "type": "patreon",
    "url": "https://www.patreon.com/my-account"
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
├── https://github.com/sponsors/expressjs
│   └── express@4.21.2
├── https://opencollective.com/babel
│   └── @babel/core@7.28.0
└── https://github.com/sponsors/sindresorhus
    └── p-limit@7.1.1
```

### Characteristics of npm's approach

- Funding information is stored within package metadata.
- Funding information is distributed through the package ecosystem.
- Funding discovery has dedicated command surface (`npm fund`).

## Comparison with Proposed Approach

### Metadata Source

#### NPM

Funding information is directly embedded in package metadata and distributed throughout the npm ecosystem

#### NuGet

Sponsorship information is retrieved from the selected package source and surfaced through client tooling

### Command Surface

#### NPM

```bash
npm fund
```

Dedicated funding workflow. 

#### NuGet

```bash
dotnet package list --sponsor
```

Report-style experience aligned with existing commands.

## Why not mirror npm exactly?

1. Sponsorship information is treated as package metadata that's exposed by a package source instead of stored directly.
2. Sponsorship discovery follows existing NuGet resolution behavior 
3. Restore output remains unchanged to avoid additional noise.
Users explicitly opt into sponsorship discovery instead of receiving sponsorship messaging during restore operations. 
