# ***Add `nuget list` Functionality to DotNet***
<!-- Replace `Title` with an appropriate title for your design -->

- [Nigusu](https://github.com/Nigusu-Allehu) <!-- GitHub username link -->
- [GitHub Issue](https://github.com/NuGet/Home/issues/6060) <!-- GitHub Issue link -->

## Summary

<!-- One-paragraph description of the proposal. -->
The specification seeks to add `nuget list` functionality to dotnet. The functionality will be added to dotnet as a search command: `dotnet package search`.  
## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
This is a customer requested functionality as discussed in this issue: https://github.com/NuGet/Home/issues/6060. Adding the functionality will aid our customers to be able to use the command when writing scripts.
## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
Imagine you have your dotnet CLI open. You would like to get the list of all packages from a source `<MySource>`. No worries, you can just use the following command : `dotnet package search -source <MySource>`. It will provide you with the list of all the packages in the source `<MySource>`.
### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->
The `package search [search terms] [options]` command will have the following options 

| Option | Function |
|---------|:----------|
| `-Source` | A list of packages to search |
| `-ExactMatch` | Return exact matches only as a search result |
| `-Verbose` | Displays a detailed ist of information for each package |
| `-Prerelease` | Allow prerelease packages to be shown. |
| `-IncludeDelisted` | Allow unlisted packages to be shown |
| `-NonInteractive` | Do not prompt for user input or confirmations.|
| `-Help` | Show command help and usage information |
| `-Verbosity` | Display the amount of details in the output: normal, quiet, detailed. |
| `-ConfigFile` | The NuGet configuration file. If not specified, the hierarchy of configuration files from the current directory will be used. |
|||
#### **Algorithm**
1. Read and parse arguments from user
2. Use the nuget.exe Search API to look for the specific term in the provided source. The search filter will be composed of the `-Source`, `Search term`, `-Prerelease`, `-IncludeDelisted` values.
3. Based on `-Verbosity` value, provide with a list of packages with various verbosity
* Verbosity
    - **Quiet** : Each line would look as follows : 
    
            <Package Name> <Latest Package Version>
    - **Normal** :

                <Package Name> | <Latest Package Version> | <Amount of Downloads>
                <Description of the Package(short form)>
    - **Detailed** :

                <Package Name> | <Latest Package Version> | <Amount of Downloads>
                Deprecated : YES/NO | Vulnerable : YES/NO
                <Description of the Package(Readme file)>
                License URL : <URL>

#### **New Option `ExactMatch`**
* This new option will allow for users to be able to search and have only exact matches as an output. 
* For example if a user uses `dotnet package search NuGet.CommandLine -Verbosity Quiet`

        NuGet.CommandLine | 6.7.0
        NuGet.CommandLine.XPlat | 6.7.0
        NuGet.Commands | 6.7.0
        NuGet.exe | 3.4.3
        NuGet.Bootstrapper | 2.6.0
        CommandLineParser20 | 2.0.0
        NuGet.VerifyMicrosoftPackage | 1.0.0
        NuGet.for.MSBuild | 2.1.0 ...
* Using ``dotnet package search NuGet.CommandLine -ExactMatch -Verbosity Quiet`` on the other side will have the following output

         NuGet.CommandLine | 6.7.0
## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
In nuget.exe there is `nuget list` command which does the same thing. However, customers would like this functionality to be available in dotnet.

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
Make the search command bigger and vast