# ***Add `nuget search` Functionality to DotNet***
<!-- Replace `Title` with an appropriate title for your design -->

- [Nigusu](https://github.com/Nigusu-Allehu) <!-- GitHub username link -->
- [GitHub Issue](https://github.com/NuGet/Home/issues/6060) <!-- GitHub Issue link -->

## Summary

<!-- One-paragraph description of the proposal. -->
The specification seeks to add search functionality to dotnet. The functionality will be added to dotnet as a search command: `dotnet package search`.  

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
As outlined in the customer request on this GitHub [issue](https://github.com/NuGet/Home/issues/6060), there is a call for the incorporation of `nuget.exe list` functionality into dotnet. The customers are requesting for this feature, but a `search` command can replicate the same functionality, with the only difference being the quantity of package results it outputs. A search command mitigates unnecessary server use by limiting the number of results through the `--take` option. By integrating this search functionality, we aim to accommodate our customers' needs, especially for scripting purposes.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
Imagine you have your dotnet CLI open. You would like to look up a NuGet package named `MyPackage` from a source `<MySource>`. No worries, you can just use the following command : `dotnet package search MyPackage --source <MySource>`. It will provide you with the list of the packages in the source `<MySource>` that match with the search criteria.

The `package search [search terms] [options]` command will have the following options

| Option | Function |
|---------|:----------|
| `--source` | A source to search |
| `--exact-match` | Return exact matches only as a search result |
| `--prerelease` | Allow prerelease packages to be shown. |
| `--interactive` | Allows the command to stop and wait for user input or action (for example to complete authentication).|
| `--take` | The number of results to return. The default value is 20.|
| `--help` | Show command help and usage information |
|||

#### **Option `--source`**

This option will specify a list of sources to search from. If a source is not specified using this option, the sources in the `nuget.config` file will be used.

#### **Option `-exact-match`**

- This option will allow for users to be able to search and have only exact matches as an output.
- For example if a user uses `dotnet package search NuGet.CommandLine`

        >NuGet.CommandLine | 6.7.0 | Downloads: N/A
        >NuGet.CommandLine.XPlat | 6.7.0 | Downloads: N/A
        >NuGet.Commands | 6.7.0 | Downloads: N/A
        >NuGet.exe | 3.4.3 | Downloads: N/A
        >NuGet.Bootstrapper | 2.6.0 | Downloads: N/A
        >CommandLineParser20 | 2.0.0 | Downloads: N/A
        >NuGet.VerifyMicrosoftPackage | 1.0.0 | Downloads: N/A
        >NuGet.for.MSBuild | 2.1.0 ...

- Using ``dotnet package search NuGet.CommandLine --exact-match`` on the other side will have the following output

         >NuGet.CommandLine | 6.7.0 | Downloads: N/A

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->
This command will prepare a search parameter using the inputs of  `Search Term`, `--take`, and `--prerelease`. This parameter is then used prepare an API query to the specified source. In the dotnet/sdk repo, there is already a command, `dotnet tool search`, which does a similar thing. However, it specifies the package type to be only `dotnettool`. Instead of adding a new set of classes and methods, I will modify the methods and classes used by `dotnet tool search` to do a general search when needed. This will allow both `dotnet package search` and `dotnet tool search` to use the same API request class. The result of the query is then parsed to provide output to users.

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
I believe `dotnet tool search` is a subset to `dotnet package search`, as a result we could deprecate it. If it is necessary we could add an option in `dotnet package search` to allow users to specify that they want to only search dotnet tool.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
