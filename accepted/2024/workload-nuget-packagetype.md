# **Create a new NuGet PackageType for Workloads-related packages**
- [baronfel](https://github.com/baronfel)
- N/A (will replace later)

## Summary

This spec proposes to add a new member to the set of known [PackageTypes](https://github.com/NuGet/NuGet.Client/blob/bd0764b4a5b78eea77c61f5b82078623c4fc0cfe/src/NuGet.Core/NuGet.Packaging/Core/PackageType.cs#L15-L20) to identify .NET SDK Workloads-related packages, and elaborate on how that new known PackageType will be used by the NuGet client and various other .NET Tooling that interacts with packages.

## Motivation 
 
Workloads have been a key part of the .NET experience for the past 3 major versions, and over that time key .NET platform features have been added to the set of known workloads, and new workloads concepts like workload sets have been added. New tooling experiences like Aspire and MAUI, and new platforms like WASM, are purely distributed as Workloads.

As a result, workloads-related packages have proliferated on NuGet.org, and in  highly-searched areas like Aspire and MAUI the workloads-related packages often drowned out other user-facing packages that are more relevant to the user's search.

If NuGet has a first-class idea of what a Workloads-related package is, it can use that information to improve the search experience for users, and ensure that NuGet clients that interact with workloads are correctly scoping their queries. Today, searching NuGet.org for `MAUI` returns 2688 packages, and of the first 10 results 8 are workloads packages that a user would never install as a PackageReference. This makes it much hard to discover MAUI-compatible packages.

## Explanation

### Functional explanation


Imagine NuGet had this filter. When an end user queries NuGet for a package using `dotnet package search` they only ever see packages that can be installed in their project! This is a huge win for the end user as they no longer have to sift through packages that are not relevant to them.

Similarly, when a user runs `dotnet workload search` they only see workload packs that are known to their feeds - guaranteed.

Also, when a user searches through NuGet.org, or the Visual Studio experiences, they can choose to filter out Workloads-related packages if they are not interested in them - this could even be the default, as the SDK team is quite convinced that users should never be interacting with Workloads-related packages directly.

Finally, when a user views details for a Workloads-related package on NuGet.org, the UI would be able to hide the 'package manager installation' section, as this is never correct for workload packages, and computing the correct `dotnet workload install` command would require a lot of work at ingestion-time from NuGet (which we explicitly don't want to ask for).

### Technical explanation

There would need to be a number of stages to this work:
* The new PackageType would need to be defined in [NuGet.Packaging](https://github.com/NuGet/NuGet.Client/blob/bd0764b4a5b78eea77c61f5b82078623c4fc0cfe/src/NuGet.Core/NuGet.Packaging/Core/PackageType.cs#L15-L20)
* Workload authoring would have to be updated to include the new PackageType in the NuSpecs generated for all workload packages - this happens in [dotnet/arcade](https://github.com/dotnet/arcade) mostly.
* Separately, experiences could start to use the new package type
  * `dotnet workload search`
  * `dotnet package search`
  * VS NuGet UI
  * VSCode NuGet UI
  * NuGet.org search

## Drawbacks

We shouldn't do this because it would be a new field that that non-NuGet.org servers would have to understand and process.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

This is a good design because it integrates nicely with the existing PackageType concept, recognizes a class of package that is fundamental to the ecosystem, important to organizational goals, and almost guaranteed to grow more in the future.

Other designs might codify patterns outside of NuGet itself (like naming conventions, or hijacking metadata in the NuSpec) that would make it more difficult to standardize the behavior across the ecosystem.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->

Other types of packages have gotten this same treatment in the past:
* .NET SDK Tools
* .NET SDK Templates

These similarly are foundational to the way the .NET ecosystem works and are worth filtering (either out or in).

<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
I've laid this out a bit above, but I think different package search experiences in the ecosystem could start explicitly excluding workload packages ASAP once this is merged.
