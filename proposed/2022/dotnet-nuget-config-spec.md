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
Design and implement `dotnet nuget config` command with commands other than `list`, e.g. add/update/delete

## Solution
The following command will be implemented in the `dotnet.exe` CLI.

### `dotnet nuget config`

#### Commands

- List

Lists all the NuGet configuration file locations. 

This command will include all the NuGet configuration file that will be applied, when invoking NuGet command from the current working directory path. The listed NuGet configuration files are in priority order. So the order of loading those configurations is reversed, that is, loading order is from the bottom to the top. So the configuration on the top will apply.
You may refer to [How settings are applied](https://learn.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior#how-settings-are-applied) for more details. 

#### Arguments

- WORKING_DIRECTORY

Run this command as if working directory is set to the specified directory.

If the specified `WORKING_DIRECTORY` doesn't exist, an error is displayed indicating the `WORKING_DIRECTORY` doesn't exist.

> [!Note]
> If `WORKING_DIRECTORY` (or its parent directories) is not accessible, the command will ignore any NuGet configuration files under those directories without any warning/error. This is aligned with other NuGet commands.

#### Options
- -v|--verbosity <LEVEL>

Sets the verbosity level of the command. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic]. The default is minimal. 
When the verbosity level is detailed or diagnostic, the command will display the merged NuGet configuration.

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

- List all the NuGet configuration file that will be applied, and show the merged NuGet configuration, when invoking NuGet command in the specific directory.

```
dotnet nuget config list  C:\Test\Repos -v d

C:\Test\Repos\NuGet.Config
C:\Test\NuGet.Config
C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.FallbackLocation.config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.Offline.config

The merged NuGet configuration:
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <add key="Microsoft Visual Studio Offline Packages" value="C:\Program Files (x86)\Microsoft SDKs\NuGetPackages\" />
    <add key="Test Package source" value="C:\work" />
  </packageSources>
  <packageRestore>
    <add key="enabled" value="False" />
    <add key="automatic" value="False" />
  </packageRestore>
  <bindingRedirects>
    <add key="skip" value="False" />
  </bindingRedirects>
  <packageManagement>
    <add key="format" value="0" />
    <add key="disabled" value="False" />
  </packageManagement>
</configuration>

```

- List all the NuGet configuration file that will be applied, but passing a non-exsiting `WORKING_DIRECTORY`.

```
dotnet nuget config list  C:\Test\NonExistingRepos

Error: The path "C:\Test\NonExistingRepos" doesn't exist.
```

- List all the NuGet configuration file that will be applied, but passing an inaccessible `WORKING_DIRECTORY`: C:\Test\AccessibleRepos\NotAccessibleSolution. 

The configuration file under C:\Test\AccessibleRepos\NotAccessibleSolution\NuGet.Config will be ignored without any warning or error.

```
dotnet nuget config list  C:\Test\AccessibleRepos\NotAccessibleSolution

C:\Test\AccessibleRepos\NuGet.Config
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

## Considerations

