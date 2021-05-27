# Title

- Author Name [Volodymyr Shkolka @(BlackGad)](https://github.com/BlackGad) 
- Start Date (2021-05-27)
- GitHub Issue (https://github.com/NuGet/Home/issues/10793)
- GitHub PR (GitHub PR link)

## Summary

Add ability to restore symbols from snupkg packages in same way as generic nupkg do.

## Motivation 

We need to simplify debugging process for applications which are used NuGet packaging.

## Explanation

### Functional explanation

[NuGet package management](https://en.wikipedia.org/wiki/NuGet) is a standart way for your code distribution. [In a few clicks](https://docs.microsoft.com/en-us/nuget/create-packages/overview-and-workflow) you can pack `nupkg` package with your brand new framework which solves everything in the world (at least it may try to do this) and share it to others.

Your framework working hard as the part of other products. And, of course, some of users cannot link their simple logic with your API. The easiest way to figure it out whats wrong is to debug code line by line with end user data. 

For proper debugging you need to provide [debug symbols](https://en.wikipedia.org/wiki/Debug_symbol). Call NuGet framework with [symbols packaging feature](https://docs.microsoft.com/en-us/nuget/create-packages/symbol-packages-snupkg) to rescue. Few more clicks and your symbols will be packed into separate `snupkg` package. 

With general `nupkg` and symbols `snupkg` packages end user is able to fulfil debugger with all required information.

Detailed instruction for the framework owner:
- Place general `nupkg` and symbols `snupkg` packages into discovarable feed ([local](https://docs.microsoft.com/en-us/nuget/hosting-packages/local-feeds) or any remote one). Note: `nupkg` can be located in one feed and `snupkg` in another but their id and version must be identical.

Detailed instruction for the end user:
- Install ([nuget.exe install -Symbols](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-install), [dotnet add package --symbols](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-add-package?tabs=netcore2x)) or restore ([nuget.exe restore -Symbols](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-restore), [dotnet restore --symbols](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-restore)) NuGet package.
- Make sure your debugger consumed all required data. 
    Generic approach for Visual Studio is to use symbols from only one of [three places](https://docs.microsoft.com/en-us/visualstudio/debugger/specify-symbol-dot-pdb-and-source-files-in-the-visual-studio-debugger?view=vs-2019#symbol-file-locations-and-loading-behavior):
    - The location that is specified inside the DLL or the executable (.exe) file.
    - The same folder as the DLL or .exe file.
    - Debugger options for symbol files.

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

This is basically first stop on the long road to resolving target issue https://github.com/NuGet/Home/issues/6579.

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevent to this proposal? -->

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
