# Title

- Author Name (https://github.com/Nigusu-Allehu)
- Start Date (YYYY-MM-DD)
- GitHub Issue (https://github.com/NuGet/Home/issues/9180)
- GitHub PR (GitHub PR link)

## Summary

<!-- One-paragraph description of the proposal. -->
The proposal seeks to eliminate user confusion regarding the `-NoCache`, `--no-cache`, and `RestoreNoCache` CLI options in dotnet.exe, nuget.exe, and msbuild.exe by introducing a new CLI option, `--no-http-cache`, which clearly specifies that it disables only HTTP cache caching, not the global packages folder. To ensure a smooth transition and avoid additional confusion, the old options will not be deprecated but will co-exist with the new option. Updated documentation will provide guidance on the specific functions of each option, allowing users to make informed decisions based on their caching needs.
## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
The motivation behind introducing the new `--no-http-cache` CLI option is to enhance user experience with clarity. Existing options like `-NoCache`, `--no-cache`, and `RestoreNoCache` have proven to be ambiguous, leading to misunderstaings about their functionality. 

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
Imagine you're working on a .NET project and you're using various CLI tools like dotnet.exe, nuget.exe, and msbuild.exe. You've been using the `-NoCache`, `--no-cache`, or `RestoreNoCache` options to disable caching, but you're a bit confused because it doesn't seem to affect the global packages folder. Well, that's because these older options were designed to disable only the HTTP cache, not the global packages folder.

To make things clearer, a new CLI option has been introduced: `--no-http-cache`. When you use this flag, it explicitly disables only the HTTP cache, leaving the global packages folder untouched. The older options are still there; they haven't been deprecated, so you can use them if you're used to them. 

Here's a simple example with nuget restore:

Old way (still works): `dotnet restore --no-cache`
New way (clearer): `dotnet restore --no-http-cache`
### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->
The proposal is to add a new option `-NoHttpCache` which will set the exact same `NoCache` option bolean. For now if either of these options are set, `NoCache` will be set to true
## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
This design is the best because it introduces explicitness without breaking existing workflows; the older flags are not deprecated and still work as before. Alternative designs like modifying the behavior of existing flags or deprecating them were considered but ruled out because we do not want to confues our users. 

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
