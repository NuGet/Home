# Configurable HTTP cache refresh after a cached version miss

- Author: [@donnie-msft](https://github.com/donnie-msft)
- GitHub Issue: [NuGet/Home#3116](https://github.com/NuGet/Home/issues/3116)
- Related implementation: [NuGet/NuGet.Client#7321](https://github.com/NuGet/NuGet.Client/pull/7321)

## Summary

Add an opt-in NuGet configuration setting that refreshes an HTTP package source when a confirmed cache hit contains package metadata that cannot satisfy a requested version.
The setting can be enabled for all HTTP package sources or overridden for an individual package source.

This addresses the publish-then-consume failures reported in [NuGet/Home#3116](https://github.com/NuGet/Home/issues/3116).
The V3 provider must preserve whether package metadata was served from an existing HTTP cache entry.
NuGet refreshes only after a confirmed cache hit whose version list cannot satisfy the request.

The feature is disabled by default.
This avoids adding network requests to existing restores while allowing repositories and build environments that publish and immediately consume packages to opt in.

## Motivation

NuGet caches package version metadata for HTTP sources.
If a package version is published after the metadata was cached, restore can report `NU1102` until the cache expires even though the requested package is available from the source.

The current workarounds are broader than the problem:

- `--no-http-cache`, `--no-cache`, or `RestoreNoCache` bypass the HTTP cache for the entire restore.
- Clearing the HTTP cache affects unrelated sources and restore operations.
- Waiting for the cache to expire delays developer and CI workflows.

[NuGet/NuGet.Client#7321](https://github.com/NuGet/NuGet.Client/pull/7321)
proposes automatically refreshing after a package version miss.
However, the proposed restore-layer implementation cannot determine whether the initial lookup was actually served from cache.
A normal `SourceCacheContext` can fetch from the origin when an entry is absent or expired.
In that case, automatically refreshing after the miss immediately repeats an origin request.

The same implementation can also refresh one source while another configured source successfully resolves the package.
This means the behavior can add HTTP traffic to successful restores, not only restores that were about to fail.

The refresh should therefore be implemented in or below the V3 provider layer where cache provenance can be preserved.
Configuration allows users to enable the behavior only for sources where packages are published and immediately consumed.

## Goals

- Allow refresh-after-cached-version-miss to be enabled for all configured HTTP package sources.
- Allow an individual package source to override the global setting.
- Refresh only when the initial package metadata was served from an existing HTTP cache entry.
- Do not repeat an origin request when the cache entry was missing or expired.
- Limit refreshes to one per package ID and source in a restore operation.
- Reuse NuGet's existing HTTP cache refresh behavior so both memory and disk cache entries are replaced.
- Preserve current restore behavior when the feature is not configured.
- Make the additional requests observable through logging and telemetry.

## Non-Goals

- Changing the default HTTP cache lifetime.
- Changing Package Source Mapping semantics.
- Adding a general-purpose HTTP request timeout setting.
- Changing the Global Packages Folder.
- Applying the feature to the MSBuild SDK resolver in V1.

## Explanation

### Functional explanation

The feature can be enabled globally in the `config` section:

```xml
<configuration>
  <config>
    <add key="httpCacheRefreshOnVersionMiss" value="true" />
  </config>

  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
    <add key="contoso" value="https://pkgs.contoso.com/v3/index.json" />
  </packageSources>
</configuration>
```

This enables the behavior for every HTTP package source in the effective NuGet configuration.

An individual package source can override the global value:

```xml
<configuration>
  <config>
    <add key="httpCacheRefreshOnVersionMiss" value="false" />
  </config>

  <packageSources>
    <add key="nuget.org"
         value="https://api.nuget.org/v3/index.json" />
    <add key="contoso"
         value="https://pkgs.contoso.com/v3/index.json"
         httpCacheRefreshOnVersionMiss="true" />
  </packageSources>
</configuration>
```

In this example, only the `contoso` source refreshes after a cached version miss.

The per-source attribute takes precedence over the global setting:

1. The `httpCacheRefreshOnVersionMiss` attribute on the package source, when present.
2. The global `httpCacheRefreshOnVersionMiss` value in the `config` section.
3. The default value, `false`.

Values are parsed as case-insensitive Boolean values.
Invalid values produce a configuration error identifying the setting and, for an attribute, the package source.

### Restore behavior

When the effective value is `true` for an HTTP source:

1. NuGet performs the normal package lookup using the existing cache policy.
2. The V3 provider records whether the metadata was read from an existing HTTP cache entry or fetched from the origin.
3. If a confirmed cache hit does not contain a version satisfying an eligible request, NuGet repeats the metadata lookup with the HTTP memory and disk caches bypassed.
4. NuGet replaces the cached metadata with the fresh response.
5. NuGet evaluates the request against the refreshed metadata.
6. If the request is still not satisfied, normal unresolved-package and
   failed-source behavior applies.

V1 applies to non-floating version requests with an inclusive minimum version.
This includes the common `PackageReference` form:

```xml
<PackageReference Include="Contoso.Common" Version="1.2.3" />
```

The setting does not cause a refresh when:

- The source is not HTTP or HTTPS.
- The feature is disabled for the source.
- The initial metadata lookup was fetched from the origin because the cache entry was missing, expired, or invalid.
- The original lookup found a satisfying version.
- The restore is already bypassing the HTTP cache.
- The request uses a floating version.
- The package ID and source have already been refreshed during the restore.

### Multiple package sources

Package sources are queried independently.
If refresh-after-cached-version-miss is enabled globally, an enabled source
can refresh after a stale cache hit even when another source resolves the
package and the overall restore succeeds.

This is an explicit consequence of global opt-in.
Users concerned about this traffic should enable the setting only on sources where publish-then-consume consistency is required.

Package Source Mapping requires no new syntax or behavior. Existing mappings
already limit which sources are considered for a package ID and therefore also
limit which sources can perform a refresh.

### Logging

When NuGet performs a configured refresh, it logs an informational message:

```text
Cached metadata from source 'contoso' did not contain a version of
'Contoso.Common' satisfying '[1.2.3, )'. Refreshing its HTTP metadata once
because 'httpCacheRefreshOnVersionMiss' is enabled.
```

The message can identify the cached response because cache provenance is an implementation requirement.

### Technical explanation

#### Configuration

NuGet already has two relevant configuration patterns:

- `maxHttpRequestsPerSource` is read from the global `config` section, copied onto each `PackageSource`, and consumed by the HTTP resource providers.
- `protocolVersion`, `allowInsecureConnections`,
  `disableTLSCertificateValidation`, and `minPublishAgeHours` are attributes on
  individual entries in the `packageSources` section.

`httpCacheRefreshOnVersionMiss` combines these patterns:

- Add a global configuration constant and Boolean parser.
- Add a nullable `httpCacheRefreshOnVersionMiss` attribute to `SourceItem`.
- Carry the effective value on `PackageSource`.
- Preserve an explicitly configured source override when cloning or writing a
  package source.
- Consume the effective value in the V3 package lookup implementation.

The implementation must distinguish an absent per-source attribute from an explicit `false` so the source can override a global `true`.

#### V3 provider behavior

The policy should be implemented in or below the V3 version metadata lookup, rather than as an unconditional retry in the project dependency resolver.

The HTTP cache path must preserve whether the response was read from an existing cache entry or fetched from the network and then written to the cache.
Today, a network response written to the disk cache can be presented to callers in the same form as an existing cached response.
The implementation must add sufficient internal result metadata or a distinct result status so the V3 provider can distinguish those cases.

The implementation may reuse
`SourceCacheContext.WithRefreshCacheTrue()` or equivalent existing plumbing.
The forced request must:

- Bypass in-memory version metadata.
- Use `MaxAge = TimeSpan.Zero` for the on-disk HTTP cache.
- Update the cache with the response.
- Share one in-progress refresh task for the same package ID and source.

Coordination is scoped to a restore operation and keyed by package ID and source.
Concurrent callers must await the same refresh rather than allowing one caller to return an unresolved result while another caller refreshes.

The provider must not issue the refresh when the initial request reached the origin because the cache was missing, expired, or invalid.

#### Existing no-cache behavior

If `SourceCacheContext.RefreshMemoryCache` is already true, NuGet has already
bypassed the HTTP cache. Refresh-after-cached-version-miss does not issue another request.

This includes restores using `--no-http-cache`, `--no-cache`, or `RestoreNoCache`.

#### Telemetry

Restore telemetry should include:

- Whether refresh-after-cached-version-miss was enabled globally.
- The number of sources with an explicit override.
- The number of cached version misses that triggered a refresh.
- The number of refreshes that found the requested version.

Telemetry must not include package IDs, source names, or source URLs.

## Test plan

### Configuration tests

- The feature defaults to `false`.
- A global `true` or `false` value is applied to HTTP sources.
- A per-source value overrides the global value in both directions.
- Invalid global and per-source values produce actionable errors.
- Cloning and writing package sources preserve explicit source attributes.
- Merged NuGet configuration files produce the documented precedence.

### Protocol and restore tests

- A stale cached version list is refreshed and a newly published version is
  resolved.
- A missing, expired, or invalid cache entry that causes an origin request is
  not immediately requested again.
- A genuinely missing version in cached metadata causes at most one refresh per
  package ID and source per restore.
- Concurrent requests for the same package ID and source await one refresh.
- A source-specific opt-in does not refresh other configured sources.
- A global opt-in documents and verifies that multiple missing sources can each
  refresh even when another source resolves the package.
- Package Source Mapping limits refreshes to mapped sources.
- `--no-http-cache`, `--no-cache`, and `RestoreNoCache` do not cause a second
  request after an origin miss.
- Floating versions do not trigger V1 behavior.
- Local and fallback-folder sources are unaffected.

At least one functional test must use the real V3 HTTP, memory-cache, and on-disk-cache implementations.
Tests that only return different mock results based on `RefreshMemoryCache` are insufficient to verify the behavior.

## Drawbacks

### Cache provenance must be preserved

The existing restore-layer abstraction does not reliably indicate whether the first metadata lookup was served from cache.
The V3 and HTTP cache layers must preserve this information until version selection determines whether the cached metadata satisfies the request.
This is more invasive than an unconditional restore-layer retry.

### Global opt-in can add traffic to successful restores

With multiple sources, one source can hit stale cached metadata and refresh while another source successfully resolves the package.
Per-source configuration and Package Source Mapping can reduce this cost.

### Configuration is required

Users do not receive the publish-then-consume improvement automatically.
This is a deliberate initial trade-off while NuGet gathers telemetry and validates the behavior across public and private feeds.

## Rationale and alternatives

### Unconditionally double-check after a version miss

This is simpler to implement in the restore layer, but the initial lookup may already have reached the origin because the cache entry was missing or expired.
Repeating that request immediately adds latency and load without improving correctness.

This proposal instead requires a confirmed cache hit before refreshing.

### Enable refresh-after-cached-version-miss by default

Default-on behavior fixes the issue without configuration, but it can still add traffic to successful multi-source restores when one source has stale cached metadata and another source resolves the package.
This proposal starts with an opt-in policy until that traffic is measured.

### Use Package Source Mapping configuration

Package Source Mapping answers which sources are eligible to provide a package.
Refresh-after-cached-version-miss answers how an eligible HTTP source handles
stale version metadata. Combining the settings would overload a security and
source-selection feature with cache policy.

No new Package Source Mapping setting is proposed. Existing mappings naturally
reduce refresh traffic by limiting eligible sources.

### Make the HTTP timeout configurable

Cached HTTP requests already have request and download timeouts internally.
Making them configurable would affect many NuGet HTTP operations, not only the
refresh request, and would require separate decisions about retries,
header timeouts, body timeouts, defaults, and source-specific overrides.

A dedicated timeout for the refresh would add another setting and could
make slow private feeds fail unexpectedly. V1 instead uses the existing request
timeouts and restore cancellation token. General HTTP timeout configuration can
be proposed separately.

### Always disable the HTTP cache for selected sources

This avoids stale metadata but gives up the cache's performance benefit on
every request. Refresh-after-cached-version-miss retains normal cache behavior
and pays for a second request only when an existing cached version list cannot
satisfy the request.

## Prior Art

- `maxHttpRequestsPerSource` demonstrates passing global HTTP policy through
  `PackageSource` to the protocol resource providers.
- `minPublishAgeHours`, `allowInsecureConnections`, and
  `disableTLSCertificateValidation` demonstrate per-source attributes in the
  `packageSources` section.
- `--no-http-cache` and `RestoreNoCache` demonstrate the existing mechanism for
  bypassing NuGet's HTTP memory and disk caches.

## Unresolved Questions

1. Should the global and per-source setting be named
   `httpCacheRefreshOnVersionMiss`, `refreshHttpCacheOnVersionMiss`, or
   `refreshCachedPackageMetadataOnVersionMiss`?
1. Should V1 apply only to an exact version range such as `[1.2.3]`, or also to
   the common minimum-inclusive `PackageReference` interpretation
   `[1.2.3, )`?
1. Should the MSBuild SDK resolver consume the same setting in a later version? SDK packages can encounter the same stale-version-list problem, but this restore implementation would not fix them.
1. Does NuGet server API currently support (or is it feasible for them to support) conditional requests using ETags or `Last-Modified`.
This reduces refresh bandwidth, but requires feeds to support validators correctly.
On refresh, NuGet could ask the server:
    - If-None-Match: `<etag>`, using the cached response's `ETag`.
    - If-Modified-Since: `<date>`, using its `Last-Modified` timestamp.

    If unchanged, the server returns `304 Not Modified` without resending metadata.
    If changed, it returns `200` with the updated version list.

## Future Possibilities

1. Support management of this new package source setting in the VS Options UI for package sources.
1. Enable refresh-after-cached-version-miss by default for selected source types or all HTTP sources.
1. Apply the policy to the MSBuild SDK resolver.
1. Consider a separate proposal for configurable HTTP request and download
  timeouts.
