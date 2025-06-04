# Using NuGet for MCP servers

- Author Names: Jon Douglas ([@jondouglas](https://github.com/jondouglas)), Joel Verhagen ([@joelverhagen](https://github.com/joelverhagen))
- GitHub Issue: [NuGet/NuGetGallery#10461](https://github.com/NuGet/NuGetGallery/issues/10461)

## Summary

Today it is possible for an [MCP](https://modelcontextprotocol.io/introduction) server to be implemented in many different programming languages. The protocol is relatively agnostic to the underlying programming language. However, client tooling such as VS Code is tailored to specific runtimes when installing and launching a local MCP server. VS Code, for example, supports [Docker, Python, and npm MCP servers](https://code.visualstudio.com/docs/copilot/chat/mcp-servers#_configuration-format) (as of June 2025). Other runtimes such as .NET are supported via custom steps, such as wrapping the app in Docker/npx or installing the MCP server out of band and then executing it by a command name available in `PATH`.

This document describes several steps needed to improve the use of local MCP servers written in .NET. We focus primarily on the packaging (NuGet) perspective but will reference ongoing or completed work in the .NET ecosystem.

We will streamline the authoring, discovery, installation, and execution of local MCP servers written in .NET.

The main missing pieces are:

1. [Well-defined conventions to identify MCP server packages and startup instructions.](#improve-mcp-server-authoring)
2. [Browsing experience on NuGet.org tailored to MCP server packages](#improve-browsing-experience)
3. [Single-shot execution of .NET tools](#enable-single-shot-execution-for-net-tools)
4. [Support for NuGet packages in the MCP metaregistry](#add-support-for-nuget-packages-in-the-mcp-registry)
5. [Support for NuGet package MCP server installation in IDEs, e.g., VS Code](#add-support-for-nuget-packages-in-vs-code)

## Motivation

As an MCP server author, it should be easy to create MCP servers in .NET and host them on NuGet.org or a private feed.

As an MCP server consumer (user), it should be easy to discover MCP servers and execute them in your IDE of choice. 

Most of the groundwork is done to ship a .NET MCP server. The SDK is available at [modelcontextprotocol/csharp-sdk](https://github.com/modelcontextprotocol/csharp-sdk). However, conventions for packaging them with NuGet are not well defined.

Some Microsoft MCP servers are implemented in .NET but distributed via npm, for example [@azure/mcp](https://www.npmjs.com/package/@azure/mcp). This is a fine approach if a Node.js runtime and npm packaging are not concerns. For MCP authors that want to target an environment where the .NET runtime is available, and not depend on npm, Python, or Docker, we should enable an end-to-end experience using just .NET and the MCP client IDE of choice (e.g., VS Code).

## Success criteria

Ideally, we will publish a guide on learn.microsoft.com on how to create, pack, publish, and browse an MCP server, targeted at potential MCP server authors. A bonus would be working with Microsoft teams working on .NET MCP servers to publish to NuGet.org in addition to or instead of their existing delivery mechanisms.

## Explanation

### Improve MCP server authoring

#### Today's experience

To create a .NET MCP server today, the experience is somewhat self-guided and results in a NuGet package that looks no different from any other .NET CLI tool.

An MCP server author can create a .NET console app, consume the [ModelContextProtocol NuGet package](https://www.nuget.org/packages/ModelContextProtocol), and implement tools that will be available to the LLM. The SDK helps with the stdio-based protocol that allows the end user's IDE to launch, discover, and invoke tools.

The author will decide what CLI arguments or environment variables are needed to invoke the MCP server.

When the MCP server is ready, the author will pack the [project as a tool with `<PackAsTool>`](https://learn.microsoft.com/en-us/dotnet/core/tools/global-tools-how-to-create) and publish the NuGet package to NuGet.org (or their private package feed), so that it can be used by other people.

This approach works, but has a couple of problems:

- The package has no indication that it is an MCP server. It just has the `DotnetTool` package type like any other .NET tool.
  - NuGet.org and other package sources have no way of filtering packages to "MCP" or tailoring the browsing experience.
- The package provides no guidance to the end user on how to start the MCP server.
  - The end user doesn't have a good way of knowing the needed `command`, `args`, and `env` settings they should use.
- The package author needs to set up their project just right, with a console app, .NET tool, and MCP dependency.

#### New package type

To address the filtering and discoverability problem, we will introduce an additional NuGet package type of `McpServer`.

Currently, .NET tools get the `DotnetTool` package type, defined in the resulting package manifest (.nuspec file) generated by `dotnet pack`. [As of .NET 10](https://github.com/dotnet/sdk/pull/48039), it is possible to add additional package types to .NET tool packages using the `<PackageType>McpServer</PackageType>` MSBuild property in the tool .csproj.

The resulting MCP server .nupkg will have two package types: `DotnetTool` and `McpServer`. For more information on package types, [see NuGet documentation](https://learn.microsoft.com/en-us/nuget/reference/nuspec#packagetypes).

#### Startup instructions

We have two options to encode the startup instructions into the package:

1. Instruct the package author to include the desired consumer MCP JSON in the README, and allow NuGet.org to scrape the JSON from the README markdown (a code block matching a certain pattern).
   
2. Embed standardized, machine-readable information in the package to allow tooling to know the startup instructions required for the MCP server.
   - This could be the same [author `server.json`](https://github.com/modelcontextprotocol/registry/blob/main/tools/publisher/README.md) used for publishing to the MCP registry, embedded in the root of the package.
   - This could be information in a new .nuspec field.
   - The core idea here is to include similar information as the [`package` entity in the MCP registry Open API schema](https://github.com/modelcontextprotocol/registry/blob/3df06d38d9b6590f6ba9bfde56fb3583d8ff4e9d/docs/openapi.yaml#L165-L200). This is essentially the information provided by the MCP registry to MCP client tooling to enable MCP server installation and setup.
   - See [modelcontextprotocol/registry#118](https://github.com/modelcontextprotocol/registry/discussions/118) for discussion.

| Option            | Pros | Cons |
| ----------------- | ----- | ----- |
| 1. Scrape Markdown | *"soft commitment, wait and see"*<br>- Allows the package author to choose the consumption syntax<br>- Easier to integrate with NuGet.org (README is already read)<br>- Does not bet on any specific schema yet | - May be brittle if the JSON shape varies too much<br>- NuGet.org specific (custom scrape code)
| 2a. Embed server.json | *"align with MCP registry schema"*<br>- Would adhere to a schema defined in the ecosystem<br>- Allows other .nupkg readers to see it easily<br>- Shares effort with MCP registry publishing<br>- Likely to be stable after MCP registry launch | - There are other machine-readable formats like VS Code mcp.json<br>- Diverges from npm/pypi, which do not have rich MCP support<br>- Needs mapping code to generate consumption JSON (mcp.json)
| 2b. Embed mcp.json | *"align with VS Code config schema"*<br>- Would adhere to a schema defined in the ecosystem<br>- Allows other .nupkg readers to see it easily<br>- Makes VS Code consumption very clear | - There are other machine-readable formats like Claude format<br>- Picks a format that may change over time (VS Code config)

**I propose we start with option 2a since it is client-agnostic and positions the package author for publishing to the MCP registry as a next step.**

The resulting JSON available to copy on the NuGet.org page (either scraped from the README [option 1], mapped from server.json [option 2a], or copied from mcp.json [option 2b]) would look like this:

```json
{
  "inputs": [
    {
      "type": "promptString",
      "id": "contoso-api-key",
      "description": "Contoso API Key",
      "password": true
    }
  ],
  "servers": {
    "Contoso.MySuperMcp": {
      "type": "stdio",
      "command": "dnx",
      "args": ["Contoso.MySuperMcp", "--", "mcp", "start"],
      "env": {
        "CONTOSO_API_KEY": "${input:contoso-api-key}"
      }
    }
  }
}
```

For option 1, NuGet.org would look in README.md for a JSON code block with a `servers` JSON property containing a property matching the current package ID. If found, it will place the JSON in the command palette for easy copying. Other MCP JSON configuration shapes will be investigated also. It appears Anthropic uses `mcpServers` in their JSON. If no recognized JSON was found, we would either generate a default JSON (likely missing required arguments and environment variables) or say "see project documentation for how to start the MCP server".


```json
{
  "servers": {
    "Contoso.MySuperMcp": {
      "type": "stdio",
      "command": "dnx",
      "args": ["Contoso.MySuperMcp", "--version", "1.0.1"]
    }
  }
}
```

#### Project template

To improve the project setup experience, we will introduce a new project template. The template will be available via `dotnet new mcp-server`. This will create a .csproj for a CLI tool, with a stable MCP SDK dependency version, and an `McpServer` server package type.

The .csproj will have the following shape:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>

    <PackAsTool>true</PackAsTool>
    <PackageType>McpServer</PackageType>
  </PropertyGroup>

  <PropertyGroup>
    <PackageReadmeFile>README.md</PackageReadmeFile>
  </PropertyGroup>

  <ItemGroup>
    <!-- option 1 for startup instructions, scrape them from a JSON code block in the README.md -->
    <None Include="README.md" Pack="true" PackagePath="/" />

    <!-- option 2a for startup instructions, use MCP registry format -->
    <None Include="server.json" Pack="true" PackagePath="/" />

    <!-- option 2b for startup instructions, use VS Code configuration format -->
    <None Include="mcp.json" Pack="true" PackagePath="/" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="ModelContextProtocol" Version="1.0.0" />
  </ItemGroup>

</Project>
```

The template will also include machine-readable startup instructions (aligning with the [startup instructions](#startup-instructions) described above).

### Improve browsing experience

#### Today's experience

An MCP server can be published as a .NET tool or with any custom package type.

.NET tool MCP servers are not differentiated from any other .NET tool, so an end user can't find them easily among the hundreds of .NET tools or thousands of other NuGet packages.

It is possible to filter by any package type using the NuGet.org search UI by manipulating the URL, or by using the V3 search API. But this is hard to discover for end users.

#### Search filtering

Currently, only three package types are recognized by NuGet.org and enabled for default package type filtering.

We will add the "MCP Server" (`McpServer`) type to the list.

<img src="../../meta/resources/nuget-mcp/search-ui.png" alt="Search UI with MCP server filtering" width="800">

#### Package details page

The package details page will be enhanced to have a new MCP Server tab in the command palette, using the JSON snippet scraped from the README.md (or generated if not found).

<img src="../../meta/resources/nuget-mcp/command-palette.png" alt="Sample of the generated command palette" width="800">

See the [Startup instructions](#startup-instructions) section above for more details.

### Enable single-shot execution for .NET tools

#### Today's experience

It is not possible to download and run a .NET tool with a single command today. This is in contrast to npm, Python, and Docker. For example, an MCP server on npm can be started by VS Code using `npx`.

#### New experience: `dotnet tool exec` / `dnx`

The .NET team is working on a single-shot experience similar to `npx`. This is not work done by the NuGet team, so we'll just link to the existing efforts.

- GitHub issues: [dotnet/sdk#31103](https://github.com/dotnet/sdk/issues/31103), [dotnet/sdk#47517](https://github.com/dotnet/sdk/issues/47517)
- Design document: [dotnet/designs#334 - Add a design proposal for dotnet tool exec and dnx](https://github.com/dotnet/designs/pull/334)
  - Proposal PR: [dotnet/sdk#48443](https://github.com/dotnet/sdk/pull/48443)
- Design document: [dotnet/designs#333 - Add proposal for RID-specific .NET Tool packages](https://github.com/dotnet/designs/pull/333)

The sample JSON above leverages this new single-shot command execution.

RID-specific tools solve the "giant package" problem but are not necessarily a hard blocker for the experience.

### Add support for NuGet packages in the MCP registry

#### Today's experience

The [official MCP registry](https://github.com/modelcontextprotocol/registry/discussions/11) is not yet live, but the discussion and protocol description around it clearly list [several supported underlying registries](https://github.com/modelcontextprotocol/registry/blob/a4cefcf05f81466ad65e7c3971e76d0f6d60783e/docs/openapi.yaml#L173-L176) for hosting the local server's code.

Current list: `npm`, `docker`, `pypi`, `homebrew`

#### Add NuGet to the list

We will work with the MCP server registry team to add `nuget` to the list.

We will publish/link to guidance on how to publish a NuGet-based MCP server to the MCP registry. This step is performed after the package is published to NuGet.org.

### Add support for NuGet packages in VS Code

#### Today's experience

Similar to the previous section, NuGet is not a recognized MCP server host.

![VS Code MCP server installation](../../meta/resources/nuget-mcp/vscode-today.png)

#### Add NuGet to the list

We will work with the VS Code team to add a NuGet option to the list, which updates the user's `mcp.json` to invoke `dnx` with the provided package ID.

This is tracked by [microsoft/vscode-copilot#15329](https://github.com/microsoft/vscode-copilot/issues/15329).

Once Visual Studio has a corresponding experience ([the current experience is manually editing the `mcp.json`](https://learn.microsoft.com/en-us/visualstudio/ide/mcp-servers?view=vs-2022)), we will ensure NuGet is supported similarly.

## Rollout plan

1. Enable `McpServer` support on NuGet.org search and the package details page, behind a feature flag.
2. Work with Microsoft and community MCP server implementers to package as NuGet.
   - As of June 2025, there are 28 .NET tools on NuGet.org that use the MCP SDK. Newer versions should have the `McpServer` package type.
   - Some Microsoft MCP servers are implemented in .NET but distributed via npm, for example [@azure/mcp](https://www.npmjs.com/package/@azure/mcp).
3. Wait for `dnx` to land in a .NET 10 preview.
4. Work with the MCP registry and VS Code to get NuGet support, perhaps providing PRs/OSS contributions ourselves.
5. Enable MCP server UI on NuGet.org.
6. Publish a document on learn.microsoft.com on how to create your own NuGet MCP server. 

## Future Possibilities

We will wait to publish an MCP server template until the .NET MCP SDK has announced a stable API surface area. It is currently in prerelease. In addition, we will continue to keep an eye on the development of the [MCP specification](https://modelcontextprotocol.io/development/updates) and [MCP Registry](https://github.com/modelcontextprotocol/registry).

As MCP servers are run in more and more places, we can consider enhancing the MSBuild project file to enable an MCP server dependency. This could allow the MCP server to be available to the editor (instead of defined in client `mcp.json` configuration) or on a CI for build-time tasks. For example, an MCP server could be used inside an analyzer to produce or fix build warnings. This could work much like the existing [build integration that NuGet has to ship MSBuild props and targets](https://learn.microsoft.com/en-us/nuget/concepts/msbuild-props-and-targets). Thanks to Jeff Kluge ([@jeffkl](https://github.com/jeffkl)) for the idea!

## Prior Art

We should replicate what is already working for npm, PyPI, and Docker.

## Unresolved Questions

- What guidance should be provided for private MCP server implementations?
  - For example, if you publish an `McpServer` to your Azure DevOps feed, what MCP registry should be used?
- What schema should be used for a machine-readable MCP server startup instruction?
  - The package author could include a `server.json` in the NuGet package [matching the MCP registry OpenAPI spec](https://github.com/modelcontextprotocol/registry/blob/a4cefcf05f81466ad65e7c3971e76d0f6d60783e/docs/openapi.yaml#L183-L201).
  - I opened a discussion about this on the MCP registry repo: [Embed runtime instructions inside the package artifact](https://github.com/modelcontextprotocol/registry/discussions/118)

## Resolved questions

- How would the MCP server template ship? Would it be part of the .NET SDK or ship from the MCP SDK repo as a third-party template? 
  - **Answer:** this should be shipped from the .NET MCP SDK repository as a sibling artifact with the dependency packages. The template would iterate along with the SDK as it changes.
- How are client runtime requirements expressed?
  - For example, if an MCP server needs a certain .NET version, how is this communicated to the end user before failure occurs?
  - **Answer:** we will not try to solve this problem, aside from documenting this potential issue and roll-forward capabilities in the guide we publish. We will depend on IDE enhancements (VS Code could detect the missing runtime and help fulfill it) or .NET SDK enhancements. This is a general problem for running .NET tools, not specific to MCP.

## Drawbacks

TBD.

## Rationale and alternatives

TBD.
