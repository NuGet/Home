# NuGet Package Search
<!-- Replace `Title` with an appropriate title for your design -->

- [Nigusu](https://github.com/Nigusu-Allehu) <!-- GitHub username link -->
- [GitHub Issue](https://github.com/NuGet/Home/issues/6060) <!-- GitHub Issue link -->

## Summary

<!-- One-paragraph description of the proposal. -->
This specification will discuss three key improvements to the NuGet package search functionality. These improvements are: adding an `-ExactMatch` option to the `search` command, deprecating the `list` command in favor of `search`, and introducing a `dotnet nuget search` command to the Dotnet CLI.
## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Improving the nuget search functionality across all platforms is highly requested by customers. As shown in this [issue](https://github.com/NuGet/Home/issues/5138), customers would like to have `-ExactMatch` option added to the search command. In this other [issue](https://github.com/NuGet/Home/issues/6060), we can see that it has been repeatedly requested by customers for the Dotnet CLI to adopt a search functionality. Lastly, as discussed in this [issue](https://github.com/NuGet/Home/issues/7912) the `nuget list` command is redundant with `nuget search` as both commands basically display a list of packages from a source. The only difference between the two is that the search command allows for filters. In addition, the `nuget list` command can be confusing as there is a `nuget list` command in the Dotnet CLI with a different functionality: lists configured sources and client certificates. Addressing these issues will provide users with a not confusing search functionality on both the Dotnet CLI and nuget.exe.
## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
#### 1. Adding `-ExactMatch` Option: 
A new flag, `-ExactMatch`, will be added to the `search` command. When this flag is used, it will only return packages whose names exactly match the query.
- **Version not specified** : In this case, the latest version of the package specified is listed .\
*Nuget.exe Usage* : `nuget search <PackageName> -ExactMatch` \
*Dotnet Usage* : `dotnet nuget search <PackageName> -ExactMatch`
- **Version specified** : In this case, the package with the specific version number is listed.\
*Nuget.exe Usage* : `nuget search <PackageName> -ExactMatch -Version 1.2.3.4` \
*Dotnet Usage* : `dotnet nuget search <PackageName> -ExactMatch -Version 1.2.3.4`
- **All Versions** : In this case, all versions of the package with the exact match are listed.\
*Nuget.exe Usage* : `nuget search <PackageName> -ExactMatch -AllVersions` \
*Dotnet Usage* : `dotnet nuget search <PackageName> -ExactMatch -AllVersions`
#### 2. Deprecating list Command: 
The list command is planned to be deprecated, given its functionalities can be covered by the search command. A warning message will be displayed to inform users of this change. `Warning: The 'list' command is deprecated. Use 'search' instead.` \
The functionalities of the `list` command can be replicated as follows
* In nuget.exe `nuget list` will be `nuget search`.
* In Dotnet, `dotnet nuget search` will be added and it will be the same as `nuget search`.
#### 3. Introducing nuget search to Dotnet:
A new command dotnet nuget search will be introduced to bring package search functionality to the Dotnet CLI. This will help in resolving the highly requested `dotnet nuget list` functionality.
### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->
The `-ExactMatch` flag will require modifying the query parser for the `search` command in NuGet.

For deprecating the list command, the current implementation needs to be flagged as obsolete and redirect users to the `search` command with a warning message.

Lastly, the introduction of nuget `search` to Dotnet will require adding a new command.
## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->
NuGet.exe already supports package search with nuget search but lacks an exact match feature. Dotnet CLI also has a list command but serves a different purpose. Aligning these functionalities can simplify the user experience.
## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->
What would be the transition plan for users currently relying on the list command?
## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
