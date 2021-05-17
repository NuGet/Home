# Package Namespaces

- [Jon Douglas](https://github.com/JonDouglas) & [Nikolche Kolev](https://github.com/nkolev92)
- Start Date: (2021-02-19)
- GitHub Issue ([6867](https://github.com/NuGet/Home/issues/6867))

## Summary

<!-- One-paragraph description of the proposal. -->
NuGet allows access to all package IDs on a package source. However, many .NET developers have needs to filter & consume a subset of the package IDs available on public, private, and local sources. Although NuGet supports a concept of [trusted-signers](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-trusted-signers) to trust packages signed by specific authors, users would like to optionally specify package namespaces that their organization and project's software supply chain trusts.

This proposal introduces a concept known as package namespaces, allowing a developer to include or exclude package IDs by specifying package namespaces on their package source(s).

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Giving the user more control on what packages are allowed in their software supply chain is an on-going need in the .NET ecosystem. Today, users do not have much control nor capabilities to filter the software dependencies they would consider including in their project. There's a misconception about open source dependencies being more secure which is known as the [Linus' Law](https://en.wikipedia.org/wiki/Linus%27s_Law), which allowing the world an opportunity at your software supply chain is posing a greater risk as more new packages are created everyday. Many requirements by organizations is quite the opposite. Having a controlled list of dependencies that are allowed within the company's policy is regular procedure & considered a best practice.

By providing an allowlist of package namespaces, we believe we can meet the security needs of the ecosystem from cybersquatting & typosquatting attacks like [Dependency Confusion](https://medium.com/@alex.birsan/dependency-confusion-4a5d60fec610). Additionally, we can extend a security feature that makes NuGet unique of allowing [package creators to reserve a package ID prefix](https://docs.microsoft.com/nuget/nuget-org/id-prefix-reservation).

This work will also allow future experiences in browsing, installing, and updating packages under an allowed list of namespaces to make developers secure by default when managing their dependencies in their software supply chain.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
When using a combination of public, private, and local sources defined in `NuGet.config` file(s), a user can add a new `<packageNamespaces>` element to opt-in to the feature. They can then create `<packageSource>` children elements to define the feed in which they'd like to add allowed namespaces to. Lastly by adding individual `<namespace>` elements in the `<packageSource>` node, the source will only allow the matching package namespaces from the respective package source.

**Definition:**

Add a new `<packageNamespaces>` element within the `NuGet.config` using the following syntax:

```xml
<packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
         
    <add key="contoso" value="https://contoso.com/packages/" />
 
</packageSources>
 
<packageNamespaces>
</packageNamespaces>
```

Define the `<packageSource>` element within the `<packageNamespaces>` parent with the name of a valid package source:

```xml
<packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
         
    <add key="contoso" value="https://contoso.com/packages/" />
 
</packageSources>
 
<packageNamespaces>
    <packagesource key="nuget.org">

    </packageSource>
 
</packageNamespaces>
```

Next, add `<namespace>` elements under the `<packageSource>` with an `id` to specify the namespace. Namespaces can be defined as their full namespace or using a wildcard(*) to match the glob pattern of 0 or more package ID(s):

```xml
<packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
         
    <add key="contoso" value="https://contoso.com/packages/" />
 
</packageSources>
 
<packageNamespaces>
    <!-- Add a namespace for Microsoft.* or NuGet.* under the nuget.org source. -->
    <packagesource key="nuget.org">
        <namespace id="Microsoft.*" />
        <namespace id="NuGet.*" />
    </packageSource>
 
</packageNamespaces>
```

If a user would like to support namespaces on different package sources, they can repeat this process for each source.
A user may also pin a specific package id instead of the complete namespace.
Specific ids take precedence over the namespaces.

**Example:**

```xml
<packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
         
    <add key="contoso" value="https://contoso.com/packages/" />
 
</packageSources>
 
<packageNamespaces>
    <!-- Add a namespace for Microsoft.* or NuGet.* under the nuget.org source. -->
    <packagesource key="nuget.org">
        <namespace id="Microsoft.*" />
        <namespace id="NuGet.*" />
    </packageSource>

    <!-- Add a namespace for Contoso.* under the contoso source. -->
    <packagesource key="contoso">
        <namespace id="Contoso.*" />
        <!-- Add a specific id to be download from  the contoso source. -->
        <namespace id="Special.Package.With.An.Imperfect.Id" />
    </packageSource>
 
</packageNamespaces>
```

By default, namespaces will allow a package to match multiple namespaces and download with no precedence. In some cases, one might want to avoid ambiguous cases. That can be done by adding a `strict` flag.

```xml
<config>
    <add key="namespaceMode" value="strict" />
</config>
```

The strict flag provides a source pinning behavior by nature in which one package source is allowed per unique namespace. Entering a strict mode will provide users an error experience when there are namespace conflicts to which a user will be able to resolve by defining one namespace per package source configuration.

Additionally there may be different modes for namespaces such as:

- `fullySpecified` - Any package id must be in one or more matching namespace declarations
- `singleSource` - No package id may match more than one feed (based on precedence rules)

An error for this experience might look like:

```console
NUXXXX: Package namespace {0} is listed on the following sources: {1}. Only one unique package namespace can be defined across sources.
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

#### Package installation rules

- When the requested package is already installed in the global packages folder, no source look-up will happen. The namespaces are irrelevant.
- The namespace metadata may be defined on zero, one or all sources.
- When a source has no metadata, the default is *all*.
- When a package id needs to be downloaded, it is first compared against sources with namespaces. If any match, only those sources are used. If none of the namespaces match, then the sources without namespaces are considered, if any.
- Strict namespaces allow only 1 source to match. NuGet will error in every other scenario.
- A namespace with a specific package id is *always* preferred over a namespace with a prefix.
- When multiple different namespaces match the package id, the most specific one will be considered.

**Scenario 1:**

The following are single project scenarios.

The sources are:

- nuget.org : `https://api.nuget.org/v3/index.json`
- contoso : `https://contoso.org/v3/index.json`

**Scenario 1A:**

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

Microsoft.C 1.0.0

```xml
<PackageReference Include="NuGet.A" Version="1.0.0"/>
<PackageReference Include="Microsoft.C" Version="1.0.0"/>
```

```xml
    <packagesource key="nuget.org">
        <namespace id="NuGet.*" />
    </packageSource>
    <!-- no contoso namespaces -->
```

**Result:**

- Package `NuGet.A` will be installed from nuget.org.
- Package `Microsoft.B` will be installed from contoso as a fallback.
- Package `Microsoft.C` will be installed from contoso as a fallback.

**Scenario 1B:**

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

Microsoft.C 1.0.0 -> Microsoft.B 1.0.0

```xml
<PackageReference Include="NuGet.A" Version="1.0.0" />
<PackageReference Include="Microsoft.C" Version="1.0.0" />
```

```xml
    <packagesource key="nuget.org">
        <namespace id="NuGet.*" />
    </packageSource>
    <packagesource key="contoso">
        <namespace id="Microsoft.*" />
    </packageSource>
```

**Result:**

- Package `NuGet.A` gets installed from `nuget.org`.
- Package `Microsoft.C` gets installed from `contoso`.
- Package `Microsoft.B` gets installed from `contoso`.

**Scenario 1C:**

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

Microsoft.C 1.0.0 -> Microsoft.B 2.0.0

NuGet.Internal.D 1.0.0

```xml
<PackageReference Include="NuGet.A" Version="1.0.0" />
<PackageReference Include="Microsoft.C" Version="1.0.0" />
<PackageReference Include="NuGet.Internal.D" Version="1.0.0" />
```

```xml
    <packagesource key="nuget.org">
        <namespace id="NuGet.*" />
        <namespace id="Microsoft.B" />
    </packageSource>
    <packagesource key="contoso">
        <namespace id="Microsoft.*" />
        <namespace id="NuGet.Internal.*" />
    </packageSource>
```

**Result:**

- Package `NuGet.A` gets installed from `nuget.org`.
- Package `Microsoft.C` gets installed from `contoso`.
- Package `Microsoft.B` gets installed from `nuget.org`. Even though the contoso namespace matches, the nuget.org one is an exact package id match.
- Package `NuGet.Internal.D` gets installed from `contoso`, because the prefix match is more specific.

**Scenario 1D:**

A 1.0.0 -> Microsoft.B 1.0.0

Microsoft.C 1.0.0 -> Microsoft.B 2.0.0

```xml
<PackageReference Include="A" Version="1.0.0" />
<PackageReference Include="Microsoft.C" Version="1.0.0" />
```

```xml
    <packagesource key="nuget.org">
        <namespace id="NuGet.*" />
    </packageSource>
    <packagesource key="contoso">
        <namespace id="Microsoft.*" />
    </packageSource>
```

**Result:**

- Package `A` fails installation as none of the namespaces match.

**Scenario 1E:**

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

Microsoft.C 1.0.0 -> Microsoft.B 2.0.0

```xml
<PackageReference Include="NuGet.A" Version="1.0.0" />
<PackageReference Include="Microsoft.C" Version="1.0.0" />
```

```xml
    <packagesource key="nuget.org">
        <namespace id="NuGet.*" />
        <namespace id="Microsoft.*" />
    </packageSource>
    <packagesource key="contoso">
        <namespace id="Microsoft.*" />
    </packageSource>
```

**Result:**

- Package `NuGet.A` will installed from nuget.org.
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
    <packagesource key="nuget.org">
        <namespace id="Microsoft.Community.*" />
    </packageSource>
    <packagesource key="contoso">
        <namespace id="Microsoft.Community.*" />
        <namespace id="Microsoft.*" />
    </packageSource>
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
    <packagesource key="nuget.org">
        <namespace id="NuGet*" />
    </packageSource>
    <!-- no contoso namespaces -->
```

**Result:**

- Package `NuGetA` will be installed from nuget.org. Namespaces do not have to separated by a `.`.
- Package `Microsoft.B` will be installed from contoso as a fallback.

---

**Scenario 2:**

The following examples cover scenarios in *strict* mode.

The sources are:

- nuget.org : `https://api.nuget.org/v3/index.json`
- contoso : `https://contoso.org/v3/index.json`

**Scenario 2A:**

Equivalent to scenario 1A in strict mode.

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

```xml
<PackageReference Include="NuGet.A" Version="1.0.0"/>
```

```xml
    <packagesource key="nuget.org">
        <namespace id="NuGet.*" />
    </packageSource>
    <!-- no contoso namespaces -->
```

**Scenario 2B:**

Equivalent to scenario 1E in strict mode.

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

Microsoft.C 1.0.0 -> Microsoft.B 2.0.0

```xml
<PackageReference Include="NuGet.A" Version="1.0.0" />
<PackageReference Include="Microsoft.C" Version="1.0.0" />
```

```xml
    <packagesource key="nuget.org">
        <namespace id="NuGet.*" />
        <namespace id="Microsoft.*" />
    </packageSource>
    <packagesource key="contoso">
        <namespace id="Microsoft.*" />
    </packageSource>
```

**Result:**

- The operation will fail due to conflicting namespaces for `Microsoft.*`.

**Scenario 2C:**

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

Microsoft.C 1.0.0 -> Microsoft.B 2.0.0

NuGet.Internal.D 1.0.0

```xml
<PackageReference Include="NuGet.A" Version="1.0.0" />
<PackageReference Include="Microsoft.C" Version="1.0.0" />
<PackageReference Include="NuGet.Internal.D" Version="1.0.0" />
```

```xml
    <packagesource key="nuget.org">
        <namespace id="NuGet.*" />
    </packageSource>
    <packagesource key="contoso">
        <namespace id="Microsoft.*" />
        <namespace id="NuGet.Internal.*" />
    </packageSource>
```

**Result:**

- Package `NuGet.A` gets installed from `nuget.org`.
- Package `Microsoft.C` gets installed from `contoso`.
- Package `Microsoft.B` gets installed from `contoso`.
- Package `NuGet.Internal.D` gets installed from `contoso`, because the prefix match is more exact. Even though this package matches both contoso and nuget.org prefixes, there's no ambiguity, so this is a valid strict mode configuration.

**Scenario 2D:**

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

This scenario has an additional source.

```xml
    <add key="Local" value="E:\packages" />
```

```xml
<PackageReference Include="NuGet.A" Version="1.0.0"/>
```

```xml
    <packagesource key="nuget.org">
        <namespace id="NuGet.*" />
    </packageSource>
    <!-- no contoso namespaces -->
    <!-- no local source namespaces -->
```

**Result:**

- Package `NuGet.A` will be installed from nuget.org.
- Package `Microsoft.B` will fail installation.
There are two sources without a namespace, thus creating an ambiguity not allowed in strict mode.

---

**Scenario 3:**

The following are multi project scenarios.

The sources are:

- nuget.org : `https://api.nuget.org/v3/index.json`
- contoso : `https://contoso.org/v3/index.json`

**Scenario 3A:**

Commandline PackageReference restore supports project level configuration. This equivalent is not support in Visual Studio, so this is not a recommended setup.

Given that, it's theoretically possible to get into an ambigious scenario.

NuGet.A 1.0.0 -> Microsoft.B 1.0.0

```xml
<!-- Project 1 Config -->
<packagesource key="nuget.org">
    <namespace id="NuGet.*" />
</packageSource>
<packagesource key="contoso">
    <namespace id="Microsoft.*" />
</packageSource>
```

```xml
<!-- Project 1 -->
<PackageReference Include="NuGet.A" Version="1.0.0" />
```

```xml
<!-- Project 2 Config -->
<packagesource key="nuget.org">
    <namespace id="Microsoft.*" />
</packageSource>
<packagesource key="contoso">
    <namespace id="NuGet.*" />
</packageSource>
```

```xml
<!-- Project 2 -->
<PackageReference Include="Microsoft.B" Version="1.0.0" />
```

**Result:**

- Not deterministic, because it depends on the order in which the projects are restored, this could lead to either package getting restored from either source.
This is *not* a very common, nor a recommended scenario.

## Drawbacks

<!-- Why should we not do this? -->
There are many ways to exclude & include dependencies in various CI/CD providers like Azure DevOps, GitHub Actions, and more. These are typically for individual dependencies or upstream packages. This however is not supported universally for each CI/CD provider & can be confusing on the limitations.

Package namespaces has best security practices in mind at the cost of user experience. One thing NuGet is known for is "just working". By using package namespaces, we are functionally changing how you might think about including new dependencies into your software supply chain.

The migration for users to leverage package namespaces will be tedious as they will need to lookup each package ID / namespace used in their project(s). There are no tools planned to do this on behalf of the user & therefore will be a one-time manual effort.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

We believe that this feature provides the highest degree of control and allow users to be more secure using NuGet than they have ever been. Given that other ecosystems like npm & Maven support a concept of scoped or banned dependencies through a concept of namespaces, NuGet would largely benefit from this type of feature as it complements NuGet's existing ability of [reserving package namespaces](https://docs.microsoft.com/nuget/nuget-org/id-prefix-reservation). This is a benefit for any internal packages in which a [best practice is having a package prefix](https://docs.microsoft.com/nuget/create-packages/package-authoring-best-practices#package-id).

The primary alternative to this feature was a concept known as source pinning which would allow you to specify a source on a `<PackageReference>`. We found the feasibility of this feature implementation to be difficult when dealing with [transitive dependencies](https://en.wikipedia.org/wiki/Transitive_dependency) & it's support for `<PackageReference>` only although it had an intuitive UX. We believe that this current proposal captures the spirit of being able to pin sources with an introduction of a `strict` mode.

We also considered alternatives such as [`npm scopes`](https://docs.npmjs.com/cli/v7/using-npm/scope) which would include the package source & namespace on the package ID, but that did not fit the MSBuild expectations of our developer-base as the syntax was too foreign & potentially breaking.

We then considered package grouping concepts which was proposed in [Central Version Package Management](https://github.com/NuGet/Home/issues/6764) which would allow control from the package declaration perspective compared to a source view. Although people found this promising as a concept, we found that without large adoption of the existing feature & limitation on `PackageReference` scenarios, that we would not be able to cover our hybrid ecosystem of .NET Framework & .NET Core users.

Lastly, we considered package lock files which would ensure repeatability based on the contents of a package. For the sake of control to the user, this approach did not cover the many needs of limiting or filtering as there are currently no great ways to specify a package source nor package namespace within lock file tooling. We may reconsider this at a future date.

## Mockups

![](../../meta/resources/PackageNamespaces/VSOptions.png)
![](../../meta/resources/PackageNamespaces/VSOptions1.png)
![](../../meta/resources/PackageNamespaces/VS.png)

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

- Q: Should strict namespaces mode be the default? That would deliver a `secure by default` namespacing experience.

- A: Yes. The feature's intention is to limit one package source to a single namespace prefix, which should be enabled by default.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
- The current proposal focuses on the nuget.config experience only. Adding a capability to source pin through RestoreSources is a future task.
- NuGet can allow users to filter their package namespaces per source within CLI & IDE experiences.
- NuGet can allow a user to add a full or glob package ID namespace at install time with an additional click/parameter in Visual Studio or CLI.
- NuGet can combine this feature with `Package Lock Files` to allow a user to ensure the lock file is generated under the allowlist of namespaces.