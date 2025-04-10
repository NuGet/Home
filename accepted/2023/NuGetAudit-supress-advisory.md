# Suppress specific advisories/CVEs in NuGetAudit
<!-- Replace `Title` with an appropriate title for your design -->

- Author: [zivkan](https://github.com/zivkan)
- GitHub Issue: https://github.com/NuGet/Home/issues/11926
- todo: Another issue for NuGetAudit suppressions

## Summary

<!-- One-paragraph description of the proposal. -->

Provide a syntax that allows developers to give a list of URLs that NuGet will no longer warn about in restore (NuGetAudit) or `dotnet list package --vulnerable`.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Software with known vulnerabilities are often only vulnerable only in certain scenarios.
But not all applications using a library with a known vulnerability use it in a way that's at risk.
There are also times when upgrading is not easy.
For example, if a package introduced a breaking change, so an application is using an old version, but the security vulnerability is only fixed in the newest version of the package, it could require non-trivial effort to upgrade the package.

While it's possible to use `NoWarn` to ignore all known vulnerabilities of a specific severity, this will also prevent any future vulnerability of the same severity from being reported.

An example is there have been multiple deserialization libraries that had known vulnerabilities reported where the attack is a deeply nested object hierarchy leading to a stack overflow situation.
The recommended fix in these situations are usually to configure the deserialization library to limit the maximum depth it will allow.
On .NET, this changes from an unrecoverable `StackOverflowException`, to a recoverable (via `try-catch`) exception, with a more meaningful error.
However, for some apps, this doesn't matter, either because the app still fails, or because the stream being read is trusted not to have malicious content.
In these scenarios, the development team might choose to ignore one advisory, but still wish to be informed of any new advisories for this package that may come out in the future.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or pseudocode to show how this proposal would look. -->

Add an MSBuild `NuGetAuditSuppress` item for the URL that NuGet reports. For example, to suppress https://github.com/advisories/GHSA-5crp-9r3c-p9vr, add `<NuGetAuditSuppress Include="https://github.com/advisories/GHSA-5crp-9r3c-p9vr" />`.

Here is a complete project example:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <OutputType>exe</OutputType>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Newtonsoft.Json" Version="9.0.1" />
    <NuGetAuditSuppress Include="https://github.com/advisories/GHSA-5crp-9r3c-p9vr" />
  </ItemGroup>
</Project>
```

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->
#### NuGetAudit (restore)

Unfortunately, restore has many entry points, each of which read MSBuild properties and items in a different way.
Therefore, just like adding any other property or item, it will need modifications in all of them.
The list is: MSBuild task (so msbuild and dotnet restore), static graph restore, nuget.exe, VS CPS projects (nominations), VS non-CPS projects (LegacyPackageReferenceProject).

##### `CollectNuGetAuditSuppressions` target

We already have `CollectPackageReferences`, `CollectPackageDownloads`, `CollectFrameworkReferences`, and `CollectCentralPackageVersions`.
The VS restore path needs these targets in order to collect any items we want to pass as inputs to the restore process. This has a side-effect that it provides customers, and other MSBuild SDK authors, a way to customize their build and dynamically add or modify items as needed.

We will add a `CollectNuGetAuditSuppressions` target with the new `NuGetAuditSuppress` item. We will need to not only modify our own *NuGet.targets* to add it to the appropriate `DependsOnTargets`, but we also need to investigate MSBuild's static restore or .NET SDK to see if it needs to be added to the list of targets it "hardcodes" it runs.
Additionally, we'll need to check if Visual Studio's project systems need any changes, specifically for design time builds.

If NuGet's restore always ran as an MSBuild target, the customers and MSBuild SDK authors could probably just have used `BeforeTarget="Restore"`.
However, in Visual Studio that's not the case, so it won't work.

##### `_CollectRestoreInputs` target

The new `CollectNuGetAuditSuppressions` target needs to be added to our list of 'targets to run' in multiple places. In order to avoid adding these new targets in multiple places every time, we will also take this opportunity to unify all the 'Collect' targets (5, after we add this one) into a single `_CollectRestoreInputs` target, which we can re-use for everything going forward.

This target is strictly an internal implementation detail, meant to reduce the amount of work needed to add new targets in the future. This is not intended as a target for customers to hook onto.

#### `dotnet list package --vulnerable`

`dotnet list package`'s `--vulnerable` was implemented before NuGetAudit was, long before the `VulnerabilityInfo` resource was added to the NuGet Server API.
Therefore, at this time this spec is being written, its implementation is that it makes an HTTP request to every package's Package Details (registration) endpoint, which is slow when there are many packages to check.
Performance could be improved by changing the implementation to use the new `VulnerabilityInfo` resource, and check for vulnerabilities in the same way that restore (NuGetAudit) does.
However, this would be a breaking change for package sources that have not implemented `VulnerabilityInfo`.
On the other hand, we don't know of any package source that provide any package vulnerability info through the registration resource, other than nuget.org.

Finally, `dotnet list package` already reads some properties out of the project, but doesn't currently retrieve any MSBuild items.
Therefore, some new abstractions or helper methods will probably be needed, and there might not be existing examples in our code to copy-paste, as restore uses different APIs to get the same data.


## Drawbacks

<!-- Why should we not do this? -->

### Priority

The linked issue has few up-votes, so we don't yet have evidence that it's a high impact feature.

### Alternatives

Customers can already achieve a similar outcome, but it will require a lot more effort on their end.
Firstly, they wouldn't use NuGetAudit, at least on CI.
Instead, they would use `dotnet list package --format json --vulnerable` (possibly also with `--include-transitive`) as a separate step in their pipeline.
Finally, they would need to have a script that parses the output, remove vulnerabilities they wish to suppress, then return a non-zero exit code if the result still contains any other vulnerabilities.

This effort would need to be duplicated by every customer who wishes to implement such behavior.
Even if someone in the community (or even the NuGet team ourselves) provides a sample, it requires developers to find the location where the sample is documented, and then to adapt it to their needs.
Alternatively, if this feature is implemented, then it's much easier for customers to adopt, as it's a fairly small configuration change.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

### MSBuild vs nuget.config

Some NuGet features are only available via *nuget.config*, and not MSBuild items or properties.
However, we had [one customer provide feedback that they'd like the suppression to be per-project](https://github.com/NuGet/Home/issues/11926#issuecomment-1683384471), rather than per repo.
This allows a project already using a package with a known vulnerability to prevent CI pipeline errors, while preventing other projects in the solution from starting to use it.
This seems like an important use-case that should be enabled, and MSBuild items allow these settings to be applied at the solution-level (*directory.packages.props*) or project-level.

### MSBuild item vs property

The current proposal is to use an MSBuild item.

NuGet currently uses MSBuild properties for various settings, such as additional package sources, and we can learn from experiences using it.

Firstly, adding a per-project item into an MSBuild property has worse syntax (at least in my opinion): `<NuGetAuditSuppress>$(NuGetAuditSuppress);https://sample.test/CVE</NuGetAuditSuppress>`.

Secondly, when there are a long list of values, it similarly ends up with a poor editing experience. Either a very long line, or an XML element with new lines as part of the value:

```xml
<NuGetAuditSuppress>
  https://example.com/CVE1;
  https://example.com/CVE2;
<NuGetAuditSuppress>
```

While creating a new MSBuild item for each advisory URL uses more characters I feel it "fits" better with XML & MSBuild generally.

Further, MSBuild properties don't allow additional metadata.
By using an item, we can add metadata, such as `Packages`:
  
  `<NuGetAuditSuppress Include="https://example.com/CVE1" Packages="ExamplePackage1;ExamplePackage2" />`,

  or `Justification`:
  
  `<NuGetAuditSuppress Include="https://example.com/CVE1" Justification="mitigated risks" />`.

For package sources this would have been helpful to enable credentials to authenticated package sources.
For `NuGetAuditSuppress`, it could enable new features more easily.

On the other hand, we do not read any items for packages.config projects, so relying on a completely MSBuild item based solution would add some technical complexity. Properties are also better for performance and memory concerns, and will involve less overhead than items. Further, if we decided to reverse our item vs property decision later, moving from properties to items is easier than the other way around. 

### Metadata on PackageReference items

Consider metadata on a `PackageReference` item:

```xml
<PackageReference
    Include="SomePackageId"
    Version="1.2.3"
    NuGetAuditSuppress="https://sample.test/CVE1;https://sample.test/CVE2" />
```

When a single advisory is relevant to multiple packages, as is common for .NET, ASP.NET, and NuGet advisories, it will require duplication in multiple packages.

Additionally, this will only work for direct packages, not transitive packages.
If we use this approach for direct packages, there's no obvious alternative for transitive packages.
Using a new MSBuild item for transitive packages, but metadata on a PackageReference item for direct packages is confusing because developers need more context in order to choose the correct syntax.
It also means duplication when a package is direct in one project, but transitive in others.
Having the suppress metadata flowed down to transitive packages, as Include/Exclude/Private Assets does is another option, because it's behavior that already exists.
However, this makes it difficult to suppress centrally, like in a *Directory.Packages.props* file, as a transitive package will have different "entry points" in different projects in a solution.

### Performance concerns

Restore is NuGet's most performance critical path.
Generally, .NET application performance is hurt most by memory allocations, and using MSBuild items is probably the worst choice for memory allocations.

If the setting was in nuget.config, it would be loaded only once, and then a single instance would be passed around in memory when restoring multiple projects in parallel.
In MSBuild, items are an object, probably causing multiple allocations, whereas a property is a single string.
Unless MSBuild implements copy-on-write when modifying MSBuild items, it's likely that MSBuild will allocate a duplicate for every project that imports a shared props file.
Even if we used a property, it's likely that MSBuild would allocate a duplicate string in each project importing a shared props file.
Even if MSBuild did smart string pooling, when Nuget reads a dgspec file, since the dgspec is per-project, NuGet would need to do string pooling across parallel project reads to deduplicate those strings.
So, it's very likely that using MSBuild at all will cause many allocations, both in MSBuild (and therefore when NuGet isn't even run), as well as within NuGet itself.

