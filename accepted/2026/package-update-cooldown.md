# ***Package update cooldown***

- Author: [zivkan](https://github.com/zivkan/)
- GitHub Issue: [Home#14657](https://github.com/NuGet/Home/issues/14657)

## Summary

Allow automated and assisted package version updates to be delayed by a cooldown period.
This will allow Visual Studio and `dotnet package update` to pre-select a version that was published before the specified cooldown period.

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

#### Defining the cooldown

The cooldown is defined in the nuget.config file via a new `minPublishAgeHours` attribute on package sources.
When a source does not have a `minPublishAgeHours` value, it is considered zero, which allows packages to be used immediately.

```xml
<packageSources>
  <add key="nuget.org" value="https://api.nuget.org/v3/index.json" minPublishAgeHours="72" />
  <add key="internal" value="https://contoso.example/nuget/v3/index.json" />
</packageSources>
```

Visual Studio's Package Sources option page should provide a way to enter the value.
Similarly, `dotnet nuget [add|update] source` commands should add a `--min-publish-age-hours` option.

NuGet creates a default NuGet.Config file in the user-settings directory when it does not exist, with nuget.org added automatically as a package source.
It will not add a cooldown automatically.
This makes the cooldown feature entirely opt-in at this time.

#### Updating package versions

The following actions will need to be updated to support cooldown:

- `dotnet package update`

The command will need to check the publish age exceeds the configured value in all the scenarios where it chooses a version.

When a package source is configured for a cooldown, but the feed doesn't return `published` metadata, a warning will be written to stderr, and the highest version will be used.

- Visual Studio Package Manager UI

There are several places that Visual Studio's Package Manager UI (PMUI) will need changes to take cooldowns into account.

1. Quick install button on the package list.
   - The button should install the highest version that meets the minimum age constraint.
1. Versions dropdown and install button on the package details page.
   - In situations where the versions dropdown currently selects the highest version, it should be changed to the highest version not in the cooldown period.
   - The versions dropdown should have a "(cooldown)" marker on each version still in the cooldown period, similar to "(vulnerable)" or "(deprecated)" for relevant packages.
1. Multiple package updates on the Update tab.
   - When choosing the highest version of each package to update to, it should take cooldown into account.
1. Update tab package count
   - The package count overlay on the Update tab text should show the number of packages that are older than the cooldown date.

In addition the package details page shows the package publish date.
When the date is within the cooldown period, it should show a warning icon, similar to vulnerable or deprecated packages, with a tooltip explaining it's due to the cooldown.

All of the above is hopefully clear when the package source dropdown has a single source selected.
However, when the "(All)" item is selected, then everything becomes more difficult.
If Package Source Mapping is used to make each package only available from a single source, then most people will hopefully agree on what the expected behavior is.
But when a package can come from multiple sources, and the sources don't agree with what the package's publish date was, or the sources have different cooldown settings, then it becomes ambiguous what the expectation should be.

Excluding the multiple-sources complexity, on the Installed, Update and Consolidate tabs, NuGet already downloads package metadata via the registration resource, so all these features should be easy to implement.

However, on the Browse tab, NuGet gets the package list from the feed's search resource, which does not have a `published` property.
Therefore, when a package source has a cooldown enabled, the quick install button will be disabled, requiring users to select the package and use the package details panel to install via the versions dropdown list and install button.
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

#### Changes to restore

Fail restore when cooldown is enabled and at least one `PackageReference` uses a floating version.
The NU code will be determined when the feature is implemented.
Otherwise, restore will not use cooldown settings, and will not warn if a package that was restored is still in the cooldown period.

Please see the [cooldown during restore section](#cooldown-during-restore) for more information.

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

Hopefully this should be a minor inconvenience, because developers are most likely to want to delay packages from nuget.org only, and not company internal feeds, or potentially packages from 3rd party vendors via paid feeds.
However, it could be a problem for internal feeds that host packages sourced from nuget.org.
There are two common ways for feeds to source packages from nuget.org, "up-sourcing" and "re-publishing".

Feeds that have automatic up-sourcing conceptually act similarly to a caching HTTP proxy.
NuGet asks the feed what versions of the package it has, the feed aggregates the list of versions it already has with what nuget.org has (via its own request to nuget.org), then returns the de-duplicated list to NuGet.
If the feed changes the publish date to the date that it was added to the feed, NuGet will be unable to perform cooldown accurately.

Feeds that re-publish nuget.org packages are ones that don't intrinsically know that packages came from nuget.org.
Instead someone, or some other automated process, downloads the package from nuget.org and then pushes the package to the feed.
In this case, the best case is that the feed lists the publish date as when the package was pushed to the feed.
But if this is days or weeks after the package was originally published to nuget.org, then from the developer's point of view, NuGet might not behave in the way they expect.

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

### Alternate options to define the cooldown period

The cooldown value goes on the package source because cooldown is naturally per-feed, and NuGet.Config aligns better with per-feed settings.
There is no existing per-source MSBuild configuration, so attempting to define cooldown via MSBuild would be bigger in scope.

- **Global cooldown** — not chosen. We have per-feed cooldown anyway; a separate global knob just adds configuration points for little benefit (setting the same value on each source already covers it).
- **Per-package cooldown** — not chosen. Not enough benefit for the added complexity.

### Cooldown during restore

Checking cooldown during restore was not chosen due to performance prototyping suggesting it would be infeasible to maintain restore performance.

|Repository|baseline|prototype|delta|
|--|--|--|--|
|[OrchardCore](https://github.com/OrchardCMS/OrchardCore)|14.77s|17.06s|+15.5%|
|[Orleans](https://github.com/dotnet/orleans)|11.46s|13.69s|+19.5%|
|[NuGet.Client](https://github.com/NuGet/NuGet.Client)|22.63s|65.87s|+191.1%|
|[Roslyn](https://github.com/dotnet/roslyn)|40.96s|90.71s|+121.5%|

Investigating and prototyping changes to the protocol in order to enable cooldown checks during restore will slow down delivery of the other features proposed in this spec.
So, if cooldown checks during restore are going to be implemented, it can be done as a follow up after the initial release.
This will mean customers who hand edit MSBuild XML and run restore will not get benefit from this feature initially.

See more details in the [restore prototype details section](#restore-prototype).

Other options include changing floating versions to choose a version not in cooldown, and this will limit perf regressions to solutions that use both floating versions and cooldowns (turn off either, and performance would be unaffected).
Using a lockfile would further limit the performance impact to restores where the lockfile is modified, so "locked-mode" restores will continue to maintain current performance.
However, multiple people in the first round of reviews of this feature spec said (either explicitly, or implicitly) that they expect warnings if any package in the graph is newer than the cooldown period.
So, there's risk of confusion if floating versions use cooldown for version selection, but no warnings if an explicit version or a transitive package is younger than the cooldown period.

### Packages with known vulnerabilities

If a project is already referencing a package that now has a known vulnerability, it may be important to upgrade the package sooner to reduce the time that project may be vulnerable to publicly disclosed bugs.
On the other hand, there are instances of developer machines being compromised and credentials or tokens being stolen.
If the attacker can steal both a nuget.org push token, as well as a suitable github token, the attacker might be able to create a GitHub security advisory, which will then automatically become a NuGetAudit warning within hours.
For this reason, it's not necessarily safer to update a package with a known vulnerability than updating a package without.
Different developers will have different opinions on whether to upgrade.
As long as there's a way for them to upgrade when they decide that upgrading is more important than waiting for the cooldown, their objectives can be met.

If `TreatWarningsAsErrors` is being used, consider using `WarningsNotAsErrors` to prevent NuGetAudit from blocking all work when a new vulnerability is disclosed and the fixed version is still in cooldown.
You can use MSBuild conditions to choose when to keep it as an error, or when to leave it as a warning, for example [if you use a separate pipeline to validate NuGetAudit success](https://learn.microsoft.com/nuget/concepts/auditing-packages#separating-errors-from-warnings-with-a-dedicated-auditing-pipeline).

## Prior Art

Similar "minimum age" / "cooldown" mechanisms exist in other ecosystems and are good precedent for units, defaults, and handling sources without publish timestamps:

- **npm** — `min-release-age` in `.npmrc` (in days), added in npm v11.10.0, delays installing newly published versions.
- **Cargo (Rust)** — [RFC 3923](https://github.com/rust-lang/rfcs/pull/3923) adds `registry.global-min-publish-age` (e.g. `"14 days"`) plus a per-registry `registries.<name>.min-publish-age` override, closely mirroring the per-feed model here.
   Versions already in `Cargo.lock` are exempt, and an env var can bypass the age for urgent fixes.
- **Dependabot** — a cooldown option to delay dependency update PRs.
- **Renovate** — `minimumReleaseAge` holds back update PRs until a release reaches a configured age.

### A different approach: pinning to a fixed date

Python's [uv](https://docs.astral.sh/uv/) takes a different approach with its `exclude-newer` setting (and the per-package `exclude-newer-package` variant).
Rather than a rolling age relative to "now", it limits resolution to versions published before a fixed date or timestamp (e.g. `2026-01-01`).
This was designed primarily for reproducible resolutions ("resolve the graph as it existed on date X") rather than as a security cooldown, though it can be used to hold back new versions.
The trade-off is that a fixed date must be advanced manually over time, whereas a rolling age like the one proposed here keeps moving forward automatically.

## Unresolved Questions

- **PM UI warning location.** When a source with cooldown enabled doesn't have `published` metadata, where should a warning be displayed?
- **Warning or error when feed does not provide published metadata.** Warning seems appropriate for restore, but should PMC and `dotnet package update` warn or fail?
- **Block updates to versions still in cooldown.** If someone uses `dotnet package update` or `Update-Package`, explicitly specify a version number, should we silently allow the update, warn but succeed, or fail the command?
- **PM UI and the (All) package source.** All of the PM UI features become ambiguous when the package source dropdown has the "(All)" item selected, and the package is available in more than one source with different cooldown periods and/or different feeds report the same version published at a different date or time.

## Future Possibilities

Warn during restore about packages still within the cooldown period.

If per-package or per-prefix cooldown configuration turns out to be valuable, it could be added.

If customers tend to use cooldown on internal feeds in addition to nuget.org, then a "global cooldown" setting could be introduced, so it's not necessary to duplicate the same value on multiple package feeds.

Some kind of "skip cooldown" option could be added to `dotnet package update` and PMC's `Update-Package` commands.

## Appendix

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
