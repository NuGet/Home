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
`dotnet list package --sponsor` is opt-in per invocation, run only when a developer actually wants this information, keeping sponsorship messaging out of the default build/restore loop while still making the data fully discoverable on demand.

## Who this affects

- **Package consumers** get a way to discover, from the command line, which of their dependencies are seeking sponsorship — without having to visit nuget.org for every package individually.
- **Package authors** who've already added sponsorship links to their packages get more visibility for those links, since consumers can now see them as part of a workflow they already use (`dotnet list package`), not just on the package's web page.
- **Repository/org admins** get transparency into which of their organization's dependencies have funding needs, which can support internal conversations about sponsoring critical open-source dependencies.

## Explanation

This proposal adds `--sponsor` to `dotnet list package`, following the same opt-in report pattern as `--deprecated`, `--outdated`, and `--vulnerable`.

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

When there are no packages looking for sponsors, there will be a message: 

```text
No packages in project 'Contoso.Tools' are looking for sponsors.
```

For private/internal feeds, users can explicitly query nuget.org sponsorship data:

```text
dotnet list package --sponsor --source nuget.org
```

- **Scope:** solution-wide across all projects.
- **Transitive packages:** respects `--include-transitive`; no sponsor-specific behavior is required.
- **Multiple sponsorship URLs:** up to 10 URLs are stored per package.
- **Empty state:** if a project has no sponsored packages, show a per-project message indicating none were found.

## Drawbacks

- **No link priority/reorder support** With append/remove semantics, default ordering is oldest-added first. Not a v1 design need per this proposal's scope.
- **CLI-only scope for v1.** PM UI (Phase 2), popup link-out (Phase 3), Copilot/IDE, and Azure Search-backed surfaces are deferred.
- **Freshness is cache-policy dependent.** Origin updates can be immediate, but user visibility depends on cache behavior.

## Rationale and alternatives

Proposed solution: a `--sponsor` flag on `dotnet list package`, so developers can discover which dependencies are seeking sponsors.

Alternatives considered:

1. **Discovery alternatives**
- Local cache or assets-file discovery: stale/non-authoritative for the current dependency graph — could show consumers outdated sponsorship information.
- Separate tool outside `dotnet`/`nuget.exe`: inconsistent with existing CLI patterns consumers already know.

2. **Command alternatives**
- New `dotnet sponsor` verb: higher cost than adding a report flag, and inconsistent with how consumers already discover `--deprecated`/`--outdated`/`--vulnerable` information.
- Combining sponsorship into an existing report flag: would blur `--sponsor`'s informational nature with report flags that call out actionable problems (deprecations, vulnerabilities), for limited benefit over a dedicated flag.

3. **Display alternatives**
- JSON-only output: inconsistent with existing report UX that consumers already expect from `dotnet list package`.
- Link-out popup flow: depends on separate nuget.org web work, deferred to Phase 3.

4. **Restore-time messaging**
- Restore is a noise-sensitive surface run on every build; An explicit, per-invocation `--sponsor` flag keeps this information fully opt-in without polluting the default build/restore loop.

**Impact of not doing this:** sponsorship links remain visible only on the nuget.org website; there is no way for `dotnet list package`, PM UI, or other client tooling to programmatically surface which dependencies are seeking sponsorship, limiting discoverability for package authors relying on this signal for funding.

## Prior Art

- **[`sponsor-link.md` (2023 community proposal)](https://github.com/NuGet/Home/blob/sponsor-link/proposed/2023/sponsor-link.md)**: closest precedent for the overall idea — introduced the `--sponsor` flag concept, sponsor metadata authors could set, a Visual Studio UI link, and an opt-in restore-time summary message.
- **[`nuget/home#14739`](https://github.com/nuget/home/issues/14739)**: open customer ask for a Package Manager UI sponsorship button, confirming real demand for Phase 2.
- **`--deprecated`/`--vulnerable`**: precedent for opt-in report flags that consumers already use and understand.
- **PM UI's existing project/license/report-abuse links**: precedent for Phase 2 — PM UI already shows package-supplied links to consumers using an established, low-risk pattern.

## Unresolved Questions



## Future Possibilities

- **Phase 2: VS Package Manager UI hyperlinks** for sponsorship links, directly addressing [nuget/home#14739](https://github.com/nuget/home/issues/14739).
- **Phase 3: Compact link-out CLI display** using template-driven website links (`nuget.org/.../{id}/sponsor`) once sponsor popup URLs are independently addressable.
- **Azure Search-backed visibility** for PM UI Browse and nuget.org search experiences, helping consumers discover sponsorship needs while browsing for packages.
- **Copilot/IDE surfaces**, per original customer interest cited in Motivation.