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

- List

Lists all the NuGet configuration file locations. This command will include all the NuGet configuration file that will be applied, when invoking NuGet command from the current working directory path. The listed NuGet configuration files are in priority order. So the order of loading those configurations is reversed, that is, loading order is from the bottom to the top. So the configuration on the top will apply.
You may refer to [How settings are applied](https://learn.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior#how-settings-are-applied) for more details. 

#### Arguments

- CURRENT_DIRECTORY

Run this command as if current directory is set to the specified directory.

#### Options

- -?|-h|--help

Prints out a description of how to use the command.

#### Examples

- List all the NuGet configuration file that will be applied, when invoking NuGet command in the current directory.

```
dotnet nuget config list

C:\Test\Repos\Solution\NuGet.Config
C:\Test\Repos\NuGet.Config
C:\Test\NuGet.Config
C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.FallbackLocation.config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.Offline.config
```

- List all the NuGet configuration file that will be applied, when invoking NuGet command in the specific directory.

```
dotnet nuget config list  C:\Test\Repos

C:\Test\Repos\NuGet.Config
C:\Test\NuGet.Config
C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.FallbackLocation.config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.Offline.config
```

## Future Work
1. The `dotnet nuget config list` is a community ask. We will consider adding more commands, like add/update/delete, in the future.
2. We will discuss if adding this command into NuGet.exe CLI, in the future.
3. NuGet.exe [config command](https://learn.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-config) is implemented. But there is no `list` command. And the behavior is confusing (the `set` command will set the property which appears last when loading, so sometimes it's not updating the closest NuGet configuration file). Do we want to implement those subcommand(e.g.`set`) in the future in dotnet.exe differently?

## Open Questions
1. When the specified `CURRENT_DIRECTORY` doesn't exist, shall we list user-wide and machine-wide config files? Or show a warning saying the working directory doesn't exist? Or do both?

I prefer do just a warning, or do both. 
When user has a spelling mistake when passing `CURRENT_DIRECTORY` without knowing, if we don't show a warning, that would mislead the user.
Showing them user-wide and machine-wide config files could provide extra info and may help them to understand the example of a right path. But since this is not a real scenario (It's impossible that a real `CURRENT_DIRECTORY` doesn't exist), this adds very limited value.

## Considerations

