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
Design and implement in the same way for NuGet.exe command.

## Solution
The following command will be implemented in the `dotnet.exe` CLI.

### `dotnet nuget config`

### Commands

### Paths

List all the paths of NuGet configuration files that will be applied, when invoking NuGet command from the current working directory path.

The listed NuGet configuration files are in priority order. So the order of loading those configurations is reversed, that is, loading order is from the bottom to the top. So the configuration on the top will apply.
You may refer to [How settings are applied](https://learn.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior#how-settings-are-applied) for more details. 

#### Arguments

- WORKING_DIRECTORY

Run this command as if working directory is set to the specified directory. If it's not specified, the current working directory will be used.

If the specified `WORKING_DIRECTORY` doesn't exist, an error is displayed indicating the `WORKING_DIRECTORY` doesn't exist.

> [!Note]
> If `WORKING_DIRECTORY` (or its parent directories) is not accessible, the command will ignore any NuGet configuration files under those directories without any warning/error. This is aligned with other NuGet commands.

#### Options

- -?|-h|--help

Prints out a description of how to use the command.

#### Examples

- List all the NuGet configuration file that will be applied, when invoking NuGet command in the current directory.

```
dotnet nuget config paths 

C:\Test\Repos\Solution\NuGet.Config
C:\Test\Repos\NuGet.Config
C:\Test\NuGet.Config
C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.FallbackLocation.config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.Offline.config
```

- List all the paths of NuGet configuration files that will be applied, when invoking NuGet command in the specific directory.

```
dotnet nuget config paths C:\Test\Repos

C:\Test\Repos\NuGet.Config
C:\Test\NuGet.Config
C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.FallbackLocation.config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.Offline.config
```

- List all the NuGet configuration file that will be applied, but passing a non-existing argument `WORKING_DIRECTORY`.

```
dotnet nuget config paths C:\Test\NonExistingRepos

Error: The path "C:\Test\NonExistingRepos" doesn't exist.
```

- List all the NuGet configuration file that will be applied, but passing an inaccessible `WORKING_DIRECTORY`: C:\Test\AccessibleRepos\NotAccessibleSolution. 

The configuration file under C:\Test\AccessibleRepos\NotAccessibleSolution\NuGet.Config will be ignored without any warning or error.

```
dotnet nuget config paths C:\Test\AccessibleRepos\NotAccessibleSolution

C:\Test\AccessibleRepos\NuGet.Config
C:\Test\NuGet.Config
C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.FallbackLocation.config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.Offline.config
```

### Get

Get the NuGet configuration settings that will be applied. 

#### Arguments

- ALL

Get all merged NuGet configuration settings from multiple NuGet configuration files that will be applied, when invoking NuGet command from the working directory path. 

- CONFIG_KEY

Get the effective value of the specified configuration settings of the [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section). 


> [!Note]
> The CONFIG_KEY could only be one of the valid keys in config section. 
For other sections, like package source section, we have/will have specific command [dotnet nuget list source](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-nuget-list-source).

- WORKING_DIRECTORY

Run this command as if working directory is set to the specified directory. If it's not specified, the current working directory will be used.

If the specified `WORKING_DIRECTORY` doesn't exist, an error is displayed indicating the `WORKING_DIRECTORY` doesn't exist.

> [!Note]
> If `WORKING_DIRECTORY` (or its parent directories) is not accessible, the command will ignore any NuGet configuration files under those directories without any warning/error. This is aligned with other NuGet commands.

#### Options

- -?|-h|--help

Prints out a description of how to use the command.

- --show-path

Indicate that the NuGet configuration file path will be shown besides the configuration settings.

#### Examples

- Get all the NuGet configuration settings that will be applied, when invoking NuGet command in the current directory.

```
dotnet nuget config get all

packageSources:
  clear
  add key="source1" value="https://test/source1/v3/index.json"
  add key="source2" value="https://test/source2/v3/index.json"

packageSourceMapping:
  clear
  packageSource key="source1"  pattern="microsoft.*","nuget.*"
  packageSource key="source2"  pattern="system.*"

packageRestore:
  add key="enabled" value="False"
  add key="automatic" value="False"

```
- Get all the NuGet configuration settings that will be applied, when invoking NuGet command in the specific directory.

```
dotnet nuget config get all C:\Test\Repos

packageSources:
  clear
  add key="source1" value="https://test/source1/v3/index.json"
  add key="source2" value="https://test/source2/v3/index.json"

packageSourceMapping:
  clear
  packageSource key="source1"  pattern="microsoft.*","nuget.*"
  packageSource key="source2"  pattern="system.*"

packageRestore:
  add key="enabled" value="False"
  add key="automatic" value="False"

```

- Get all the NuGet configuration settings that will be applied, when invoking NuGet command in the current directory. Show the source(nuget configuration file path) of each configuration settings/child items.

```
dotnet nuget config get all --show-path

packageSources:
  add key="source1" value="https://test/source1/v3/index.json"     file: C:\Test\Repos\Solution\NuGet.Config
  add key="source2" value="https://test/source2/v3/index.json"     file: C:\Test\Repos\NuGet.Config

packageSourceMapping:
  clear                                                            file: C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
  packageSource key="source1"  pattern="microsoft.*","nuget.*"     file: C:\Test\Repos\Solution\NuGet.Config
  packageSource key="source2"  pattern="system.*"                  file: C:\Test\Repos\NuGet.Config                                 

packageRestore:
  add key="enabled" value="False"                                 file: C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
  add key="automatic" value="False"                               file: C:\Users\username\AppData\Roaming\NuGet\NuGet.Config

```

- Get `http_proxy` from config section, when invoking NuGet command in the current directory.

```
dotnet nuget config get http_proxy 

http://company-squid:3128@contoso.com"

```

- Get `http_proxy` from config section, when invoking NuGet command in the current directory. Show the nuget configuration file path of this configuration setting.

```
dotnet nuget config get http_proxy --show-path

http://company-squid:3128@contoso.com"         file: C:\Test\Repos\Solution\NuGet.Config

```

- Get `http_proxy` from config section, when `http_proxy` is not set in any of the NuGet configuration files.

```
dotnet nuget config get http_proxy 

Key 'http_proxy' not found.

```

### Set

Set the NuGet configuration settings. 

This command will set the value of a specified NuGet configuration setting.

Please note this command only manages settings in [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section).
For other settings not in config section, we have/will have other dedicated commands. E.g., for [trustedSigners section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#trustedsigners-section), we have [dotnet nuget trust](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-nuget-trust) command.

#### Arguments

- CONFIG_KEY

Specify the key of the settings that are to be set.

If the specified `CONFIG_KEY` is not a key in [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section), a message is displayed indicating the `CONFIG_KEY` could not be set.

- CONFIG_VALUE

Set the value of the CONFIG_KEY to CONFIG_VALUE.

#### Options

- --configfile <FILE>

The NuGet configuration file (nuget.config) to use. If specified, only the settings from this file will be used. If it's not specified, `%AppData%\NuGet\NuGet.Config` (Windows), or `~/.nuget/NuGet/NuGet.Config` or `~/.config/NuGet/NuGet.Config` (Mac/Linux) is used. See [On Mac/Linux, the user-level config file location varies by tooling.](https://learn.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior#on-maclinux-the-user-level-config-file-location-varies-by-tooling)

- -?|-h|--help

Prints out a description of how to use the command.

#### Examples

- Set the `signatureValidationMode` to true in the closest NuGet configuration file.

```
dotnet nuget config set signatureValidationMode require

```

- Set the `defaultPushSource` in the specified NuGet configuration file.

```
dotnet nuget config set defaultPushSource https://MyRepo/ES/api/v2/package --configfile C:\Users\username\AppData\Roaming\NuGet\NuGet.Config

```

### Unset

Remove the NuGet configuration settings. 

This command will remove the key-value pair from a specified NuGet configuration setting.

Please note this command only manages settings in [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section).
For other settings not in config section, we have/will have other commands. E.g. for [trustedSigners section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#trustedsigners-section), we have [dotnet nuget trust](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-nuget-trust) command.

#### Arguments

- CONFIG_KEY

Specify the key of the settings that are to be removed.

If the specified `CONFIG_KEY` is not a key in [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section), a message is displayed indicating the `CONFIG_KEY` could not be unset.

#### Options

- --configfile <FILE>

The NuGet configuration file (nuget.config) to use. If specified, only the settings from this file will be used. If it's not specified, `%AppData%\NuGet\NuGet.Config` (Windows), or `~/.nuget/NuGet/NuGet.Config` or `~/.config/NuGet/NuGet.Config` (Mac/Linux) is used. See [On Mac/Linux, the user-level config file location varies by tooling.](https://learn.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior#on-maclinux-the-user-level-config-file-location-varies-by-tooling)

- -?|-h|--help

Prints out a description of how to use the command.

#### Examples

- Unset the `signatureValidationMode` in the user-wide NuGet configuration file.

```
dotnet nuget config unset signatureValidationMode

```

- Unset the `defaultPushSource` in the specified NuGet configuration file.

```
dotnet nuget config unset defaultPushSource --configfile C:\Users\username\AppData\Roaming\NuGet\NuGet.Config

```

## Future Work
1. The `dotnet nuget config paths/get` is a community ask. We will discuss if adding this command into NuGet.exe CLI, in the future.

2. NuGet.exe [config command](https://learn.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-config) is implemented. 
But the behavior is confusing: the `set` command will set the property which appears last when loading(for all writable files), so it's not updating the closest NuGet configuration file, but the user-wide NuGet configuration file.(Related code: https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.Configuration/Settings/Settings.cs#L229)
We keep the behavior of `dotnet nuget config set` the same with above for now.
But we might need to change this behavior in the future. 
Considering this will be a breaking change, we will only consider doing it in main version change, if there are enough votes.

## Open Questions


## Considerations
1. Will this command help with diagnosing incorrect setting format?
<br />No. Incorrect NuGet settings should have separate error/warning message to tell the customer what's wrong in the setting file. If we have incorrect NuGet settings, all NuGet command, including `dotnet nuget config` command, should display the same error/warning message.
<br />E.g., if we have an invalid XML problem in one of the NuGet configuration file, running all NuGet command will get an error as following:
```
dotnet nuget list source
error: NuGet.Config is not valid XML. Path: 'C:\Users\username\Source\Repos\NuGet.Config'.
error:   The 'disabledPackageSources' start tag on line 19 position 4 does not match the end tag of 'configuration'. Line 20, position 3.
```

2. Shall we use `dotnet nuget config get all` or `dotnet nuget config get` to get all configuration settings?
<br />We will use `dotnet nuget config get all` to get all configuration settings, or else, we could not differentiate `dotnet nuget config get <CONFIG_KEY>` and `dotnet nuget config get <WORKING_DIRECTORY>`.


3. `dotnet nuget config get <CONFIG_KEY>` will get the value of the specific config key (which is aligned with NuGet config command). `dotnet nuget config get` will get all merged configuration settings(not XML format). Since many sections are not simple key-value pairs, we need to define the format of outputs when getting all merged configuration settings. We need to define formats for all kinds of config sections. Here is an example:
```
packageSources:
  clear
  add key="source1" value="https://test/source1/v3/index.json"
  add key="source2" value="https://test/source2/v3/index.json"

packageSourceMapping:
  clear
  packageSource key="source1"  pattern="microsoft.*","nuget.*"
  packageSource key="source2"  pattern="system.*"

packageRestore:
  add key="enabled" value="False"
  add key="automatic" value="False"
```

4. Shall we use `dotnet nuget config path` or `dotnet nuget config paths` to get all configuration file paths?
<br />Since it returns multiple paths, we will use `dotnet nuget config paths`.

5. To show configuration files locations, is it better to use `--verbosity` option or some option named like `--show-path`? (git command is using `--show-origin` for similar purpose)
<br />`--show-path` is better. Verbosity is something to apply to logging, not so much the output of a command like this. Also in most cases of the .NET CLI, the verbosity doesn't do anything unless it's a command that ends up running MSBuild.


6. `WORKING_DIRECTORY` is changed from an option to an argument. So we have `dotnet nuget config paths <WORKING_DIRECTORY>` and `dotnet nuget config get <ALL|CONFIG_KEY> <WORKING_DIRECTORY>`. Is it okey if we have two arguments in the second command? And if it's okey, only the second argument could be optional, right? 
<br /> Confirmed with .NET sdk folks. There is no problem of having two arguments in the command and the second argument could be optional.