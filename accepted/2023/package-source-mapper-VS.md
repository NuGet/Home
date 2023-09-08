# Package Source Mapper in Visual Studio
<!-- Replace `Title` with an appropriate title for your design -->

- Donnie Goodson ([donnie-msft](https://github.com/donnie-msft))
- GitHub Issue <!-- GitHub Issue link -->

## Summary

<!-- One-paragraph description of the proposal. -->
Package source mapping is a relatively new feature in the .NET ecosystem, and Visual Studio (VS) doesn't currently have an onboarding experience for existing solutions. Let's bring the `PackageSourceMapper` tool's functionality into Visual Studio by introducing a button to launch the tool via the `NuGet Package Manager` VS Options. The existing `Package Source Mappings` options page can be automatically populated by the tool, and then update the solution's `NuGet.Config` with all package's mapped to the appropriate source.

## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
The vast majority of existing .NET solutions were created prior to package source mapping. Onboarding to the feature can be done manually, but this may be cumbersome for larger solutions with complex graphs. To reduce friction and encourage adoption of security features, the `PackageSourceMapper` tool was created to analyze the graphs and NuGet package sources to generate source mappings. Bringing this tool's functionality into Visual Studio is the next evolution of the onboarding experience.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->

Open a solution which has not onboarded to Package Source Mapping. Navigate to the VS Options page, `Package Source Mappings` under `NuGet Package Manager`. In the blank list of source mappings, notice the link, "Create source mappings for this Solution's installed packages".

If a solution is already onboarded, there will be at least 1 mapping already, and therefore, the link to onboard a solution will not be available.

Press the link, and a cancellable dialog window will appear indicating the following progress:
1. Loading the `PackageSourceMapper` tool as an external process.
1. The tool is reading the solution's package graph.
1. The tool is calculating the source mappings to create.
1. Results are shown in the dialog, and the Cancel button changes to an OK button.
    1. If any conflicts or errors occurred, those are shown in the dialog. 
    1. If successful, a count is shown with a successful status message. After pressing OK, the source mappings are shown in the mappings list. This is the same result as manually adding these mappings.


<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->
- `PackageSourceMapper` installation to VS
    - Optional component? Workload?
    - NuGet.Tools.vsix? Separate vsix?
- External process initiated from VS
- VS Option pages already use WPF dialogs which will be the UI to communicate this tool's state.
- Populating the list gives the customer the ability to "consent" to the generated mappings prior to writing creating them. The heavy lifting is behind-the-scenes, but the impact is visible to the customer.
- Writing to the `NuGet.Config` is functionality that's already available from NuGet's VS Option pages.

## Drawbacks

<!-- Why should we not do this? -->
None

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

None

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

The `PackageSourceMapper` tool does the heavy lifting. Customers have used the tool outside of VS successfully, so making it part of VS should build upon that success.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->
None

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
None