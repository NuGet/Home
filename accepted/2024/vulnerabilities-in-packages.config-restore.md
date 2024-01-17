# ***Vulnerabilities in packages.config restore***

- [Nikolche Kolev](https://github.com/nkolev92)
- GitHub Issue <https://github.com/NuGet/Home/issues/12307>

## Summary

This is a continuation of the [vulnerabilities in PackageReference work](../2022/vulnerabilities-in-restore.md), extending matching functionality for packages.config restore.

## Motivation

See [vulnerabilities in PackageReference restore motivation](../2022/vulnerabilities-in-restore.md#motivation).

## Explanation

### Functional explanation

Packages.config restore combines all packages regardless of project. Instead of raising warnings and errors on a per project level, at restore time, they're raised on a per package level.

The configuration knobs for packages.config restore auditing functionality will be NuGet.config based.
In particular, there will be 2 new configuration keys:

| Key | Acceptable values | Description | Default |
|-----|-------------------|-------------|---------|
| auditForPackagesConfig | enable, disable | Enables or disables NuGet Audit for packages config projects | If not specified, the default will be `enable` |
| auditLevelForPackagesConfig | Critical, high, moderate, low | Configures the default audit level for NuGet audit for packages config projects |  If not specified, the default will be `low` |

The audit functionality for packages.config restore will be enabled by default.
To disable it, one can specify a property in the config section of the configuration file.

```xml
<configuration>
    <config>
        <add key="audit" value="enable" />
        <add key="auditLevel" value="low" />
    </config>
</configuration>
```

Whenever a vulnerability for a package is discovered, a warning will be raised indicating the severity and advisory url.
Note that warnings as errors and no warn are not support in packages.config projects, so these warnings will not fail the build.

> Package 'Contoso.Service.APIs' 1.0.3 has a known critical severity vulnerability, https://github.com/advisories/GHSA-1234-5678-9012.

### Technical explanation

An [AuditUtility](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.PackageManagement/AuditUtility.cs) already exists for packages.config projects, written along similar lines as the AuditUtility for PackageReference.

When we run restore for packages.config, the following metrics will be considered:

- Was Audit enabled
- Was Audit Run
- Reason why audit was not run. (No package downloads for example)
- Sev0Matches
- Sev1Matches
- Sev2Matches
- Sev3Matches
- InvalidSevMatches
- List of package ids with advisories
- Severity
- DownloadDurationSeconds
- CheckPackagesDurationSeconds
- SourcesWithVulnerabilityData

All of these metrics are going to the added to the root vs/nuget/restoreinformation event.

## Drawbacks

- Vulnerability checking comes with a performance hit.

## Rationale and alternatives

- Enable vulnerability checking on demand.

## Prior Art

- [Vulnerability reporting in PackageReference restore](../2022/vulnerabilities-in-restore.md)

## Unresolved Questions

- Should we use MSBuild properties instead?
- Should the NuGet.config configuration *affect* the PackageReference defaults as well?
- What should the vulnerability check frequency be? Every time might lead to a lot of overhead on packages.config restores, since no-ops are currently very fast.
  - A possible alternative is to run on the first restore within a process and everytime a new package is downloaded.
    - That'd basically mean every CLI restore checks for vulnerabilities, but within VS, we only do it selectively, since on-build restores are so many and we don't want people to pay performance penalties.

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

- NuGet Audit without nuget.org as a package source - [Pull Request #12918](https://github.com/NuGet/Home/pull/12918)
