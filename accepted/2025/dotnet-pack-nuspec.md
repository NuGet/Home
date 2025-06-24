# Allow dotnet pack to pack .nuspec files without needing csproj 

- Author Name: [kfikadu](https://github.com/kfikadu), [martinrrm](https://github.com//martinrrm)  
- GitHub Issue: [Issue #4254](https://github.com/NuGet/Home/issues/4254)  

## Summary


`dotnet pack` currently does not support packing a .nuspec file without a corresponding .csproj file.  
As a result, developers are forced to either use `nuget.exe` (which is Windows-only) or create  
a dummy .csproj file solely for packaging purposes. This creates friction for cross-platform  
workflows, disrupts legacy systems that rely on .nuspec-only packaging, and undermines modular packaging strategies.  
This proposal aims to add support for .nuspec-only packaging in dotnet pack, eliminating the need for a .csproj file and  
improving developer experience across platforms.  


## Motivation

Customers have been requesting the functionality of packing using a .nuspec file  
when using the command `dotnet pack` in files or non-sdk-style projects.  

## Explanation

### Functional explanation

Currently, arguments for `dotnet pack` are [\<PROJECT\>|\<SOLUTION\>]. This feature will enable customers to also use a .nuspec to pack files. 
`dotnet pack` is available for projects that are using the SDK-style format. Adding the ability to use a .nuspec path instead  
will enable customers to pack projects or files that aren't SDK-style. In these cases, `dotnet pack` with a nuspec will not run  
`NuGet.Build.Tasks.Pack.targets` and instead use the current implementation of `nuget.exe` [pack commands](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Clients/NuGet.CommandLine/Commands/PackCommand.cs)  

### Technical explanation

**Option 1: .nuspec file path as an arugment dotnet pack [\<PROJECT\>|\<SOLUTION\>|\<NUSPEC\>]**  

Currently, dotnet pack options and nuget.exe pack options are very different, meaning that we will need to add new options  
that would not apply when packing an SDK project. There are a couple that are shared but the main difference is that when   
using nuget.exe you can use the option -Properties to do token replacement in the .nuspec (ex. $variable$).  
All new options and existing ones will need to have a check to see if they are applicable to the user scenario.  

This implementation doesn't require us to create a new command or subcommand, making the command look cleaner and  
customer won't need to learn a new command  

**Option 2: New subcommand dotnet pack nuspec [\<NUSPEC\>]**  

This new subcommand will help us add all current nuget.exe pack options more easily and don't worry about existing pack options  

**Current result of running `nuget.exe pack -h` and `dotnet pack -h`**  
`nuget.exe pack -h`: ![output of  `nuget.exe pack -h`](/meta/resources/dotnet-pack-nuspec/nuget%20pack%20-h%20ss.png)  

`dotnet pack -h`: ![output of `dotnet pack -h`](/meta/resources/dotnet-pack-nuspec/dotnet%20pack%20-h%20ss.png) 



## Prior Art

Previously, in 4.0.0-rc2, you were able to pack a .nuspec file without a csproj file by using 
`dotnet nuget pack (nuspec)` file. This was removed in 4.0.0-rc3.
