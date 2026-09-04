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

NuGet noticed the cached versions list for `Contoso.Foo` on `contoso` did not include `1.0.2`, refreshed that one document from the origin, found `1.0.2`, and continued. No flag, no manual cache clear. If the package is genuinely not on the feed, the second lookup confirms this and the restore fails as it does today, with no extra latency in the (overwhelming majority of) restores where the cache is up to date.

The behaviour is observable in the diagnostic-level restore log:

```
info :   GET https://pkgs.contoso.com/v3/registration5-gz-semver2/contoso.foo/index.json
info :   CACHE https://pkgs.contoso.com/v3/registration5-gz-semver2/contoso.foo/index.json
info :   Cached versions for 'Contoso.Foo' on 'contoso' did not contain 1.0.2; refreshing.
info :   GET https://pkgs.contoso.com/v3/registration5-gz-semver2/contoso.foo/index.json
info :   OK https://pkgs.contoso.com/v3/registration5-gz-semver2/contoso.foo/index.json 312ms
```

#### When does refresh happen

NuGet performs at most one refresh per `(package id, source)` per restore, and only when **all** of the following are true:

1. The lookup is for an exact version (or for a floating range whose lower bound is higher than every version in the cached list).
2. The cached document was served from the HTTP cache (i.e. NuGet did not already go to the origin during this restore for this URL).
3. The required version is not present in the cached document.
4. The user has not opted out (see "Configuration" below).

When the refresh happens, NuGet reissues the request with `Cache-Control: no-cache` semantics so the response is fetched from the origin, the cache file is overwritten atomically, and the new document is used for the rest of the restore. Subsequent restores in the same time window then see a fresh document and never trigger the refresh path.

#### Configuration

