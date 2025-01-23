# ***Dotnet list package checks when restore is not current***
<!-- Replace `Title` with an appropriate title for your design -->

- Author Name [Nigusu](https://github.com/Nigusu-Allehu)
- [GitHub Issue](https://github.com/NuGet/Home/issues/13703) <!-- GitHub Issue link -->

## Summary

The `dotnet list package` command is used to list packages referenced by a project, but it requires a restore operation to be performed beforehand to ensure accurate information. NuGet currently checks for the existence of an assets file to assert that restore has been performed.
However, if a user modifies the project file after running restore, the assets file may become outdated, leading to misinformation from the dotnet list package command.
This proposal discusses how to ensure that NuGet asserts the assets file is in sync with the project file to prevent such issues

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->

`dotnet list package` command is used to list packages referenced by a project.
Before this command is executed, users are expected to perform a restore operation.
NuGet expects restore to be run both after project creation and every time a change has been made to the project.
This is because the `dotnet list package` command is based on the project assets file providing accurate information.
NuGet currently asserts restore has been performed by checking the existence of an assets file.
However, it is possible a user might have run restore once and followed it up with a modification to the project file.
That means the assets file has information that has expired.
This is not detected/asserted by the `dotnet list package command`.
As a result, in this specific scenario, `dotnet list package` command misinforms users about their projects.

## Explanation

### Functional explanation

Assuming the functionality has been implemented, here is what the expected interaction with a user would look like.

#### **Scenario 1: User runs `dotnet restore` and modifies the project file**

*User Action:*

- Runs `dotnet restore` to restore packages for their project.
- Modifies the project file by adding or removing a package reference.
- Runs `dotnet list package`.

*Expected Behavior:*

- The command checks if the assets file is in sync with the project file.
- If the assets file is outdated, it prompts the user to run `dotnet restore` again.

#### **Scenario 2: User runs `dotnet restore` and does not modify the project file**

*User Action:*

- Runs `dotnet restore`.
- Runs `dotnet list package`.

*Expected Behavior:*

- The command lists packages accurately without any prompts.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

Comparing the contents of the project file and the assets file is the most important step here. We will achieve this by using no-op restore.

- Create a DGSpec file from the evaluated project
  - To create the DGSpec file, use an MSBuild target, [GenerateRestoreGraphFile](https://github.com/NuGet/NuGet.Client/blob/cb0b5561f4fd98347cedac11919f769da0b767f4/src/NuGet.Core/NuGet.Build.Tasks/NuGet.RestoreEx.targets#L46), that writes the DGSpec to a file and then load it.
- Hash the DGSpec
- Compare the hash value with the one saved in `project.nuget.cache` file

#### If unable to load DGSpec file

Log the following [similar to the dotnet sdk](https://github.com/dotnet/sdk/blob/b324c2e074f7691705b85b6ed69be23d350164b8/src/Cli/dotnet/commands/dotnet-add/dotnet-add-package/LocalizableStrings.resx#L147)

> Error: Unable to create dependency graph file for project '{0}'.

#### If the hash values are different

Log the following

> Error: The project's dependency graph has been altered. Please perform a restore for project '{0}'.

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

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
