<!-- mcp-name: com.microsoft/nuget -->

# NuGet MCP Server

Contains an [Model Context Protocol](https://modelcontextprotocol.io/introduction) (MCP) server for NuGet, enabling advanced tooling and automation scenarios for NuGet package management.
See the [official NuGet MCP documentation](https://learn.microsoft.com/nuget/concepts/nuget-mcp-server) for the latest information.

## Capabilities

- Uses your configured NuGet feeds to get real time information about packages.
- Provides the ability to update packages with known vulnerabilities, including transitive dependencies.
- Provides advanced tooling for updating packages which provides the best updates based on a projects unique package graph and target frameworks.

## Requirements

To run the MCP server, you must have **[.NET 10 Preview 6 or later](https://dotnet.microsoft.com/en-us/download/dotnet/10.0)** installed.
This version of .NET adds a command, `dnx`, which is used to download, install, and run the MCP server from [nuget.org](https://nuget.org).

To verify your .NET version, run the following command in your terminal:
```bash
dotnet --info
```

## Getting Started

To configure the NuGet MCP server, you will need to modify an `mcp.json` file or other configuration.
The following table provides links to documentation for configuring MCP servers in different environments:

| Environment | Documentation |
|---|---|
| Visual Studio | [File locations for automatic discovery of MCP configuration](https://learn.microsoft.com/visualstudio/ide/mcp-servers?view=vs-2022#file-locations-for-automatic-discovery-of-mcp-configuration) |
| VS Code | [MCP configuration in VS Code](https://code.visualstudio.com/docs/copilot/chat/mcp-servers#_add-an-mcp-server) |
| GitHub Copilot Coding Agent | [Setting up MCP servers in a repository](https://docs.github.com/en/copilot/how-tos/agents/copilot-coding-agent/extending-copilot-coding-agent-with-mcp#setting-up-mcp-servers-in-a-repository)

### Visual Studio 2026

The NuGet MCP server ships in-box with Visual Studio 2026.
You must enable it the first time in the GitHub Copilot chat tools menu.

If you'd like to use a newer version of the NuGet MCP server than the one included with Visual Studio, you can configure it with the following snippet and include it in your `mcp.json`:


```jsonc
{
  "servers": {
    "nuget": {
      "type": "stdio",
      "command": "dnx",
      "args": [ "NuGet.Mcp.Server", "--source", "https://api.nuget.org/v3/index.json", "--yes" ]
    }
  }
}
```

If you'd like to use a specific version of the MCP server, you can specify it with package name like `NuGet.Mcp.Server@1.0.0`:
```jsonc
{
  "servers": {
    "nuget": {
      "type": "stdio",
      "command": "dnx",
      "args": [ "NuGet.Mcp.Server@1.0.0", "--source", "https://api.nuget.org/v3/index.json", "--yes" ]
    }
  }
}
```

When configured this way, you will need to update the version as new releases become available.

See [File locations for automatic discovery of MCP configuration](https://learn.microsoft.com/visualstudio/ide/mcp-servers?view=vs-2022#file-locations-for-automatic-discovery-of-mcp-configuration) for more information on the location of the appropriate `mcp.json` for you.

### Visual Studio 2022

To configure the MCP server for use with Visual Studio 2022, make sure you have update 17.14 or later installed.
Then use the following snippet and include it in your `mcp.json`:

```jsonc
{
  "servers": {
    "nuget": {
      "type": "stdio",
      "command": "dnx",
      "args": [ "NuGet.Mcp.Server", "--source", "https://api.nuget.org/v3/index.json", "--yes" ]
    }
  }
}
```

If you'd like to use a specific version of the MCP server, you can specify it with package name like `NuGet.Mcp.Server@1.0.0`:
```jsonc
{
  "servers": {
    "nuget": {
      "type": "stdio",
      "command": "dnx",
      "args": [ "NuGet.Mcp.Server@1.0.0", "--source", "https://api.nuget.org/v3/index.json", "--yes" ]
    }
  }
}
```

When configured this way, you will need to update the version as new release become available.

See [File locations for automatic discovery of MCP configuration](https://learn.microsoft.com/visualstudio/ide/mcp-servers?view=vs-2022#file-locations-for-automatic-discovery-of-mcp-configuration) for more information on the location of the appropriate `mcp.json` for you.

### VS Code

To configure the NuGet MCP server in VS code, you can use the following badges to quickly install the MCP server:

[![Install in VS Code](https://img.shields.io/badge/VS_Code-Install_Server-0098FF?style=flat-square&logo=visualstudiocode&logoColor=white)](
https://vscode.dev/redirect/mcp/install?name=NuGet&config=%7B%22name%22%3A%22NuGet.Mcp.Server%22%2C%22type%22%3A%22stdio%22%2C%22command%22%3A%22dnx%22%2C%22args%22%3A%5B%22NuGet.Mcp.Server%22%2C%22--source%22%2C%22https%3A%2F%2Fapi.nuget.org%2Fv3%2Findex.json%22%2C%22--yes%22%5D%7D) [![Install in VS Code Insiders](https://img.shields.io/badge/VS_Code_Insiders-Install_Server-24bfa5?style=flat-square&logo=visualstudiocode&logoColor=white)](https://vscode.dev/redirect/mcp/install?name=NuGet&config=%7B%22name%22%3A%22NuGet.Mcp.Server%22%2C%22type%22%3A%22stdio%22%2C%22command%22%3A%22dnx%22%2C%22args%22%3A%5B%22NuGet.Mcp.Server%22%2C%22--source%22%2C%22https%3A%2F%2Fapi.nuget.org%2Fv3%2Findex.json%22%2C%22--yes%22%5D%7D&quality=insiders)


To manually configure the MCP server for use with Visual Studio or VS Code, use the following snippet and include it in your `mcp.json`:


```jsonc
{
  "servers": {
    "nuget": {
      "type": "stdio",
      "command": "dnx",
      "args": [ "NuGet.Mcp.Server", "--source", "https://api.nuget.org/v3/index.json", "--yes" ]
    }
  }
}
```

If you'd like to use a specific version of the MCP server, you can specify it with package name like `NuGet.Mcp.Server@1.0.0`:
```jsonc
{
  "servers": {
    "nuget": {
      "type": "stdio",
      "command": "dnx",
      "args": [ "NuGet.Mcp.Server@1.0.0", "--source", "https://api.nuget.org/v3/index.json", "--yes" ]
    }
  }
}
```

When configured this way, you will need to update the version as new release become available.

See [MCP configuration in VS Code](https://code.visualstudio.com/docs/copilot/chat/mcp-servers#_add-an-mcp-server) for more information on the location of the appropriate `mcp.json` for you.

### GitHub Copilot

You can also configure the MCP Server to work with GitHub Copilot as a Coding Agent in your repositories.

First, you need to add the MCP Server configuration in your Copilot Coding Agent:

```json
{ 
  "mcpServers": {
    "NuGet": {
      "type": "local",
      "command": "dnx",
      "args": ["NuGet.Mcp.Server", "--yes"],
      "tools": ["*"],
      "env": {}
    }
  } 
}
```

This will make all the MCP Server tools available, if you want specific tools you can list them in the `"tools"` parameter array. 

You will also need to make sure Copilot installs .NET 10 Preview 6 or higher in order to have the command `dnx` and install the MCP Server.

`.github/workflows/copilot-setup-steps.yml`
```yml
name: "Copilot Setup Steps"

# Automatically run the setup steps when they are changed to allow for easy validation, and
# allow manual testing through the repository's "Actions" tab
on:
  workflow_dispatch:
  push:
    paths:
      - .github/workflows/copilot-setup-steps.yml
  pull_request:
    paths:
      - .github/workflows/copilot-setup-steps.yml

jobs:
  # The job MUST be called `copilot-setup-steps` or it will not be picked up by Copilot.
  copilot-setup-steps:
    runs-on: ubuntu-latest

    # Set the permissions to the lowest permissions possible needed for your steps.
    # Copilot will be given its own token for its operations.
    permissions:
      # If you want to clone the repository as part of your setup steps, for example to install dependencies, you'll need the `contents: read` permission. If you don't clone the repository in your setup steps, Copilot will do this for you automatically after the steps complete.
      contents: read

    # You can define any steps you want, and they will run before the agent starts.
    # If you do not check out your code, Copilot will do this for you.
    steps:
      - name: Install .NET 10.x
        uses: actions/setup-dotnet@v5
        with:
          dotnet-version: |
            10.x
          dotnet-quality: preview

      - name: dotnet --info
        run: dotnet --info
```

## Currently Supported Tools
- `get-nuget-solver`: Fix all your package vulnerable version by updating your packages (direct and transitive) to the best compatible non-vulnerable version.
- `get-nuget-solver-latest-versions`: Fix all your package vulnerable version by updating your packages (direct and transitive) to the latest compatible non-vulnerable version.
- `get-latest-package-version`: Gets the latest version of a NuGet package.
- `get-package-readme`: Gets the README for a NuGet package and returns it as markdown.
- `update-package`: Updates installed packages to the specified version if compatible with the project configuration. It will also install/update packages needed to complete the operation.

## Data Collection
The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft's [privacy statement](https://www.microsoft.com/privacy/privacystatement). You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

### Telemetry Configuration
Telemetry collection is on by default to help improve the product. This can be disabled, see [Disabling All Telemetry](#disabling-telemetry-only) section below for more details.

#### Disabling Telemetry Only
To disable Microsoft telemetry collection, set the environment variable `DOTNET_CLI_TELEMETRY_OPTOUT` to `false` or `1`:

```bash
export DOTNET_CLI_TELEMETRY_OPTOUT=true
```

## Support
If you experience an issue with the NuGet MCP server or have any other feedback, please open an issue on the [NuGet GitHub repository](https://github.com/NuGet/Home/issues/new?template=MCPSERVER.yml).
Please provide the requested information in the issue template so that we can better understand and address your issue or suggestion.

### No Warranty / Limitation of Liability
This software is provided "as is" without warranties or conditions of any kind, either express or implied. Microsoft shall not be liable for any damages arising from use, misuse, or misconfiguration of this software.