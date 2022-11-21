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

#### Commands

- Path

List all the paths of NuGet configuration files that will be applied, when invoking NuGet command from the current working directory path.

The listed NuGet configuration files are in priority order. So the order of loading those configurations is reversed, that is, loading order is from the bottom to the top. So the configuration on the top will apply.
You may refer to [How settings are applied](https://learn.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior#how-settings-are-applied) for more details. 


#### Options

- -w|--working-dir <WORKING_DIRECTORY>

Run this command as if working directory is set to the specified directory.

If the specified `--working-dir` doesn't exist, an error is displayed indicating the `--working-dir` doesn't exist.

> [!Note]
> If `--working-dir` (or its parent directories) is not accessible, the command will ignore any NuGet configuration files under those directories without any warning/error. This is aligned with other NuGet commands.

- -?|-h|--help

Prints out a description of how to use the command.

#### Examples

- List all the NuGet configuration file that will be applied, when invoking NuGet command in the current directory.

```
dotnet nuget config path 

C:\Test\Repos\Solution\NuGet.Config
C:\Test\Repos\NuGet.Config
C:\Test\NuGet.Config
C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.FallbackLocation.config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.Offline.config
```

- List all the paths of NuGet configuration files that will be applied, when invoking NuGet command in the specific directory.

```
dotnet nuget config path  --working-dir C:\Test\Repos

C:\Test\Repos\NuGet.Config
C:\Test\NuGet.Config
C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.FallbackLocation.config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.Offline.config
```

- List all the NuGet configuration file that will be applied, but passing a non-exsiting `--working-dir`.

```
dotnet nuget config path  --working-dir C:\Test\NonExistingRepos

Error: The path "C:\Test\NonExistingRepos" doesn't exist.
```

- List all the NuGet configuration file that will be applied, but passing an inaccessible `--working-dir`: C:\Test\AccessibleRepos\NotAccessibleSolution. 

The configuration file under C:\Test\AccessibleRepos\NotAccessibleSolution\NuGet.Config will be ignored without any warning or error.

```
dotnet nuget config list  --working-dir C:\Test\AccessibleRepos\NotAccessibleSolution

C:\Test\AccessibleRepos\NuGet.Config
C:\Test\NuGet.Config
C:\Users\username\AppData\Roaming\NuGet\NuGet.Config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.FallbackLocation.config
C:\Program Files (x86)\NuGet\Config\Microsoft.VisualStudio.Offline.config
```

#### Commands
- Get

Get the NuGet configuration settings that will be applied. 

#### Arguments

- CONFIG_KEY

Get the effective value of the specified configuration settings of the [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section). Please note this is the result of che 

If CONFIG_KEY is not specified, this command will get all merged NuGet configuration settings from multiple NuGet configuration files that will be applied, when invoking NuGet command from the current working directory path. 

> [!Note]
> The CONFIG_KEY could only be one of the valid key in config section. 
For other sections, like package source section, we have/will have specific command [dotnet nuget list source](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-nuget-list-source).

#### Options

- -w|--working-dir <WORKING_DIRECTORY>

Run this command as if working directory is set to the specified directory.

If the specified `--working-dir` doesn't exist, an error is displayed indicating the `--working-dir` doesn't exist.

> [!Note]
> If `--working-dir` (or its parent directories) is not accessible, the command will ignore any NuGet configuration files under those directories without any warning/error. This is aligned with other NuGet commands.

- -?|-h|--help

Prints out a description of how to use the command.

- -v|--verbosity <LEVEL>

Sets the verbosity level of the command. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic]. The default is minimal. 

When the verbosity level is detailed or diagnostic, the source(NuGet configuration file path) will be show besides the configuration settings.

#### Examples

- Get all the NuGet configuration settings that will be applied, when invoking NuGet command in the current directory.

```
dotnet nuget config get

<configuration>
  <packageSources>
    <add key="source1" value="https://test/source1/v3/index.json" />
    <add key="source2" value="https://test/source2/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    <clear />
    <packageSource key = "source1">
      <package pattern="microsoft.*" />
      <package pattern="nuget.*" />
    </packageSource>
    <packageSource key = "source2">
      <package pattern="system.*" />
    </packageSource>
  </packageSourceMapping>
  <packageRestore>
    <add key="enabled" value="False" />
    <add key="automatic" value="False" />
  </packageRestore>
</configuration>

```
- Get all the NuGet configuration settings that will be applied, when invoking NuGet command in the specific directory.

```
dotnet nuget config get --working-dir C:\Test\Repos

<configuration>
  <packageSources>
    <add key="source1" value="https://test/source1/v3/index.json" />
    <add key="source2" value="https://test/source2/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    <clear />
    <packageSource key = "source1">
      <package pattern="microsoft.*" />
      <package pattern="nuget.*" />
    </packageSource>
    <packageSource key = "source2">
      <package pattern="system.*" />
    </packageSource>
  </packageSourceMapping>
  <packageRestore>
    <add key="enabled" value="False" />
    <add key="automatic" value="False" />
  </packageRestore>
</configuration>

```

- Get all the NuGet configuration settings that will be applied, when invoking NuGet command in the current directory. Show the source(nuget configuration file path) of each configuration settings/child items.