Additionally, by using MSBuild items and properties, it forces MSBuild to do these allocations on every project load, even when restore (or `dotnet list package`) is not run.
Putting it in *nuget.config* would not only make it much easier to avoid duplicate strings, it would also only be read when NuGet is actually used vs every MSBuild project evaluation.

However, basic tests on MSBuild evaluation performance doesn't show measurable regressions when adding 100 additional items into a project, and I don't believe it's likely that customers will suppress 100 different advisories.
Therefore, even though using MSBuild items is theoretically the highest allocation design choice, given how much other work MSBuild does, it doesn't appear to result in a measurable performance impact.

### NuGetAuditSuppress name

We considered a simpler name like **"IgnoreAdvisory"**, but had concerns over whether it could potentially clash with an item or property that someones introduces later. It is generally preferred that MSBuild items or properties have a specific prefix, so that related items all fall in the same "namespace", and do not get easily confused with items or properties used by other processes. Taking that into account, and considering the names of the other **NuGetAudit** properties, we decided on **"NuGetAuditSuppress"**.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

`cargo-audit`'s config can contain a list of advisory IDs to ignore: https://docs.rs/cargo-audit/latest/cargo_audit/config/struct.AdvisoryConfig.html

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

### Per-package suppressions

Most of NuGet's and .NET's security advisories affect multiple packages.
For example, https://github.com/NuGet/NuGet.Client/security/advisories/GHSA-6qmf-mmc7-6c2p affects packages *NuGet.Commands*, *NuGet.Common*, *NuGet.Protocol*, and some other packages that aren't really intended on being referenced by other projects (they're packages for infrastructure reasons).
Say a customer is using one of these packages and wants to suppress the advisory, but wants to reduce risk that someone starts using another one of these packages, but still with a vulnerable version.

