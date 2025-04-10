# `dotnet nuget <add|remove|enable|disable|update|list> source`

* Status: **Reviewed**
* Author(s): [Rob Relyea](https://github.com/rrelyea)

## Issue

add `dotnet nuget <add|remove|update|disable|enable|list> source` command [#4126](https://github.com/NuGet/Home/issues/4126)

## Problem Background

`NuGet.exe sources <add|remove|enable|disable|update|list>` functionality hasn't been ported to `dotnet.exe` yet. 

## Who are the customers

Package Authors & Package Consumers who are using .NET core. Many of these devs are used to using dotnet.exe as their primary interface to dotnet core development.

## Requirements

* Blend in nicely with dotnet.exe.
* Provide all important functionality.
* Review behavior, because now would be a good time to change/tweak/improve, especially if it is breaking.

## DotNet CLI command strategy

How do NuGet Commands fit into Dotnet.exe?

1. Make part of dotnet verb-noun pattern: `dotnet nuget <add|remove|enable|disable|update|list> source`
repository|feed|source

1. Port directly, but under "nuget" keyword: `dotnet nuget sources <add|remove|enable|disable|update|list>`

We are choosing the first. (verb-noun, rather than noun-verb)

```
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
```

### Usage: dotnet nuget list source [options]

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

  -p|--password <password>        ...

  --store-password-in-clear-text  Enables storing portable package source credentials by disabling password encryption.

  --valid-authentication-types    Comma-separated list of valid authentication types for this source. By default, all authentication types are valid. Example: basic,negotiate

  -c|--configfile                 The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used. To learn more about NuGet configuration go to https://docs.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior.

  -h|--help                       Show help information

Consider Post-MVP Improvement: target first config file found, not just one with PackageSources - [#1589](https://github.com/NuGet/Home/issues/1589)

Consider Post-MVP Improvement: if config file is not found, create one.

Consider Post-MVP Improvement: tell which config it was added to or removed from
  ANDY: really important when config isn't specified.

Consider Post-MVP Improvement: `dotnet nuget list source` should be able to show which config a source was defined in. [#9342]

Consider Post-MVP Improvement: where do credentials get written down? is that good? should there be another flag to control? (looks like -configfile will write the source and the creds in the file pointed to????)
```
   Anand: likes that behavior.
   Others: ??
   Perhaps we ask nuget authors DL
   Andy: do we do it via docs...2 steps...
```

TODO: Anand: wants 'dotnet nuget add source https://foo.com' to work.
SOMEPROGRESS: 
 - current plan on drawing board:
   - default name to "source1", "source2", etc...
   - sourceUri is default arg in add source
   - name is default arg in remove source


Consider Post-MVP Improvement: Discussion with Loïc:  consider validating a source on creation... does the directory exist? does the web url exist? if you cannot access the url, do you need to add a password or credprovider?


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

Consider Post-MVP Improvement: Anand: should you be able to pass in a source instead of name?



### Usage: dotnet nuget disable source [options]

Options:
  -n|--name <name>  Name of the source.

  -c|--configfile   The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used. To learn more about NuGet configuration go to https://docs.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior.

  -h|--help         Show help information

If -name param matches existing source, disables the source.

Consider Post-MVP Improvement: [#8668](https://github.com/NuGet/Home/issues/8668)
  andy: do 2 fixes, make case match...but support non-matching cases.
  anand: should we persist as lower case?
  rob: for MVP, i've made a change to persist the disabled source name as the same case as the source. can consider 2nd fix to support non-matching case, post-MVP.

### Implementation

Old implementation

- NuGet.CommandLine\SourcesCommand.cs

Refactored into:

- NuGet.CommandLine\SourcesCommand.cs
- NuGet.CommandLineXplat\SourceCommand.cs
- NuGet.Commands\SourceArgs.cs
- NuGet.Commands\SourceRunner.cs


### Localization Impact

NuGet.exe is using an out of date localization strategy.
(new/changed strings aren't being localized by our current processes)

Plan:
- First step:
Move string from NuGet.CommandLine -> NuGet.Commands
ILMerge NuGet.Commands.resources.dll (for each localized lang), into NuGet.exe
- Second step
Get moved string localized, then consider right testing.
- Third step
Move rest of strings from NuGet.exe into satellite assemblies and ILMerge them

Consider Post-MVP Improvement: should we merge in all satellite assemblies??? or just a few imporatnt ones...

### Related issues:

This is a review of NuGet sources issues.

#### Do as part of this work
- Documentation recommendations for setting up sources (w/ or w/o auth) for projects that run on CI [#5881](https://github.com/NuGet/Home/issues/5881)
- Determine if nuget source name is case-sensitive and ensure disable and other uses works properly given that [#8668](https://github.com/NuGet/Home/issues/8668) - fixing main scenario.

#### Followup
- [Test Failure][Accessibility][ESN][CSY]Duplicated hotkeys show in “Options->NuGet Package Manager->Package Sources” dialog [#7822](https://github.com/NuGet/Home/issues/7822)
- Nuget.exe sources add does not work if nuget.config does not have proper section [#1589](https://github.com/NuGet/Home/issues/1589)
- andy added one to be able to add and remove clear??
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

### Other ideas

Q: should these commands accept "source and sources" as synonyms?
A: Code now detects and redirects users nicely if they do 'dotnet nuget sources *' or 'dotnet nuget * sources' to: 'dotnet nuget * source'

Consider Post-MVP Improvement: Validation rules on sources could be integrated into CLI and VS. (http vs https, source exists, etc...)
- on add/update, and on list.

Consider Post-MVP Improvement: consider an airplane mode, or the like, to disable all sources which aren't available right now. but perhaps not the same disable as normal, so we can move back to enable later.

### Open Questions
Consider Post-MVP Improvement: Should dotnet nuget list source understand sources (and fallback folders?) set in project files?
should there be a way to probe .csproj files??? to list other sources?
    dotnet nuget list source --solution foo.sln

Consider Post-MVP Improvement: credentail provider...
  should authenticated sources be handled better.
  could servers advertise what they need?
  could client make it easier to install?
  should validation rules for sources, help you understand if sources exist...if you can authenticate.



TODO: Investigate - VS PM UI...compare where source info goes from that dialog vs CLI commands. And rationalize.
Answer: They both have same behavior today...first nuget.config found with a clear in the sources, is used. if not, it uses %userprofile%\AppData\Roaming\NuGet\NuGet.Config

Consider Post-MVP Improvement: Loïc: what about encrypted passwords on non-windows machines?
TODO: figure out long term strategy here...so we know whether to have store-in-clear-text param.

TODO: go write CLI level code for validation/intellisense.
TODO: finish all strings...including code gen of resx from commands.xml
TODO: fix overridable log, for dotnet.exe scenario.
