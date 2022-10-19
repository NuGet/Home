# dotnet nuget config command

- Author: [Heng Liu](https://github.com/heng-liu)
- GitHub Issue [8420](https://github.com/NuGet/Home/issues/8420)

## Problem Background

Currently, there is no command for NuGet users to know about the NuGet configuration file locations. This is inconvienient for both NuGet users and NuGet team. When NuGet users want to figure out where is the merged configuration coming from, or when NuGet team tries to diagnose issues but needs all the configuration files, this command will be helpful.

## Who are the customers

This feature is for dotnet.exe users.

## Goals
Design and implement `dotnet nuget config list` commands.

## Non-Goals
Design and implement other `dotnet nuget config` commands. E.g. add/update/delete

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

### Future Work
The `dotnet nuget config list` is a community ask. We will consider adding more commands, like add/update/delete, in the future.

## Open Questions
1. Shall we add `working directory` as an option? So that people could check different NuGet configuration lists without changing current directory.
2. Do we need to add this into NuGet.exe CLI?

