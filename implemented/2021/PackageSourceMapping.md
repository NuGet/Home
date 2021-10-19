# Package Source Mapping

- [Jon Douglas](https://github.com/JonDouglas) & [Nikolche Kolev](https://github.com/nkolev92) & [Chris Gill](https://github.com/chgill-MSFT)
- Start Date: (2021-02-19)
- GitHub Issue ([6867](https://github.com/NuGet/Home/issues/6867))

## Status

This feature is released in preview and will GA with Visual Studio 17.0.

Release announcement: https://devblogs.microsoft.com/nuget/introducing-package-source-mapping/

 compatible with the following tools:

* [Visual Studio 2022 preview 4](https://visualstudio.microsoft.com/vs/preview/) and later
* [nuget.exe 6.0.0-preview.4](https://www.nuget.org/downloads) and later
* [.NET SDK 6.0.100-rc.1](https://devblogs.microsoft.com/nuget/introducing-package-source-mapping/#package-source-mapping-rules) and later

Older tooling will ignore the Package Source Mapping configuration. To use this feature, ensure all your build environments use compatible tooling versions.

Package Source Mappings will apply to all project types as long as compatible tooling is used for build and restore.

## Summary

<!-- One-paragraph description of the proposal. -->
NuGet allows access to all package IDs on a package source. However, many .NET developers have needs to filter & consume a subset of the package IDs available on public, private, and local sources. Although NuGet supports a concept of [trusted-signers](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-trusted-signers) to trust packages signed by specific authors, users would like to optionally specify which package IDs should be allowed from which sources.

This proposal introduces a concept known as Package Source Mapping that allows developers to map package ID patterns, including exact IDs and package ID prefixes, to specific sources. These mappings will enable users to centrally manage what packages are allowed in their solution and where those packages should come from.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Giving the user more control on what packages are allowed in their software supply chain is an on-going need in the .NET ecosystem. Today, users do not have much control nor capabilities to filter the software dependencies they would consider including in their project. There's a misconception about open source dependencies being more secure which is known as the [Linus' Law](https://en.wikipedia.org/wiki/Linus%27s_Law), which allowing the world an opportunity at your software supply chain is posing a greater risk as more new packages are created everyday. Many requirements by organizations is quite the opposite. Having a controlled list of dependencies that are allowed within the company's policy is regular procedure & considered a best practice.

By providing an allowlist of package ID patterns, we believe we can meet the security needs of the ecosystem from cybersquatting & typosquatting attacks like [Dependency Confusion](https://medium.com/@alex.birsan/dependency-confusion-4a5d60fec610). Additionally, we can extend a security feature that makes NuGet unique of allowing [package creators to reserve a package ID prefix](https://docs.microsoft.com/nuget/nuget-org/id-prefix-reservation).

This work will also allow future experiences in browsing, installing, and updating packages under an allowed list of package ID patterns to make developers secure by default when managing their dependencies in their software supply chain.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
When using a combination of public, private, and local sources defined in `NuGet.config` file(s), a user can add a new `<packageSourceMapping>` element to opt-in to the feature. Lastly by adding individual `<package pattern="">` elements in the `<packageSource>` node, the source will only allow the matching package IDs from the respective package source.

**Prerequisites**

Have or create a repo-level `nuget.config` file by executing `dotnet new nugetconfig` at the repo root. In your `nuget.config`, define your package sources.

```xml
<!-- [Optional] Define a global packages folder for your repository. -->
<config>
  <add key="globalPackagesFolder" value="globalPackagesFolder" />
</config>

<!-- Define my package sources, nuget.org and contoso.com. -->
<!-- `clear` ensures no additional sources are inherited from another config file. -->
<packageSources>
  <clear />
  <!-- `key` can be any identifier for your source. -->
  <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  <add key="contoso" value="https://contoso.com/packages/" />
</packageSources>
```

**Definition:**

Add a new `<packageSourceMapping>` element within the `NuGet.config` using the following syntax:

```xml
<!-- Define your source mapping element -->
<packageSourceMapping>
 
</packageSourceMapping>
```

Define the `<packageSource>` element within the `<packageSourceMapping>` parent with the name of a valid package source:

```xml
<!-- Define your source mapping element -->
<packageSourceMapping>

    <packagesource key="nuget.org">

    </packageSource>
 
</packageSourceMapping>
```

Next, add `<package pattern="">` elements under the `<packageSource>` to map matching package IDs to that source. Patterns can be defined as an exact package ID or a package ID prefix using a wildcard(*) to match the glob pattern of 0 or more package ID(s):

```xml
<!-- Define your source mapping element -->
<packageSourceMapping>
    <!-- Add a pattern for Microsoft.* or NuGet.* under the nuget.org source. -->
    <packagesource key="nuget.org">
        <package pattern="Microsoft.*" />
        <package pattern="NuGet.*" />
    </packageSource>
 
</packageSourceMapping>
```

Repeat this process for all sources.

When using package source mapping, every source should have a list of allowed package patterns.
A user may also pin a specific package id instead of broader package ID prefix.

The most specific pattern that matches a package ID will have the highest precedence. Patterns with exact IDs will always have the highest precedence over a prefix pattern.

When you're finished, your `nuget.config` might look like the following:

**Example:**

```xml
<!-- [Optional] Define a global packages folder for your repository. -->
<config>
  <add key="globalPackagesFolder" value="globalPackagesFolder" />
</config>

<!-- Define my package sources, nuget.org and contoso.com. -->
<!-- `clear` ensures no additional sources are inherited from another config file. -->
<packageSources>
  <clear />
  <!-- `key` can be any identifier for your source. -->
  <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  <add key="contoso" value="https://contoso.com/packages/" />
</packageSources>

<!-- Define your source mapping element -->
<packageSourceMapping>
    <!-- Add a pattern for Microsoft.* or NuGet.* under the nuget.org source. -->
    <packagesource key="nuget.org">
        <package pattern="Microsoft.*" />
        <package pattern="NuGet.*" />
    </packageSource>

    <!-- Add a pattern for Contoso.* under the contoso source. -->
    <packagesource key="contoso">
        <package pattern="Contoso.*" />
        <!-- Add a specific id to be download from  the contoso source. -->
        <package pattern="Special.Package.With.An.Imperfect.Id" />
    </packageSource>
 
</packageSourceMapping>
```

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

#### Technical background - how NuGet package installation works today

This approach builds on top of the current package installation behavior as described in the [package installation process](https://docs.microsoft.com/nuget/concepts/package-installation-process).

A few other important concepts:

- global packages folder - The installation directory for all packages in PackageReference. Think of this as the `Program Files` equivalent. All packages are consumed from this location. A single package installation can be shared safely among many different builds. A project *does not own* a specific package installation.
The global packages folder is an *append only* resource. This means NuGet only ever installs a new package. There is **no** refreshing, or overriding, or `re-installing` packages of any kind.
- When requesting a particular version (not floating), local, file sources are currently preferred - When installing a package, NuGet checks local sources independently before checking http sources.
- Package installation is operation based - If 3 projects are being restored during that operation, and all those projects have a dependency to `Newtonsoft.Json`, version `9.0.1`, in regular scenarios, only 1 project will *actually* download and install the package. The other projects will use the already installed version.
- `.nupkg.metadata` - Each package installation directory contains a `.nupkg.metadata` file which signify that a package installation is complete. This is expected to be the last file written in the package directory. This file is *not* use during build. NuGet.Client writes the package source information inside this file.

#### Package Source Mapping rules

1. Two types of package patterns are supported:

    a. `NuGet.*` - Package prefixes. Must end with a `*`, which may match 0 or more characters. `*` is the broadest valid prefix that matches all package IDs, but will have the lowest precedence by default. `NuGet*` is also valid and will match package IDs `NuGet`, `NuGetFoo`, and `NuGet.Bar`.
    
    b. `NuGet.Common` - Exact package IDs.

2. Any requested package ID must map to one or more sources by matching a defined package ID pattern. In other words, once you have defined a `packageSourceMapping` element you must explicitly define which sources *every* package - *including transitive packages* - will be restored from.

    a. Both top level (directly installed) *and transitive* packages must match defined patterns. There is no requirement that a top level package and its dependencies come from the same source.
    
    b. The same ID pattern can be defined on multiple sources, allowing matching package IDs to be restored from any of the feeds that define the pattern. However, this isn't recommended due to the impact on restore predictability (a given package could come from multiple sources).

3. When multiple unique patterns match a package ID, the most specific (longest) match will be preferred. 

    a. Exact package ID patterns always have the highest precedence while the generic `*` always has the lowest precedence. For an example package ID `NuGet.Common`, the following package ID patterns are ordered from highest to lowest precedence: `NuGet.Common`, `NuGet.*`, `*`. 

4. Package Source Mapping settings are applied following [nuget.config precedence rules](https://docs.microsoft.com/nuget/consume-packages/configuring-nuget-behavior#how-settings-are-applied) when multiple `nuget.config` files at various levels (machine-level, user-level, repo-level) are present. 

> Important: When the requested package already exists in the global packages folder, no source look-up will happen and the mappings will be ignored. Declare a [global packages folder for your repo](https://docs.microsoft.com/nuget/reference/nuget-config-file#config-section) to gain the full security benefits of this feature. Work to improve the experience with the default global packages folder in planned for a next iteration.

#### Packge Source Mapping strategies and tips

* Use a repo-specific `nuget.config` file as a best practice. User and machine level config files add complexity through inheritance as explained in the [nuget.config precedence rules](https://docs.microsoft.com/nuget/consume-packages/configuring-nuget-behavior#how-settings-are-applied).
* Add a `<clear />` statement in your <packageSources> element to ensure no sources are inherited from lower level configs.
* Use broad package ID prefixes like `Microsoft.*` and take advantage of the precedence rules to efficiently onboard and scale your configuration to large solutions.
* Use narrow package ID prefixes or exact IDs to effectively use your source mappings as a centralized package allowlist.
* `*` is a valid ID prefix that matches all package IDs but also has the lowest precedence. Defining it for a source will effectively make that source your default source where all packages that don't match more specific defined patterns will be restored from.
* Having the exact same package ID pattern defined for multiple sources is allowed. However, this practice is not recommended as it introduces potential restore inconsistencies.
* Using a consistent unique prefix for internal packages such as `CompanyName.Internal.*` will make your configurations easier to define and manage.

#### Examples

**Scenario 1:**

The following are single project scenarios.

The sources are:

- `nuget.org` : `https://api.nuget.org/v3/index.json`
- `contoso` : `https://contoso.org/v3/index.json`

**Scenario 1A:**

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

Microsoft.C 1.0.0 -> Microsoft.B 1.0.0

```xml
<PackageReference Include="NuGet.A" Version="1.0.0" />
<PackageReference Include="Microsoft.C" Version="1.0.0" />
```

```xml
<packageSourceMapping>
    <packagesource key="nuget.org">
        <package pattern="NuGet.*" />
    </packageSource>
    <packagesource key="contoso">
        <package pattern="Microsoft.*" />
    </packageSource>
</packageSourceMapping>
```

**Result:**

- Package `NuGet.A` gets installed from `nuget.org`.
- Package `Microsoft.C` gets installed from `contoso`.
- Package `Microsoft.B` gets installed from `contoso`.

**Scenario 1B:**

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

Microsoft.C 1.0.0 -> Microsoft.B 2.0.0

NuGet.Internal.D 1.0.0

```xml
<PackageReference Include="NuGet.A" Version="1.0.0" />
<PackageReference Include="Microsoft.C" Version="1.0.0" />
<PackageReference Include="NuGet.Internal.D" Version="1.0.0" />
```

```xml
<packageSourceMapping>
    <packagesource key="nuget.org">
        <package pattern="NuGet.*" />
        <package pattern="Microsoft.B" />
    </packageSource>
    <packagesource key="contoso">
        <package pattern="Microsoft.*" />
        <package pattern="NuGet.Internal.*" />
    </packageSource>
</packageSourceMapping>
```

**Result:**

- Package `NuGet.A` gets installed from `nuget.org`.
- Package `Microsoft.C` gets installed from `contoso`.
- Package `Microsoft.B` gets installed from `nuget.org`. Even though the `contoso` namespace matches, the `nuget.org` one is an exact package id match.
- Package `NuGet.Internal.D` gets installed from `contoso`, because the prefix match is more specific.

**Scenario 1C:**

A 1.0.0 -> Microsoft.B 1.0.0

Microsoft.C 1.0.0 -> Microsoft.B 2.0.0

```xml
<PackageReference Include="A" Version="1.0.0" />
<PackageReference Include="Microsoft.C" Version="1.0.0" />
```

```xml
<packageSourceMapping>
    <packagesource key="nuget.org">
        <package pattern="NuGet.*" />
    </packageSource>
    <packagesource key="contoso">
        <package pattern="Microsoft.*" />
    </packageSource>
</packageSourceMapping>

```

**Result:**

- Package `A` fails installation as none of the patterns match.

**Scenario 1D:**

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

Microsoft.C 1.0.0

```xml
<PackageReference Include="NuGet.A" Version="1.0.0"/>
<PackageReference Include="Microsoft.C" Version="1.0.0"/>
```

```xml
<packageSourceMapping>
    <packagesource key="nuget.org">
        <package pattern="NuGet.*" />
    </packageSource>
    <!-- no patterns for contoso source -->
</packageSourceMapping>
```

**Result:**

- Package `NuGet.A` will be installed from `nuget.org`.
- Package `Microsoft.B` will fail installing as there's no matching pattern.
- Package `Microsoft.C` will fail installing as there's no matching pattern.

**Scenario 1E:**

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

Microsoft.C 1.0.0 -> Microsoft.B 2.0.0

```xml
<PackageReference Include="NuGet.A" Version="1.0.0" />
<PackageReference Include="Microsoft.C" Version="1.0.0" />
```

```xml
<packageSourceMapping>
    <packagesource key="nuget.org">
        <package pattern="NuGet.*" />
        <package pattern="Microsoft.*" />
    </packageSource>
    <packagesource key="contoso">
        <package pattern="Microsoft.*" />
    </packageSource>
</packageSourceMapping>

```

**Result:**

- Package `NuGet.A` will installed from `nuget.org`.
- Package `Microsoft.C` is inconsistent, can get installed from either `nuget.org` or `contoso`.
- Package `Microsoft.B` is inconsistent, can get installed from either `nuget.org` or `contoso`.

**Scenario 1F:**

Microsoft.A 1.0.0

Microsoft.Community.B 1.0.0

```xml
<PackageReference Include="Microsoft.A" Version="1.0.0" />
<PackageReference Include="Microsoft.Community.B" Version="1.0.0" />
```

```xml
<packageSourceMapping>
    <packagesource key="nuget.org">
        <package pattern="Microsoft.Community.*" />
    </packageSource>
    <packagesource key="contoso">
        <package pattern="Microsoft.Community.*" />
        <package pattern="Microsoft.*" />
    </packageSource>
</packageSourceMapping>

```

**Result:**

- Package `Microsoft.A` gets installed from `contoso`.
- Package `Microsoft.Community.B` is inconsistent, can get installed from either `nuget.org` or `contoso`.

**Scenario 1G:**

NuGetA 1.0.0 -> Microsoft.B 1.0.0

```xml
<PackageReference Include="NuGetA" Version="1.0.0"/>
```

```xml
<packageSourceMapping>
    <packagesource key="nuget.org">
        <package pattern="NuGet*" />
    </packageSource>
    <packagesource key="contoso">
        <package pattern="*" />
    </packageSource>
</packageSourceMapping>

```

**Result:**

- Package `NuGetA` will be installed from `nuget.org`. ID prefixes do not need `.` delimiters.
- Package `Microsoft.B` will be installed from `contoso`. `*` is a valid ID prefix that matches all package IDs and be used to define a default/fallback source. However, `*` has the lowest precedence and will "lose" if a package ID matches a more specific pattern.

**Scenario 1H:**

```xml
<PackageReference Include="Microsoft.A" Version="1.0.0"/>
<PackageReference Include="Newtonsoft.Json" Version="11.0.0"/>
<PackageReference Include="Serilog" Version="11.0.0"/>
<PackageReference Include="Contoso.Is.Private.Package" Version="1.0.0"/>
```

```xml
<packageSourceMapping>
    <packagesource key="nuget.org">
        <package pattern="Serilog" />
        <package pattern="Microsoft.Extensions.Options" />
        <package pattern="Newtonsoft.Json" />
    </packageSource>
    <packagesource key="contoso">
        <package pattern="*" />
    </packageSource>
</packageSourceMapping>
```

**Result:**

- `Serilog`, `Microsoft.A`, and `Newtonsoft.Json` are all installed from `nuget.org`.
- `Microsoft.Is.Private.Package` is installed from `contoso` feed.
- All packages not explicitly defined by the listed patterns will be only be searched for from `contoso` feed due to matching `*`.

Essentially, this configuration makes my internal feed a "default" and creates an explicit allowlist for `nuget.org` packages.

---

**Scenario 2:**

The following are multi project scenarios.

The sources are:

- `nuget.org` : `https://api.nuget.org/v3/index.json`
- `contoso` : `https://contoso.org/v3/index.json`

**Scenario 2A:**

Commandline PackageReference restore supports project level configuration. This equivalent is not support in Visual Studio, so this is not a recommended setup.

Given that, it's theoretically possible to get into an ambigious scenario.

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

```xml
<!-- Project 1 Config -->
<packageSourceMapping>
    <packagesource key="nuget.org">
        <package pattern="NuGet.*" />
    </packageSource>
    <packagesource key="contoso">
        <package pattern="Microsoft.*" />
    </packageSource>
</packageSourceMapping>
```

```xml
<!-- Project 1 -->
<PackageReference Include="NuGet.A" Version="1.0.0" />
```

```xml
<!-- Project 2 Config -->
<packageSourceMapping>
    <packagesource key="nuget.org">
        <package pattern="Microsoft.*" />
    </packageSource>
    <packagesource key="contoso">
        <package pattern="NuGet.*" />
    </packageSource>
</packageSourceMapping>
```

```xml
<!-- Project 2 -->
<PackageReference Include="Microsoft.B" Version="1.0.0" />
```

**Result:**

- Not deterministic, because it depends on the order in which the projects are restored, this could lead to either package getting restored from either source.
This is *not* a common, nor a recommended scenario.

## Drawbacks

<!-- Why should we not do this? -->
There are many ways to exclude & include dependencies in various CI/CD providers like Azure DevOps, GitHub Actions, and more. These are typically for individual dependencies or upstream packages. This however is not supported universally for each CI/CD provider & can be confusing on the limitations.

Package Source Mapping has best security practices in mind at the cost of user experience. One thing NuGet is known for is "just working". By using Package Source Mapping, we are functionally changing how you might think about including new dependencies into your software supply chain.

The migration for users to leverage Package Source Mapping will be tedious as they will need to lookup each package ID / namespace used in their project(s). There are no tools planned to do this on behalf of the user & therefore will be a one-time manual effort.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

We believe that this feature provides the highest degree of control and allows users to be more secure using NuGet than they have ever been. Given that other ecosystems like npm & Maven support a concept of scoped or banned dependencies through a concept of source mapping, NuGet would largely benefit from this type of feature as it complements NuGet's existing ability of [reserving package ID prefixes on `nuget.org`](https://docs.microsoft.com/nuget/nuget-org/id-prefix-reservation). This is a benefit for any internal packages in which a [best practice is having a package prefix](https://docs.microsoft.com/nuget/create-packages/package-authoring-best-practices#package-id).

The primary alternative to this feature was a concept known as source pinning which would allow you to specify a source on a `<PackageReference>`. We found the feasibility of this feature implementation to be difficult when dealing with [transitive dependencies](https://en.wikipedia.org/wiki/Transitive_dependency) & it's support for `<PackageReference>` only although it had an intuitive UX. We believe that this current proposal captures the spirit of being able to pin sources.

We also considered alternatives such as [`npm scopes`](https://docs.npmjs.com/cli/v7/using-npm/scope) which would include the package source on the package ID, but that did not fit the MSBuild expectations of our developer-base as the syntax was too foreign & potentially breaking.

We then considered package grouping concepts which was proposed in [Central Version Package Management](https://github.com/NuGet/Home/issues/6764) which would allow control from the package declaration perspective compared to a source view. Although people found this promising as a concept, we found that without large adoption of the existing feature & limitation on `PackageReference` scenarios, that we would not be able to cover our hybrid ecosystem of .NET Framework & .NET Core users.

Lastly, we considered package lock files which would ensure repeatability based on the contents of a package. For the sake of control to the user, this approach did not cover the many needs of limiting or filtering as there are currently no great ways to specify a package source nor package namespace within lock file tooling. We may reconsider this at a future date.

## Mockups

![Options 1](../../meta/resources/packageSourceMapping/VSOptions.png)
![Options 2](../../meta/resources/packageSourceMapping/VSOptions1.png)
![Options 3](../../meta/resources/packageSourceMapping/VS.png)

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevent to this proposal? -->
There's a number of features that exist in various ecosystems & layers that solve similar problems by providing the user more control of their software supply chain such as:

- [npm (scopes)](https://docs.npmjs.com/about-scopes)
- [Maven (banned dependencies)](https://maven.apache.org/enforcer/enforcer-rules/bannedDependencies.html)
- [JFrog (exclude patterns)](https://jfrog.com/blog/yet-another-case-for-using-exclude-patterns-in-remote-repositories/)
- [Azure DevOps (packaging exclusions)](https://docs.microsoft.com/en-us/dynamics365/fin-ops-core/dev-itpro/dev-tools/exclude-test-packages)
- [Azure DevOps (.artifactIgnore)](https://docs.microsoft.com/en-us/azure/devops/artifacts/reference/artifactignore?view=azure-devops)
- [GitHub Actions (exclude paths)](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions#excluding-paths)

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
- Different modes or strategies can be considered in future iterations of the feature.
- The current proposal focuses on the nuget.config experience only. Adding a capability to source pin through RestoreSources is a future task.
- NuGet can allow users to filter their Package Source Mapping per source within CLI & IDE experiences.
- NuGet can allow a user to add a full or glob package ID namespace at install time with an additional click/parameter in Visual Studio or CLI.
- NuGet can combine this feature with `Package Lock Files` to allow a user to ensure the lock file is generated under the allowlist of package ID patterns.
- Create a better experience for this feature interacting with the global packages folder so that packages in the GPF are validated against the source mapping configuration.
- Enable users to validate the outcome of their configuration with a CLI command, maybe a part of `dotnet list package`
