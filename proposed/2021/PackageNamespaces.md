# Package Namespaces

- [Jon Douglas](https://github.com/JonDouglas) & [Nikolche Kolev](https://github.com/nkolev92)
- Start Date: (2021-02-19)
- GitHub Issue ([7007](https://github.com/NuGet/Home/issues/7007))

## Summary

<!-- One-paragraph description of the proposal. -->
NuGet allows access to all package IDs on a package source. However, many .NET developers have needs to filter & consume a subset of the package IDs available on public, private, and local sources. Although NuGet supports a concept of [trusted-signers](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-trusted-signers) to trust packages signed by specific authors, users would like to optionally specify package namespaces that their organization and project's software supply chain trusts. 

This proposal introduces a concept known as package namespaces, allowing a developer to include or exclude package IDs by specifying package namespaces on their package source(s).

## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Giving the user more control on what packages are allowed in their software supply chain is an on-going need in the .NET ecosystem. Today, users do not have much control nor capabilities to filter the software dependencies they would consider including in their project. There's a misconception about open source dependencies being more secure which is known as the [Linus' Law](https://en.wikipedia.org/wiki/Linus%27s_Law), which allowing the world an opportunity at your software supply chain is posing a greater risk as more new packages are created everyday. Many requirements by organizations is quite the opposite. Having a controlled list of dependencies that are allowed within the company's policy is regular procedure & generally considered a best practice.

By providing an allowlist of package namespaces, we believe we can meet the security needs of the ecosystem. This work will also allow future experiences in browsing, installing, and updating packages under an allowed list of namespaces.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
When using a combination of public, private, and local sources defined in `NuGet.config` file(s), a user can add a new `<packageNamespaces>` element to opt-in to the feature. They can then create `<packageSource>` children elements to define the feed in which they'd like to add allowed namespaces to. Lastly by adding individual `<namespace>` elements in the `<packageSource>` node, the source will only allow the matching package namespaces from the respective package source.

**Definition:**

Add a new `<packageNamespaces>` element within the `NuGet.config` using the following syntax:

```
<packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
         
    <add key="contoso" value="https://contoso.com/packages/" />
 
</packageSources>
 
<packageNamespaces>
</packageNamespaces>
```

Define the `<packageSource>` element within the `<packageNamespaces>` parent with the name of a valid package source:

```
<packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
         
    <add key="contoso" value="https://contoso.com/packages/" />
 
</packageSources>
 
<packageNamespaces>
    <packageSource name="nuget.org">

    </packageSource>
 
</packageNamespaces>
```

Next, add `<namespace>` elements under the `<packageSource>` with an `id` to specify the namespace. Namespaces can be defined as their full namepsace or using a wildcard(*) to match the glob pattern of 0 or more package ID(s):

```
<packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
         
    <add key="contoso" value="https://contoso.com/packages/" />
 
</packageSources>
 
<packageNamespaces>
    <!-- Add a namespace for Microsoft.* or NuGet.* under the nuget.org source. -->
    <packageSource name="nuget.org">
        <namespace id="Microsoft.*" />
        <namespace id="NuGet.*" />
    </packageSource>
 
</packageNamespaces>
```

If a user would like to support namespaces on different package sources, they can repeat this process for each source.

**Example:**

```
<packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
         
    <add key="contoso" value="https://contoso.com/packages/" />
 
</packageSources>
 
<packageNamespaces>
    <!-- Add a namespace for Microsoft.* or NuGet.* under the nuget.org source. -->
    <packageSource name="nuget.org">
        <namespace id="Microsoft.*" />
        <namespace id="NuGet.*" />
    </packageSource>

    <!-- Add a namespace for Contoso.* under the contoso source. -->
    <packageSource name="contoso">
        <namespace id="Contoso.*" />
    </packageSource>
 
</packageNamespaces>
```

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

<!-- Why should we not do this? -->
There are many ways to exclude & include dependencies in various CI/CD providers like Azure DevOps, GitHub Actions, and more. These are typically for individual dependencies or upstream packages. This however is not supported universally for each CI/CD provider & can be confusing on the limitations. 

The migration for users to leverage package namespaces will be tedious as they will need to lookup each package ID / namespace used in their project(s). There are no tools planned to do this on behalf of the user & therefore will be mostly a one-time manual cost.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

We believe that this feature combined with [Source Pinning] will make users more secure using NuGet than they have ever been. Given that other ecosystems like npm & Maven support a concept of scoped or banned dependencies through a concept of namespaces, NuGet would largely benefit from this type of feature.

We considered alternatives such as `npm scopes` which would include the package source & namespace on the package ID. Sadly did not fit the MSBuild expectations of our customer-base.

We also considered package grouping concepts which was proposed in [Central Version Package Management]() which would allow greater control at the cost of complexity. Although people found this promising as a concept, we found that without large adoption of the existing feature & limitation on `PackageReference` scenarios only, that we would not be able to cover our hybrid ecosystem of .NET Framework & .NET Core users.

Lastly, we considered package lock files which would ensure repeatability based on the contents of a package. For the sake of control to the user, this approach did not cover the many needs of limiting or filtering as there are currently no great ways to specify a package source nor package namespace within lock file tooling. We may reconsider this at a future date.

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

- Can namespaces include both package IDs & namespaces?
    - If we support just "package namespaces" i.e. package IDs, will that be enough?
- When a namespace has a conflict, what is the warning experience?
    - What is the precedence of conflicts on two sources?
- Should the `RestoreSource` property support package namespaces since it's not part of the `nuget.config`?
    - First iteration supports `nuget.config` only?

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
- NuGet can combine this feature with `Source Pinning` to allow a user much more control on their package sources & package namespaces they want to allow in their software supply chain.
- NuGet can allow users to filter their package namespaces per source within CLI & IDE experiences.
- NuGet can allow a user to add a full or glob package ID namespace at install time with an additional click/parameter in Visual Studio or CLI.
- NuGet can combine this feature with `Package Lock Files` to allow a user to ensure the lock file is generated under the allowlist of namespaces.