The refresh-on-miss behaviour is on by default. It can be disabled in the rare case where it is undesirable (e.g. a user intentionally wants the cache to be authoritative for offline builds — see [@binki's comment on #3116](https://github.com/NuGet/Home/issues/3116#issuecomment-2855244557)) via:

- `nuget.config`:

  ```xml
  <configuration>
    <config>
      <add key="http_cache_refresh_on_miss" value="false" />
    </config>
  </configuration>
  ```

- Environment variable: `NUGET_HTTP_CACHE_REFRESH_ON_MISS=false`.
- MSBuild property: `<RestoreHttpCacheRefreshOnMiss>false</RestoreHttpCacheRefreshOnMiss>`.

The default is `true`. `--no-cache` continues to behave as it does today (skip the HTTP cache for all requests).

### Technical explanation

#### Where the change lives

The relevant code lives in [NuGet/NuGet.Client](https://github.com/NuGet/NuGet.Client), in the V3 HTTP source stack:

- `src/NuGet.Core/NuGet.Protocol/HttpSource/HttpSource.cs`
- `src/NuGet.Core/NuGet.Protocol/HttpSource/HttpSourceCacheContext.cs`
- `src/NuGet.Core/NuGet.Protocol/Resources/RegistrationResourceV3.cs`
- `src/NuGet.Core/NuGet.Protocol/Resources/RemoteV3FindPackageByIdResource.cs`
- `src/NuGet.Core/NuGet.Protocol/Resources/HttpFileSystemBasedFindPackageByIdResource.cs`

These are the components that resolve a `(package id, version)` to a content URL using a cached registration / flat-container `index.json`.

#### Algorithm

For each `(package id, source)` lookup performed by `FindPackageByIdResource.GetAllVersionsAsync` and the registration resource:

1. Acquire the cached document via `HttpSource.GetAsync` with the existing `HttpSourceCacheContext`.
2. Parse the version list as today.
3. If a caller (the dependency resolver) subsequently asks "does this list satisfy version `v`?" and the answer is no, mark the `(id, source)` as a candidate for refresh.
4. Before returning `NU1102`, if any `(id, source)` was marked and refresh-on-miss is enabled and refresh has not already been attempted for that `(id, source)` in this restore, reissue the same request with `HttpSourceCacheContext` `DirectDownload = false` and `MaxAge = TimeSpan.Zero` (forces revalidation; this is what `--no-cache` already uses internally).
5. Re-run the satisfiability check against the refreshed document. If the version is still not present, fail with `NU1102` as today (the error message is unchanged so existing diagnostics remain valid).

The refresh attempt is recorded in a per-restore `ConcurrentDictionary<(string id, string sourceUrl), byte>` so a package referenced from many projects in the same solution causes at most one refresh.

#### Floating ranges

The same logic applies to floating versions whose lower bound is greater than the maximum version in the cached list — exactly the heuristic [@NinoFloris suggested](https://github.com/NuGet/Home/issues/3116#issuecomment-540884810). For floating ranges that are already satisfied by the cached list, no refresh occurs (the cache may be slightly behind the feed, but that is the trade-off the cache exists to make and is unchanged from today's behaviour). This keeps the new code path scoped to "the cache cannot satisfy the request" and avoids amplifying traffic for normal restores.

#### Interaction with `--no-cache` and global packages folder

- `--no-cache` already bypasses the HTTP cache; this proposal does not change its behaviour.
- The Global Packages Folder (`%userprofile%/.nuget/packages`) is unaffected — refresh-on-miss only operates against the HTTP cache layer (`%localappdata%/NuGet/v3-cache`).
- If the package exists in the GPF, NuGet still resolves it from there as today; the HTTP cache is only consulted when the GPF does not satisfy the request.

#### Performance

The added cost in the failure-prone case is exactly one extra HTTP round-trip for the affected `(id, source)`. In the common case (cache is up to date) there is no extra HTTP traffic at all. The refresh is bounded:

- At most one refresh per `(id, source)` per restore.
- Only when the cached document was actually used (no double-fetch when the document was already fetched fresh).
- Only when the requested version is not present — i.e. the restore was *about* to fail anyway.

This is consistent with [@nkolev92's analysis](https://github.com/NuGet/Home/issues/3116#issuecomment-540879988): the perf impact is bounded by the number of distinct package ids whose cached version list does not satisfy the request, which in steady state is zero.

#### Telemetry

A new restore telemetry property `HttpCacheRefreshOnMissCount` is emitted per restore (count of `(id, source)` refreshes triggered). This makes the impact of the change observable on real-world feeds and gives the team a signal to tune the heuristic or scope it further if it produces unexpected traffic.

## Drawbacks

1. **Extra HTTP traffic on failing restores.** A restore that would have failed with `NU1102` now issues one additional request per missing `(id, source)` before failing. We consider this acceptable because: (a) it only happens on the failure path, (b) it's bounded to one extra request per `(id, source)` per restore, and (c) the user's alternative today is to rerun the restore with `--no-cache`, which issues *many* extra requests.
2. **Surprises offline users who relied on cached negatives** — a small population (e.g. [@binki](https://github.com/NuGet/Home/issues/3116#issuecomment-2855244557)) intentionally relies on the cache as an authoritative "this version doesn't exist" oracle when offline. Mitigation: the new behaviour is opt-out via `nuget.config`, an environment variable, or an MSBuild property. Offline users who hit the refresh path will see a network error rather than `NU1102`, which is in fact more accurate.
3. **One more knob.** Adding `http_cache_refresh_on_miss` increases the config surface. We mitigate this by keeping the default sensible and by re-using the existing `HttpSourceCacheContext.MaxAge = 0` plumbing rather than introducing a new HTTP code path.

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

1. Should the refresh also fire when the cached document indicates the package id is entirely absent (i.e. the registration index 404'd and that 404 was cached), or should that case be handled by a follow-up proposal? The current proposal only addresses the "version not in list" case, which is the one reported in #3116.
2. Should the opt-out knob be `http_cache_refresh_on_miss`, or should it be folded into a more general "HTTP cache freshness policy" config introduced in a future proposal? The minimal, targeted name is preferred unless the broader policy work is also being scheduled.
3. Naming: should the MSBuild property be `RestoreHttpCacheRefreshOnMiss` or align with the existing `RestoreNoCache` naming convention? Resolving with the implementation review.

## Future Possibilities

- **Server-driven freshness signals.** Once feeds publish a versions/last-modified manifest (à la [#3389](https://github.com/NuGet/Home/issues/3389)), refresh-on-miss can be generalized into "refresh when the feed says newer data exists", removing even the one extra request on the miss path.
- **Conditional GETs (`If-None-Match`).** The same plumbing can be extended so refreshes use ETags / `Last-Modified` and benefit from 304 responses, further reducing traffic.
- **Apply to MSBuild SDK resolver.** Once the client has a stable refresh-on-miss primitive, the MSBuild SDK resolver ([#7777](https://github.com/NuGet/Home/issues/7777)) can adopt it and finally close the gap that `RestoreNoCache` does not bridge today.
- **UI surfacing.** Visual Studio's Package Manager UI can call out when a refresh-on-miss occurred so users learn that NuGet self-corrected, building trust in the cache.
