# Add NoHttpCache option

- [Nigusu](https://github.com/Nigusu-Allehu)
- [GitHub Issue](https://github.com/NuGet/Home/issues/9180)

## Summary

<!-- One-paragraph description of the proposal. -->
The proposal seeks to eliminate user confusion regarding the `-NoCache`, `--no-cache`, and `RestoreNoCache` options in nuget.exe, dotnet.exe, and msbuild.exe respectively by introducing new options: `-NoHttpCache`, `--no-http-cache`, `RestoreNoHttpCache`, which clearly specify that they disables only HTTP cache caching, not the global packages folder. To ensure a smooth transition and avoid additional confusion, the old options will not be deprecated but will co-exist with the new option. Updated documentation will provide guidance on the specific functions of each option, allowing users to make informed decisions based on their caching needs.
## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
The motivation behind introducing the new `--no-http-cache`  option is to enhance user experience with clarity. Existing options like `-NoCache`, `--no-cache`, and `RestoreNoCache` have proven to be ambiguous, leading to misunderstandings about their functionality. 

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
Imagine you're working on a .NET project and you're using various CLI tools like dotnet.exe, nuget.exe, and msbuild.exe. You've been using the `-NoCache`, `--no-cache`, or `RestoreNoCache` options to disable caching, but you're a bit confused because it doesn't seem to affect the global packages folder. Well, that's because these options were designed to disable only the HTTP cache, not the global packages folder.

To make things clearer, a new CLI option has been introduced: `--no-http-cache`. When you use this flag, it explicitly disables only the HTTP cache, leaving the global packages folder untouched. The previous options are still there; And they will have messages to help move people towards the better named options. In addition, we will be hiding the existing `--no-cache` option from the CLI help output. The `--no-http-cache` option will be shown in the CLI help output. This will help guide users to the new option.

Here's a simple restore example:

Old way (still works): `dotnet restore --no-cache`
New way (clearer): `dotnet restore --no-http-cache`
### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->
The proposal is to add a new option `-NoHttpCache` which will set the exact same `NoCache` option boolean. For now if either of these options are set, `NoCache` will be set to true.
## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
This design is the best because it introduces explicitness without breaking existing workflows; the older flags are not deprecated and still work as before. Alternative designs like modifying the behavior of existing flags or deprecating them were considered but ruled out because we do not want to confuse our users. 

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->
* None
## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->
To ensure a smooth transition, the current `-NoCache` options will be preserved. However, we would also like our users to know this option will only stop Http caching and that there is a new option `-NoHttpCache` which is clearer and does the same thing. As a result, printing a log message that warns users when they use the `-NoCache` option is ideal. I am not sure if the following is a sufficient message \
&ensp; `"NoCache is deprecated in favor of the appropriately named NoHttpCache."` 

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
* None