```
dotnet nuget config get -v d

<configuration>
  <packageSources>
    <add key="source1" value="https://test/source1/v3/index.json" />   <!-- file: C:\Test\Repos\Solution\NuGet.Config -->
    <add key="source2" value="https://test/source2/v3/index.json" />   <!-- file: C:\Test\Repos\NuGet.Config -->
  </packageSources>
  <packageSourceMapping>
    <clear />                                 <!-- file: C:\Users\username\AppData\Roaming\NuGet\NuGet.Config -->
    <packageSource key = "source1">           <!-- file: C:\Test\Repos\Solution\NuGet.Config -->
      <package pattern="microsoft.*" />
      <package pattern="nuget.*" />
    </packageSource>
    <packageSource key = "source2">           <!-- file: C:\Test\Repos\NuGet.Config -->
      <package pattern="system.*" />
    </packageSource>
  </packageSourceMapping>
</configuration>

```

- Get `http_proxy` from config section, when invoking NuGet command in the current directory.

```
dotnet nuget config get http_proxy 

http://company-squid:3128@contoso.com"

```

- Get `http_proxy` from config section, when `http_proxy` is not set in any of the NuGet configuration files.

```
dotnet nuget config get http_proxy 

Key 'http_proxy' not found.

```

#### Commands

- Set

Set the NuGet configuration settings. 

This command will set the value of a specified NuGet configuration setting.

Please note this command only manages settings in [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section).
For other settings not in config section, we have/will have other dedicated commands. E.g. for [trustedSigners section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#trustedsigners-section), we have [dotnet nuget trust](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-nuget-trust) command.

#### Arguments

- CONFIG_KEY

Specify the key of the settings that are to be set.

If the specified `CONFIG_KEY` is not a key in [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section), a message is displayed indicating the `CONFIG_KEY` could not be set.

- CONFIG_VALUE

Set the value of the CONFIG_KEY to CONFIG_VALUE.

#### Options

- --config-file

Specify the config file path to add the setting key-value pair. If it's not specified, `%AppData%\NuGet\NuGet.Config` (Windows), or `~/.nuget/NuGet/NuGet.Config` or `~/.config/NuGet/NuGet.Config` (Mac/Linux) is used. See [On Mac/Linux, the user-level config file location varies by tooling.](https://learn.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior#on-maclinux-the-user-level-config-file-location-varies-by-tooling)

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

#### Commands

- Unset

Remove the NuGet configuration settings. 

This command will remove the key-value pair from a specified NuGet configuration setting.

Please note this command only manages settings in [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section).
For other settings not in config section, we have/will have other commands. E.g. for [trustedSigners section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#trustedsigners-section), we have [dotnet nuget trust](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-nuget-trust) command.

#### Arguments

- CONFIG_KEY

Specify the key of the settings that are to be removed.

If the specified `CONFIG_KEY` is not a key in [config section](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#config-section), a message is displayed indicating the `CONFIG_KEY` could not be unset.

#### Options

- --config-file

Specify the config file path to remove the setting key-value pair. If it's not specified, `%AppData%\NuGet\NuGet.Config` (Windows), or `~/.nuget/NuGet/NuGet.Config` or `~/.config/NuGet/NuGet.Config` (Mac/Linux) is used. See [On Mac/Linux, the user-level config file location varies by tooling.](https://learn.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior#on-maclinux-the-user-level-config-file-location-varies-by-tooling)

- -?|-h|--help

Prints out a description of how to use the command.

#### Examples

- Unset the `signatureValidationMode` in the user-wide NuGet configuration file.

```
dotnet nuget config unset signatureValidationMode

```

- Unset the `defaultPushSource` in the specified NuGet configuration file.

```
dotnet nuget config unset defaultPushSource --config-file C:\Users\username\AppData\Roaming\NuGet\NuGet.Config

```

## Future Work
1. The `dotnet nuget config path/get` is a community ask. We will discuss if adding this command into NuGet.exe CLI, in the future.

2. NuGet.exe [config command](https://learn.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-config) is implemented. 
But the behavior is confusing: the `set` command will set the property which appears last when loading(for all writable files), so it's not updating the closest NuGet configuration file, but the user-wide NuGet configuration file.(Related code: https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.Configuration/Settings/Settings.cs#L229)
We keep the behavior of `dotnet nuget config set` the same with above for now.
But we might need to change this behavior in the future. 
Considering this will be a breaking change, we will only consider doing it in main version change, if there are enough votes.

## Open Questions
1. To show configuration files locations, is it better to use `--verbosity` option or some option named like `--show-path`? (git command is using `--show-origin` for similar purpose)

2. `dotnet nuget config get <CONFIG_KEY>` will get the value of the specifc config key (which is aligned with NuGet config command). But
`dotnet nuget config get` will get all merged configuration settings in xml format, since many sections are not simple key-value pairs.
 Do we need to have another verb for getting all merged configuration settings? 

3. `dotnet nuget config get -v d` will display source of each configuration setting key, in a format of comment in xml file. So that people can still redirect the output into a file without breaking any syntax. Does that sound good to you?

3. `--working-dir` is changed from an argument into an option. Because we could not differentiate `dotnet nuget config get <WORKING_DIRECTORY>` and `dotnet nuget config get <CONFIG_KEY>`. Any better ideas?

## Considerations
1. Will this command help with diagnosing incorrect setting format?
<br />No. Incorrect NuGet settings should have seperate error/warning message to tell the customer what's wrong in the setting file. If we have incorrect NuGet settings, all NuGet command, including `dotnet nuget config` command, should display the same error/warning message.
<br />E.g. if we have an invalid XML problem in one of the NuGet configuration file, running all NuGet command will get an error as following:
```
dotnet nuget list source
error: NuGet.Config is not valid XML. Path: 'C:\Users\username\Source\Repos\NuGet.Config'.
error:   The 'disabledPackageSources' start tag on line 19 position 4 does not match the end tag of 'configuration'. Line 20, position 3.
```
