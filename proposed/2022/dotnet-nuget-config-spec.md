# NuGet configuration CLI for dotnet.exe

- Author: [Heng Liu](https://github.com/heng-liu)
- GitHub Issue [8420](https://github.com/NuGet/Home/issues/8420)

## Problem Background

Currently, there is no NuGet configuration CLI for dotnet.exe. It's inconvenient for NuGet users to know about the NuGet configuration file locations and figure out where is the merged configuration coming from. 

## Who are the customers

This feature is for dotnet.exe users.

## Goals
Design and implement `dotnet nuget config` command.

## Non-Goals
Design and implement `dotnet nuget config` command with commands other than `list`, E.g. add/update/delete

## Solution
The following command will be implemented in the `dotnet.exe` CLI.

### `dotnet nuget config`

#### Commands
If no command is specified, the command will default to list.

- List

Lists all the NuGet configuration file locations. This command will include all the NuGet configuration file that will be applied, when invoking NuGet command from the current working directory path. The listed NuGet configuration files are in priority order. So the order of loading those configurations is reversed, that is, loading order is from the bottom to the top. So the configuration on the top will apply.
You may refer to [How settings are applied](https://learn.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior#how-settings-are-applied) for more details. 

#### Options
- -?|-h|--help

Prints out a description of how to use the command.

#### Examples

- List all the NuGet configuration file that will be applied.

```
dotnet nuget config list

c:\repos\Solution\Project\NuGet.Config
c:\repos\Solution\NuGet.Config
C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.FallbackLocation.config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.Offline.config
```

## Future Work
The `dotnet nuget config list` is a community ask. We will consider adding more commands, like add/update/delete, in the future.

## Open Questions
1. Shall we add `working directory` as an option? So that people could check different NuGet configuration lists without changing current directory.
2. Do we need to add this into NuGet.exe CLI?

## Considerations
1. NuGet.exe [config command](https://learn.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-config) is implemented. But there is no `list` command. And the behavior is confusing (the `set` command will set the property which appears last when loading, so sometimes it's not updating the closest NuGet configuration file). Do we want to implement those subcommand(e.g.`set`) in the future in dotnet.exe differently?

