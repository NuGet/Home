# ***Package update cooldown***

- Author: [zivkan](https://github.com/zivkan/)
- GitHub Issue: [Home#14657](https://github.com/NuGet/Home/issues/14657)

## Summary

Allow automated and assisted package version updates to be delayed by a cooldown period.
This will allow Visual Studio and `dotnet package update` to pre-select the version whose publishing age is greater than the configured value.
Restore can also take this into account for floating versions by using an opt-in property.

## Motivation

Recently there has been a significant uptick in supply chain security attacks across multiple ecosystems.
Updating packages after a cooldown period has become increasingly common, to allow various stakeholders to investigate and remove malicious packages before widespread use.

Developers usually want this on public feeds like nuget.org but not on trusted internal feeds, where it would just slow things down.

## Explanation

### Functional explanation

#### Defining the cooldown

The cooldown is defined in the nuget.config file via a new `updateCooldown` attribute on package sources.
When a source does not have an `updateCooldown` value, then there is no cooldown period and NuGet will use new versions immediately.

```xml
<packageSources>
  <add key="nuget.org" value="https://api.nuget.org/v3/index.json" updateCooldown="72" />
  <add key="internal" value="https://contoso.example/nuget/v3/index.json" />
</packageSources>
```

NuGet provides a package source editor in Visual Studio, and `dotnet nuget [add|update] source` commands, which should also be updated.

NuGet creates a default NuGet.Config file in the user-settings directory when it does not exist, with nuget.org added automatically as a package source.
It will not add a cooldown automatically.
This makes the cooldown feature entirely opt-in at this time.

#### Floating version cooldown opt-in

Restore only applies cooldowns to floating version `PackageReference` items when the project sets the `RestoreCooldownFloatingVersions` MSBuild property to `true`.

```xml
<PropertyGroup>
    <RestoreCooldownFloatingVersions>true</RestoreCooldownFloatingVersions>
</PropertyGroup>
```

This will make restore slower, as NuGet will need to download and parse significantly more JSON metadata, sometimes spread across multiple additional HTTP requests.
This cost is paid when restore evaluates floating versions, but locked restores can avoid resolving new versions.

Since the NuGet protocol makes the `published` metadata for package versions optional, a warning will be raised if the feed is configured for cooldown, but does not provide the `published` metadata.
The exact NU code will be determined during implementation, in case another feature takes the code before this feature is implemented.

Floating versions are only supported on PackageReference items, so it does not affect dependencies of other packages.

#### Updating package versions

The following actions will need to be updated to support cooldown:

- `dotnet package update`

When the command is run without any arguments, it updates all packages to the latest version.
When the command is run with one or more package names (but without specifying the version), it similarly updates to the latest version of those packages.
The `--vulnerable` option limits which packages are in scope for updating and changes the version selection to "lowest version that is higher than the vulnerable version and is not also vulnerable itself".
All of these scenarios need to take cooldown into account.

When a package source is configured for a cooldown, but the feed doesn't return `published` metadata, a warning will be written to stderr, and the highest version will be used.

- Visual Studio Package Manager UI

There are multiple install/upgrade workflows in Visual Studio's Package Manager UI (PMUI).

1. Quick install button on the package list.
   - Clicking the quick install should install the highest version that is not in the cooldown period.
1. Versions dropdown and install button on the package details page.
   - In situations where the versions dropdown currently selects the highest version, it should be changed to the highest version not in the cooldown period.
   - The versions dropdown should have a "(cooldown)" marker on each version still in the cooldown period, similar to "(vulnerable)" or "(deprecated)" for relevant packages.
1. Multiple package update on the Update tab.
   - When choosing the highest version of each package to update to, it should take cooldown into account.

In addition the package details page shows the package publish date.
When the date is within the cooldown period, it should show a warning icon, similar to vulnerable or deprecated packages, with a tooltip explaining it's due to the cooldown.

On the Installed, Update and Consolidate tabs, NuGet already downloads package metadata via the registration resource, so all these features should be easy to implement.

However, on the Browse tab, NuGet gets the package list from the feed's search resource, which does not have a `published` property.
Therefore, when a package source has a cooldown enabled, the quick install button will be disabled, forcing users to select the package and use the package details panel to install via the versions dropdown list and install button.
The quick install button should have a hover tooltip saying to use the package details panel because of the cooldown feature.

When a package source has cooldown enabled, but the package metadata (registration) resource does not provide `published` metadata, a warning should be displayed.
Location to be determined.

All of these features should only occur when the package source dropdown has a package source with cooldown selected, or the "(All)" source is selected and at least one of the sources has cooldown enabled.

- Visual Studio Package Manager Console

The `Update-Package` command should take cooldown into account when not provided with a specific version number.

If the feed does not provide `published` metadata, a warning will be output, and the highest version will be selected.

- NuGet MCP Server

The NuGet MCP server has tools to fix vulnerable packages and update packages.
These will need to be updated to support cooldown as well.

### Technical explanation

This feature does not propose any changes to the NuGet protocol.
This means companies using private feeds may be able to keep using their existing feeds, as long as the feed already returns `published` metadata on the package metadata (registration) resource.

NuGet.Protocol already populates the `Published` property for local file feeds using the file's last modified timestamp.
So, cooldown on file feeds will work, but customers are responsible for setting the last modified time carefully.

## Drawbacks

### Accurate package publishing dates

NuGet can only make decisions as good as the data it receives.
The way NuGet clients can get a package version's publishing date from a server is from the package metadata (registration) resource, in an optional `published` field.
Since the field is optional, feeds that don't provide a `published` property can't be cooled down.

Hopefully this should be a minor inconvenience, because developers are most likely to want to cooldown packages from nuget.org only, and not company internal feeds, or potentially packages from 3rd party vendors via paid feeds.
However, it could be a problem for internal feeds that host packages sourced from nuget.org.
There are two common ways for feeds to source packages from nuget.org, "up-sourcing" and "re-publishing".

Feeds that have automatic up-sourcing conceptually act similarly to a caching HTTP proxy.
NuGet asks the feed what versions of the package it has, the feed aggregates the list of versions it already has with what nuget.org has (via its own request to nuget.org), then returns the de-duplicated list to NuGet.
If the feed changes the publish date to the date that it was added to the feed, NuGet will be unable to perform cooldown accurately.

Feeds that re-publish nuget.org packages are ones that don't intrinsically know that packages came from nuget.org.
Instead someone, or some other automated process, downloads the package from nuget.org and then pushes the package to the feed.
In this case, the best case is that the feed lists the publish date as when the package was pushed to the feed.
But if this is days or weeks after the package was originally published to nuget.org, then from the developer's point of view, NuGet might not behave in the way they expect.

### Floating version performance

Currently restore downloads the list of package versions from the package download (flat container) resource, which contains only the version list without any additional metadata.
It's optimized for restore performance.
Therefore, for restore to find the publish date of each version, it will need to download the package metadata (registration) resource instead.
Using the package Microsoft.Extensions.DependencyInjection as an example:

|Metric|flat container|registration|
|--|--|--|
|HTTP requests|1|4|
|combined json size|3.8 KB|1.0 MB (34 KB)|

api.nuget.org does not gzip compress the flat container index.json, but registration metadata is available gzipped, which is why two values are shown, uncompressed and gzipped.
Also consider that the package's nupkg is 302 KB, showing the significant network, cache, and parsing cost of using registration, rather than the flat container for finding the floating version.

NuGet.Protocol version 7.6.0 allocates about 4.7 MB when parsing this under .NET 10, and 5.7 MB on .NET Framework.
CI pipelines are likely to be more sensitive to GC pauses.
Even when individual pauses are short, the cumulative effect can lead to non-trivial increases in restore duration.
Therefore, it will become more important for customers using floating versions to also use lock files to avoid this penalty on CI.
Fortunately, both lock files and cooldown are features related to supply chain security, so it's likely that customers using floating versions with cooldown will also want to use lock files.

### Delayed security fixes

By using a single cooldown value for all packages in a feed, it means that packages with a known security vulnerability will be delayed just as packages without a known vulnerability.
When the fixed package version is legitimate, then fixing the project also gets delayed which exposes the application to risk for a longer time.

However, cooldown is intended to reduce risk of supply chain security attacks by waiting for malicious packages to be discovered and removed before upgrading.
If a malicious actor can publish a new version of a package, they might also be able to publish a security advisory on older versions of the package, as a form of social engineering to trick victims into upgrading.

Therefore there's a balance between taking new versions to fix known security vulnerabilities and waiting for security experts to vet new packages for malicious code.

### Hierarchical nuget.config settings

NuGet accumulates settings from multiple nuget.config files, and if the "closest" file does not have a `<clear />` element in the `<packageSources>` section, then package sources from multiple files can be used.
Typically this shows up as nuget.org being added in the user-profile nuget.config, and company internal feeds being added in a solution directory nuget.config file.
If the user-profile nuget.config is edited to set a cooldown period, this will affect all solutions on the computer (well, that user account on that computer), which may be unintended.
The NuGet team has documented a recommendation that all repos commit a nuget.config where `<clear />` is the first element in the package sources section, to ensure the package sources are deterministic.

## Rationale and alternatives

The cooldown value goes on the package source because cooldown is naturally per-feed, and NuGet.Config aligns better with per-feed settings.
The MSBuild property only controls whether restore applies cooldown to floating versions.

- **Global cooldown** — not chosen. We have per-feed cooldown anyway; a separate global knob just adds configuration points for little benefit (setting the same value on each source already covers it).
- **Per-package cooldown** — not chosen. Not enough benefit for the added complexity.

## Prior Art

Similar "minimum age" / "cooldown" mechanisms exist in other ecosystems and are good precedent for units, defaults, and handling sources without publish timestamps:

- **npm** — `min-release-age` in `.npmrc` (in days), added in npm v11.10.0, delays installing newly published versions.
- **Cargo (Rust)** — [RFC 3923](https://github.com/rust-lang/rfcs/pull/3923) adds `registry.global-min-publish-age` (e.g. `"14 days"`) plus a per-registry `registries.<name>.min-publish-age` override, closely mirroring the per-feed model here. Versions already in `Cargo.lock` are exempt, and an env var can bypass the age for urgent fixes.
- **Dependabot** — a cooldown option to delay dependency update PRs.
- **Renovate** — `minimumReleaseAge` holds back update PRs until a release reaches a configured age.

### A different approach: pinning to a fixed date

Python's [uv](https://docs.astral.sh/uv/) takes a different approach with its `exclude-newer` setting (and the per-package `exclude-newer-package` variant).
Rather than a rolling age relative to "now", it limits resolution to versions published before a fixed date or timestamp (e.g. `2026-01-01`).
This was designed primarily for reproducible resolutions ("resolve the graph as it existed on date X") rather than as a security cooldown, though it can be used to hold back new versions.
The trade-off is that a fixed date must be advanced manually over time, whereas a rolling age like the one proposed here keeps moving forward automatically.

## Unresolved Questions

- **Units.** Is the number days, hours, or minutes (is `72` three days or 72 hours)? Needs to be decided.
- **Known vulnerabilities.** How does cooldown interact with packages that have known vulnerabilities?
  - A second setting that relaxes cooldown when the project currently uses a vulnerable package?
  - Or vulnerable packages skip cooldown so fixes apply immediately?
  - Counterpoint: an attacker who can publish a new version of a popular package may also be able to file an advisory against the old one. Upgrading immediately on an advisory would defeat the cooldown even when the older version genuinely has a CVE. We need to balance fast fixes against this risk.
- **PM UI warning location.** When a source with cooldown enabled doesn't have `published` metadata, where should a warning be displayed?
- **Warning or error when feed does not provide published metadata.** Warning seems appropriate for restore, but should PMC and `dotnet package update` warn or fail?

## Future Possibilities

If per-package or per-prefix cooldown configuration turns out to be valuable, it could be added.

If customers tend to use cooldown on internal feeds in addition to nuget.org, then a "global cooldown" setting could be introduced, so it's not necessary to duplicate the same value on multiple package feeds.

Some kind of "skip cooldown" option could be added to `dotnet package update` and PMC's `Update-Package` commands.
