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

By implementing this specification, we offer plugin authors the option to use .NET tools for plugin deployment.
They can install these as a `tool path` global tool. This eliminates the need to maintain separate versions for `.NET Framework` and `.NET Core`.
It also simplifies the installation process by removing the necessity for plugin authors to create subcommands like `codeartifact-creds install/uninstall`.

The proposed workflow for repositories that access private NuGet feeds, such as Azure DevOps, would be:

1. Ensure that the dotnet CLI tools are installed.
2. Execute the command `dotnet tool install Microsoft.CredentialProviders --tool-path "%UserProfile%/.nuget/plugins/tools"` on the Windows platform.
For Linux and Mac, run `dotnet tool install Microsoft.CredentialProviders --tool-path $HOME/.nuget/plugins`.
3. Run `dotnet restore --interactive` with a private endpoint. It should 'just work', meaning the credential providers installed in step 2 are used during credential acquisition and are used to authenticate against private endpoints.

The setup instructions mentioned in step 2 are platform-specific, but they are simpler compared to the current instructions for installing credential providers.

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
The `tool path` option aligns well with the design of NuGet plugins architecture, making it the recommended approach for installing and executing NuGet plugins.

### Security considerations

The [.NET SDK docs](https://learn.microsoft.com/dotnet/core/tools/global-tools#check-the-author-and-statistics) clearly state, `.NET tools run in full trust. Don't install a .NET tool unless you trust the author`.
This is an important consideration for plugin customers when installing NuGet plugins via .NET Tools in the future.

### Technical explanation

Currently, plugins are discovered through a convention-based directory structure, such as the `%userprofile%/.nuget/plugins` folder on Windows.
CI/CD scenarios and power users can use environment variables to override this behavior.
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

## Drawbacks

- The ideal workflow for repositories accessing private NuGet feeds, such as Azure DevOps, is to easily search for NuGet plugins and install them without needing to know the destination location.
However, the current proposal suggests installing the plugin as a tool-path .NET tool.
As mentioned in the technical explanation section, customers can opt to install NuGet plugins as a global tool instead of a tool-path tool.
To do this, they need to set the `NUGET_DOTNET_TOOLS_PLUGIN_PATHS` environment variable.
This variable should point to the location of the .NET Tool executable, which the NuGet Client tooling can invoke when needed.

- There is some risk of the `dotnet tool` introducing breaking changes that could negatively impact NuGet.
If the `dotnet tool` started writing non-executable files into the directory, it would affect how NuGet discovers and runs plugins at runtime.

## Rationale and alternatives

### NuGet commands to install credential providers

[Andy Zivkovic](https://github.com/zivkan) kindly proposed an alternative design in [[Feature]: Make NuGet credential providers installable via the dotnet cli](https://github.com/NuGet/Home/issues/11325).
The recommendation was developing a command like `dotnet nuget credential-provider install Microsoft.Azure.Artifacts.CredentialProvider`.
Here are the advantages and disadvantages of this approach:

**Advantages:**

- Improved discoverability, as `dotnet tool search` will list packages that are not NuGet plugins.
- Doesn't require customers to memorize or lookup the NuGet plugin directory location in order to pass it to all `dotnet tool` commands via the `--tool-path` argument, for install, uninstall, and update.

**Disadvantages:**

- The NuGet Client team would be required to maintain all the .NET Commands for installing, updating, and uninstalling the plugins. However, these tasks are already handled by the existing commands in the .NET SDK.
- This approach would still require the extraction of plugins into either a `netfx` or a `netcore` folder.
As a result, package authors would need to maintain plugins for both of these target frameworks.
However, NuGet plugins are executables, and the .NET SDK provides a convenient way for authors to publish an executable that can run on all platforms via .NET Tools.
This eliminates the need for a framework-specific approach.

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
- Customers can install the plugins as global .NET Tools, eliminating the need to specify a custom location based on the platform.

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

The AWS team has developed a [.NET tool](https://docs.aws.amazon.com/codeartifact/latest/ug/nuget-cli.html#nuget-configure-cli) to simplify authentication with their private NuGet feeds.
In their current implementation, they've added a subcommand, `codeartifact-creds install`.
This command copies the credential provider to the NuGet plugins folder.
They also provide an `uninstall` subcommand to remove the files from the NuGet plugin folders.
However, due to limitations in the NuGet Client tooling, they've had to maintain plugins for both .NET Framework and .NET Core tooling. Additionally, they've had to provide commands to install and uninstall the NuGet plugins.

## Unresolved Questions

- None as of now.

## Future Possibilities

### Managing NuGet plugins per repository using .NET Local Tools

- A potential future possibility is mentioned under the `Specify the authentication plugin in NuGet.Config file` section.
In addition to that, if we ever plan to provide users with an option to manage their plugins per repository instead of loading all the available plugins, we can consider using [.NET Local tools](https://learn.microsoft.com/dotnet/core/tools/local-tools-how-to-use).
- The advantage of local tools is that the .NET CLI uses manifest files to keep track of tools that are installed locally to a directory.
When the manifest file is saved in the root directory of a source code repository, a contributor can clone the repository and invoke a single .NET CLI command such as [`dotnet tool restore`](https://learn.microsoft.com/dotnet/core/tools/dotnet-tool-restore) to install all of the tools listed in the manifest file.
- Having NuGet plugins under the repository folder eliminates the need for NuGet to load plugins from the user profile.
