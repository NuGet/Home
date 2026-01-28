# ***New hostname for nuget.org audit source***

- Author: [zivkan](https://github.com/zivkan/)
- GitHub Issue: [NuGetGallery#10656](https://github.com/NuGet/NuGetGallery/issues/10656)

## Summary

Create a new URL that can be used with the NuGet.Config `<auditSources>` element in networks where www.nuget.org and api.nuget.org are blocked.
This new host must contain only vulnerability information (no package download, search, registration, or other endpoints).

## Motivation

Package substitution, or dependency confusion, is a security risk where a package manager is configured to download packages from multiple sources, and a package that is intended to be downloaded from a company's private source is instead downloaded from another source.
If the package's payload is malicious, it is a vector for remote code execution (RCE) attacks.
As mentioned in NuGet's [best practices for a secure software supply chain documentation](https://learn.microsoft.com/nuget/concepts/security-best-practices), Package Source Mapping and audit sources are built-in ways to mitigate the risk, and another is to block api.nuget.org and www.nuget.org so that only company-controlled package sources may be used.
Teams using the block approach either need to mirror packages they need from nuget.org onto their private feed, or use a NuGet server that can automate it for them, while still providing the protection they desire.

NuGet also added a feature, NuGet Audit, which will generate warnings during restore when packages with known vulnerabilities are used.
To make onboarding onto the feature easy, a `VulnerabilityInfo` resource was added to the V3 service index, so that anyone using https://api.nuget.org/v3/index.json as a package source (which NuGet uses by default when no configuration file says otherwise) can use NuGet Audit automatically.

The combination of the two means that companies that block api.nuget.org to mitigate the risk of package substitution can no longer use NuGet Audit, unless the NuGet server they use for their private feed also supports it.

## Explanation

### Functional explanation

If audit.nuget.org is chosen as the new hostname, then companies that block nuget.org for package substitution reasons could put audit.nuget.org on their DNS/network allow list.
Then, teams could configure their solution NuGet.Config files as follows:

```xml
<configuration>
  <packageSources>
    <clear />
    <add key="contoso" value="https://pkgs.dev.azure.com/contoso/public/_packaging/my-project-feed/nuget/v3/index.json" />
  </packageSources>
  <auditSources>
    <clear />
    <add key="nuget.org" value="https://audit.nuget.org/v3/index.json" />
  </auditSources>
</configuration>
```

By using a single package source, they delegate the risk of package substitution to the server configuration of the package source they've configured, and using audit sources allows them to get warnings about vulnerable packages.

### Technical explanation

The service index on this new hostname should contain only the `VulnerabilityInfo` resource, and nothing else.
It's absolutely critical that this hostname cannot serve arbitrary binaries, otherwise it will not be trusted for the same reason that api.nuget.org gets blocked.

The way that NuGet's server protocol is designed, the service index file contains absolute URLs to individual resources.
NuGet Audit uses the `VulnerabilityInfo` resource:

```json
{
  "@id": "https://api.nuget.org/v3/vulnerabilities/index.json",
  "@type": "VulnerabilityInfo/6.7.0",
  "comment": "The endpoint for discovering information about vulnerabilities of packages in this package source."
},
```

Similarly, the vulnerability index page contains links to vulnerability pages:

```json
{
    "@name": "base",
    "@id": "https://api.nuget.org/v3-vulnerabilities/2026.01.15.05.28.15/vulnerability.base.json",
    "@updated": "2026-01-15T05:28:15.6714127Z",
    "comment": "The base data for vulnerability update periodically"
  },
```

Both of these files need the URLs listed to be changed to the new hostname.

## Drawbacks

This only helps in situations where DNS-level blocks are used.
If the new hostname is hosted on the same CDN that api.nuget.org is hosted on, then they're likely to resolve to the same IP address, and therefore an IP-level block will block both.

However, I think that IP-level blocks are less likely than DNS-level blocks for the following reasons:

- nuget.org does not publish what IP addresses the service is available on ([currently?](https://github.com/NuGet/NuGetGallery/issues/8883))
- CDNs will resolve the hostname to different IP addresses in different geographic regions
- CDNs might change the IP address within the same geographic region, either intentionally, or a developer's machine might take a different network path to the CDN.
- CDNs might use the same IP address to host multiple websites, so blocking api.nuget.org's website can block other websites that the company wants to use

## Rationale and alternatives

NuGet servers can implement the VulnerabilityInfo resource.
However, at best the NuGet team can contribute to implementations of open-source NuGet servers.
Otherwise we can't do anything more than ask closed-source NuGet servers to implement it.

The NuGet client team had a customer report a problem where their third-party NuGet server added the VulnerabilityInfo resource by pointing it to api.nuget.org.
This means that NuGet and Visual Studio were having network problems because their package source was directing NuGet to access a URL that was being blocked at their firewall.
So, even when a third-party NuGet server implementation adds the VulnerabilityInfo resource, it might be done in a way that doesn't work for the customer.

Additionally, in some companies, individual developers may have limited influence over which NuGet server the company or team uses.
If they're mandated to use a specific server that does not provide the VulnerabilityInfo resource to allow NuGet Audit to work, and api.nuget.org is also blocked at the firewall, then there's no path for that developer to use NuGet Audit.
An audit only host will be easier to get approval to unblock at the firewall than switching the entire company to a new NuGet server, allowing the developer to use it as an `auditSource` in their nuget.config file.

## Prior Art

Rust's `cargo-audit`, and Python's `pypi` are similar.
They download packages from one server, and download an audit database from a different server (both appear to use github.com as their CDN).

NPM does not appear to have similar functionality.
Information I've been able to find is that NPM uses a security endpoint on the configured package registries, so the same hostname is used for downloading packages and auditing.
However, NPM sends the package graph to the server, rather than downloading an audit database to check locally, so there are different tradeoffs to consider.

## Unresolved Questions

All questions have been resolved at the time of this spec being merged.

## Future Possibilities

Some kind of validation that the new hostname only has audit information and not binary files for download.
However, customer development would be needed to understand how this validation can work.
Package Source Mapping and Audit Sources already implement NuGet client side protections against downloading arbitrary binaries from unwanted package sources.
But if a company's security team blocks api.nuget.org at the firewall, this suggests that the security team either don't trust NuGet's client side settings, or want to protect against misconfiguration.
We need feedback about what type of client side validation will satisfy the security team to unblock the DNS name, while providing value over looking at the URL in a web browser.
