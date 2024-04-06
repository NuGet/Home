# ***Vulnerabilities in packages.config restore***

- [Nikolche Kolev](https://github.com/nkolev92)
- GitHub Issue <https://github.com/NuGet/Home/issues/12307>

## Summary

This is a continuation of the [vulnerabilities in PackageReference work](../2022/vulnerabilities-in-restore.md), extending matching functionality for packages.config restore.

## Motivation

See [vulnerabilities in PackageReference restore motivation](../2022/vulnerabilities-in-restore.md#motivation).

## Explanation

### Functional explanation

#### Raising vulnerability warnings

After every restore, the vulnerability warnings will be displayed for every package with vulnerabilities ([see technical explanation for the visual studio performance optimization](#visual-studio-performance-optimization)).
Packages.config restore combines all packages regardless of project. If 10 projects have a vulnerability package, 10 equivalent warnings will be raised, one for each project. This matches the PackageReference behavior where the warnings are raised on a per project basis, and each projet may contain the same package.

Whenever a vulnerability for a package is discovered, a warning will be raised indicating the severity and advisory url.
Note that warnings as errors and no warn are not supported in packages.config projects, so these warnings will not fail the build.

> Package 'Contoso.Service.APIs' 1.0.3 has a known critical severity vulnerability, https://github.com/advisories/GHSA-1234-5678-9012.

#### Configuring NuGet audit

The configuration knobs for packages.config restore auditing functionality will be MSBuild based.
The `NuGetAudit` and `NuGetAuditLevel` properties are going to be considered the same way they are in PackageReference audit.

#### Enabling the feature

The feature will be enabled by default in Visual Studio 17.10 as restore in packages.config does not fail the build.

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

### Visual Studio performance optimization

Vulnerability warnings will be displayed after every packages.config restore.
In Visual Studio, there will be a caching layer to avoid recalculating stable data when no packages are no downloaded.

To best understand that, we define a packages.config no-op restore, as a restore that does not install any packages in the packages folder.
Given that, vulnerabilties will be raised via the following heuristic.

- Refresh vulnerability warnings at every restore that does not no-op.
- Refresh vulnerabilities during the first restore in Visual Studio.
- Replay vulnerabilities at every no-op restore that's not the first restore in Visual Studio.

This could potentially go out of date, but it's the same optimization as PackageReference restore's no-op.

## Drawbacks

- Vulnerability checking comes with a performance hit.

## Rationale and alternatives

### MSBuild properties vs nuget.config for packages.config restore configuration

The primary consideration for packages.config restore is how the feature is enabled and how the audit levels are configured.
Regardless of whether we take a msbuild property centric or nuget.config centric approach for configuration, the only 2 values that are relevant are: enabling/disabling audit, setting the minimum log level.

Understanding the proposal requires some background about the configuration knobs for restore and packages.config and PackageReference in general.

- packages.config restore/installation has historically been nuget.config based. Nearly all of the packages.config configuration knobs are nuget.config based.
  - [dependencyVersion](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file) - controls the default algorithm for package installation in packages.config
  - [repositoryPath](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file) - controls where the packages folder is
  - [bindingRedirects](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#bindingredirects-section) - configures whether or not the binding redirects are applied.
- However, packages.config project properties are relevant in certain scenarios as well.
  - We infer the Target Framework from those. (project specific, no other way to do it)
  - Repeatable build uses similar properties as the PackageReference, for example you can enable lock files in packages.config restore by setting `RestoreUsePackagesWithLockFile`. Unfortunately those properties are [not consistently respected](https://github.com/NuGet/Home/issues/13170) within Visual Studio, and repeatable builds for packages config (or sha checking) is [not a very commonly used feature](https://github.com/NuGet/Home/issues/10268), as it doesn't have non-[design doc](https://github.com/NuGet/Home/wiki/Packages.config-SHA-Validation) documentation. Note that creating a packages.lock.json file opts in the project into it as well, which means that `RestoreUsePackagesWithLockFile` is not necessary.
  Despite all that though, it doesn't those ideas are not worthwhile.
- packages.config project use the classic style, large project files, which are not commonly edited manually, and as such project properties are used less frequently.
- PackageReference projects tends to use SDK based projects. The large majority of restore configuration knobs are configured as project properties.
Features such as NoWarn, TreatWarningsAsErrors are supported. Usage of Directory.build.props files is common for PackageReference based projects.
- NuGet.Config configurations still affect PackageReference projects. There are quite a few settings that are primarily or only configurable through NuGet.Config.
  - In particular, we encourage that package sources are configuration within nuget.config, ensuring the same behavior across the whole repo. This is configurable both as a project property and in NuGet.config.
  - PackageSourceMapping is only configurable in NuGet.config. The expectation is that these are repository specific.
  - Trusted signers in only configurable in NuGet.Config
- In general, PackageReference is more project centric, while packages.config is more repo centric.
With every configuration knob, it is worth asking whether it is primarily repo or primarily project centric.

Given all that, the pros and cons of a property centric vs a nuget.config centric approach:

| | Pros | Cons |
|-|------|------|
| NuGet.config centric approach | Matches other packages.config configuration knobs. </br> Enabling audit and audit level is a repo setting, not a project one.  | May require 2 configuration knobs for mixed projects, or potentially having a project property page that does not recognize the nuget.config value. |
| Property centric approach | Matches the PackageReference configuration | Introduces a new concept for packages.config users. </br> Implementation cost for functionality that won't be used frequently, if at all. |

Another consideration for these 2 properties is that the default are arguably good enough, and that they'd rarely be configured.

### Enable audit through NuGet.Config

| Key | Acceptable values | Description | Default |
|-----|-------------------|-------------|---------|
| auditForPackagesConfig | enable, disable | Enables or disables NuGet Audit for packages config projects | If not specified, the default will be `enable` |
| auditLevelForPackagesConfig | Critical, high, moderate, low | Configures the default audit level for NuGet audit for packages config projects |  If not specified, the default will be `low` |

The audit functionality for packages.config restore will be enabled by default.
To disable it, one can specify a property in the config section of the configuration file.

```xml
<configuration>
    <config>
        <add key="auditForPackagesConfig" value="enable" />
        <add key="auditLevelForPackagesConfig" value="low" />
    </config>
</configuration>
```

## Prior Art

- [Vulnerability reporting in PackageReference restore](../2022/vulnerabilities-in-restore.md)

## Unresolved Questions

## Future Possibilities

- NuGet Audit without nuget.org as a package source - [Pull Request #12918](https://github.com/NuGet/Home/pull/12918)
