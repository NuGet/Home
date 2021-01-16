# `dotnet nuget verify --verbosity`

* Status: **Draft**
* Author: [Kartheek Penagamuri](https://github.com/kartheekp-ms)
* Issue: [#10316](https://github.com/NuGet/Home/issues/10316) - dotnet nuget verify is too quiet

## Problem background

`--verbosity` option available on the `dotnet nuget verify` command doesn't provide any output by default due to logical error in the code. Customers need information about packages’ signatures to [manage package trust boundaries](https://docs.microsoft.com/en-us/nuget/consume-packages/installing-signed-packages).

## Who are the customers

Package consumers that use the `dotnet nuget verify` command to verify package signature and configure NuGet security policy.

## Goals

* Change the output of `dotnet nuget verify` command for various `--verbosity` options.

## Non-goals

* Add `--verbosity` option to `dotnet nuget verify` command.

## Solution

### Situation before this design

Currently, the default verbosity for `dotnet` commands is [`LogLevel.Information`](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.CommandLine.XPlat/Program.cs#L31). If the user didn't pass value for `--verbosity` option, then the log level is set to [`LogLevel.Minimal`](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.CommandLine.XPlat/Commands/Signing/VerifyCommand.cs#L58) due to logical error in the `dotnet nuget verify` command implementation. Hence by default this command does not display any log messages.

### Changes required

The details that should be displayed on each verbosity level are described below. Each level should display the same as the level below plus whatever is specified in that level. In that sense, `quiet` will be give the less amount of information, while `diagnostic` the most.

​                                  | `q[uiet]` | `m[inimal]` | `n[ormal]` | `d[etails]` | `diag[nostic]`
----------------------------------| --------- | ----------- | ---------- | -----------| --------------
`Certificate chain Information`   | ❌       | ❌          | ❌         | ✔️         | ✔️   
`Package name`                    | ❌       | ❌          | ✔️         | ✔️         | ✔️   
`Path to package being verified`  | ❌       | ❌          | ✔️         | ✔️         | ✔️   
`Type of signature (author or repository)`| ❌       | ❌          | ✔️         | ✔️         | ✔️   
`Hashing algorithm used for signature`        | ❌       | ❌          | ✔️         | ✔️         | ✔️   
`Certificate -> SHA1 hash`| ❌       | ✔️          | ✔️         | ✔️         | ✔️   
`Certificate -> Subject`| ❌       | ✔️          | ✔️         | ✔️         | ✔️   
`Certificate -> SHA-256 hash`| ❌       | ✔️          | ✔️         | ✔️         | ✔️   
`Certificate -> Issued By`| ❌       | ✔️          | ✔️         | ✔️         | ✔️   
`Certificate -> Validity period`| ❌       | ✔️          | ✔️         | ✔️         | ✔️   
`Certificate -> Service index URL (If applicable)`| ❌       | ✔️          | ✔️         | ✔️         | ✔️   


### Log level mapping - The following details are copied from [here](https://github.com/NuGet/Home/blob/dev/designs/Package-List-Verbosity.md#log-level-mapping). Thanks to [Joel Verhagen](https://github.com/joelverhagen) for the detailed information

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

​                                     | `q[uiet]` | `m[inimal]` | `n[ormal]` | `d[etailed]` | `diag[nostic]`
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