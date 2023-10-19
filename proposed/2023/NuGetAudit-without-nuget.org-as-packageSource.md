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
This is especially true following the 2021 blog post titled "Dependency confusion" which significantly increased knowledge of multi-source package substitution supply chain risks.

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
*NuGet.Config* files have a new section `<auditSources>` where the URL(s) of any audit sources can be specified, which will be used only to download a VDB, and will not be used for downloading packages.
Like `<packageSources>`, `<auditSources>` can contain zero, one, or more sources, and supports `<clear />`.
When there is at least one source in `auditSources`, NuGet should no longer use `packageSources` to get a VDB.

For example, consider a developer at Contoso using a company-internal source as a single package source, and using nuget.org as an audit source:

```xml
<configuration>
  <packageSources>
    <clear />
    <add key="contoso" value="https://internal.corp.contoso.com/packages/nuget/index.json" >
  </packageSources>
  <auditSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" >
  </auditSources>
</configuration>
```

Any URL specified in the `auditSources` section must implement the [NuGet Server API V3 protocol](https://learn.microsoft.com/nuget/api/overview).
However, the server will only need to implement the [`VulnerabilityInfo` resource](https://learn.microsoft.com/en-us/nuget/api/vulnerability-info) (and service index), and can avoid implementing all the other resources that are required to be used as a package source.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

Not using `packageSources` for VDB when there's at least one source in `auditSources` is a performance optimization.
Since we expect customers to use `auditSources` when their `packageSources` don't already provide a VDB, having restore spend time making HTTP requests to the package sources is unlikely to provide any benefit.
While downloading the VDB from audit sources is likely to take more time than verifying that package sources don't have a vulnerability resource, if any package source is slow, downloading the VDB from the audit source might complete first.
Additionally, in the case where NuGet doesn't otherwise need to communicate with any package source, checking the package sources for a VDB might trigger a credential provider.

## Drawbacks

<!-- Why should we not do this? -->
Customers who appear functionally network isolated from nuget.org (for example, by blocking nuget.org at the firewall) will still not be able to use this feature.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

### Wait for other servers to implement the VulnerabilityInfo resource

While the NuGet team may be able to influence other teams and encourage them to work on implementing support for the `VulnerabilityInfo` resource, ultimately the teams that implement those NuGet servers have their own backlogs and priorities.
Therefore, the NuGet team doesn't have agency to ensure that it gets implemented, and customers who want to use *NuGetAudit* may not have enough influence to get the implementation prioritized in a timely manor.

Additionally, not all customers use a server that supports upstreaming, or have configured their server to use nuget.org as an upstream source.
An example is developers working in highly regulated industries where packages need to be individually vetted and approved before it can be used.
The reasons customers may do this do not preclude them from using nuget.org as an audit source, so allowing these customers an easy way to use *NuGetAudit* benefits them.

Therefore, in order to provide customers with the ability to use NuGetAudit most easily, it's more effective to implement a new feature that does not depend on other teams to implement features.

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

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

1. default value?

   Should we add nuget.org as a default value, so that customers who remove nuget.org as a package source are more easily able to use NuGetAudit?
   Would using nuget.org as a default audit source cause undue concern from customers who don't want to use nuget.org as a package source, and the new tooling version starts making network requests to nuget.org?

   If we want to make nuget.org a default/automatic audit source, how?
   NuGet has tried before to use a tracking file to automatically add nuget's v3 URL as a package source to user-profile nuget.config files that don't have any package sources.
   However, this caused a security issue when customers wanted to remove nuget.org as a default package source, and this code incorrectly re-added it once (the customer could successfully remove nuget.org a second time).
   When we removed this auto-update to mitigate the security concern, it exposed a bug where multiple other apps created user-profile nuget.config files without any package sources, and many customers assumed it was a bug with NuGet.

   Should we hard-code nuget.org's default URL in NuGet.Configuration, and require customers to use `<clear/>` if they don't want any audit source?

   Should we just add it as a default in new user-profile nuget.config files, and just accept that existing developers won't get it by default?

2. Stop using package source as audit source?

   On one hand, using package sources as a defacto audit source makes it easier for customers to use the feature when they knowingly or unknowingly use a package source with a VDB.
   On the other hand, overloading `<packageSources>` with multiple meanings is confusing and customers probably won't understand why sometimes they get vulnerable package information and sometimes they don't.
   If we add nuget.org as a default audit source, and don't use packageSources when auditSources has a value, then using packageSources to get a VDB when auditSources is empty will be particularly confusing/unintuitive to customers.

   Another challenge is that if we want to change the behavior it' will be a breaking change, which is typically discouraged.
   However, given that nuget.org is the only know source with a VDB, if we make nuget.org a default audit source, then it will effectively be a non-breaking change.

3. Tooling

   How important is it to add CLI commands to manage audit sources?
   How important is it to add a GUI in Visual Studio to manage audit sources?

4. Restore summary

   When you restore at normal verbosity, NuGet outputs a list of package sources that were used for restore. Should we add audit sources as well?
   If so, presumably we should only output it if at least 1 project in the restore has NuGetAudit enabled, as outputting audit sources when NuGetAudit is disabled for all projects might confuse customers.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

### Allow auditSources to point to a filesystem directory

In order to provide customers who are disconnected from nuget.org (and possibly the internet more widely), we could load the VDB from files on disk.
It would be up to customers to determine how to copy the VDB to their disconnected network/machine.
We could consider a .NET tool, for example `nuget-audit-download` which knows how to communicate with nuget.org's V3 protocol, and merge results into a single file, so that it's easy for customers to obtain the file that needs to be copied.

### Add support for common file formats

https://osv.dev is a free vulnerability database, with per-ecosystem downloads available as a zip download.
For NuGet, the URL is https://osv-vulnerabilities.storage.googleapis.com/NuGet/all.zip.
It could be interesting to be able to use this URL as an audit source, especially for customers who block access to nuget.org.
