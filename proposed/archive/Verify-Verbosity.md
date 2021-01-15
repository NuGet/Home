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

The details that should be displayed on each verbosity level are described below. Each level should display the same as the level below plus whatever is specified in that level. In that sense, `quiet` will be give the less amount of information, while `diagnostic` the most.
