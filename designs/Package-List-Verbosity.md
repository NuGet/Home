# `dotnet list package --verbosity`

* Status: **In Review**
* Author: [Joel Verhagen](https://github.com/joelverhagen)
* Issue: [#9600](https://github.com/NuGet/Home/issues/9600) - No verbosity switch on dotnet list packages so HTTP requests are invisible

## Problem background

No `--verbosity` switch is available on the `dotnet list package` command so HTTP requests made during the operation
are not visible. For large dependency graphs, this can mean there's a long hang before any output is shown.
Additionally, any warnings that occur during the operation are invisible, which can lead to unexpected or delayed
behavior without any ability to understand what is going on.

HTTP start and end log messages act as an indication of progress. Also, they helps diagnose problems with slow sources
or any other problems when talking to a feed.

This is important with the `--outdated` or `--deprecated` switches since the command goes online to get information from
the configured sources.

Many commands in the .NET CLI have a verbosity switch. For example, `dotnet restore --verbosity normal` shows the HTTP
requests made during restore. The default verbosity (`minimal`) does not show HTTP request log messages but does show
minimal messages, warnings, and errors.

## Who are the customers

Package consumers that use the `dotnet list package` command in conjunction with `--outdated` or `--deprecated`.

## Goals

* Enable increasing log verbosity so that HTTP requests are visible
* Output related to the core experience is unaffected by this change
* Align with the verbosity levels of .NET CLI and MSBuild (not NuGet verbosity levels)
  - In general, verbosity levels in .NET CLI use the MSBuild pattern. We should align on that.
  - [Generic dotnet documention](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet#sdk-options-for-running-a-command)
  - Specific commands:
    [build](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-build#options),
    [clean](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-clean#options),
    [pack](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-pack#options),
    [publish](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-publish#options),
    [restore](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-restore#options),
    [run](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-run#options),
    [store](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-store#optional-options),
    [test](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-test#options),
    [tool install](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-tool-install#options),
    [tool restore](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-tool-restore#options),
    [tool update](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-tool-update#options)

## Non-goals

* Add `--verbosity` switch to other commands
* Provide a way to silence output related to the core experience (e.g. the package list itself)

## Solution

### Situation before this design

Currently, the logger is not passed into the protocol resources that perform HTTP. A `NullLogger` is passed in. This
means that no matter what, no log messages will be seen about HTTP traffic.

Also, the logger that is passed into the `dotnet list package` command has the default verbosity set to `Information`.
This means if we simply pass the existing logger into the protocol resources, HTTP traffic will *always* be show, which
is not desirable as this is a change in default behavior.

The logger is passed into the `MSBuildAPIUtility` constructor but the method on this class used by the
`list package` command never writes the logger.

In other words, the logger is entirely unused by the `list package` command.

### Changes required

1. Change the default NuGet log level for the `list package` command from `Information` to `Minimal`
   - This aligns with `restore` behavior.
   - This equates to a default `--verbosity` switch value of `m[inimal]`.
1. Pass the logger into the protocol resources.
1. Add a `-v|--verbosity` switch to allow the logger level to be changed.
1. Ensure `CommandOutputLogger.HidePrefixForInfoAndMinimal` is set to `true`.
   - This will give the HTTP log messages a similar appearance to `restore`, `push`, and `delete`.

### Log level mapping

The provided `--verbosity` value will include to NuGet log messages with the following levels:

​             | `q[uiet]` | `m[inimal]` | `n[ormal]` | `d[etails]` | `diag[nostic]`
------------- | --------- | ----------- | ---------- | ----------- | --------------
`Error`       | ✔️        | ✔️         | ✔️         | ✔️         | ✔️   
`Warning`     | ✔️        | ✔️         | ✔️         | ✔️         | ✔️   
`Minimal`     | ❌        | ✔️         | ✔️         | ✔️         | ✔️   
`Information` | ❌        | ❌         | ✔️         | ✔️         | ✔️   
`Verbose`     | ❌        | ❌         | ❌         | ✔️         | ✔️   
`Debug`       | ❌        | ❌         | ❌         | ✔️         | ✔️   


Note that MSBuild itself has the following mapping for it's own "log levels"
([source](https://docs.microsoft.com/en-us/visualstudio/msbuild/obtaining-build-logs-with-msbuild?view=vs-2019#verbosity-settings)):

​                                     | `q[uiet]` | `m[inimal]` | `n[ormal]` | `d[etails]` | `diag[nostic]`
------------------------------------- | --------- | ----------- | ---------- | ----------- | --------------
Errors                                | ✔️        | ✔️         | ✔️         | ✔️         | ✔️   
Warnings                              | ✔️        | ✔️         | ✔️         | ✔️         | ✔️   
High-importance Messages              | ❌        | ✔️         | ✔️         | ✔️         | ✔️   
Normal-importance Messages            | ❌        | ❌         | ✔️         | ✔️         | ✔️   
Low-importance Messages               | ❌        | ❌         | ❌         | ✔️         | ✔️   
Additional MSBuild-engine information | ❌        | ❌         | ❌         | ❌         | ✔️   

In other words, you can think of the following log concepts per row as equivalent.

NuGet log level    | MSBuild verbosity switch | MSBuild message type
------------------ | ------------------------ | --------------------
`Error`, `Warning` | `q[uiet]`                | Errors and Warnings
`Minimal`          | `m[inimal]`              | High-importance Messages
`Information`      | `n[ormal]`               | Normal-importance Messages
`Verbose`, `Debug` | `d[etailed]`             | Low-importance Messages
​                   | `diag[nostic]`           | Additional MSBuild-engine information

### What about errors, warnings, and minimal level messages?

The logger will only be added to the protocol layer. This is because this is the only place that logger is used at all
in the `list package` command. The only API called is `PackageMetadataResource.GetMetadataAsync`. Upon inspection of
these code paths, these are the types of logs that will start showing by default:

- warnings when the HTTP cache contains a corrupted file (e.g. bad JSON)
- warnings from `X-NuGet-Warning`
- warnings when directories in a local source can't be enumerated
- minimal, warning, and error messages from the credential providers

If this is a concerning, one potential solution is leave
`CommandOutputLogger.HidePrefixForInfoAndMinimal` as `false` and the caller can filter output undesired `stdout` lines
via log level prefix. For example:

- PowerShell: `dotnet list package --deprecated | ? { !$_.StartsWith("warn :") }`
- GNU tools: `dotnet list package --deprecated | sed '/^warn :/d'`

This design proposal is to set `CommandOutputLogger.HidePrefixForInfoAndMinimal` to `true` to align with other commands
mentioned before, thus encouraging the user to notice the errors, warnings, or minimal messages that are now logged.

### Usage text

The new usage text from `dotnet list package --help` will be:

<pre>
Usage: dotnet list &lt;PROJECT | SOLUTION&gt; package [options]

Arguments:
  &lt;PROJECT | SOLUTION&gt;   The project or solution file to operate on. If a file is not specified, the command will search the current directory for one.

Options:
  -h, --help                                Show command line help.
  --outdated                                Lists packages that have newer versions.
  --deprecated                              Lists packages that have been deprecated.
  --framework &lt;FRAMEWORK | FRAMEWORK\RID&gt;   Chooses a framework to show its packages. Use the option multiple times for multiple frameworks.
  --include-transitive                      Lists transitive and top-level packages.
  --include-prerelease                      Consider packages with prerelease versions when searching for newer packages. Requires the '--outdated' or '--deprecated' option.
  --highest-patch                           Consider only the packages with a matching major and minor version numbers when searching for newer packages. Requires the '--outdated' or '--deprecated' option.
  --highest-minor                           Consider only the packages with a matching major version number when searching for newer packages. Requires the '--outdated' or '--deprecated' option.
  --config &lt;CONFIG_FILE&gt;                    The path to the NuGet config file to use. Requires the '--outdated' or '--deprecated' option.
  --source &lt;SOURCE&gt;                         The NuGet sources to use when searching for newer packages. Requires the '--outdated' or '--deprecated' option.
  --interactive                             Allows the command to stop and wait for user input or action (for example to complete authentication).
  <b>-v, --verbosity &lt;LEVEL&gt;</b>                   <b>Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].</b>
</pre>

### Example output

This is output of the invocation of `dotnet list package --outdated --framework netcoreapp2.1` for
[NuGet.CommandLine.XPlat.csproj](https://github.com/NuGet/NuGet.Client/blob/05925a63fde32ab277ccaab13ed466add9ac9dc8/src/NuGet.Core/NuGet.CommandLine.XPlat/NuGet.CommandLine.XPlat.csproj).

#### Default verbosity | `--verbosity mimimal` | `--verbosity quiet`

```
The following sources were used:
   C:\Program Files (x86)\Microsoft SDKs\NuGetPackages\
   https://api.nuget.org/v3/index.json

Project `NuGet.CommandLine.XPlat` has the following updates to its packages
   [netcoreapp2.1]:
   Top-level Package                            Requested                 Resolved                  Latest
   > Microsoft.Build                            16.5.0-preview-19606-01   16.5.0-preview-19606-01   16.5.0
   > Microsoft.Build.Locator                    1.2.2                     1.2.2                     1.2.6
   > Microsoft.CodeAnalysis.FxCopAnalyzers      2.9.8                     2.9.8                     3.0.0
   > Microsoft.Extensions.CommandLineUtils      1.0.1                     1.0.1                     1.1.1
   > Microsoft.SourceLink.GitHub                1.0.0-beta2-19351-01      1.0.0-beta2-19351-01      1.1.0-beta-20204-02
```

#### `--verbosity normal` | `--verbosity detailed` | `--verbosity diagnostic`

```
The following sources were used:
   C:\Program Files (x86)\Microsoft SDKs\NuGetPackages\
   https://api.nuget.org/v3/index.json

  GET https://api.nuget.org/v3/registration5-gz-semver2/microsoft.build/index.json
  GET https://api.nuget.org/v3/registration5-gz-semver2/microsoft.netcore.app/index.json
  GET https://api.nuget.org/v3/registration5-gz-semver2/microsoft.extensions.commandlineutils/index.json
  GET https://api.nuget.org/v3/registration5-gz-semver2/microsoft.codeanalysis.fxcopanalyzers/index.json
  GET https://api.nuget.org/v3/registration5-gz-semver2/microsoft.build.locator/index.json
  GET https://api.nuget.org/v3/registration5-gz-semver2/microsoft.sourcelink.github/index.json
  GET https://api.nuget.org/v3/registration5-gz-semver2/system.runtime.serialization.primitives/index.json
  OK https://api.nuget.org/v3/registration5-gz-semver2/microsoft.extensions.commandlineutils/index.json 85ms
  OK https://api.nuget.org/v3/registration5-gz-semver2/microsoft.codeanalysis.fxcopanalyzers/index.json 116ms
  OK https://api.nuget.org/v3/registration5-gz-semver2/microsoft.sourcelink.github/index.json 211ms
  OK https://api.nuget.org/v3/registration5-gz-semver2/microsoft.netcore.app/index.json 234ms
  OK https://api.nuget.org/v3/registration5-gz-semver2/system.runtime.serialization.primitives/index.json 231ms
  OK https://api.nuget.org/v3/registration5-gz-semver2/microsoft.build/index.json 303ms
  OK https://api.nuget.org/v3/registration5-gz-semver2/microsoft.build.locator/index.json 299ms
Project `NuGet.CommandLine.XPlat` has the following updates to its packages
   [netcoreapp2.1]:
   Top-level Package                            Requested                 Resolved                  Latest
   > Microsoft.Build                            16.5.0-preview-19606-01   16.5.0-preview-19606-01   16.5.0
   > Microsoft.Build.Locator                    1.2.2                     1.2.2                     1.2.6
   > Microsoft.CodeAnalysis.FxCopAnalyzers      2.9.8                     2.9.8                     3.0.0
   > Microsoft.Extensions.CommandLineUtils      1.0.1                     1.0.1                     1.1.1
   > Microsoft.SourceLink.GitHub                1.0.0-beta2-19351-01      1.0.0-beta2-19351-01      1.1.0-beta-20204-02
```

## References

- [MSBuild verbosity settings](https://docs.microsoft.com/en-us/visualstudio/msbuild/obtaining-build-logs-with-msbuild?view=vs-2019#verbosity-settings) - how log
  level specified in the `--verbosity` switch affects different message types
- [NuGet's `MSBuildLogger.LogForNonMono`](https://github.com/NuGet/NuGet.Client/blob/05925a63fde32ab277ccaab13ed466add9ac9dc8/src/NuGet.Core/NuGet.Build.Tasks/Common/MSBuildLogger.cs#L82-L109) -
  how NuGet log levels map to MSBuild message types
- [NuGet's `NuGetSdkLogger.Log`](https://github.com/NuGet/NuGet.Client/blob/05925a63fde32ab277ccaab13ed466add9ac9dc8/src/NuGet.Core/Microsoft.Build.NuGetSdkResolver/NuGetSdkLogger.cs) -
  another example of NuGet log level mapping
