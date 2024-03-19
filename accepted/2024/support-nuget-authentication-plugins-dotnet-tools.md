# ***Support for NuGet authentication plugins deployed via .NET tools***

- Author Name: <https://github.com/kartheekp-ms>
- GitHub Issue: <https://github.com/NuGet/Home/issues/12567>

## Summary

Currently, NuGet utilizes a [cross-platform plugin model](https://learn.microsoft.com/nuget/reference/extensibility/nuget-cross-platform-plugins#supported-operations) which is primarily used for [authentication against private feeds](https://learn.microsoft.com/nuget/reference/extensibility/nuget-cross-platform-authentication-plugin).
It also supports the [package download](https://github.com/NuGet/Home/wiki/NuGet-Package-Download-Plugin) operation.

To accommodate all scenarios involving NuGet client tools, plugin authors will need to create plugins for both `.NET Framework` and `.NET Core`.
The following details the combinations of client and framework for these plugins.

| Client tool | Framework |
|-------------|-----------|
| Visual Studio | .NET Framework |
| dotnet.exe | .NET Core |
| NuGet.exe | .NET Framework |
| MSBuild.exe | .NET Framework |
| NuGet.exe on Mono | .NET Framework |

Currently, NuGet maintains `netfx` folder for plugins that will be invoked in `.NET Framework` code paths, `netcore` folder for plugins that will be invoked in `.NET Core` code paths.
The proposal is to add a new `any` folder to store NuGet plugins that are deployed as [tool Path](https://learn.microsoft.com/dotnet/core/tools/global-tools-how-to-use#use-the-tool-as-a-global-tool-installed-in-a-custom-location) .NET tools.
Upon installation, .NET tools are organized in a way that helps NuGet quickly determine which file in the package to run at runtime.

| Framework | Root discovery location |
|-----------|------------------------|
| .NET Core | %UserProfile%/.nuget/plugins/netcore |
| .NET Framework | %UserProfile%/.nuget/plugins/netfx |
| .NET Framework & .NET Core [current proposal] |  %UserProfile%/.nuget/plugins/any |

## Motivation

Currently, the NuGet plugin architecture requires support and deployment of multiple versions.
For `.NET Framework`, NuGet searches for files ending in `*.exe`, while for `.NET Core`, it searches for files ending in `*.dll`.
These files are typically stored in two distinct folders such as `netfx` and `netcore` under the NuGet plugins base path.
This design decision is due to the different entry points for `.NET Core` and `.NET Framework`, as explained in the [original design](https://github.com/NuGet/Home/wiki/NuGet-cross-plat-authentication-plugin#plugin-installation-and-discovery).
`.NET Core` uses files with a `dll` extension, while `.NET Framework` uses files with an `exe` extension as entry points.
This distinction is further highlighted by the two plugin path environment variables, `NUGET_NETFX_PLUGIN_PATHS` and `NUGET_NETCORE_PLUGIN_PATHS`, which must be set for each framework type.

Another motivating factor for this work is the current story for installing these credential providers, which is not ideal.
For instance, let's consider the two cross-platform authentication plugins that I am aware of while writing this specification:

1. **Azure Artifacts Credential Provider** - The [setup](https://github.com/microsoft/artifacts-credprovider/tree/master?tab=readme-ov-file#setup) instructions vary based on the platform.
2. **AWS CodeArtifact Credential Provider** - The AWS team has developed a [.NET tool](https://docs.aws.amazon.com/codeartifact/latest/ug/nuget-cli.html#nuget-configure-cli) to facilitate authentication with their private NuGet feeds.
In their current implementation, they've added a subcommand, `codeartifact-creds install`, which copies the credential provider to the NuGet plugins folder.
The log below shows all possible subcommands.
However, plugin authors could leverage the .NET SDK to allow their customers to install, uninstall, or update the NuGet plugins more efficiently.

```log
~\.nuget\plugins\any
❯ .\dotnet-codeartifact-creds.exe
Required command was not provided.

Usage:
  dotnet-codeartifact-creds [options] [command]

Options:
  --version         Show version information
  -?, -h, --help    Show help and usage information

Commands:
  install      Installs the AWS CodeArtifact NuGet credential provider into the NuGet plugins folder.
  configure    Sets or Unsets a configuration
  uninstall    Uninstalls the AWS CodeArtifact NuGet credential provider from the NuGet plugins folder.
```

## Explanation

### Functional explanation

A deployment solution for .NET is the [.NET tools](https://learn.microsoft.com/dotnet/core/tools).
These tools provide a seamless installation and management experience for NuGet packages in the .NET ecosystem.
The use of .NET tools as a deployment mechanism has been a recurring request from users and internal partners who need to authenticate with private repositories.
Currently, this solution works for the Windows .NET Framework.
However, the goal is to extend this support cross-platform for all supported .NET runtimes.

The reasons why `.NET tools` were chosen as the deployment mechanism are mentioned below:

- NuGet plugins are console applications. A `.NET tool` is a special NuGet package that contains a console application, which presents a natural fit.

- The .NET SDK has already simplified the process for customers to develop a tool.
All the plugin authors have to do is set the following properties and execute `dotnet pack` to generate the package:

```xml
<PackAsTool>true</PackAsTool>
<ToolCommandName>botsay</ToolCommandName>
```

- Leveraging `.NET Tools` provides a standard experience for customers to share console applications, with NuGet plugins being one such use case.
If there is an existing mechanism that works well, is familiar to customers, and fits our use case, I question the benefit of developing a new layout specifically for NuGet plugins.

- Another advantage of this established `.NET tools` approach is that plugin authors won't have to maintain separate code paths for .NET Framework and .NET Core runtimes.
All these complexities are handled by the .NET SDK by providing a native shim upon the installation of the .NET tool.

Currently, at least to my understanding, the generated `.nupkg` will include a file named `DotnetToolSettings.xml` with additional metadata such as the command name, entry point, and runner.

For example, the [dotnetsay tool](https://nuget.info/packages/dotnetsay/2.1.7) includes the following content:

```xml
<?xml version="1.0" encoding="utf-8"?>
<DotNetCliTool Version="1">
  <Commands>
    <Command Name="dotnetsay" EntryPoint="dotnetsay.dll" Runner="dotnet" />
  </Commands>
</DotNetCliTool>
```

By implementing this specification, we offer plugin authors the option to use .NET tools for plugin deployment.
On the consumer side, these plugins will be installed as a `tool path` global tool. This eliminates the need to maintain separate versions for `.NET Framework` and `.NET Core`.
It also simplifies the installation process by removing the necessity for plugin authors to create subcommands like `codeartifact-creds install/uninstall`.

The proposed workflow for repositories that access private NuGet feeds, such as Azure DevOps, would be:

1. Ensure that the .NET SDK is installed.
1. Execute the command `dotnet nuget plugin install Microsoft.CredentialProvider`.
1. Run `dotnet restore --interactive` with a private endpoint. It should 'just work', meaning the credential providers installed in step 2 are used during credential acquisition and are used to authenticate against private endpoints.

The `dotnet nuget plugin install` command installs the NuGet plugin as `tool path` global .NET tool in the default NuGet plugins location, as mentioned below.

| Operating System | Installation Path |
| ---------------- | ----------------- |
| Windows | %UserProfile%/.nuget/plugins/any |
| Linux/Mac | $HOME/.nuget/plugins/any |

I proposed using a `tool path` .NET tool because, by default, .NET tools are considered [global](https://learn.microsoft.com/dotnet/core/tools/global-tools).
This means they are installed in a default directory, such as `%UserProfile%/.dotnet/tools` on Windows, which is then added to the PATH environment variable.

- Global tools can be invoked from any directory on the machine without specifying their location.
- One version of a tool is used for all directories on the machine.
However, NuGet cannot easily determine which tool is a NuGet plugin.
On the other hand, the `tool path` option allows us to install .NET tools as global tools, but with the binaries located in a specified location.
This makes it easier to identify and invoke the appropriate tool for NuGet operations.
- The binaries are installed in a location that we specify while installing the tool.
- We can invoke the tool from the installation directory by providing the directory with the command name or by adding the directory to the PATH environment variable.
- One version of a tool is used for all directories on the machine.
The `tool path` option aligns well with the NuGet plugins architecture design, and hence, it is the recommended approach for installing and executing NuGet plugins.

We should consider adding `dotnet nuget plugin install/uninstall/update` commands to the .NET SDK as wrappers for the `dotnet tool install/uninstall/update` commands.
This would simplify the installation process by eliminating the need for users to specify the NuGet plugin path, making the process more user-friendly and platform-independent.

We should also introduce a `dotnet nuget credentialprovider search` command.
To enable this, plugin authors would simply need to add `<PackageType>CredentialProvider</PackageType>` to their `.csproj` file.

Special thanks to [Nikolche Kolev](https://github.com/nkolev92) for suggesting a verification method.
This involved creating a .NET tool and then updating the `PackageTypes` manually in the `.nuspec` file to inlclude both `DotnetTool` and `CredentialProvider`.
This file is part of the nupkg generated by executing the `dotnet pack` command.
The installation of this tool with multiple package types was successful with the .NET 8 SDK. However, it failed with the .NET 7 SDK due to the `.nuspec` in the nupkg containing multiple package types.

Given that this issue has been resolved in the .NET 8 SDK, and considering our plans to add `dotnet nuget plugin install/uninstall/update/search` commands and support for NuGet plugins deployed via .NET tools in the latest version, I believe we are on the right track.

The `dotnet nuget credentialprovider search` command would allow customers to search for available Credential Providers that are published as .NET tools. However, I believe we need a separate specification for `dotnet nuget plugin install/uninstall/update/search` commands to fully understand all the options and the functional/technical details.

The `dotnet workload` command is separate and has its own set of sub-commands, including `install`, `uninstall`, and `list`.
These sub-commands are wrappers for the corresponding `dotnet tool` sub-commands.
Workloads are installed in a different location than .NET tools, which makes it easier for them to be discovered at runtime, addressing a problem that NuGet also faces.
However, NuGet plugins and .NET tools share the similarity of being console applications.

This approach is similar to the alternative design that [Andy Zivkovic](https://github.com/zivkan) kindly proposed in [[Feature]: Make NuGet credential providers installable via the dotnet cli](https://github.com/NuGet/Home/issues/11325).
The recommendation was developing a command like `dotnet nuget credential-provider install Microsoft.Azure.Artifacts.CredentialProvider`.

### Security considerations

The [.NET SDK docs](https://learn.microsoft.com/dotnet/core/tools/global-tools#check-the-author-and-statistics) clearly state, `.NET tools run in full trust. Don't install a .NET tool unless you trust the author`.
This is an important consideration for plugin customers when installing NuGet plugins via .NET Tools in the future.

### Technical explanation

Currently, plugins are discovered through a convention-based directory structure, such as the `%userprofile%/.nuget/plugins` folder on Windows.
For CI/CD scenarios, and for power users, environment variables can be used to override this behavior.
Note that only absolute paths are allowed when using these environment variables.

- `NUGET_NETFX_PLUGIN_PATHS`: Defines the plugins used by the .NET Framework-based tooling (NuGet.exe/MSBuild.exe/Visual Studio). This takes precedence over `NUGET_PLUGIN_PATHS`.
- `NUGET_NETCORE_PLUGIN_PATHS`: Defines the plugins used by the .NET Core-based tooling (dotnet.exe).
This takes precedence over `NUGET_PLUGIN_PATHS`.
- `NUGET_PLUGIN_PATHS`: Defines the plugins used for the NuGet process, with priority preserved.
If this environment variable is set, it overrides the convention-based discovery.
It is ignored if either of the framework-specific variables is specified.

I propose the addition of a `NUGET_DOTNET_TOOLS_PLUGIN_PATHS` environment variable.
This variable will define the plugins, installed as .NET tools, to be used by both .NET Framework and .NET Core tooling.
It will take precedence over `NUGET_PLUGIN_PATHS`.

The plugins specified in the `NUGET_DOTNET_TOOLS_PLUGIN_PATHS` environment variable will be used regardless of whether the `NUGET_NETFX_PLUGIN_PATHS` or `NUGET_NETCORE_PLUGIN_PATHS` environment variables are set.
The primary reason for this is that plugins installed as .NET tools can be executed in both .NET Framework and .NET Core tooling.

If customers prefer to install NuGet plugins as a global tool instead of a tool-path tool, they can set the `NUGET_DOTNET_TOOLS_PLUGIN_PATHS` environment variable.
This variable should point to the location of the .NET Tool executable that the NuGet Client tooling can invoke when needed.

If none of the above environment variables are set, NuGet will default to the conventional method of discovering plugins from predefined directories.
In the [current implementation](https://github.com/NuGet/NuGet.Client/blob/8b658e2eee6391936887b9fd1b39f7918d16a9cb/src/NuGet.Core/NuGet.Protocol/Plugins/PluginDiscoveryUtility.cs#L65-L77), the NuGet code looks for plugin files in the `netfx` directory when running on .NET Framework, and in the `netcore` directory when running on .NET Core. This implementation should be updated to include the new `any` directory.
This directory should be added alongside `netcore` in the .NET code paths and `netfx` in the .NET Framework code paths, to ensure backward compatibility.

In the [current implementation](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.Protocol/Plugins/PluginDiscoveryUtility.cs#L79-L101), the NuGet code searches for plugin files in a plugin-specific subdirectory.
For example, in the case of the Azure Artifacts Credential Provider, the code looks for `*.exe` or `*.dll` files under the "CredentialProvider.Microsoft" directory.
However, when .NET tools are installed in the `any` folder, executable files (like `.exe` files on Windows or files with the executable bit set on Linux & Mac) are placed directly in the `any` directory.
The remaining files are stored in a `.store` folder. This arrangement eliminates the need to search in subdirectories.

NuGet will discover plugins in the new directory by enumerating files, without recursing into child directories.
This is compatible with the layout that `dotnet tool install` uses, where packages are extracted to a `.store` subdirectory, and shims are put in the tool directory, one file per executable command.
All files could be considered executables that NuGet will run.
Alternatively, on Windows, NuGet could filter `*.exe`.
On Mac and Linux, where apps typically don't have extensions, to do functionally equivalent filtering NuGet should check each file's permissions and ensure the execute bit is enabled (although technically we'd probably also need to check the file owner and group, to know if we should check the user, group, or other permissions).

The new folder structure for NuGet plugins on the Windows platform is as follows:

```folder
├───any
│   │   dotnetsay.exe
│   │
│   └───.store│
├───netcore
├   ├───AWS.CodeArtifact.NuGetCredentialProvider
├   │
│   └───CredentialProvider.Microsoft
└───netfx
├   ├───AWS.CodeArtifact.NuGetCredentialProvider
├   │
├   └───CredentialProvider.Microsoft
└
```

The new folder structure for NuGet plugins on the Linux platforms is as follows:

```log
{user}:~/.nuget/plugins$ dir
netcore  any

{user}:~/.nuget/plugins$ cd any/
{user}:~/.nuget/plugins/any$ dir
botsay  dotnetsay

{user}:~/.nuget/plugins/any$ ls -la
total 164
drwxr-xr-x 3 {user}  4096 Feb 10 08:21 .
drwxr-xr-x 4 {user}  4096 Feb 10 08:20 ..
drwxr-xr-x 5 {user}  4096 Feb 10 08:21 .store
-rwxr-xr-x 1 {user} 75632 Feb 10 08:21 botsay
-rwxr-xr-x 1 {user} 75632 Feb 10 08:20 dotnetsay
```

## Roadmap

In terms of the implementation roadmap, I propose the following stages:

1. Initially, plugin authors will publish NuGet plugins as .NET Tools. Consumers will install NuGet plugins using `dotnet tool` sub-commands.
They will specify the plugin's path based on their operating system. We will make the necessary code changes on the NuGet side to enable running the plugins installed as `.NET tools`.

2. Subsequently, we will introduce a `dotnet nuget plugin` subcommand. This will allow users to `install, update, uninstall, and search` for plugins.
However, we will still rely on the `dotnet tool` command under the hood, as mentioned above.
Please note that these command names are subject to change based on feedback to the specification we are going to create in the near future.

## Drawbacks

- The ideal workflow for repositories accessing private NuGet feeds, such as Azure DevOps, is to easily search for NuGet plugins and install them as global tool.
However, the current proposal suggests installing the plugin as a tool-path .NET tool.
As mentioned in the technical explanation section, customers can opt to install NuGet plugins as a global tool instead of a tool-path tool.
To do this, they need to set the `NUGET_DOTNET_TOOLS_PLUGIN_PATHS` environment variable.
This variable should point to the location of the .NET Tool executable, which the NuGet Client tooling can invoke when needed.

- There is some risk of the `dotnet tool` introducing breaking changes that could negatively impact NuGet.
If the `dotnet tool` started writing non-executable files into the directory, it would affect how NuGet discovers and runs plugins at runtime.

- Currently, NuGet Client plugin code will only support plugins developed in .NET. See the `Future Possibilities` section for more details.

## Rationale and alternatives

### Specify the the authentication plugin in NuGet.Config file

To simplify the authentication process with private NuGet feeds, customers can specify the authentication plugins installed as .NET Tools in the `packagesourceCredentials` section of the NuGet.Config file.

Here is an example of how to configure the NuGet.Config file:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="ExamplePrivateRepo" value="https://example.com/nuget" />
    <!-- Add other package sources as needed -->
  </packageSources>

  <packageSourceCredentials>
    <ExamplePrivateRepo>
      <add key="ToolName" value="Microsoft.CredentialProvider" />
      <!-- The value here is the .NET tool name installed globally or in a specific tool-path -->
    </ExamplePrivateRepo>
    <!-- Add credentials for other package sources as needed -->
  </packageSourceCredentials>
</configuration>
```

**Advantages:**

- This approach explicitly configures the intent to use the .NET Tool as a plugin for authentication in the NuGet.Config file itself.
- Customers can install the plugins as global .NET Tools.

**Disadvantages:**

- Configuring the setting per feed can be cumbersome if multiple private feeds can use the same .NET tool for authentication.

An alternative approach to address this disadvantage is to declare the plugins explicitly outside of the package source sections.
This approach allows customers to specify the dependency only once, without configuring it per private feed as discussed above.

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <DotNetToolPlugins>
    <Authentication>
      <plugin id="CredentialProvider.Microsoft" />
      <plugin id="CredentialProvider.GitHub" />
      <!-- Allows specifying multiple authentication plugins with additional details -->
    </Authentication>
  <!-- This format provides flexibility for future plugin types and detailed configurations -->
  </DotNetToolPlugins>
</configuration>
```

However, the NuGet Client plugins functionality is a global setting.
This means that the plugins are discovered based on the platform and target framework, as discussed earlier, and there is currently no way to configure the dependent plugins via NuGet settings per repository.
It could be a future possibility to provide users with an option to manage their plugins per repository instead of loading all the available plugins.
However, given the limited number of plugin implementations currently available, this is not a problem that needs to be solved at this point in time, in my understanding.

## Prior Art

- The AWS team has developed a [.NET tool](https://docs.aws.amazon.com/codeartifact/latest/ug/nuget-cli.html#nuget-configure-cli) to simplify authentication with their private NuGet feeds.
In their current implementation, they've added a subcommand, `codeartifact-creds install`.
This command copies the credential provider to the NuGet plugins folder.
They also provide an `uninstall` subcommand to remove the files from the NuGet plugin folders.
However, due to limitations in the NuGet Client tooling, they've had to maintain plugins for both .NET Framework and .NET Core tooling. Additionally, they've had to provide commands to install and uninstall the NuGet plugins.

- The `dotnet workload` command is separate and has its own set of sub-commands, including `install`, `uninstall`, and `list`.
These sub-commands are wrappers for the corresponding `dotnet tool` sub-commands.
Workloads are installed in a different location than .NET tools, which makes it easier for them to be discovered at runtime, addressing a problem that NuGet also faces.
However, NuGet plugins and .NET tools share the similarity of being console applications.
This prior art will be helpful for us as we consider the implementation of the `dotnet nuget plugin install/uninstall/update/search` commands.

## Unresolved Questions

- The issue regarding workload installation on Mac and Linux, as well as NuGet credential providers, is discussed in [GitHub Issue #35912](https://github.com/dotnet/sdk/issues/35912#issuecomment-1759774310).
When executing .NET SDK workload commands under sudo, the HOME directory path is modified, preventing the .NET SDK from writing files owned by root to the user's regular HOME directory.
This alteration can cause problems when running standard commands without sudo and also interferes with NuGet credential providers.
We have proposed a [workaround](https://github.com/dotnet/sdk/issues/35912#issuecomment-2004522180) for this issue.

## Future Possibilities

### Managing NuGet plugins per repository using .NET Local Tools

- A potential future possibility is mentioned under the `Specify the authentication plugin in NuGet.Config file` section.
In addition to that, if we ever plan to provide users with an option to manage their plugins per repository instead of loading all the available plugins, we can consider using [.NET Local tools](https://learn.microsoft.com/dotnet/core/tools/local-tools-how-to-use).
- The advantage of local tools is that the .NET CLI uses manifest files to keep track of tools that are installed locally to a directory.
When the manifest file is saved in the root directory of a source code repository, a contributor can clone the repository and invoke a single .NET CLI command such as [`dotnet tool restore`](https://learn.microsoft.com/dotnet/core/tools/dotnet-tool-restore) to install all of the tools listed in the manifest file.
- Having NuGet plugins under the repository folder eliminates the need for NuGet to load plugins from the user profile.

### Support for non-.NET NuGet plugins

- The NuGet Client plugin code needs to be updated to utilize a standard RPC mechanism, such as StreamJsonRpc, in order to support NuGet plugins developed in languages other than .NET.
Currently, the NuGet Client plugin code only supports plugins developed in .NET.
The IPC (Inter-Process Communication) used by NuGet is custom-made, and it would be beneficial for plugin implementers if it were based on industry standards.
This would allow plugin authors to reuse existing implementations for other languages.
While there is no technical barrier preventing the implementation of a client in a non-.NET language, there is an additional cost associated with reimplementing the plugin protocol.
This cost serves as a deterrent for writing non-.NET plugins.
