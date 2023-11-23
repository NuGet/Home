# NuGetAudit without nuget.org as a package source
<!-- Replace `Title` with an appropriate title for your design -->

- Author: [zivkan](https://github.com/zivkan)
- GitHub Issue: [12698](https://github.com/NuGet/Home/issues/12698)

## Summary

<!-- One-paragraph description of the proposal. -->
This proposal adds a new `<auditSource>` to *NuGet.Config* files, allowing *NuGetAudit* to obtain known vulnerabilities without adding nuget.org as a package source.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
[NuGetAudit](https://learn.microsoft.com/nuget/concepts/auditing-packages) is a feature where NuGet will report during restore which packages with known vulnerabilities are being used by projects, [proposed in late 2022](../2022/vulnerabilities-in-restore.md), and finally released with .NET 8 in 2023.
The first version of NuGetAudit used package sources as the data source for known vulnerabilities, which will be referred to as a Vulnerability Database (VDB) for the remainder of this document.
While nuget.org provides a VDB, there are several reasons why customers may not be using nuget.org as a package source.
This is especially true following the 2021 [blog post titled "Dependency confusion"](https://medium.com/@alex.birsan/dependency-confusion-4a5d60fec610) which significantly increased knowledge of multi-source package substitution supply chain risks.

While the design of NuGetAudit attempts to make it easy for upstreaming package sources to also upstream the `VulnerabilityInfo` resource, the NuGet team and customers are reliant of the feed implementor to implement the change.
An upstreaming package source is one that either aggregates multiple package sources or caches packages from another package source.
Upstreaming isn't a concept that exists in NuGet, so servers have to present to clients as if all data (packages, search results, vulnerability information) originates from itself.

However, there are also cases where customers are not using upstreaming feeds, but instead curate approved 3rd party packages and manually upload them to an internal feed.
There are also other scenarios where customers do not use nuget.org (directly) as a package source.

It's possible for customers to use [Package Source Mapping](https://learn.microsoft.com/nuget/consume-packages/package-source-mapping) to add nuget.org as a package source, but configured in a way that NuGet will never restore packages from this package source.
However, some developers might consider this an unacceptable risk and prefer another way to get a VDB that cannot accidentally be used to get packages.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

#### auditSources in nuget.config

*NuGet.Config* files have a new section `<auditSources>` where the URL(s) of any audit sources can be specified, which will be used only to download a VDB, and will not be used for downloading packages.
Like `<packageSources>`, `<auditSources>` can contain zero, one, or more sources, and supports `<clear />` to remove any `auditSources` inherited from parent *nuget.config* files.
NuGetAudit will use attempt to download a VDB from both package sources and audit sources.

For example, consider a developer at Contoso using a company-internal source as a single package source, and using nuget.org as an audit source:

```xml
<configuration>
  <packageSources>
    <!-- Clear to ensure package sources not inherited from other config files -->
    <clear />
    <add key="contoso" value="https://internal.corp.contoso.com/packages/nuget/index.json" >
  </packageSources>
  <auditSources>
    <!-- Clear to ensure audit sources not inherited from other config files -->
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" >
  </auditSources>
</configuration>
```

Any URL specified in the `auditSources` section must implement the [NuGet Server API V3 protocol](https://learn.microsoft.com/nuget/api/overview).
However, the server will only need to implement the [`VulnerabilityInfo` resource](https://learn.microsoft.com/en-us/nuget/api/vulnerability-info) (and service index), and can avoid implementing all the other resources that are required to be used as a package source.

NuGet should report a warning to customers if a source listed under `<auditSources>` does not provide a VDB.
However, NuGet should not warn about any `<packageSources>` that do not provide a VDB.
If a customer lists the same URL under both `<auditSources>` and `<packageSources>`, then the warning should be emit.
The exact warning code will depend on which codes are unused at the time of implementation, but NU1905 is a good candidate.

NuGet will use same semantics for `auditSources` as it already has with `packageSources`.
This means that `auditSources` are accumulated from other nuget.config files, and `<clear />` can be used to remove them.
`auditSources` will also follow `packageSources` with regards to insecure http warnings, errors, and `allowInsecureConnections` configurations.
Sources that need credentials will use `packageSourceCredentials`, using the `key` as the lookup, just as `packageSources` does.
This means that credentials can be re-used by using the same key for a source that is defined in both `packageSources` and `auditSources`.

#### Restore summary

When restore is run at normal or detailed verbosity, NuGet outputs detected nuget.config files and package sources (feeds) used.
Audit sources should be added.

```diff
 NuGet Config files used:
     C:\Users\zivkan\AppData\Roaming\NuGet\NuGet.Config

 Feeds used:
     https://internal.corp.contoso.com/packages/nuget/index.json
+
+Audit sources used:
+    https://api.nuget.org/v3/index.json
```

The "Audit sources used" section should ideally list sources where a VDB was successfully obtained.
This depends on the feasibility of implementation.
For example, if two package sources are defined, and no audit sources are defined by the *nuget.config* file, but only one of the two sources has a VDB, then the restore summary will only list the one source with a VDB under "Audit sources used".

If `NuGetAudit` is disabled for all projects in the solution, the audit sources used section of the summary should be omitted.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

NuGet currently uses the `VulnerabilityInfo` V3 server API in two scenarios: restore, and VS's Package Manager UI.
Both of these scenarios will need to use `auditSources`, in addition to `packageSources`.

`dotnet list package --vulnerable` also shows customers vulnerability information.
However, at the time this document is being written it does not use the server's `VulnerabilityInfo`, it uses package metadata (registration) instead.
Therefore, this is being considered out of scope for this feature's V1, but [it is something that can be done in the future](#dotnet-list-package---vulnerable)

## Drawbacks

<!-- Why should we not do this? -->
Customers who appear functionally network isolated from nuget.org (for example, by blocking nuget.org at the firewall) will still need another source that implements the `VulnerabilityInfo` resource, which they could then list either as a `packageSource` or `auditSource`.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

### Only use audit sources, not package sources

The first implementation of NuGet Audit used package sources as the only source for a VDB.
So, it would be a breaking change to stop doing so, and to use audit sources as the only source for VDBs.

It is convenient to use package sources as an audit source, as it increases the feature usage when customers have a package source that provides a VDB, such as nuget.org.
Additionally, it eliminates the need to duplicate the URL in two sections of *NuGet.config* files.

However, overloading a single configuration for multiple reasons can be confusing, and adds a little complexity in documentation and might make it more difficult to clearly explain in a GUI for configuring NuGet's configuration.
It also makes it impossible for customers to configure NuGet to avoid using a package source during audit, which may be desirable when the customer knows the source doesn't provide a VDB and the source needs credentials (especially when the source doesn't have a credential provider).

Originally this spec proposed to use package sources for NuGet Audit only when `auditSources` was empty.
However during review nobody appeared to agree.

### Wait for other servers to implement the VulnerabilityInfo resource

While the NuGet team may be able to influence other teams and encourage them to work on implementing support for the `VulnerabilityInfo` resource, ultimately the teams that implement those NuGet servers have their own backlogs and priorities.
Therefore, the NuGet team doesn't have agency to ensure that it gets implemented, and customers who want to use *NuGetAudit* may not have enough influence to get the implementation prioritized in a timely manor.

Additionally, not all customers use a server that supports upstreaming, or have configured their server to use nuget.org as an upstream source.
An example is developers working in highly regulated industries where packages need to be individually vetted and approved before it can be used.
The reasons customers may do this do not preclude them from using nuget.org as an audit source, so allowing these customers an easy way to use *NuGetAudit* benefits them.

Therefore, in order to provide customers with the ability to use NuGetAudit most easily, it's more effective to implement a new feature that does not depend on other teams to implement features.

### Provide a sample "static feed" with no packages, and use nuget.org's VulnerabilityInfo resource

We could provide a sample of a few json files to put on a static web server that would appear to be a NuGet feed that doesn't have any packages, and its `VulnerabilityInfo` resource would use nuget.org's URL.

The [Sleet](https://github.com/emgarten/Sleet) static feed generator already demonstrates that static feeds are technically feasible.
The only issue is that search doesn't behave nicely, although for an audit source, there wouldn't be any packages, so an empty search result would be correct.

This would give customers confidence that this "package source" really does not provide packages.
However, the difficulty for development teams getting approval to host a server, and the compliance required in doing so, will still be infeasible in many companies.

While the cost of doing this would be very low, once `auditSources` is implemented, there will be no benefit in providing the documentation/samples.

### NuGet Team supplied upsourcing server

The NuGet team could provide a web application that looks like a NuGet package source that never contains any packages (and doesn't support push), and the `VulnerabilityInfo` resource effectively proxies nuget.org's VDB.
However, getting permission to install a new web app is likely difficult in most corporate environments, so wouldn't be practical.

Besides the high up-front cost of implementation, it would also have ongoing maintenance costs to the NuGet team.
For example ensuring it's patched following every Patch Tuesday, and probably maintaining docker images to make it easy to use.

Unlike this spec's proposal, this vulnerability-only upsourcing server idea could in theory enable customers in companies that block nuget.org at the firewall to get always up-to-date VDB.
But in such a restrictive environment, I expect it's even less likely that their security would allow this web app to be installed than other companies that simply have a policy of "don't use nuget.org as a package source".

The NuGet team already has a [NuGet server implementation](https://github.com/NuGet/NuGet.Server) that can be self hosted.
But the V3 NuGet Server API wasn't implemented.
While I find the idea of a reference implementation of NuGet's server API interesting (imagine ASP.NET Core middleware where customers implement a backend interface, and getting new NuGet features is as simple as upgrading the middleware package version), we should consider [NuGet.Server](https://github.com/NuGet/NuGet.Server)'s lack of modernization as a signal that it's likely an unreasonable cost.

### Read vulnerability database from local files

In order to enable customers working in offline environments (or just nuget.org is blocked), the most realistic option is likely to allow NuGet to read the VDB from a file on disk (including a network share).
In these disconnected (from nuget.org) environments, it will be up to the customer to find an approved way with their security compliance to get nuget.org's VDB onto their computer.
In non-disconnected scenarios, we could provide a tool, such as `dotnet tool install -g NuGet.VulnerabilityTool ; NuGet.VulnerabilityTool download -o path/to/destination/`.

However, this doesn't provide any benefit over this spec's proposed *NuGet.Config* `<auditSource>`, coupled with the future possibility's [auditSources with local files](#allow-auditsources-to-point-to-a-filesystem-directory) idea.
It would be worse because for customers who do not have nuget.org blocked at the firewall, it would require a manual action to update the VDB, whereas an audit source would allow NuGet to automatically download and cache the VDB.

### Specify audit sources via MSBuild

Some customers are MSBuild enthusiasts and wish to be able to control everything via MSBuild.
In theory, this could allow customers to avoid having a *nuget.config* file in their repo.
However, there are multiple features in NuGet that only work via *nuget.config*, such as package source credentials, and package source mapping.
Therefore, in order to avoid implementation delays, we'll limit the scope 

Additionally, the biggest benefit to MSBuild is that different projects can use different values.
However, it's not clear what customer benefit would result in being able to use different audit sources in different projects in the same solution or repo.
My best guess is that the most likely scenario is customers using different settings when working in the office compared to working from home.
However, we have not received much feedback that this is desirable for package sources, so it's unlikely that it's important for audit sources.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->
Although [`npm audit`'s help docs](https://docs.npmjs.com/cli/v10/commands/npm-audit?v=true) don't mention it, it appears to have a `--registry={url}` argument, as can be seen on [the Azure DevOps docs on npm audit](https://learn.microsoft.com/azure/devops/artifacts/npm/npm-audit?view=azure-devops&tabs=yaml).

Pypi's `pip` has [an audit command](https://pypi.org/project/pip-audit/), and `--index-url` and `--extra-index-url` appear to enable using custom audit sources.

Rust's cargo audit command has [configuration for the advisory DB URL](https://docs.rs/cargo-audit/latest/cargo_audit/config/struct.DatabaseConfig.html)

Note that for these other package ecosystems, they do not appear to need any explicit configuration file in order to specify default sources (either package source, or audit source).
Instead, defaults appear hard-coded into the app, and it requires explicit configuration to remove.

Contrast this to NuGet's design where NuGet creates a default configuration file at first use, and then requires sources to be explicitly defined.
However, NuGet settings that fall under the `<config>` section of the *nuget.config* file do have hard-coded defaults that do not need to be explicitly defined in any config file.

Both choices have advantages and disadvantages.
Needing explicit config files, as NuGet's package sources do, means it might be easier for customers to discover why a source is being used.
Also, customers are less likely to have unexpected changes if the app changes defaults.
On the other hand, when customers are happy to change with changing defaults, having an explicit config file makes it much more difficult for customers to learn about changed defaults, and from the package manager team's point of view, much more difficult to have customers adopt new defaults.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

All resolved during the spec review process.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

### Allow auditSources to point to a filesystem directory

In order to provide customers who are disconnected from nuget.org (and possibly the internet more widely), we could load the VDB from files on disk.
It would be up to customers to determine how to copy the VDB to their disconnected network/machine.
We could consider a .NET tool, for example `nuget-audit-download` which knows how to communicate with nuget.org's V3 protocol, and merge results into a single file, so that it's easy for customers to obtain the file that needs to be copied.

### Add support for common file formats

<https://osv.dev> is a free vulnerability database, with per-ecosystem downloads available as a zip download.
For NuGet, the URL is <https://osv-vulnerabilities.storage.googleapis.com/NuGet/all.zip>.
It could be interesting to be able to use this URL as an audit source, especially for customers who block access to nuget.org.

### Tooling support

Visual Studio has a GUI to manage package sources, and the `dotnet` CLI has commands such as `dotnet nuget add source`.
The first version of `auditSources` will not include equivalent experiences in order to avoid slowing down the implementation of the first version.

### `dotnet list package --vulnerable`

As mentioned in the [technical explanation](#technical-explanation), `dotnet list package --vulnerable` doesn't currently use servers `VulnerabilityInfo` resource.
A tracking issue to use both `VulnerabilityInfo` and `auditSources` has been created: <https://github.com/NuGet/Home/issues/13026>
