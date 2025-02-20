# ***When to require implicit restore***
<!-- Replace `Title` with an appropriate title for your design -->

- Author Name [Nigusu](https://github.com/Nigusu-Allehu)
- GitHub [Issue](https://github.com/NuGet/Home/issues/13406) <!-- GitHub Issue link -->

## Summary

<!-- One-paragraph description of the proposal. -->
This proposal explores when implicit restore should be required in NuGet commands.
Some commands require restore to have been performed for them to function correctly.
If a command depends on restore, it should trigger an implicit restore to ensure accuracy.
However, since implicit restore could impact performance and potentially require a connection to sources, commands should offer a `--no-restore` option to allow users to bypass it when necessary.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Commands such as `dotnet list package` and `dotnet nuget why` are intended to reflect the user's project state accurately.
However, since these commands require restore to have been performed, they may provide outdated or incorrect information if restore has not been executed recently.
These commands depend on the assets files, they may provide outdated information if restore has not been recently executed.
Ensuring an implicit restore will maintain synchronization between the assets file and the project file, enhancing the reliability of these commands.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

When a user executes a NuGet command that requires restore, the system should:

1. **Check if restore has been performed and is up to date**
   - If it is missing, restore must be triggered implicitly.
   - If it is outdated (i.e., the project file has changed since the last restore), implicit restore should also occur.

2. **Provide a `--no-restore` option**
   - Users who want to skip restore due to performance concerns or when they are confident the assets file is up-to-date should be able to pass this flag.

3. **Handle scenarios where restore is unsuccessful**
   - If implicit restore fails due to network issues, package source unavailability, or conflicting dependencies, the command should fail with a clear error message.
   - If `--no-restore` is specified and the assets file is missing or outdated, the command should either:
     - Proceed with a warning that the results may be inaccurate.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

The command should invoke restore **only when necessary**, checking the assets file has against the project dgspec has.
The `--no-restore` flag should override automatic restore, and the command should verify the presence of a valid assets file before proceeding.

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
1. **Requiring Manual Restore**: Users must manually run `dotnet restore` before commands. Rejected as it introduces usability friction.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

- `dotnet build` and `dotnet run` both trigger restore implicitly when needed.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

- How should failure scenarios be communicated? Should errors halt execution or only show warnings?

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
