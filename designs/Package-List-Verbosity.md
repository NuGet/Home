# `dotnet list package --verbosity`

* Status: **In Review**
* Author: [Joel Verhagen](https://github.com/joelverhagen)
* Issue: [#9600](https://github.com/NuGet/Home/issues/9600) - No verbosity switch on dotnet list packages so HTTP requests are invisible

## Problem Background

No `--verbosity` switch is available on the `dotnet list package` command so HTTP requests made during the operation
are not visible. For large dependency graphs, this can mean there's a long hang before any output is shown.

In other workds, HTTP start and end log messages act as an indication of progress. Also, it helps diagnose problems
with slow sources or any other problem when talking to a feed.

This is especially important with the `--outdated` or `--deprecated` switches since the command goes online to get
information from the configured sources.

Many commands in the .NET CLI have a verbosity switch. For example, `dotnet restore --verbosity normal` shows the HTTP
requests made during restore. The default verbosity (`minimal`) does not show HTTP request log messages. 

## Who are the customers

Package consumers that use the `dotnet list package` command in conjunction with `--outdated` or `--deprecated`.

## Goals

* Enable increasing log verbosity so that HTTP requests are visible
* Output related to the core experience is unaffected by this change
* Align with the verbosity levels of .NET CLI and MSBuild (not NuGet verbosity levels)

## Non-goals

* Add `--verbosity` switch to other commands
* Provide a way to silence output related to the core experience (e.g. the package list itself)

## Solution

### Current situation

Currently, the logger is not passed into the protocol resources that perform HTTP. A `NullLogger` is passed in. This
means that no matter what, no log messages will be seen about HTTP traffic.

Also, the logger that is passed into the `dotnet list package` command has the default verbosity set to `Information`.
This means if we simply pass the existing logger into the protocol resources, HTTP traffic will *always* be show, which
is not desirable as this is a change in default behavior.

The logger is passed into the `MSBuildAPIUtility` constructor but the method on this class used by the
`list package` command never writes the logger.

In other words, the logger is entirely unused by the by the `list package` command.

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
​                  | `diag[nostic]`           | Additional MSBuild-engine information

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
  <b>-v, --verbosity &lt;LEVEL&gt;</b>            <b>Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].</b>
</pre>

## References

- [MSBuild verbosity settings](https://docs.microsoft.com/en-us/visualstudio/msbuild/obtaining-build-logs-with-msbuild?view=vs-2019#verbosity-settings) - how log
  level specified in the `--verbosity` switch affects different message types
- [NuGet's `MSBuildLogger.LogForNonMono`](https://github.com/NuGet/NuGet.Client/blob/05925a63fde32ab277ccaab13ed466add9ac9dc8/src/NuGet.Core/NuGet.Build.Tasks/Common/MSBuildLogger.cs#L82-L109) -
  how NuGet log levels map to MSBuild message types
- [NuGet's `NuGetSdkLogger.Log`](https://github.com/NuGet/NuGet.Client/blob/05925a63fde32ab277ccaab13ed466add9ac9dc8/src/NuGet.Core/Microsoft.Build.NuGetSdkResolver/NuGetSdkLogger.cs) -
  another example of NuGet log level mapping
