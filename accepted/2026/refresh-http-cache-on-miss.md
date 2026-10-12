# Refresh the HTTP cache when a requested package version is missing

- Author: [@AdamStachowicz](https://github.com/AdamStachowicz)
- GitHub Issue: [NuGet/Home#3116](https://github.com/NuGet/Home/issues/3116)

## Summary

When NuGet restore is asked to install a specific package version and the cached `index.json` (registration / versions list) for that package on a given V3 source does not contain the requested version, NuGet should treat the cache entry as potentially stale and transparently refresh it from the origin once before failing the restore. Today the cached document is reused for its full TTL (30 minutes by default), which causes spurious "package not found" failures for users who push and immediately consume packages from private feeds. This proposal adds a single, bounded, opportunistic refresh on a "version miss" so that the common case stays fast while the failing case becomes self-healing without users having to discover `--no-cache`, `RestoreNoCache`, or manual cache clearing.

## Motivation

Issue [#3116](https://github.com/NuGet/Home/issues/3116) has been open since 2016 with 87+ 👍 reactions and frequent comments from teams whose CI pipelines and developer inner loops break in the same way:

1. A package version `X 1.0.2` is published to a private feed (Azure Artifacts, GitHub Packages, ProGet, MyGet, internal NuGet.Server, etc.).
2. A consuming repository updates its `<PackageReference>` to `1.0.2` and runs `dotnet restore` / `nuget restore` / restore-on-build.
3. Some machines fail with `NU1102` ("Unable to find package X with version (>= 1.0.2)") even though the package is available on the feed, because the machine has a cached versions list from before publication and the cache TTL has not expired.

The HTTP cache for the V3 protocol stores the `index.json` (registration index) and the versions list per `(package id, source)`. The default TTL is 30 minutes (`HttpSourceCacheContext.DefaultMaxAge`) and the cache is keyed by URI, so until the TTL expires every restore on that machine sees the same stale list. The cache was designed to amortize the cost of repeated lookups, not to be authoritative about whether a specific version exists.

The only existing workarounds are all unsatisfactory:

- `restore --no-cache` / `RestoreNoCache=true` — works, but every consumer has to know to set it, it skips the HTTP cache for *every* request (not just the missing one), and it has to be applied per build / per project / per machine. It also is not honoured by the MSBuild SDK resolver, so it does not help SDK references ([#7777](https://github.com/NuGet/Home/issues/7777)).
- `dotnet nuget locals http-cache --clear` — needs to be re-run on every affected machine and build agent, often by an administrator; users in [#3116](https://github.com/NuGet/Home/issues/3116) report doing this multiple times per week across fleets of build agents.
- Waiting 30 minutes for the cache to expire — wastes developer and pipeline time and is not viable on shared CI agents that keep producing failures during that window.

The expected outcome of this proposal: when a user asks for an exact version that the cached document says does not exist, NuGet does what every other cache does — it consults the origin once before declaring the item missing.

## Explanation

### Functional explanation

#### Before

```
> dotnet restore
error NU1102: Unable to find package Contoso.Foo with version (>= 1.0.2)
  - Found 5 version(s) in contoso [ Nearest version: 1.0.1 ]
```

The user pushed `Contoso.Foo 1.0.2` to `contoso` two minutes ago, the feed already serves it, but the local HTTP cache from the previous restore still lists only versions up to `1.0.1`. The restore fails. The user has to know to run `dotnet nuget locals http-cache --clear` or rerun with `--no-cache`.

#### After

```
> dotnet restore
  Restored C:\src\app\app.csproj (in 4.2 sec).
```

NuGet noticed the cached versions list for `Contoso.Foo` on `contoso` did not include `1.0.2`, refreshed that one document from the origin, found `1.0.2`, and continued. No flag, no manual cache clear. If the package is genuinely not on the feed **and** the first lookup already went to origin, there is no second GET. If the first answer came from the HTTP cache, one extra origin GET confirms the miss, then restore fails with `NU1102` as today. Successful restores whose cache already contains the version do no extra HTTP.

The behaviour is observable at minimal log level:

```
info :   CACHE https://pkgs.contoso.com/v3/flat2/contoso.foo/index.json
info :   Cached versions for 'Contoso.Foo' did not contain a version satisfying '[1.0.2, )'; refreshing the HTTP cache once before failing.
info :   GET https://pkgs.contoso.com/v3/flat2/contoso.foo/index.json
info :   OK https://pkgs.contoso.com/v3/flat2/contoso.foo/index.json 312ms
```

#### When does refresh happen

NuGet performs at most one refresh per `(package id, source)` per restore, and only when **all** of the following are true:

1. The lookup is an exact, min-inclusive, non-floating version range (for example `[1.0.2, )` from a `PackageReference` Version). Floating ranges (`1.0.0-*`) are not refreshed in this change (traffic amplification).
2. The versions document was served from the on-disk HTTP cache (`HttpSourceResultStatus.OpenedFromDisk`). A download that then writes the cache file is recorded as `OpenedFromNetwork` and is **not** refreshed again in the same restore.
3. Every HTTP source missed on the first pass (a hit on nuget.org does not refresh a private feed that simply does not have the package).
4. `NUGET_HTTP_CACHE_REFRESH_ON_MISS` is not `false` or `0`.

When the refresh happens, NuGet uses `SourceCacheContext.WithRefreshCacheTrue()` (`MaxAge = now`, `RefreshMemoryCache = true`) so the origin document overwrites the cache file. Subsequent restores in the same TTL window then see a fresh document.

#### Configuration

The refresh-on-miss behaviour is on by default. This change ships **one** opt-out:

- Environment variable: `NUGET_HTTP_CACHE_REFRESH_ON_MISS=false` (also `0`; case-insensitive `false`). Any other value, including unset, leaves the behaviour on.

`--no-cache` continues to skip the HTTP cache for all requests. `nuget.config` / MSBuild knobs and restore telemetry for this feature are **not** in this change (see Unresolved Questions / Future Possibilities).

### Technical explanation

#### Where the change lives

The relevant code lives in [NuGet/NuGet.Client](https://github.com/NuGet/NuGet.Client):

- `HttpSource.GetAsync` — `OpenedFromDisk` only when an **existing** cache file was read; a download that writes a new cache file is `OpenedFromNetwork`.
- `HttpFileSystemBasedFindPackageByIdResource` and `RemoteV2FindPackageByIdResource` — record `IVersionListCacheInfo` / `VersionListFetchKind` per package id. `RemoteV3FindPackageByIdResource` does not observe `HttpSourceResult` today and stays `Unknown` (fail closed: no refresh).
- `SourceRepositoryDependencyProvider` — one refresh per id per shared provider; skip when kind is not `HttpCache` or origin already answered this restore.
- `ResolverUtility.FindLibraryByVersionAsync` — when **two or more** HTTP sources are present, a first pass sets `SuppressHttpCacheRefreshOnMiss` and a second pass runs only if every HTTP source missed. A single HTTP source (with or without local folders) skips that clone and second walk; refresh-on-miss stays in `SourceRepositoryDependencyProvider`.
- `VersionListSourceMap` — records `HttpCache` vs `Network` per id without `AddOrUpdate` closures (`TryAdd` / `TryUpdate`). Network wins if both are observed.

`IVersionListCacheInfo`, `VersionListFetchKind`, and `SuppressHttpCacheRefreshOnMiss` are public because product assemblies cannot use this repo’s `InternalsVisibleTo` (those attributes are stamped with the test signing key).

#### Algorithm

Lookups run through `SourceRepositoryDependencyProvider` (shared across projects in a restore) and `HttpSource.GetAsync`, which already reports `OpenedFromDisk` vs `OpenedFromNetwork`.

1. Acquire the versions document via `HttpSource.GetAsync` with the existing `HttpSourceCacheContext`. Record whether it came from the HTTP cache or from origin.
2. Parse the version list as today.
3. HTTP sources are queried in parallel. If there is **more than one** HTTP source, refresh-on-miss is suppressed on this first pass. If any HTTP source (or a local source) satisfies the exact version, restore continues and no source is refreshed — a miss on a private feed does not add traffic when nuget.org (or another feed) already has the package. If there is only one HTTP source, that pass is not suppressed (no extra clone or second walk).
4. Only if **every** HTTP source missed: for each source whose first answer was `OpenedFromDisk` (or an in-memory copy of that cached document), refresh **once** per `(id, source)` using `SourceCacheContext.WithRefreshCacheTrue()` (`MaxAge = now`, `RefreshMemoryCache = true`). Sources whose first answer was `OpenedFromNetwork` are not contacted again.
5. Re-run the satisfiability check against the refreshed document. If the version is still not present, fail with `NU1102` as today.

The per-source gate lives on the shared `SourceRepositoryDependencyProvider` instance (`ConcurrentDictionary` of ids already refreshed / already fetched from origin this operation), so many projects in one restore still cause at most one refresh per `(id, source)`.

#### Floating ranges

This change does **not** refresh on floating ranges (`1.0.0-*`, etc.). That matches the traffic-amplification concern from review: a floating miss is common while the graph is still walking, and a refresh-per-id there would not stay bounded to “about to fail restore”. Exact `PackageReference` versions are the #3116 report. A later follow-up can add the [@NinoFloris](https://github.com/NuGet/Home/issues/3116#issuecomment-540884810) heuristic (refresh only when the floating lower bound is above every cached version).

#### Interaction with `--no-cache` and global packages folder

- `--no-cache` already bypasses the HTTP cache; this proposal does not change its behaviour.
- The Global Packages Folder (`%userprofile%/.nuget/packages`) is unaffected — refresh-on-miss only operates against the HTTP cache layer (`%localappdata%/NuGet/v3-cache`).
- If the package exists in the GPF, NuGet still resolves it from there as today; the HTTP cache is only consulted when the GPF does not satisfy the request.

#### Performance

See Drawbacks (item 5) for CPU. Steady-state successful restore: **zero extra origin GETs**. Extra HTTP exists only on the path that was about to fail (or that #3116 would have failed), and only when that source’s first answer was a disk-cache hit.

This is consistent with [@nkolev92's analysis](https://github.com/NuGet/Home/issues/3116#issuecomment-540879988): the extra network cost is bounded by the number of distinct package ids whose **cached** version list does not satisfy the request after every HTTP source missed, which in steady state is zero.

## Drawbacks

1. **Extra HTTP only on cache-backed misses after every HTTP source failed.** At most one extra origin GET per `(id, source)` before `NU1102`. If the first lookup already hit origin, extra GETs are zero. The user's alternative today is `--no-cache`, which issues *many* extra requests.
2. **No extra HTTP on successful multi-source restores.** Refresh is deferred until every HTTP source missed.
3. **Surprises offline users who relied on cached negatives** — a small population (e.g. [@binki](https://github.com/NuGet/Home/issues/3116#issuecomment-2855244557)) uses the cache as an authoritative "this version doesn't exist" oracle when offline. Mitigation: `NUGET_HTTP_CACHE_REFRESH_ON_MISS=false`. Offline users who hit the refresh path will see a network error rather than `NU1102`, which is more accurate.
4. **One env var.** No nuget.config / MSBuild surface in this change. `WithRefreshCacheTrue()` reuses existing cache plumbing.
5. **Tiny CPU only when two or more HTTP sources are used:** clone `SourceCacheContext` and suppress refresh on pass 1. A single-feed restore does not clone or walk HTTP sources twice. Recording cache vs origin does not allocate per lookup. No extra HTTP when any HTTP source hits.

## Rationale and alternatives

### Why refresh-on-miss rather than not caching 404s

Multiple commenters on the issue ask why NuGet caches 404s. As [@nkolev92 clarified](https://github.com/NuGet/Home/issues/3116#issuecomment-540879988), NuGet does *not* cache 404s — it caches the versions list, which is a 200 response. The problem is that the cached 200 doesn't contain the version the user wants. "Stop caching 404s" is therefore not actionable; "refresh the cached versions list when it doesn't satisfy the request" is the actionable equivalent.

### Why not shorten the TTL

Lowering the default 30-minute TTL would reduce the failure window proportionally but would also increase HTTP traffic for *every* restore, including the 99%+ that don't need a refresh. Refresh-on-miss keeps the amortization benefit of the cache for the common case and pays the cost only when the cache is actually wrong.

### Why not always go to origin for exact-version lookups

This is essentially `--no-cache` for registration. It would solve the bug but at the cost of a request-per-package on every restore, which is exactly what the cache was introduced to avoid. The proposal targets the smaller subset of cases where the cache demonstrably cannot satisfy the request.

### Why not rely on `Cache-Control` from the feed

[@mungojam suggested](https://github.com/NuGet/Home/issues/3116#issuecomment-1040261486) honouring `Cache-Control: no-cache` from the server. This is complementary and worth doing as a separate improvement, but it does not solve #3116 because most feeds (including nuget.org and Azure Artifacts) serve cacheable responses; the issue is that the *content* of the cached response is stale relative to what the feed could now serve.

### Impact of not doing this

The issue has been the most-thumbsed-up open HTTP-caching issue for nearly a decade. Every quarter brings a new comment from a team that lost hours to it. Closing it ships a meaningful inner-loop and CI quality improvement and removes a recurring source of user frustration that is regularly cited externally as an example of the package manager misbehaving.

## Prior Art

- **Cargo** (Rust) revalidates the registry index on demand and refreshes it when a requested version is not present locally; users do not need a `--no-cache` analog for the publish-then-consume scenario.
- **npm** issues a metadata request to the registry on each install by default and uses HTTP cache validators (`If-None-Match` / 304); a stale cached document does not prevent finding a newly published version.
- **pip** with `--index-url` revalidates the simple index on demand; the package finder does not treat a cached page as authoritative for "version does not exist".
- Within NuGet itself, the **PackageManagement UI** in Visual Studio already performs a refresh on the version list when the user explicitly browses for a version, which is why the bug is far less visible in the UI than at the command line — exactly what users keep pointing out on the issue thread.

## Unresolved Questions

1. Cached 404s for a missing package **id**: NuGet does not store 404s in the on-disk HTTP cache. In-session "not available" memory is already preceded by an HTTP call ([review on Home#14872](https://github.com/NuGet/Home/pull/14872)). This change does not add a second origin GET in that case.
2. `nuget.config` / MSBuild opt-out and restore telemetry (`HttpCacheRefreshOnMissCount`) were in earlier drafts; this implementation ships the env-var opt-out only. Fold into a broader HTTP cache policy later if needed.
3. Registration-based V3 (`RemoteV3FindPackageByIdResource`) does not report `VersionListFetchKind` yet (fail closed). Flat-container V3 and V2 HTTP do. Should V3 registration grow the same recording in a follow-up?

## Future Possibilities

- **Server-driven freshness signals.** Once feeds publish a versions/last-modified manifest (à la [#3389](https://github.com/NuGet/Home/issues/3389)), refresh-on-miss can be generalized into "refresh when the feed says newer data exists", removing even the one extra request on the miss path.
- **Conditional GETs (`If-None-Match`).** The same plumbing can be extended so refreshes use ETags / `Last-Modified` and benefit from 304 responses, further reducing traffic.
- **Apply to MSBuild SDK resolver.** Once the client has a stable refresh-on-miss primitive, the MSBuild SDK resolver ([#7777](https://github.com/NuGet/Home/issues/7777)) can adopt it and finally close the gap that `RestoreNoCache` does not bridge today.
- **UI surfacing.** Visual Studio's Package Manager UI can call out when a refresh-on-miss occurred so users learn that NuGet self-corrected, building trust in the cache.
- **nuget.config / MSBuild opt-out and restore telemetry**, if review wants a knob besides `NUGET_HTTP_CACHE_REFRESH_ON_MISS`.
- **Floating-range refresh** when the cached max version is below the floating lower bound.
