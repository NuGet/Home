# Additional Metadata Attributes

- Author Name [@redth](https://github.com/redth)
- Start Date (2022-10-190)
- GitHub Issue (GitHub Issue link)
- GitHub PR (GitHub PR link)

## Summary

Allow the inclusion of additional metadata properties in package authoring and allow them to be used in search queries.

## Motivation 

MAUI (and previously Xamarin) has an ecosystem of 'binding' library NuGet packages which surface native platform library usage within apps through C# API projections.  These native platform libraries are often available on their native package management system counterparts (ie: Maven, CocoaPods, etc.).  Typically binding nuget packages redistribute the native libraries within them.

It's currently challenging/impossible to discern which NuGet packages map to a given native platform library package identity.  

Moving the ecosystem forward, it would be very helpful to be able to programmatically determine the native platform library identities to:

1. Deduplicate inclusion of packages through transitive dependencies (which often result in native toolchain build errors if not resolved)
2. Discover eligible packages to fulfill dependencies of known native platform libraries (ie: integrating the output of a gradle build and automatically matching up / suggesting existing packages for dependencies)

Identity can consist of multiple attributes, for example a Maven package has:

- Group Id (eg: `com.company.product`)
- Artifact Id (eg: `ProductSdk`)
- Version (eg: `1.3.0`)

While a useful consumer of the search service might query by (GroupId='com.company.product' && ArtifactId='ProductSdk') in order to return a list of packages to further inspect version attributes of to determine if any package identities satisfy its requirements.

## Explanation

The NuGet search API already allows the specification of various package [metadata fields to search by in the query parameter](https://learn.microsoft.com/en-us/nuget/consume-packages/finding-and-choosing-packages#search-syntax).  This proposal is simply an extension of that existing query syntax to include additional, potentially arbitrary attributes both in the .nuspec format as well as the search query.

### Functional explanation

Package authors could choose to include arbitrary attribute key/value pairs within the NuGet packages they publish which would be contained within the .nuspec.

These attribute key/value pairs would be searchable within the NuGet search service, via the query property, similar to how search by `owner` or `packageid` is available currently.

### Technical explanation

Inside of the .nuspec file's `<package>` and then `<metadata>` elements, create a new `<attributes>` element which can contain zero or more `<attribute key="[string]" value="[string]" />` elements. Attributes must have unique key values and there cannot have more than one attribute with the same key value.

In the NuGet search query (`q`) parameter, allow attributes to be specified as a query filter just like `owner`. That is, for example: `q=attr_[keyValue]:[attribute_value]` where the `attr_` prefix denotes matching a particular attribute key by its `[attribute_value]`. The search should look for exact, case-insensitive matches.

## Drawbacks

- Attribute key/value pair sprawl

## Rationale and alternatives

While there are no known alternatives, we have previously considered embedding custom files in the package containing this metadata.  This would be of some benefit, but ultimately supporting search queries is necessary for achieving the full benefit of the proposal for the scenarios described.

## Prior Art

### Component Governance / SBOM
Currently CG build tasks in Azure DevOps do not know how to link a NuGet package binding library to the native artifacts they project / redistribute.  We typically provide a [cgmanifest.json](https://github.com/xamarin/XamarinComponents/blob/main/Android/Guava/cgmanifest.json) file to track this relationship, however if there was metadata in NuGet packages, the CG tasks and SBOM generation could be enhanced to automatically pick this up.

### Xamarin.Binding.Helpers
There's a [couple](https://github.com/Redth/Xamarin.Binding.Helpers) [experiments](https://github.com/Redth/Microsoft.Maui.Platform.Channels) around making it easier to create bindings and integrations with platform native libraries.  One of the challenges in creating tooling and experiences around this is acquiring native artifacts and linking them into .NET apps/builds, resolving conflicts between native toolchain dependencies and nuget package dependencies in existing apps.

Being able to cross-link native dependency identities against existing nuget package references would help in creating experiences that automatically resolve and link in the correct set of build time dependencies across native and nuget assets.

Example: Maintaining a [list of popular known packages that map to maven artifacts](https://github.com/Redth/Xamarin.Binding.Helpers/blob/main/Xamarin.Binding.Helpers/NuGetResolvers/KnownMavenNugetResolver.cs#L12-L99) is not a scalable solution.


## Unresolved Questions

- How many different attribute values is reasonable for packages to contain? for the nuget service to index?
- Should attribute keys require some sort of approval before they can be used?

## Future Possibilities

- Better interoperability of native Apple and Android projects with .NET ecosystem
- Component Governance / SBOM build task automation