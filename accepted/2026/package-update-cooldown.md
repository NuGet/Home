# ***Package update cooldown V1***

- Author: [zivkan](https://github.com/zivkan/)
- GitHub Issue: [Home#14657](https://github.com/NuGet/Home/issues/14657)

## Summary

Allow automated and assisted package version updates to be delayed by a cooldown period.
This will allow Visual Studio, `dotnet package update`, and `dotnet package list --outdated` to pre-select or report versions that were published at least the configured cooldown period ago.

The initial version will not do any cooldown checks during restore.
For justification, please see the [cooldown during restore section](#cooldown-during-restore).
Cooldown checks during restore may be added later.

## Motivation

Recently there has been a significant uptick in supply chain security attacks across multiple ecosystems.
Updating packages after a cooldown period has become increasingly common, to allow various stakeholders to investigate and remove malicious packages before widespread use.

Developers usually want this on public feeds but not on trusted internal feeds, where it would just slow down product development.
In the context of .NET, this means a cooldown will be most valuable for nuget.org, or another feed that mirrors nuget.org packages.

## Explanation

### Functional explanation

These are the proposed behaviors for the first version of package cooldowns that will ship.
There are [some future ideas listed](#future-possibilities), and others not written in this document.
But, this section contains the first set of features we would like to work on.

#### Defining the cooldown

Cooldown will extend Package Source Mapping.
See the [rationale on why cooldown is being tied to Package Source Mapping](#why-require-package-source-mapping).

The existing PSM `<packageSource>` element will be extended to allow one or more `<group>` elements, which in turn will contain one or more `<package pattern="..." />` elements.
Package patterns can continue to be defined directly under `<packageSource>`, or they can be defined inside a `<group>` when they need a different cooldown value.
Both the `<packageSource>` and `<group>` elements have an optional `minPublishAgeHours` attribute to define the cooldown for the `<package>` elements within.
If both the `<packageSource>` and `<group>` elements have the `minPublishAgeHours` attribute, the value on the `<group>` is used for any child `<package>` elements.
If the `<packageSource>` element does not have a `minPublishAgeHours` attribute, it is equivalent to the value 0, which means no cooldown, packages can be upgraded as soon as they are published.
If the `<group>` element does not have a `minPublishAgeHours` attribute, then it inherits the `<packageSource>` value for cooldown, in order to leave `<group>` open for extension in the future.
It is invalid to have the same pattern more than once within a single `<packageSource>`.
Negative values for `minPublishAgeHours` are invalid.

Here are some scenarios and sample config files.
The diff syntax is used to highlight changes introduced by cooldown.

- All packages on nuget.org on a 3 day cooldown, all internal Contoso.* packages do not have a cooldown.

```diff
 <configuration>
   <packageSources>
     <clear />
     <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
     <add key="contoso" value="https://contoso.test/packages/" />
   </packageSources>
   <packageSourceMapping>
-    <packageSource key="nuget.org">
+    <packageSource key="nuget.org" minPublishAgeHours="72">
       <package pattern="*" />
     </packageSource>
     <packageSource key="contoso">
       <package pattern="Contoso.*" />
     </packageSource>
   </packageSourceMapping>
 </configuration>
```

- Packages from nuget.org are on a 3 day cooldown, except `Microsoft.*` and `System.*` packages, which are on a 1 day cooldown, but the `Fabrikam` package has a 7 day cooldown.

```diff
 <configuration>
   <packageSources>
     <clear />
     <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
   </packageSources>
   <packageSourceMapping>
-    <packageSource key="nuget.org">
+    <packageSource key="nuget.org" minPublishAgeHours="72">
       <package pattern="*" />
+      <group minPublishAgeHours="24">
         <package pattern="Microsoft.*" />
         <package pattern="System.*" />
+      </group>
+      <group minPublishAgeHours="168">
         <package pattern="Fabrikam" />
+      </group>
     </packageSource>
   </packageSourceMapping>
 </configuration>
```

- The package `Fabrikam` is available on two sources, with different cooldowns depending on the source.

This is an edge case that is not recommended, it's just a consequence of the proposal's design.
The recommended usage is to use Package Source Mapping to limit the package to a single source.
Read ahead to the [updating package versions section](#updating-package-versions) to understand how NuGet will choose package versions when there are different cooldowns for different sources.

```diff
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
    <add key="contoso" value="https://contoso.test/packages/" />
  </packageSources>
  <packageSourceMapping>
-   <packageSource key="nuget.org">
+   <packageSource key="nuget.org" minPublishAgeHours="72">
      <package pattern="*" />
      <package pattern="Fabrikam" />
    </packageSource>
    <packageSource key="contoso">
      <package pattern="Contoso.*" />
+     <group minPublishAgeHours="48">
        <package pattern="Fabrikam" />
+     </group>
    </packageSource>
  </packageSourceMapping>
</configuration>
```

When NuGet runs on a machine with no [user-scoped NuGet.config file](https://learn.microsoft.com/nuget/consume-packages/configuring-nuget-behavior#config-file-locations-and-uses), it creates a default config file with api.nuget.org as a package source.
This default nuget.config file does not have any other settings, so no Package Source Mapping enabled by default.
The default config will not change for this cooldown feature.
This makes the cooldown feature entirely opt-in on initial release.

#### Updating package versions

All tooling is expected to be aligned, but the details will be dependent on the specific tool.

- When choosing a version (either for installation, or default selection in a version list), choose the highest version whose publish age is greater than the value configured.
- When displaying a list of versions, show an indicator for which versions are still in the cooldown period.
- When enumerating packages with available updates, exclude packages which only have versions that are younger than the minimum publish age.
- When the minimum publish age is configured to a non-zero value, but the package source does not provide the publish date for at least one version of the package, display a warning that the cooldown configuration cannot be honored.
- When a package is allowed to be restored from more than one source, consider each source independently, and a version is eligible for upgrade if any one source considers it eligible.

#### Tooling changes

The following actions/gestures will need to be updated to support cooldown.

- `dotnet package update`

This command has several options, some of which will choose a version on the user's behalf.

- `dotnet package list`

Cooldown is probably only relevant when using the `--outdated` option.
In addition to notifying when updates that have passed the cooldown period are available, it should warn when a package already resolved is in cooldown, to help detect accidental upgrades, or validate after manually editing MSBuild files.

- `dotnet package search`

The `--exact-match` option tells the search command to list all the versions of a package, in which case the packages in cooldown should be marked as such.
Without the `--exact-match` option, the search command uses the [search resource](https://learn.microsoft.com/nuget/api/search-query-service-resource), which does not have a query filter for publish age, or provide the publish date in the package metadata.
Therefore, `dotnet package search` without `--exact-match` will not be affected by cooldown for the initial version, and can be discussed in a new NuGet/Home issue after the first version is finished, as it will require protocol changes and decisions on behavior when the package source doesn't implement the updated protocol.

- Visual Studio Package Manager UI

1. Quick install button on the package list.
1. Details page's version dropdown list pre-selected version.
1. Details page's version dropdown list indication of which versions are still on cooldown, similar to "(vulnerable)" or "(deprecated)" for relevant packages.
1. Details page "publish date" line.
1. Multiple package updates on the Update tab.
1. Update tab package count

However, there are complexities that will need to be addressed before or during implementation:

1. PM UI has a "Package sources" dropdown where all sources can be considered, or just a single source.
1. PM UI doesn't always take package source mapping into account.
1. The NuGet protocol only provides `published` metadata in package metadata (registration) resources (used by installed, update, consolidate tabs), not the package search resource (used by the browse tab)

- Visual Studio Package Manager Console

The `Update-Package` command should have equivalent behavior to the `dotnet package update` command, where possible.

- NuGet MCP Server

The NuGet MCP server has tools to fix vulnerable packages and update packages that will need to take cooldown into account.

#### Changes to restore

Fail restore when cooldown is enabled and at least one `PackageReference` uses a floating version.
The NU code will be determined when the feature is implemented.
Otherwise, restore will not use cooldown settings, and will not warn if a package that was restored is still in the cooldown period.

Please see the [cooldown during restore section](#cooldown-during-restore) for more information.

### Technical explanation

This feature does not propose any changes to the NuGet protocol at this time.
The [package metadata resource](https://learn.microsoft.com/en-us/nuget/api/registration-base-url-resource) contains an optional `published` field.
If a nuget.config file is using package sources that do not provide `published` metadata, then NuGet can't do cooldown calculations and should provide warning messages.

NuGet.Protocol already populates the `Published` property for local file feeds using the file's last modified timestamp.
So, cooldown on file feeds will work, but customers are responsible for setting the last modified time carefully.

## Drawbacks

### Accurate package publishing dates

NuGet can only make decisions as good as the data it receives.
The way NuGet clients can get a package version's publishing date from a server is from the package metadata (registration) resource, in an optional `published` field.
Since the field is optional, feeds that don't provide a `published` property can't be cooled down.

Additionally, there are companies and teams that do not use nuget.org directly, and instead use a private feed where nuget.org packages are copied to for internal consumption.
There are generally two approaches, "up-sourcing" and "re-publishing".

Feeds that have automatic up-sourcing conceptually act similarly to a caching HTTP proxy.
NuGet asks the feed what versions of the package it has, the feed aggregates the list of versions it already has with what nuget.org has (via its own request to nuget.org), then returns the de-duplicated list to NuGet.
The feed should retain nuget.org's original publishing date, not the date that the package was first copied/used.

Feeds that re-publish nuget.org packages are ones that don't intrinsically know that packages came from nuget.org.
Instead someone, or some other automated process, downloads the package from nuget.org and then pushes the package to the feed.
In this case, the best case is that the feed lists the publish date as when the package was pushed to the feed.
But if this is days or weeks after the package was originally published to nuget.org, then from the developer's point of view, NuGet might not behave in the way they expect.
It is recommended that the publishing process take cooldown into account, and teams using this feed should not configure NuGet to use cooldowns, since the source only gets the package once the desired time period has passed.

### Delayed security fixes

By using a single cooldown value for all packages in a feed, it means that packages with a known security vulnerability will be delayed just as packages without a known vulnerability.
When the fixed package version is legitimate, then fixing the project also gets delayed, which exposes the application to risk for a longer time.

However, cooldown is intended to reduce risk of supply chain security attacks by waiting for malicious packages to be discovered and removed before upgrading.
If a malicious actor can publish a new version of a package, they might also be able to publish a security advisory on older versions of the package, as a form of social engineering to trick victims into upgrading.

Therefore there's a balance between taking new versions to fix known security vulnerabilities and waiting for security experts to vet new packages for malicious code.
This is a decision that individuals will need to make.
NuGet will not contain defaults that choose between NuGetAudit warnings or violating cooldown periods for you.

### Hierarchical nuget.config settings

NuGet accumulates settings from multiple nuget.config files, and if the "closest" file does not have a `<clear />` element in the `<packageSources>` section, then package sources from multiple files can be used.
Typically this shows up as nuget.org being added in the user-profile nuget.config, and company internal feeds being added in a solution directory nuget.config file.
If the user-profile nuget.config is edited to set a cooldown period, this will affect all solutions on the computer (well, that user account on that computer), which may be unintended.
The NuGet team has [documented a recommendation](https://learn.microsoft.com/nuget/concepts/security-best-practices#nuget-configuration) that all repos commit a nuget.config where `<clear />` is the first element in the package sources section, to ensure the package sources are deterministic.

## Rationale and alternatives

### Why require Package Source Mapping

There are three primary reasons why cooldown is being proposed to extend Package Source Mapping (PSM), forcing customers to onboard onto PSM if they're not using it already.

1. Per-package or per-prefix values

   Initial feedback suggests that different cooldowns for different packages will be a popular request.
   Additionally, most other ecosystems have some kind of exception list (see [prior art](#prior-art)).
   Allowing different cooldown values per-package or per-prefix provides more flexibility than a single global cooldown and an exception list that skip cooldown checks, while allowing developers to use the zero value to disable cooldown for those packages.

1. Constraints due to protocol design

   As mentioned elsewhere, the only place NuGet's protocol provides the publish date metadata is in a resource that lists it as being optional.
   NuGet's docs [lists around 20 different options for hosting private feeds](https://learn.microsoft.com/nuget/hosting-packages/overview).
   It's not feasible to test them all to determine which support publish date metadata and which ones do not, in order to understand how common it is that feeds don't provide the publish date.
   Similarly, changing the protocol to make the publish date mandatory and breaking feeds that are no longer compliant with the protocol could be counter-productive by preventing uptake of the cooldown feature.

   Therefore, NuGet's cooldown feature needs to handle situations where a package's publish date is not always available.
   It's most likely that all packages on a feed either have or don't have a publish date, rather than only a subset of packages having publish dates.
   So, attaching the cooldown to specific package sources makes it clear that there are behavior differences between package sources.

1. Both features are aligned with supply chain security

   Developers wanting to use cooldown are hopefully doing so out of a desire to secure their supply chain, rather than simply following a check-list of mandatory company policies.
   In such a case, it's likely that Package Source Mapping is aligned with that desire of securing their supply chain, so using both would be acceptable or even desirable.

While there are likely certain developers who have constraints or preferences that make onboarding onto PSM infeasible, there is no perfect solution for everybody.
This design is proposed as being the best for most scenarios and that other designs may have more significant drawbacks or limitations.

### Alternate options to define the cooldown period

Since the proposal is that cooldown is configurable per source, putting the setting in nuget.config is a natural fit as that's where sources are usually configured.
While PackageReference allows package sources to be defined in MSBuild, it only allows a semicolon delimited list of URLs and local paths.
There's no existing way to define metadata on MSBuild defined sources (sources are an MSBuild property, not items).

A single global cooldown setting was not chosen because we believe that wanting a cooldown for nuget.org packages and not for company internal packages will be a common configuration.
Additionally, most other ecosystem package managers with a cooldown feature also have some kind of exclude option.
Most repositories do not have a large number of package sources, so it should not be a burden to duplicate the cooldown setting for multiple sources.

Attaching the cooldown to the `<packageSources>` (not the Package Source Mapping sub-element, but the one that defines the source in the first place) was considered.
But there was significant feedback that not all packages should use the same cooldown value.

### Cooldown during restore

There are two areas where cooldown could be taken into account during restore.
The first is warning when a package in the graph is using a version that should still be in cooldown.
The second is selecting the package version when using floating versions.

Checking cooldown during restore was not chosen due to performance prototyping suggesting it would be infeasible to maintain restore performance without protocol changes, which would delay the implementation of package upgrade scenarios.
This will mean customers who hand edit MSBuild XML and run restore will not get benefit from the cooldown feature initially.

|Repository|baseline|prototype|delta|
|--|--|--|--|
|[OrchardCore](https://github.com/OrchardCMS/OrchardCore)|14.77s|17.06s|+15.5%|
|[Orleans](https://github.com/dotnet/orleans)|11.46s|13.69s|+19.5%|
|[NuGet.Client](https://github.com/NuGet/NuGet.Client)|22.63s|65.87s|+191.1%|
|[Roslyn](https://github.com/dotnet/roslyn)|40.96s|90.71s|+121.5%|

See more details in the [restore prototype details section](#restore-prototype).

This proposal also recommends blocking restore when cooldown is enabled and at least one package in the project uses floating versions.
Since cooldown is a new feature that must be opt-in, this would not be considered a breaking change.
While a [lock file](https://learn.microsoft.com/nuget/consume-packages/package-references-in-project-files#locking-dependencies), will make restore repeatable and therefore wouldn't need each version's published date in order to select a version, the issue becomes how to update the lock file to a version that's not in cooldown.
Unless a "force evaluate" restore prevents new packages from being used in the lock file until the cooldown period passes, it doesn't solve the problem.
This could catch out some developers who would not expect this behavior.
Additionally, using floating versions with a lock file has fairly similar outcomes to not using floating versions, since committing version changes to source control will be needed either way.
Therefore, for the first version of package cooldown in NuGet, blocking floating versions seems acceptable and can be improved in a future version of .NET.

### Packages with known vulnerabilities

If a project is already referencing a package that now has a known vulnerability, it may be important to upgrade the package sooner to reduce the time that project may be vulnerable to publicly disclosed bugs.
On the other hand, there are instances of developer machines being compromised and credentials or tokens being stolen.
If the attacker can steal both a nuget.org push token, as well as a suitable GitHub token, the attacker might be able to create a GitHub security advisory, which will then automatically become a NuGetAudit warning within hours.
For this reason, it's not necessarily safer to update a package with a known vulnerability than updating a package without.
Different developers will have different opinions on whether to upgrade.
As long as there's a way for them to upgrade when they decide that upgrading is more important than waiting for the cooldown, their objectives can be met.

If `TreatWarningsAsErrors` is being used, consider using `WarningsNotAsErrors` to prevent NuGetAudit from blocking all work when a new vulnerability is disclosed and the fixed version is still in cooldown.
You can use MSBuild conditions to choose when to keep it as an error, or when to leave it as a warning, for example [if you use a separate pipeline to validate NuGetAudit success](https://learn.microsoft.com/nuget/concepts/auditing-packages#separating-errors-from-warnings-with-a-dedicated-auditing-pipeline).

## Prior Art

Similar "minimum age" / "cooldown" mechanisms exist in other ecosystems and are good precedent for units, defaults, and handling sources without publish timestamps:

- **npm** — `min-release-age` in `.npmrc` (in days), added in npm v11.10.0, delays installing newly published versions.
  npm also supports `min-release-age-exclude`, where package names or minimatch globs such as `@myorg/*` can be exempt from the age filter.
  Exempting a package only exempts that package, not its dependencies, unless those dependencies also match an exclude pattern.
- **Cargo (Rust)** — [RFC 3923](https://github.com/rust-lang/rfcs/pull/3923) adds `registry.global-min-publish-age` (e.g. `"14 days"`) plus a per-registry `registries.<name>.min-publish-age` override, closely mirroring the per-feed model here.
  Versions already in `Cargo.lock` are exempt.
  `CARGO_RESOLVER_INCOMPATIBLE_PUBLISH_AGE=allow` can temporarily bypass the age check for urgent fixes, for example with `cargo update --precise`.
  Cargo considered package-name exclude lists, but deferred them because per-registry configuration covers trusted sources and the env var plus `--precise` covers urgent one-off updates.
- **Dependabot** — a cooldown option to delay dependency update PRs.
  It supports exception-style configuration with `include` and `exclude` lists, and can configure different cooldowns for major, minor, and patch updates.
  Cooldown applies to version updates, not security updates.
- **Renovate** — `minimumReleaseAge` holds back update PRs until a release reaches a configured age.
  Renovate uses `packageRules` for exceptions, allowing selected package names, patterns, datasources, or update types to use a different `minimumReleaseAge`, including `0 days`.

### A different approach: pinning to a fixed date

Python's [uv](https://docs.astral.sh/uv/) takes a different approach with its `exclude-newer` setting (and the per-package `exclude-newer-package` variant).
Rather than a rolling age relative to "now", it limits resolution to versions published before a fixed date or timestamp (e.g. `2026-01-01`).
This was designed primarily for reproducible resolutions ("resolve the graph as it existed on date X") rather than as a security cooldown, though it can be used to hold back new versions.
The per-package variant provides a package-specific exception mechanism, but only by setting a different fixed cutoff date for that package.
The trade-off is that a fixed date must be advanced manually over time, whereas a rolling age like the one proposed here keeps moving forward automatically.

## Unresolved Questions


## Appendix

### NuGet ecosystem comparison

#### 1. Upgrading packages

In many programming language ecosystems, both projects and packages can instruct the package manager to use the latest patch version (using [SemVer2 semantics](https://semver.org)).
The exact syntax changes between ecosystems, but something like `^1.2.3` often means "the highest compatible version greater than or equal to `1.2.3` and less than `2.0.0`".

NuGet has floating versions, represented by syntax `1.2.*`, but importantly this is only possible on projects.
If a project using floating versions is packed, the floating version gets resolved to the specific version used during the build, and that becomes the package's dependency, for example `1.2.5`.
During a restore, NuGet will search for that specific package version, and if it's not found, it will raise a warning, which can be treated as an error to break the build.
However, since NuGet packs the resolved version as the dependency version, packages with dependencies where the exact version does not exist is very uncommon.
When a transitive package has a known vulnerability, customers need to add the package as a directly referenced package to control the version and upgrade it to a fixed version.

Therefore, NuGet's risk of automatically updating to new versions of a package is limited to customers who choose to use floating versions, and the risk is further limited to direct package references, not transitive packages.
While other package managers introduced lock files (partially) to enable repeatable builds, NuGet was designed as repeatable from the beginning.
This makes NuGet less susceptible to this specific form of supply chain attacks, because upgrading package versions is an explicit action that needs to be taken in most cases, rather than something the package manager does by default.

#### 2. Publishing packages

NuGet has the concept of [signed packages](https://learn.microsoft.com/nuget/reference/signed-packages-reference).
When a nuget.org account has one or more certificates registered, nuget.org no longer allows unsigned packages to be pushed by that account.
Therefore, even if an attacker obtains a nuget.org API key, an account that forces author-signed packages will prevent the attacker from pushing new versions of a package without being signed by that certificate (either unsigned packages, or signed by the wrong certificate).

This does not eliminate the risk of attackers publishing new versions of packages.
For example, the CI infrastructure might be compromised, or the package owner might not author-sign their packages, and therefore not have a certificate registered in their account.
However, in cases where the nuget.org account does have registered certificates, it makes an API key insufficient to publish packages.

This knowledge actually makes per-package/prefix cooldown more compelling, because if a customer trusts that Microsoft owned packages must be signed, then they might be willing to have a shorter cooldown, or skip the cooldown, for Microsoft owned packages.
This is particularly true if most NuGet Audit warnings are from Microsoft owned packages, allowing the customers to confidently upgrade those packages sooner than packages owned by other companies or people.
But it's important to remember that reduced risk is not the same as zero risk.

### Restore prototype

- Background information

When restore wants to download a package, even if it knows what specific version it wants to download, it downloads a version list from [the package content resource](https://learn.microsoft.com/en-us/nuget/api/package-base-address-resource) (also called "flat container" due to nuget.org's URL).
This resource has an `index.json` endpoint that contains a list of versions without any additional metadata.
It was optimized for how `PackageReference` restore was designed and implemented.
If restore wants to download a specific version, it checks that version exists in this array.
For floating versions, or where the requested version is missing, it uses the list in order to select a version.

Therefore, to check the package's published date using an existing protocol resource, NuGet will need to use [the package metadata resource](https://learn.microsoft.com/en-us/nuget/api/registration-base-url-resource) (also called "registration", due to nuget.org's URL).
As the name suggests, this contains all the package metadata, so contains a lot more than just the published date.

The protocol allows servers to split the package metadata across multiple files (pages), which nuget.org does.
However, at the time this document was written, NuGet.Client does not have logic to limit which HTTP requests are made.
Instead, it downloads all pages and deserializes all the data, even if a single package version's metadata is desired.
So, there is room for improvement, but even an optimized client is still going to download and deserialize orders of magnitude more JSON than the flat container version list.

Using the package Microsoft.Extensions.DependencyInjection as an example:

|Metric|flat container|registration|
|--|--|--|
|HTTP requests|1|4|
|combined JSON size|3.8 KB|1.0 MB (34 KB)|

api.nuget.org does not gzip compress the flat container index.json, but registration metadata is available gzipped, which is why two values are shown, uncompressed and gzipped.
Also consider that the package's nupkg is 302 KB, showing the significant network, cache, and parsing cost of using registration, rather than the flat container for finding the floating version.
NuGet.Protocol version 7.6.0 allocates about 4.7 MB when parsing this under .NET 10, and 5.7 MB on .NET Framework, increasing the number of garbage collection (GC) pauses.

- Interpreting the prototype measurements

Here is more data regarding the table from the [cooldown during restore section](#cooldown-during-restore).

|Repository|duration(b)|duration(p)|duration(delta)|sources|packages|http cache size (b)|http cache size (p)|http cache size (delta)|
|--|--|--|--|--|--|--|--|--|
|[OrchardCore](https://github.com/OrchardCMS/OrchardCore)|14.77s|17.06s|+15.5%|1|602|251 MB|346 MB|+37.8%|
|[Orleans](https://github.com/dotnet/orleans)|11.46s|13.69s|+19.5%|4|410|289 MB|336 MB|+16.3%|
|[NuGet.Client](https://github.com/NuGet/NuGet.Client)|22.63s|65.87s|+191.1%|8|620|547 MB|3404 MB|+522%|
|[Roslyn](https://github.com/dotnet/roslyn)|40.96s|90.71s|+121.5%|18|620|1358 MB|8517 MB|+527%|

(b) baseline
(p) prototype

We can see that the duration delta increase is most closely correlated to the increase in size of the HTTP cache, but there's obviously more complexity than just the HTTP cache size.
What stands out is that OrchardCore and Orleans increased their HTTP cache size and restore duration by double digit percentages, while NuGet.Client and Roslyn increased both by triple digit percentages.
The reason is almost entirely due to using Visual Studio's CI build package feed.
Using the Microsoft.VisualStudio.Sdk package as an example, there are 37 distinct versions of the package on nuget.org, but 5010 on VS's public CI feed.
The Microsoft.VisualStudio.Sdk package is a meta-package, so has no content, just dependencies, and adding it to an otherwise empty project adds about 160 packages to the package graph.
Both NuGet.Client and Roslyn use additional VS packages not included in the VS SDK.
So, switching from flat container's version list to the full registration data for hundreds of packages on the public VS CI feed, the amount of data that NuGet needs to process during restore explodes.

One idea to improve the protocol is to create a new version of the flat container version list, where each version also has the publish date.
But with NuGet.Client and Roslyn using hundreds of packages, each package has thousands of versions, there will likely be a measurable performance impact if the published date is not needed (the cooldown feature is not enabled).
This suggests that if this is the approach that ends up being taken, NuGet will need to use different versions of the flat container depending on whether cooldown is enabled or not.

- Reproduce the perf measurement yourself

You can attempt to reproduce the perf results with the following steps:

1. Clone [the NuGet.Client repo](https://github.com/NuGet/NuGet.Client), run `configure.ps1`, and then `build.ps1 -Pack`.
   This will create several packages in the `artifacts/nupkgs` directory.
   Copy these nupkgs somewhere, for a baseline measurement.
1. Edit [`SourceRepositoryDependencyProvider.cs`](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.Commands/RestoreCommand/SourceRepositoryDependencyProvider.cs).
   I suggest you ask an AI to do something like "Instead of using FindPackagesByIdResource to check package versions, use PackageMetadataResource and allow prerelease and unlisted packages where appropriate".
   But the important places are checking a package exists, and getting the version list.
   The PackageMetadataResource doesn't have a nupkg download API, and FindPackageByIdResource implements getting the package dependencies by downloading the nupkg, extracting and parsing the nuspec, so changing that to use the PackageMetadataResource would be a significant change.
1. Run `build.ps1 -Pack` again, this time saving the nupkgs to a different directory, used for the prototype measurements.
1. Use [this patching script](https://github.com/NuGet/Entropy/tree/main/SDKPatchTool) to download a .NET SDK and "patch" it with NuGet you built earlier.
   Create a baseline SDK (the build without any code changes), and a prototype SDK (with the code changes) to ensure we're testing the same thing.
1. Use [these perf test scripts](https://github.com/NuGet/NuGet.Client/tree/dev/scripts/perftests) to test restore against the solution of your choosing.
   I only reported the "arctic" results, since that's representative of most CI pipelines.
   But if you're more interested in dev machine experiences, one of the other test scenarios might be of interest to you.
