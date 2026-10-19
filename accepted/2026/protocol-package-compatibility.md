# ***Add package compatibility to client-server protocol***

- [zivkan](https://github.com/zivkan)
- [GitHub Issue](https://github.com/NuGet/Home/issues/14321)

## Summary

Add package compatibility to the NuGet client-server protocol, so clients can show more information and make smarter automatic decisions when upgrading or installing packages.

## Motivation

One of the NuGet client team's top asks from customers is to more easily upgrade packages, or search for packages, that are compatible with their projects.

For example, currently Visual Studio's Package Manager UI's Upgrade tab will show packages where a new version of a package exists, even if upgrading will fail because the newer version is not compatible with the project.
Similarly, CLI commands such as `dotnet package update` and `dotnet package add` will try to use versions of packages that are not compatible with the project and fail, rather than automatically selecting an older version of the package that is compatible.

Currently, the NuGet protocol sends dependency group information, but restore does not use dependency groups for package compatibility checks.
This makes it very difficult for NuGet server implementors to determine which target frameworks a package is compatible with.
It also requires client tooling to download nupkgs to validate locally, as clients don't have sufficient information to make a decision otherwise.

Therefore this proposal has two parts:

1. Make it easy for 3rd party NuGet servers to determine package compatibility.
1. Extend package metadata resource in the client-server protocol for servers to send the information back to clients.

## Explanation

This spec proposes two changes:

1. Add a `compatibility` property to the protocol's PackageMetadata resource output.
1. Extend `dotnet nuget verify` with package compatibility information.

### Functional explanation

#### Protocol functional changes

The protocol changes will enable `dotnet package update` and `dotnet package add` to avoid selecting versions that will cause restore to fail.
Visual Studio's Package Manager UI could show `(Incompatible)` in a package's version drop down list next to each version that is not compatible with the project.
The `dotnet package list --outdated` command, and PM UI's Updates tab, could avoid showing packages as having updates available when all of the higher versions are incompatible with the project.

#### dotnet nuget verify functional changes

Keep reading to the [the rationale section](#dotnet-nuget-verify-rationale) for more information about why this command is being extended.

`dotnet nuget verify` adds output to list the package's compatible frameworks.
The output will always include the target frameworks that the package provides assets for.

```diff
 > dotnet nuget verify NuGet.Versioning.6.14.0.nupkg

 Verifying NuGet.Versioning.6.14.0
 Content hash: 4v4blkhCv8mpKtfx+z0G/X0daVCzdIaHSC51GkUspugi5JIMn2Bo8xm5PdZYF0U68gOBfz/+aPWMnpRd85Jbow==

 Signature type: Author
   Subject Name: CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
   SHA256 hash: 566A31882BE208BE4422F7CFD66ED09F5D4524A5994F50CCC8B05EC0528C1353
   Valid from: 2023-07-27 9:30:00 AM to 2026-10-18 10:29:59 AM

 Signature type: Repository
   Subject Name: CN=NuGet.org Repository by Microsoft, O=NuGet.org Repository by Microsoft, L=Redmond, S=Washington, C=US
   SHA256 hash: 1F4B311D9ACC115C8DC8018B5A49E00FCE6DA8E2855F9F014CA6F34570BC482D
   Valid from: 2024-02-23 10:30:00 AM to 2027-05-19 9:29:59 AM

+Compatible frameworks: net472, netstandard2.0
```

The command outputs the TFMs that the package provides, not an exhaustive list of all target frameworks that will be able to restore the package.
If you [look at this package on NuGet Package Explorer](https://nuget.info/packages/NuGet.Versioning/6.14.0), you can see that there are `lib/net472/*` and `lib/netstandard2.0/*` files.
Even though this package can be used by projects targeting `net10.0` or `net10.0-windows` for example, only the frameworks that the package provides assets for will be output.
It is up to the person or tool reading the output to understand .NET's target framework compatibility rules.

### Technical explanation

#### Package Metadata resource changes

The [Catalog Entry data type in the Package Metadata (RegistrationsBaseUrl) resource](https://learn.microsoft.com/nuget/api/registration-base-url-resource#catalog-entry) will get a new property, `compatibility`, which will have data type array of strings.
For example:

```diff
 {
   "id": "NuGet.Versioning",
   "version": "6.14.0",
   // other properties
+  "compatibility": [ "net472", "netstandard2.0" ]
 }
```

Packages that have no framework-specific assets — such as tools-only, analyzer-only, or content-only packages — are compatible with all target frameworks.
For these packages, the value will be an empty array (`"compatibility": [ ]`).
This is consistent with how restore treats packages with no assets: they are considered compatible with all frameworks, even if an empty array might at first glance seem to mean "compatible with nothing."
It's not possible for a package to be incompatible with all target frameworks (compatible with zero).

When the `compatibility` property is absent from the response, it means the server has not determined compatibility for that package version.
Clients should treat a missing property as unknown and fall back to current behavior (i.e., no compatibility filtering).

Since `compatibility` metadata will always be provided when the server knows the value for a package version, clients can detect when the server does and does not support the feature.
It also allows servers to incrementally roll out the feature, as it would be too costly to scan every version of every package and update the package metadata during an upgrade migration.
Therefore, it is expected that for a period of time a server will provide the metadata for some packages, but not others.

Since clients must ignore json properties that they don't understand, adding the json property is considered backwards compatible.
Clients can simply look for the property in the response without needing to know if the server supports it in advance.
Therefore, it is not necessary to add a new protocol version in the service index.
Servers that support multiple client versions will only need to add the `compatibility` property to `RegistrationsBaseUrl/3.6.0`, since older registration versions are consumed by clients that lack code to use the data.

#### dotnet nuget verify technical changes

The expected end-to-end workflow for servers is: receive a nupkg during push → invoke `dotnet nuget verify` (or call the .NET API directly) → extract the compatible frameworks list → store it alongside other package metadata → serve it via the `compatibility` property in RegistrationsBaseUrl responses.

A new public API should be added to get the list of target frameworks for a nupkg, so that servers written in .NET can call the API directly without needing to run `dotnet nuget verify` as a child process and parse its output.
Ideally the API should be in NuGet.Packaging, but the code to do restore compatibility checks is in NuGet.Commands, so it's likely the new API will need to be in that package/assembly.
A rough shape might be:

```csharp
// Returns the TFMs the package provides assets for (using restore compatibility logic)
public static IReadOnlyList<NuGetFramework> GetCompatibleFrameworks(string nupkgPath);
```

`dotnet nuget verify` will therefore be a user facing tool that calls the API and displays its return value.

## Drawbacks

The main drawback is that all client-server protocol changes require 3rd party NuGet feed implementations to adopt and self-hosted NuGet servers will need to upgrade.

However, the only alternative is to have clients download multiple nupkgs in order to check each for compatibility.
Supporting a new property in the protocol can be done incrementally, so there's little downside to supporting this, even if nuget.org becomes the only server to support it.
But the tooling experience is very compelling, so it's likely that some NuGet servers will implement the protocol.

## Rationale and alternatives

### dotnet nuget verify rationale

NuGet servers will need to determine package compatibility in order to provide the information in the protocol.
We should make an easy to use API, however, some package repositories that support multiple ecosystems are not implemented in .NET, [such as GitLab](https://gitlab.com/gitlab-org/gitlab/-/tree/master/lib/api/entities/nuget?ref_type=heads) which is implemented in Ruby.
For this feature to be successful, we need as many servers as possible to implement it, and therefore it needs to be easy for servers to adopt.

Since NuGet feeds already get all the other package metadata from the package's nuspec file, another option it to put the package compatibility in the nuspec file, which is already listed as [a future possibility](#future-possibilities).
This would in fact be easier for servers to adopt, compared to running a child process and parsing the output, or even calling a .NET API when written in .NET.

However, NuGet considers packages immutable and using nuspec metadata would exclude all existing packages from the feature.
In favor of this approach, we should consider that over time, developers upgrade to newer versions of packages but rarely downgrade to older versions.
This means that using nuspec metadata is feasible if we accept a 2-4 year ramp-up time for the feature while package authors create and publish new versions of packages.
But package compatibility can be calculated, so there's no reason to constrain the server implementation to the nuspec.

### Search by TFM

A tracking issue for [search by Target Framework](https://github.com/NuGet/Home/issues/5725) was created in 2017, and the nuget.org server team implemented a first version around 2024.
However, it only provides this filtering on the search endpoint and the search index only contains the latest version of a package.
So, when a package publishes a new version that removes a target framework it used to be compatible with, then ["search by TFM" will not show this package in the search results](https://github.com/NuGet/NuGetGallery/issues/10250).
This means client tooling cannot use it for package upgrade or installation decisions, as it would suggest that packages would not be compatible with a project when an older version of a package could indeed be compatible.

Given that the nuget.org server team are experts in the NuGet ecosystem, this is a signal that it will be very difficult for 3rd parties to implement, and will therefore probably decrease the chance that search by TFM will be available to customers.
Even if the NuGet team creates an open source implementation to assist in the implementation, GitLab is an open source product that implements the NuGet protocol, and [we can see it's implemented in Ruby](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/api/entities/nuget/search_result.rb?ref_type=heads) and would therefore be unable to benefit from an open source .NET library.

This is also before we consider complications in determining which target frameworks are compatible with others.
For example, a project targeting `net10.0-windows` can use packages with `net9.0-windows` assets, or a package with `net10.0` assets, or `netstandard2.0` assets.
The .NET SDK also enables "asset target fallback" to make .NET (Core) projects able to use .NET Framework packages, although with a warning.
Servers written in .NET can use the `FrameworkReducer` API in the NuGet.Frameworks package.
But it's another reason that will make it harder to implement Search By TFM correctly when the server is not implemented in .NET.

Although Search By TFM, if implemented perfectly, would give customers a great experience, the complexity means it has a low chance of being implemented perfectly across the majority of package sources that customers use.
Therefore, changing the protocol to provide easy to obtain information, and then shifting the decision making to people and client side tooling, will have a much lower overall cost to the ecosystem, while still providing a good enough experience.

The `compatibility` list is purely TFM-based.
Runtime identifier (RID) specific assets (e.g., `runtimes/win-x64/native/`) are not reflected — a package with RID-specific assets is considered compatible if it has matching TFM assets, consistent with how restore handles RID selection as a separate step.

## Prior Art

The following information about other ecosystems has not been independently verified.

PyPI allows packages to declare compatibility via classifiers, for example `Programming Language :: Python :: 3.10`.
The search service has a `c` HTTP query parameter where classifiers can be filtered, but it appears to be an exact string match, so if a package declares only `3.10`, searching for `3.11` won't show the result.

npm packages can declare a version range that the package supports, but doesn't have a built-in mechanism to have different assets for different NodeJS versions.
The package needs to do runtime version checks.

Maven does not appear to support one package supporting multiple runtime versions, or filtering based on runtime version.

However, I think .NET's compatibility story is much more complicated than any other ecosystem.
Firstly, .NET has .NET Standard, which is unlike anything I've seen in other ecosystems.
Secondly, .NET 5 introduced platforms, like `net10.0-windows` and `net10.0-android`, which similarly I haven't seen equivalents for in other ecosystems.

## Unresolved Questions

How much polish do we add to `dotnet nuget verify`?

`dotnet nuget verify` has an `--all` option, that has the help text:

> Specifies that all verifications possible should be performed to the package(s).

At this time there are no options to request specific verifications, making `--all` redundant because it's the only option available.
The command originally output the package signature details, and later an addition was made to output the package's content hash.
Should we add `--content-hash`, `--signature` and `--compatibility` options to allow developers to choose a subset of the output to display?

This would be particularly helpful since `dotnet nuget verify` will return a non-successful exit code when package signature validation fails, but it could still successfully read the package and output all the package details.
This makes it hard for automated systems to detect when the package is invalid and can't be read at all.

For similar reasons, should `dotnet nuget verify` get a `--format json` output?

We intend for NuGet servers not written in .NET to call this command and a child process and parse the output.
But it's possible to use the DOTNET_CLI_UI_LANGUAGE environment variable to force the child process into using English output, and then a regex to find the right line in the output isn't a huge overhead for a one-time analysis.
We know several NuGet server implementations are written in .NET, meaning they can use NuGet Client SDK packages and this means the number of people that will benefit from verify having JSON output is very small.

## Future Possibilities

### Extend nuspec

We could extend the nuspec file contained within the nupkg to include package compatibility.
NuGet feeds have to read the nuspec already to get all the other package metadata, so this would be the easiest way for servers to get the information about a package.