It would be useful to be able to instruct NuGet that a `NuGetAuditSuppress` items is specific to certain package(s) in the project.
For example:

```xml
<NuGetAuditSuppress
    Include="https://github.com/NuGet/NuGet.Client/security/advisories/GHSA-6qmf-mmc7-6c2p"
    Packages="NuGet.Protocol;NuGet.Common" />
```

Since NuGet saves restore inputs in a `dgspec.json` file, adding this as a future possibility will mean that there will be additional changes to the file's schema, and care would need to be taken to ensure that any existing dgspec doesn't crash the deserializer and cause restore errors when it's an older version without per-package support.
If we add per-package support in the first version of `NuGetAuditSuppress`, then it reduces risk for this future change.
Additionally, given the need to modify all of NuGet's restore entry points, it reduces effort.

On the other hand, this feature has not yet been requested by any customers, so might be a form of scope creep.
The more simple `NuGetAuditSuppress` without per-package support will be quicker to implement, and significantly easier to write automated tests for. It is also not clear whether we would want to implement this as metadata on the `NuGetAuditSuppress` item, or as metadata on the `PackageReference` item, although that would exclude transitive dependencies. 

### Project properties GUI support

We can consider adding a GUI to edit suppressions through project properties.

### Tooling support

We considered adding `dotnet` CLI commands to add/remove `NuGetAuditSuppress` items, but it should be fairly easy to edit these items manually, so we don't believe it's necessary at this time.