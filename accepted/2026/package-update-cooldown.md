# ***Package update cooldown V1***

- Author: [zivkan](https://github.com/zivkan/)
- GitHub Issue: [Home#14657](https://github.com/NuGet/Home/issues/14657)

## Summary

Allow automated and assisted package version updates to be delayed by a cooldown period.
This will allow Visual Studio, `dotnet package update`, and `dotnet package list --outdated` to pre-select or report versions that were published at least the configured cooldown period ago.

The initial version will block floating versions when cooldown is enabled, but otherwise not do any cooldown checks during restore.
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
After it's available for use, we'll gather feedback on what improvements are commonly requested.

#### Defining the cooldown

The cooldown is defined in the nuget.config file via a new `minPublishAgeHours` attribute on package sources.
When a source does not have a `minPublishAgeHours` value, it is considered zero, which allows packages to be used immediately.
The value must be an unsigned integer (zero or higher).
All other values will cause config file loading failures.

In addition, a new `<minPublishAgeExceptions>` section, which accepts `<package pattern="{package or prefix}" />` children can be used to exclude certain packages and prefixes from cooldown.
The pattern syntax will be identical to [package source mapping](https://learn.microsoft.com/nuget/consume-packages/package-source-mapping#package-pattern-syntax).

In the following example, diff syntax is used to highlight the proposed changes.

```diff
 <configuration>
   <packageSources>
-    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
+    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" minPublishAgeHours="72" />
     <add key="internal" value="https://contoso.test/nuget/v3/index.json" />
   </packageSources>
+  <minPublishAgeExceptions>
+    <package pattern="System.*" />
+    <package pattern="Fabrikam.WebApi.Client" />
+  </minPublishAgeExceptions>
 </configuration>
```

Visual Studio's Package Sources option page should provide a way to enter the value.
Similarly, `dotnet nuget [add|update] source` commands should add a `--min-publish-age-hours` option.

[NuGet loads multiple nuget.config files](https://learn.microsoft.com/nuget/consume-packages/configuring-nuget-behavior) and merges their settings to come up with a final configuration to use.
The `minPublishAgeHours` attribute on package sources uses the same behavior as `protocolVersion` and `allowInsecureConnections`, which is when a config file re-adds the same key, all the attributes from previous config files are discarded.
When multiple nuget.config files define the `<minPublishAgeExceptions>` section, each config file in the hierarchy will replace the exceptions from previous config files.
This means that exceptions from other configs can't be extended, like package and audit sources, only replaced, just like Package Source Mapping package sources.
To clear the exception list, an empty `<minPublishAgeExceptions />` element is used.

#### Updating package versions

All tooling is expected to be aligned, but the details will be dependent on the specific tool.

- When choosing a version (either for installation, or default selection in a version list), choose the highest version where the package was published longer ago than the configured min publish age.
- When displaying a list of versions, show an indicator for which versions are still in the cooldown period.
- When enumerating packages with available updates, exclude packages which only have versions that are younger than the minimum publish age.
- When the minimum publish age is configured to a non-zero value, but the package source does not provide the publish date for at least one version of the package, display an error.
   Update commands should not modify the project until the configuration error is resolved.
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

Fail restore when cooldown is configured to a non-zero value, and at least one `PackageReference` uses a floating version.
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
In this case, we recommend the re-publish process implement their own cooldown logic and expose versions that satisfy the organization's requirements.
Then additional cooldown on the NuGet client side would be redundant and not needed.

### Delayed security fixes

By using a single cooldown value for all packages in a feed, it means that packages with a known security vulnerability will be delayed just as packages without a known vulnerability.
When the fixed package version is legitimate, then fixing the project also gets delayed, which exposes the application to risk for a longer time.

However, cooldown is intended to reduce risk of supply chain security attacks by waiting for malicious packages to be discovered and removed before upgrading.
If a malicious actor can publish a new version of a package, they might also be able to publish a security advisory on older versions of the package, as a form of social engineering to trick victims into upgrading.

Therefore there's a balance between taking new versions to fix known security vulnerabilities and waiting for security experts to vet new packages for malicious code.
This is a decision that individuals will need to make.
NuGet will not contain defaults that choose between NuGetAudit warnings or violating cooldown periods for you.

External (to NuGet) tooling that perform automated updates, such as Dependabot, have their own configuration independent of NuGet (or other package manager) implementation of cooldown.
Therefore, they may have settings that can be configured, or opinionated behavior that may align with an organization's preferences.

### Hierarchical nuget.config settings

NuGet accumulates settings from multiple nuget.config files, and if the "closest" file does not have a `<clear />` element in the `<packageSources>` section, then package sources from multiple files can be used.
Typically this shows up as nuget.org being added in the user-profile nuget.config, and company internal feeds being added in a solution directory nuget.config file.
If the user-profile nuget.config is edited to set a cooldown period, this may affect multiple solutions on the computer, which may be unintended.
The NuGet team has [documented a recommendation](https://learn.microsoft.com/nuget/concepts/security-best-practices#nuget-configuration) that all repos commit a nuget.config where `<clear />` is the first element in the package sources section, to ensure the package sources are deterministic.

Additionally, if one nuget.config file specifies a source with a cooldown, then another config file "closer" to the solution adds a source with the same key, all the attributes from the first config are discarded.
This may not be intuitive to customers.

## Rationale and alternatives

### Alternate options to define the cooldown period

The [prior-art](#prior-art) section has a link to a website that describes cooldown features across numerous package managers.
The most common feature set is a global cooldown with a list of packages that bypass the cooldown feature.
However, a week after npm implemented the initial cooldown feature, a request to allow internal packages to be updated immediately was created.
We expect this to be the most common NuGet configuration as well, hence a per-source cooldown was chosen over other alternatives.
Since there's one public nuget.org registry, and large companies may have multiple private feeds for different divisions or products, a global cooldown was not chosen for NuGet.
Most .NET solutions have a small number of package sources, so even if multiple sources get set to the same value, it's not expected to be difficult to configure.

A small number of package managers allow per-package overrides.
Since it's only a few package managers, it could be a signal that it's not a very commonly asked for feature.
It could be added in the future, depending on customer requests.

Since cooldown is being configured per source, not per package, and package sources are usually configured in nuget.config files, not MSBuild files, the cooldown configuration is similarly going in the nuget.config files.

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

Supply chain security has multiple things to consider.
Packages with known vulnerabilities is one part.
But attackers using stolen credentials or exploiting another package's supply chain to publish malicious packages is another.
If an attacker has gained permission to publish a package owned by somebody else, they may also have permission to publish a CVE for older versions of the package.
It's up to individual risk management preferences to choose how to handle the conflict.

Additionally, the initial version of cooldown in NuGet will only handle update scenarios, not floating version restores.
Developers can choose to override cooldown and force a specific version to install into a project.
NuGet will then restore that version, regardless of cooldown.
So, whether the personal preference is to wait for the cooldown period to pass, or upgrade vulnerable packages immediately, developers can implement their preferred strategy.

If `TreatWarningsAsErrors` is being used, consider using `WarningsNotAsErrors` to prevent NuGetAudit from blocking all work when a new vulnerability is disclosed and the fixed version is still in cooldown.
You can use MSBuild conditions to choose when to keep it as an error, or when to leave it as a warning, for example [if you use a separate pipeline to validate NuGetAudit success](https://learn.microsoft.com/nuget/concepts/auditing-packages#separating-errors-from-warnings-with-a-dedicated-auditing-pipeline).

### Clearing minPublishAgeExceptions

NuGet reads multiple config files and merges the contents into a single virtual settings.
For package and audit sources, it's necessary to explicitly use `<clear />` to remove sources from lower priority config files (or sources defined before the clear in the same file).
For Package Source Mapping (PSM), the same behavior exists for defining package sources.
However, within a PSM package source, where package patterns are defined, if a package source of the same key is defined, the package patterns defined replace any values from lower priority config files.
This means that the following two XML snippets are semantically equivalent:

```xml
<packageSourceMapping>
  <packageSource key="contoso">
    <package pattern="contoso.*">
  </packageSource>
</packageSourceMapping>

<packageSourceMapping>
  <packageSource key="contoso">
    <clear />
    <package pattern="contoso.*">
  </packageSource>
</packageSourceMapping>
```

However, PSM `packageSource` elements aren't allowed to be empty, so if the goal is to clear the package patterns from lower priority config files, then the `<clear />` is necessary.
PSM package sources are also the only location in NuGet.config where the order of the `<clear />` is not important (will not clear items defined in the same file, before the clear itself).

So, nuget.config files already not consistent with respect to `<clear />` across all different parts of the schema.
The [Package Source Mapping (PSM) spec](../2021/PackageSourceMapping.md) doesn't define whether this was intentional or an implementation bug.
But PSM was implemented years ago, so changing it to become consistent would be a breaking change in a feature related to supply chain security, so unlikely to change.

In the context of this cooldown feature, the decision comes down to what would be least confusing for customers.
Questions we don't have answers to include how many customers understand NuGet's config inheritance, and the importance to use `<clear />` to avoid being affected by machine state?
Is PSM `packageSource` behavior where the `<clear />` is ignored when at least one package pattern is defined clear or confusing?

Given that cooldown is a tool to improve supply chain security, and given the prior art of PSM package sources ignoring `<clear />` elements (when at least one pattern is defined), this proposal is recommending that inheritance does not happen, to reduce risk of unintended nuget.config files adding cooldown exceptions.
I think the PSM package source example above where the `<clear />` element doesn't change behavior is confusing to customers, so unlike PSM package sources, no `<clear />` child element is being proposed, so clearing all prior exceptions is an empty `<minPublishAgeExceptions />` element.

## Prior Art

The website [cooldowns.dev](https://cooldowns.dev/) lists 14 package managers at the time this feature spec is being written.
Of them, 3 have a single cooldown configuration only.
5 have a global cooldown, with per-package exemptions.
2 have a global cooldown, with per-package overrides (different cooldown value).
2 have per-source cooldowns, but no exceptions.
1 has per-source cooldowns and allows per-package exemptions.
1 has per-source cooldowns and supports per-package overrides.

A summary is that the majority of the package managers have a global cooldown value, and a list of packages that bypass cooldown (can be updated immediately).
It appears uncommon, but a few use an approach of only considering packages published at a specific date, so rather than calculating the "age" of a package, it ignores packages published after the cutoff date.

While a few package managers do allow individual packages to have different cooldown values, the number is small.

Dependabot will bypass cooldown when the currently installed package has a known vulnerability.
It also allows different cooldowns for different semver segments.
For example, `semver-major-days`, `semver-minor-days`, under the `cooldown` node in the configuration yaml.

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
