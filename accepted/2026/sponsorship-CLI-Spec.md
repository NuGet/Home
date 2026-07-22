# NuGet.Client CLI Sponsorship Support

- Author: [@kalebfik](https://github.com/kalebfik)
- GitHub Issue: [NuGet/NuGetGallery#10703](https://github.com/NuGet/NuGetGallery/issues/10703)

## Summary

Add sponsorship reporting to the NuGet CLI for installed packages.

The command surface has two potential commands:

- Candidate A: extend `dotnet package list` with `--sponsor` (also available through the legacy alias `dotnet list package --sponsor`)
- Candidate B: add a new `dotnet package sponsor` subcommand

Both candidates reuse the same metadata-fetch and rendering pipeline, with:

- A `Sponsor` column in console output
- A `sponsorshipUrls` array in JSON output

## Explanation

### Functional explanation

Both command candidates produce the same sponsorship data:

```bash
# Candidate A
dotnet package list --sponsor

# Candidate B
dotnet package sponsor
```

The target project or solution remains positional for either candidate.

Console and JSON entry points stay parallel:

```bash
# Console
dotnet package list --sponsor
dotnet package sponsor

# JSON
dotnet package list --sponsor --format json
dotnet package sponsor --format json
```

**Zero sponsors**

```text
Top-level Package        Sponsor
> Contoso.Tools          (none)
```

```json
{
  "id": "Contoso.Tools",
  "sponsorshipUrls": []
}
```

**Source does not provide sponsorship data**

```text
Top-level Package        Sponsor
> Contoso.Tools          (none)

Source 'X' does not provide sponsorship data
```

**One sponsor**

```text
Top-level Package        Sponsor
> Contoso.Tools          https://github.com/sponsors/username
```

```json
{
  "id": "Contoso.Tools",
  "sponsorshipUrls": [
    "https://github.com/sponsors/username"
  ]
}
```

**Ten sponsors** (matching NuGet.org's current policy cap)

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

```json
{
  "id": "Contoso.Utility",
  "sponsorshipUrls": [
    "https://patreon.com/user",
    "https://patreon.com/user2",
    "https://opencollective.com/user",
    "https://opencollective.com/user2",
    "https://opencollective.com/user3",
    "https://github.com/sponsors/user",
    "https://github.com/sponsors/user2",
    "https://ko-fi.com/123",
    "https://ko-fi.com/456",
    "https://ko-fi.com/789"
  ]
}
```

Packages with no sponsorship data display `(none)` in console output and `[]` in JSON.

### Technical explanation

Both command candidates share one sponsor-report model and one metadata pipeline.

- Candidate A extends `ListPackageCommand` with a new report flag.
- Candidate B registers `dotnet package sponsor` but still routes into the same metadata-fetch, model, and renderer internals.

Planned code updates:

- `ListPackageCommand.cs`
  - Candidate A: add `--sponsor`, extend mutual-exclusion validation, and map the flag to `ReportType.Sponsor` in `GetReportType`.
  - Candidate B: map the new command to the same sponsor report mode before invoking the existing downstream pipeline.
- `ReportType.cs` and `ListPackageArgs.cs`
  - Add `ReportType.Sponsor` and carry it through list-package arguments.
- `ListPackageCommandRunner.cs`
  - Fetch sponsorship metadata through the same source-metadata path used by other report types.
  - Update `UpdatePackagesWithSourceMetadata` so overwrite logic triggers when sponsorship data exists; otherwise fetched `SponsorshipUrls` can be dropped before rendering.
  - Add per-package failure isolation inside `ThrottledForEachAsync` so one metadata failure surfaces as `(error)` / `problems` without aborting the report.
- `ListReportPackage.cs`
  - Add `SponsorshipUrls`, following existing constructor/overload patterns used by vulnerability and deprecation data.
- `ProjectPackagesPrintUtility.cs`
  - Update `GetFrameworkPackageMetadata` to populate sponsorship data conditionally.
- `ListPackageConsoleRenderer.cs`
  - Render `Sponsor`, `(none)`, and `(error)`, along with aligned continuation lines for multiple URLs.
- `ListPackageJsonRenderer.cs`
  - Emit ordered `sponsorshipUrls` and include non-fatal fetch issues in `problems` while preserving package entries.
- `RegistrationIndex.cs` and `PackageMetadataResourceV3.cs`
  - Propagate `sponsorshipUrls` from registration index payloads to metadata objects consumed by the list pipeline.

#### Data assumptions

- The client expects optional `sponsorshipUrls` as `IReadOnlyList<string>`.
- Missing, `null`, or empty values all mean no sponsorship data.
- Console output uses `(none)`; JSON output uses `[]`.
- Multiple URLs preserve server order and show as extra rows directly under the previous sponsorship link. 

#### Source transport dependency and client abstraction

This proposal assumes the CLI consumes sponsorship data from the Registration API.
This document defines client behavior only when that data is available.

#### Testing strategy

- `DotnetListPackageTests.cs`
  - Add command-surface tests for zero, one, and ten sponsors.
  - Verify `(none)`, single inline URL, continuation-line alignment, and `Sponsor` column behavior with transitive packages.
- `DotnetListPackageTests.cs`
  - Add JSON-path variants that verify `sponsorshipUrls: []`, one-element arrays, and ten-element arrays in preserved order.
- `ListPackageCommandRunnerTests.cs`
  - Verify sponsorship metadata triggers `UpdatePackagesWithSourceMetadata` overwrite behavior.
  - Verify one package metadata failure remains isolated and does not fail the full report (exit code remains 0 once isolation behavior lands).
- `ProjectPackagesPrintUtilityTests.cs`
  - Add unit tests for sponsor-only logic in `GetFrameworkPackageMetadata`.
- List-package model tests
  - Cover `ListReportPackage` sponsorship constructor/property wiring.
- `XplatListPackageJsonRendererTests.cs`
  - Validate zero/one/many sponsor URLs and `problems` output for non-fatal metadata fetch failures.
- Multi-source coverage
  - Add sponsorship scenarios where one source fails and another succeeds, confirming partial results with warnings.

#### Extending to NuGet.exe

`NuGet.exe` does not have a project-level installed-package reporting command equivalent to `dotnet package list`.

- `NuGet.exe list` is marked `[DeprecatedCommand(typeof(SearchCommand))]`.
- `NuGet.exe list` and `NuGet.exe search` query sources for available packages, rather than reading a project's installed package graph.

`SearchCommand.cs` uses `PackageSearchResourceV3` via V3 Search endpoints, not `PackageMetadataResourceV3` / `RegistrationsBaseUrl`. As a result, sponsorship data arriving only via Registration API does not automatically appear in NuGet.exe search/list output.

Supporting NuGet.exe on this feature would likely require the Search index/response path to also publish `sponsorshipUrls`.
That is a real dependency and should be treated as a follow-on extension.

## Drawbacks

- Sources that do not emit sponsorship data cannot display sponsor URLs.
- Scope is CLI-only in v1; PM UI and IDE surfaces are deferred.

## Rationale and alternatives

| Dimension | `dotnet package list --sponsor` | `dotnet package sponsor` |
|---|---|---|
| Pros | Aligns with existing list report flags (`--deprecated`, `--outdated`, `--vulnerable`) and established user workflow; no new command registration. | Improves discoverability; gives sponsorship a dedicated, tab-completable verb. |
| Cons | Adds another mutually exclusive flag to an already busy command surface; not visible unless users already check `dotnet package list -h`. | Adds a new command entry point even though execution reuses list-package internals; creates two paths to identical data. |
| Implementation cost | Lowest: one new flag, one new `ReportType` value, and an extended mutex-count check in `ListPackageCommand.GetReportType`. | Medium: new command registration in `Program.cs`, a routing shim into `ListPackageCommandRunner`, and duplicate console/JSON coverage. |

## Prior Art

- [2023 community sponsor-link proposal](https://github.com/NuGet/Home/blob/sponsor-link/proposed/2023/sponsor-link.md)
- [`npm fund`](https://docs.npmjs.com/cli/v10/commands/npm-fund/)
- Existing report-style CLI surfaces: `--deprecated`, `--vulnerable`, `--outdated`
- PM UI's existing package link surfaces (project/license/report abuse)
- [nuget/home#14739](https://github.com/nuget/home/issues/14739) (PM UI sponsorship button request)

## Unresolved Questions

1. Which command surface ships: `dotnet package list --sponsor` or `dotnet package sponsor`?
2. Should `--include-transitive` be supported?
For example, if package A depends on package B, should sponsorship data for package B also be shown?
3. Should the command special-case NuGet.org by default?
If not, users must continue to explicitly set `--source` when they want NuGet.org sponsorship data.

## Future Possibilities

- Phase 2: Visual Studio Package Manager UI sponsorship hyperlinks, following existing PM UI link patterns and addressing [nuget/home#14739](https://github.com/nuget/home/issues/14739).
- Phase 3: CLI link-out to a NuGet.org-hosted sponsorship destination (for example, `nuget.org/.../{id}/sponsor`) for richer provider-specific experiences.
