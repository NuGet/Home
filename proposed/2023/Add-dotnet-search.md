# ***Add `nuget search` Functionality to DotNet***
<!-- Replace `Title` with an appropriate title for your design -->

- [Nigusu](https://github.com/Nigusu-Allehu) <!-- GitHub username link -->
- [GitHub Issue](https://github.com/NuGet/Home/issues/6060) <!-- GitHub Issue link -->

## Summary

<!-- One-paragraph description of the proposal. -->
The specification seeks to add `nuget search` functionality to dotnet. The functionality will be added to dotnet as a search command: `dotnet package search`.  

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
As outlined in the customer request on this GitHub [issue](https://github.com/NuGet/Home/issues/6060), there is a call for the incorporation of `nuget list` functionality into dotnet. The customers are requesting for this feature, but the `search` command can replicate the same functionality, with the only difference being the quantity of package results it outputs. The search command mitigates unnecessary server use by limiting the number of results through the `--take` option. By integrating this search functionality, we aim to accommodate our customers' needs, especially for scripting purposes.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
Imagine you have your dotnet CLI open. You would like to look up a NuGet package named `MyPackage` from a source `<MySource>`. No worries, you can just use the following command : `dotnet package search MyPackage --source <MySource>`. It will provide you with the list of the packages in the source `<MySource>` that match with the search criteria.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->
The `package search [search terms] [options]` command will have the following options

| Option | Function |
|---------|:----------|
| `--source` | A source to search |
| `--exact-match` | Return exact matches only as a search result |
| `--prerelease` | Allow prerelease packages to be shown. |
| `--interactive` | Allows the command to stop and wait for user input or action (for example to complete authentication).|
| `--take` | The number of results to return. The default value is 20.|
| `--help` | Show command help and usage information |
| `--verbosity` | Display the amount of details in the output: normal, quiet, detailed. |
|||

#### **Option `--source`**

This option will specify which source to search from. If the source is not specified using this option, the sources in the `nuget.config` file will be used.

#### **Option `--verbosity`**

Based on `--verbosity` value, the output will provide with a list of packages with various verbosity

- Quiet : Each line would look as follows :

            >[Package Name] | [Latest Package Version]
- Normal :

                >[Package Name] | [Latest Package Version] | [Amount of Downloads]
                <Description of the Package(short form)>
- Detailed :

                >[Package Name] | [Latest Package Version] | [Amount of Downloads]
                Deprecated : True/False | Vulnerable : True/False
                <Description of the Package(Readme file)>
                License URL : [URL]

#### **Option `-exact-match`**

- This option will allow for users to be able to search and have only exact matches as an output.
- For example if a user uses `dotnet package search NuGet.CommandLine --verbosity Quiet`

        >NuGet.CommandLine | 6.7.0
        >NuGet.CommandLine.XPlat | 6.7.0
        >NuGet.Commands | 6.7.0
        >NuGet.exe | 3.4.3
        >NuGet.Bootstrapper | 2.6.0
        >CommandLineParser20 | 2.0.0
        >NuGet.VerifyMicrosoftPackage | 1.0.0
        >NuGet.for.MSBuild | 2.1.0 ...

- Using ``dotnet package search NuGet.CommandLine --exact-match --verbosity Quiet`` on the other side will have the following output

         >NuGet.CommandLine | 6.7.0

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
In nuget.exe there is `nuget search` command which does the same thing. However, customers would like this functionality to be available in dotnet.

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
