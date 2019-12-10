# `dotnet <add|remove|enable|disable|update|list> source`

* Status: ** Draft **
* Author(s): [Rob Relyea](https://github.com/rrelyea)

## Issue

CLI support for `dotnet <add|remove|enable|disable|update|list> source` [#4126](https://github.com/NuGet/Home/issues/4126)

## Problem Background

`NuGet.exe sources < add | remove | enable | disable | update | list >` functionality hasn't been ported to `dotnet.exe` yet. 

## Who are the customers

dotnet core developers who are used to using dotnet.exe as their primary interface to dotnet core development.

## Requirements

* Blend in nicely with dotnet.exe.
* Provide all important functionality.
* Review behavior, because now would be a good time to change/tweak/improve, especially if it is breaking.

## Figure out entire NuGet strategy for CLI commands in dotnet.exe

Current approach:
* top level commands:
  * dotnet verb pattern
    * dotnet restore
    * dotnet pack
  * dotnet verb/noun pattern
    * dotnet add|list|remove package
    * planned: dotnet update|search package
 
* commands under dotnet nuget:
  * dotnet verb pattern
    * dotnet nuget push ...
    * dotnet nuget delete ...
  * dotnet noun pattern
    * dotnet nuget locals ...
  
Possible future approaches:
* dotnet nuget verb/noun - [commands.xml](commands.xml)
* dotnet nuget noun/verb - like nuget.exe (which is like Azure CLI)
* other...

Do we have:
* commands only in nuget?
  Commands:
-  add
-  clean
-  delete
-  disable
-  enable
-  get
-  list
-  pack
-  push
-  remove
-  restore
-  search
-  set
-  sign
-  sync
-  update
-  verify

* commands only in toplevel?

Execute a .NET Core SDK command.

sdk-options:
-  -d|--diagnostics  Enable diagnostic output.
-  -h|--help         Show command line help.
-  --info            Display .NET Core information.
-  --list-runtimes   Display the installed runtimes.
-  --list-sdks       Display the installed SDKs.
-  --version         Display .NET Core SDK version in use.

SDK commands:
-  add               Add a package or reference to a .NET project. **trusted-signers, sources
-  build             Build a .NET project.
-  build-server      Interact with servers started by a build.
-  clean             Clean build outputs of a .NET project.  **nuget locals
-  delete            **Delete packages from server.
-  disable           **disable a source
-  enable            **enable a source
-  get               **get nugetconfig value
-  help              Show command line help.
-  list              List project references of a .NET project. **packages, sources, trusted-signers
-  msbuild           Run Microsoft Build Engine (MSBuild) commands.
-  new               Create a new .NET project or file.
-  nuget             Provides additional NuGet commands.
-  pack              Create a NuGet package.
-  publish           Publish a .NET project for deployment.
-  push              **push a nuget packages to server
-  remove            Remove a package or reference from a .NET project.
-  restore           Restore dependencies specified in a .NET project. 
-  run               Build and run a .NET project output.
-  search            **for a package on servers
-  set               **set nugetconfig value
-  sign              **package
-  sln               Modify Visual Studio solution files.
-  store             Store the specified assemblies in the runtime package store.
-  sync              ** trusted signers
-  test              Run unit tests using the test runner specified in a .NET project.
-  tool              Install or manage tools that extend the .NET experience.
-  update            **package
-  verify            **signature or full validation of package
-  vstest            Run Microsoft Test Engine (VSTest) commands.


Additional commands from bundled tools:
  dev-certs         Create and manage development certificates.
  fsi               Start F# Interactive / execute F# scripts.
  sql-cache         SQL Server cache command-line tools.
  user-secrets      Manage development user secrets.
  watch             Start a file watcher that runs a command when files change.

* commands in top level and nuget?
everything available in nuget - and a few top level too (pack, restore, add package, etc...)

## Solution

1. Put under `dotnet nuget`, but follow `verb` `noun` pattern: `dotnet nuget <add|remove|enable|disable|update|list> source `

If dotnet sdk team, wants...they can promote up one level to `dotnet <add> source`



TODO: review bugs on nuget sources
    andy added one to be able to add a clear.
    command to be able to convert a nuget.config to ignore all things above it.

### Related issues:

- Arrow keys in NuGet PM UI Sources editing doesn't change order of persistence [#8315](https://github.com/NuGet/Home/issues/8315)
- Make nuget work if one of the sources is not accessable [#8711](https://github.com/NuGet/Home/issues/8711)
- Restore not pulling from source declared in global NuGet.config when the same exists in solution-based nuget.config [#8700](https://github.com/NuGet/Home/issues/8700)
- Determine if nuget source name is case-sensitive and ensure disable and other uses works properly given that [#8668](https://github.com/NuGet/Home/issues/8668)
- Issue saving settings in Visual Studio - adding a source throws an exception [#8407](https://github.com/NuGet/Home/issues/8407)
- Settings: PM UI sources shows no sources if one is an invalid file path [#7897](https://github.com/NuGet/Home/issues/7897)
- [Test Failure][Accessibility][ESN][CSY]Duplicated hotkeys show in “Options->NuGet Package Manager->Package Sources” dialog [#7822](https://github.com/NuGet/Home/issues/7822)
- Nuget.exe sources add with -password "@foo" raises System.FormatException [#7707](https://github.com/NuGet/Home/issues/7707)
- nuget.exe sources command to control <clear /> behavior (ideally in all applicable places in config) [#7580](https://github.com/NuGet/Home/issues/7580)
- VS NuGet PMUI - Machine-wide package sources area should be vertically resize-able as well [#7560](https://github.com/NuGet/Home/issues/7560)
- Warnings not displayed in presence of valid and invalid nuget source. [#7280](https://github.com/NuGet/Home/issues/7280)
- Enabling a source that is disabled in a nuget.config lower in precedence chain [#6783](https://github.com/NuGet/Home/issues/6783)
- Multiple -ConfigFile Nuget.Config / misleading help text [#6523](https://github.com/NuGet/Home/issues/6523)
- dotnet-nuget doesn't support verbosity [#6374](https://github.com/NuGet/Home/issues/6374)
- NuGet Restore/Update does not work when unrequired package sources are unavailable [#6373](https://github.com/NuGet/Home/issues/6373)
- Documentation recommendations for setting up sources (w/ or w/o auth) for projects that run on CI [#5881](https://github.com/NuGet/Home/issues/5881)
- Add ability to ignore failed sources in VS (Package Source Diagnostics) [#5643](https://github.com/NuGet/Home/issues/5643)
- Package Manager browse error / restore error for non-HTTP package source with protocol version 3 [#3537](https://github.com/NuGet/Home/issues/3537)
- [validation] Hovering over the "Package source" dropdown shows disabled sources [#3467](https://github.com/NuGet/Home/issues/3467)
- Update nuget.exe help for high level command descriptions [#1774](https://github.com/NuGet/Home/issues/1774) - see item #7
- Deal with slow/misbehaving sources [#1627](https://github.com/NuGet/Home/issues/1627) - and make errors apparent.
- Nuget.exe sources add does not work if nuget.config does not have proper section [#1589](https://github.com/NuGet/Home/issues/1589)
- Reload Visual Studio package sources when nuget.config is modified manually [#1538](https://github.com/NuGet/Home/issues/1538)
- Alt+S in VS Tools->Options->NuGet Package Manager->"Package Sources" jumps to wrong text box [#1518](https://github.com/NuGet/Home/issues/1518)

#### How Named Sources Are Used in Other Commands

- nuget.exe add doesn't recognize named sources [#8391](https://github.com/NuGet/Home/issues/8391)
- dotnet new nugetconfig -- should have option to remove "clear" element [#7581](https://github.com/NuGet/Home/issues/7581)
- RestoreSources set via MSBuild properties cannot use credentials [#6045](https://github.com/NuGet/Home/issues/6045)
- Warn or error when no package sources exist [#2472](https://github.com/NuGet/Home/issues/2472)



### Usage: dotnet nuget list source[s] [options]

Options:

 -f|--format Applies to the list action. Accepts two values: Detailed (the default) and Short.

 -c|--configfile  The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used. To learn more about NuGet configuration go to https://docs.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior.
 
 -h|--help        Show help information

Outputs a list of configured sources, including if they are enabled or disabled.

### Usage: dotnet nuget add source [options]

Options:
  -n|--name <name>                Name of the source.
  -s|--source <source>            Path to the package(s) source.

  -u|--username <username>        UserName to be used when connecting to an authenticated source.

  -p|--password <password>        UserName to be used when connecting to an authenticated source.

  --store-password-in-clear-text  Enables storing portable package source credentials by disabling password encryption.

  --valid-authentication-types    Comma-separated list of valid authentication types for this source. By default, all authentication types are valid. Example: basic,negotiate

  -c|--configfile                 The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used. To learn more about NuGet configuration go to https://docs.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior.

  -h|--help                       Show help information

Improvement: target first config file found, not just one with PackageSources
Improvement: if config file is not found, create one.
Improvement: tell which config it was added to.
Spec: where do credentials get written down? is that good? should there be another flag to control? (looks like -configfile will write the source and the creds in the file pointed to????)


### Usage: dotnet nuget update source [options]

Options:
  -n|--name <name>                Name of the source.

  -s|--source <source>            Path to the package(s) source.

  -u|--username <username>        UserName to be used when connecting to an authenticated source.

  -p|--password <password>        UserName to be used when connecting to an authenticated source.

  --store-password-in-clear-text  Enables storing portable package source credentials by disabling password encryption.

  --valid-authentication-types    Comma-separated list of valid authentication types for this source. By default, all authentication types are valid. Example: basic,negotiate

  -c|--configfile                 The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used. To learn more about NuGet configuration go to https://docs.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior.

  -h|--help                       Show help information

If -name param matches existing source, updates all other properties of that source.


### Usage: dotnet nuget remove source [options]

Options:
  -n|--name <name>  Name of the source.

  -c|--configfile   The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used. To learn more about NuGet configuration go to https://docs.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior.

  -h|--help         Show help information

If -name param matches existing source, removes the source.


### Usage: dotnet nuget enable source [options]

Options:
  -n|--name <name>  Name of the source.

  -c|--configfile   The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used. To learn more about NuGet configuration go to https://docs.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior.

  -h|--help         Show help information

If -name param matches existing source, enables the source.


### Usage: dotnet nuget disable source [options]

Options:
  -n|--name <name>  Name of the source.

  -c|--configfile   The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used. To learn more about NuGet configuration go to https://docs.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior.

  -h|--help         Show help information

If -name param matches existing source, disables the source.

### Implementation



#### Package declaration


#### Error handling


#### Assets file changes


#### PackageDownload and trust policies

### PackageDownload repeatable build


### Open work items


### Open Questions

### Question 1


### Question 2


### Question 3


#### Non-Goals


##### Risky cases


### Alternative approaches considered


## References

### Other options

1. Make part of dotnet verb-noun pattern: `dotnet <add|remove|enable|disable|update|list> source`
repository|feed|source

1. Port directly, but under "nuget" keyword: `dotnet nuget sources <add|remove|enable|disable|update|list>`

1. Other?




Dotnet
  Add -> Package
  Remove -> Package
  Update* -> Package
  List -> Package

  Nuget

    Add -> Source
    Disable -> Source
    Enable -> Source
    List -> Source
    Remove -> Source
    Update -> Source

