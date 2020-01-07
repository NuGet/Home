# `dotnet <add|remove|enable|disable|update|list> source`

* Status: ** Draft **
* Author(s): [Rob Relyea](https://github.com/rrelyea)

## Issue

CLI support for `dotnet <list|add|update|remove|disable|enable> source` [#4126](https://github.com/NuGet/Home/issues/4126)

## Problem Background

`NuGet.exe sources < add | remove | enable | disable | update | list >` functionality hasn't been ported to `dotnet.exe` yet. 

## Who are the customers

Package Authors & Package Consumers who are using .NET core. Many of these devs are used to using dotnet.exe as their primary interface to dotnet core development.

## Requirements

* Blend in nicely with dotnet.exe.
* Provide all important functionality.
* Review behavior, because now would be a good time to change/tweak/improve, especially if it is breaking.

## DotNet CLI command strategy

dotnet project commands
	add       (add package)
	build
	clean
	help
	list      (list package)
	msbuild
	new       (new nugetconfig)
	pack      (nuget!)
	publish
	remove    (remove package)
	restore   (nuget!)
	run

dotnet nuget commands
  config
    dotnet new nugetconfig
    add - named source
    remove - named source
    update - named source
    disable - named source
    enable - named source
    list - named sources
  push/delete
    push - ok, but review
    delete - ok, but review
  locals - CONSIDER eventual redesign.

dotnet tool
  install
  uninstall
  update
  list
  run
  restore

dotnet sln
dotnet build-server
dotnet vstest
dotnet store

### Related issues:

This is a review of NuGet sources issues.

#### Do as part of this work
- ensure localization of nuget.exe isn't broken. also, make sure dotnet.exe loc works. [Done - ILMerge includes 13 NuGet.Commands.resources.dll into NuGet.exe on 1/6/20]
- Documentation recommendations for setting up sources (w/ or w/o auth) for projects that run on CI [#5881](https://github.com/NuGet/Home/issues/5881)

#### Followup
- [Test Failure][Accessibility][ESN][CSY]Duplicated hotkeys show in “Options->NuGet Package Manager->Package Sources” dialog [#7822](https://github.com/NuGet/Home/issues/7822)
- Nuget.exe sources add does not work if nuget.config does not have proper section [#1589](https://github.com/NuGet/Home/issues/1589)
- Determine if nuget source name is case-sensitive and ensure disable and other uses works properly given that [#8668](https://github.com/NuGet/Home/issues/8668)
- andy added one to be able to add a clear??
- command to be able to convert a nuget.config to ignore all things above it.??

Andy: if you `dotnet nuget add source` with credentials -- he doesn't like that it adds credentials in the local file if you point it towards a nuget.config.

#### Substantial
- Make nuget work if one of the sources is not accessable [#8711](https://github.com/NuGet/Home/issues/8711)
- NuGet Restore/Update does not work when unrequired package sources are unavailable [#6373](https://github.com/NuGet/Home/issues/6373)
- Restore not pulling from source declared in global NuGet.config when the same exists in solution-based nuget.config [#8700](https://github.com/NuGet/Home/issues/8700)
- Issue saving settings in Visual Studio - adding a source throws an exception [#8407](https://github.com/NuGet/Home/issues/8407)
- Settings: PM UI sources shows no sources if one is an invalid file path [#7897](https://github.com/NuGet/Home/issues/7897)
- nuget.exe sources command to control <clear /> behavior (ideally in all applicable places in config) [#7580](https://github.com/NuGet/Home/issues/7580)
- Enabling a source that is disabled in a nuget.config lower in precedence chain [#6783](https://github.com/NuGet/Home/issues/6783)
- Multiple -ConfigFile Nuget.Config / misleading help text [#6523](https://github.com/NuGet/Home/issues/6523)
- dotnet-nuget doesn't support verbosity [#6374](https://github.com/NuGet/Home/issues/6374)
- Add ability to ignore failed sources in VS (Package Source Diagnostics) [#5643](https://github.com/NuGet/Home/issues/5643)
- Deal with slow/misbehaving sources [#1627](https://github.com/NuGet/Home/issues/1627) - and make errors apparent.
- Reload Visual Studio package sources when nuget.config is modified manually [#1538](https://github.com/NuGet/Home/issues/1538)
- Warnings not displayed in presence of valid and invalid nuget source. [#7280](https://github.com/NuGet/Home/issues/7280)

#### Fit and Finish
- Arrow keys in NuGet PM UI Sources editing doesn't change order of persistence [#8315](https://github.com/NuGet/Home/issues/8315)
- Nuget.exe sources add with -password "@foo" raises System.FormatException [#7707](https://github.com/NuGet/Home/issues/7707)
- VS NuGet PMUI - Machine-wide package sources area should be vertically resize-able as well [#7560](https://github.com/NuGet/Home/issues/7560)
- Package Manager browse error / restore error for non-HTTP package source with protocol version 3 [#3537](https://github.com/NuGet/Home/issues/3537)
- [validation] Hovering over the "Package source" dropdown shows disabled sources [#3467](https://github.com/NuGet/Home/issues/3467)
- Update nuget.exe help for high level command descriptions [#1774](https://github.com/NuGet/Home/issues/1774) - see item #7


#### How Named Sources Are Used in Other Commands

- nuget.exe add doesn't recognize named sources [#8391](https://github.com/NuGet/Home/issues/8391)
- dotnet new nugetconfig -- should have option to remove "clear" element [#7581](https://github.com/NuGet/Home/issues/7581)
- RestoreSources set via MSBuild properties cannot use credentials [#6045](https://github.com/NuGet/Home/issues/6045)
- Warn or error when no package sources exist [#2472](https://github.com/NuGet/Home/issues/2472)

### Usage: dotnet nuget list source[s] [options]
Q: should list accept "source and sources" as synonyms?

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

