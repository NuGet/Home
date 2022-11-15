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

Lists all the NuGet configuration settings. 

This command will list merged NuGet configuration settings from one or multiple NuGet configuration files that will be applied, when invoking NuGet command from the current working directory path. 

#### Arguments

- WORKING_DIRECTORY

Run this command as if working directory is set to the specified directory.

If the specified `WORKING_DIRECTORY` doesn't exist, an error is displayed indicating the `WORKING_DIRECTORY` doesn't exist.

> [!Note]
> If `WORKING_DIRECTORY` (or its parent directories) is not accessible, the command will ignore any NuGet configuration files under those directories without any warning/error. This is aligned with other NuGet commands.

#### Options
- -v|--verbosity <LEVEL>

Sets the verbosity level of the command. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic]. The default is minimal. 
When the verbosity level is detailed or diagnostic, the command will display all the NuGet configuration file that will be applied, when invoking NuGet command from the current working directory path.

The listed NuGet configuration files are in priority order. So the order of loading those configurations is reversed, that is, loading order is from the bottom to the top. So the configuration on the top will apply.
You may refer to [How settings are applied](https://learn.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior#how-settings-are-applied) for more details. 

- -?|-h|--help

Prints out a description of how to use the command.

#### Examples

- List all the NuGet configuration file that will be applied, when invoking NuGet command in the current directory.

```
dotnet nuget config list --verbosity detailed

<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <add key="Microsoft Visual Studio Offline Packages" value="C:\Program Files (x86)\Microsoft SDKs\NuGetPackages\" />
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

C:\Test\Repos\Solution\NuGet.Config
C:\Test\Repos\NuGet.Config
C:\Test\NuGet.Config
C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.FallbackLocation.config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.Offline.config
```

- List all the NuGet configuration file that will be applied, when invoking NuGet command in the specific directory.

```
dotnet nuget config list  C:\Test\Repos --verbosity detailed

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

C:\Test\Repos\NuGet.Config
C:\Test\NuGet.Config
C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.FallbackLocation.config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.Offline.config
```

- List only the NuGet configuration settings, when invoking NuGet command in the specific directory.

```
dotnet nuget config list  C:\Test\Repos

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
dotnet nuget config list  C:\Test\AccessibleRepos\NotAccessibleSolution -v d

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

C:\Test\AccessibleRepos\NuGet.Config
C:\Test\NuGet.Config
C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.FallbackLocation.config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.Offline.config
```

#### Commands

- Set

Set the NuGet configuration settings. 

This command will set the value of a specified NuGet configuration setting.

Please note this command only manages settings in [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section).
For other settings not in config section, we have/will have other commands. E.g. for [trustedSigners section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#trustedsigners-section), we have [dotnet nuget trust](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-nuget-trust) command.

#### Arguments

- SETTING_KEY

Specify the key of the settings that are to be set.

If the specified `SETTING_KEY` is not a key in [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section), an error is displayed indicating the `SETTING_KEY` could not be set.

- SETTING_VALUE

Set the value of the SETTING_KEY to SETTING_VALUE.

#### Options
- --config-file

Specify the config file path to add the setting key-value pair. If it's not specified, the config file with highest priority will be updated.

- -?|-h|--help

Prints out a description of how to use the command.

#### Examples

- Set the `signatureValidationMode` to true in the closest NuGet configuration file.

```
dotnet nuget config set signatureValidationMode require

```

- Set the `defaultPushSource` in the specified NuGet configuration file.

```
dotnet nuget config set defaultPushSource https://MyRepo/ES/api/v2/package --config-file C:\Users\username\AppData\Roaming\NuGet\NuGet.Config

```

- Unset

Remove the NuGet configuration settings. 

This command will remove the key-value pair from a specified NuGet configuration setting.

Please note this command only manages settings in [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section).
For other settings not in config section, we have/will have other commands. E.g. for [trustedSigners section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#trustedsigners-section), we have [dotnet nuget trust](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-nuget-trust) command.

#### Arguments

- SETTING_KEY

Specify the key of the settings that are to be removed.

If the specified `SETTING_KEY` is not a key in [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section), an error is displayed indicating the `SETTING_KEY` could not be set.


#### Options

- --config-file

Specify the config file path to remove the setting key-value pair. If it's not specified, the config file with highest priority will be updated.

- -?|-h|--help

Prints out a description of how to use the command.

#### Examples

- Unset the `signatureValidationMode` in the closest NuGet configuration file.

```
dotnet nuget config unset signatureValidationMode

```

- Unset the `defaultPushSource` in the specified NuGet configuration file.

```
dotnet nuget config unset defaultPushSource --config-file C:\Users\username\AppData\Roaming\NuGet\NuGet.Config

```

## Future Work
1. The `dotnet nuget config list` is a community ask. We will consider adding more commands, like add/update/delete, in the future.
2. We will discuss if adding this command into NuGet.exe CLI, in the future.
3. NuGet.exe [config command](https://learn.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-config) is implemented. But there is no `list` command. And the behavior is confusing (the `set` command will set the property which appears last when loading, so sometimes it's not updating the closest NuGet configuration file). Do we want to implement those subcommand(e.g.`set`) in the future in dotnet.exe differently?

## Open Questions
1. To show configuration files locations, is it better to use `--verbosity` option or some option named like `--show-path`? (git command is using `--show-origin` for similar purpose)
2. What are the recommended verbs in dotnet command when setting and unsetting values?  ('set' and 'unset' work or not?)
3. `Get` is not mentioned in this doc. It may cause some confusions:
   Should `get` work for settings not in config section? (It's workable, but then we will miss `set` and `unset` for those as those are not doable)
   Should `get` get the settings from a specific config file(like `set` and `unset`), or get the merged settings from multiple config files?

## Considerations
1. Will this command help with diagnosing incorrect setting format?
<br />No. Incorrect NuGet settings should have seperate error/warning message to tell the customer what's wrong in the setting file. If we have incorrect NuGet settings, all NuGet command, including `dotnet nuget config` command, should display the same error/warning message.
<br />E.g. if we have an invalid XML problem in one of the NuGet configuration file, running all NuGet command will get an error as following:
dotnet nuget list source
error: NuGet.Config is not valid XML. Path: 'C:\Users\username\Source\Repos\NuGet.Config'.
error:   The 'disabledPackageSources' start tag on line 19 position 4 does not match the end tag of 'configuration'. Line 20, position 3.
