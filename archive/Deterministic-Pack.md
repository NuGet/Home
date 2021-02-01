# Deterministic pack

* Status: **Implemented** 
* Update; **Reverted in 5.3 and .NET Core 3.0.100** See https://github.com/NuGet/Home/issues/8601 for more details
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)
  * I'm merely the person writing up the spec, the bulk of the analysis and implementation work goes to [tmat](https://github.com/tmat) and [ctaggart](https://github.com/ctaggart)

## Issue

[6229](https://github.com/NuGet/Home/issues/6229) - NuGet Pack is not deterministic

## Problem Background

The need for deterministic in the build tools is obvious. Given the same input, the tooling should generate the exact same binary output. Effectively this means that the build should not depend on the ambient state of the environment such as the current time, a global random number generator state, the machine name the build is running on, the root directory the repository is built from, etc.
The compiler implements determinism with the [-deterministic](https://docs.microsoft.com/en-us/dotnet/visual-basic/reference/command-line-compiler/deterministic) switch. More information about roslyn & determinism in this [blog](https://blog.paranoidcoding.com/2016/04/05/deterministic-builds-in-roslyn.html) by [jaredpar](https://github.com/jaredpar).
NuGet packages are one of the most common distribution vehicles for binaries, so as such the tooling that creates the packages should be deterministic too. 

## Who are the customers

All .NET customers

## Requirements

* Given the same input, pack should generate the same byte-for-byte package, and not be influenced by the ambient state of the machine we're packing on.

## Solution

There are 2 different pack entry point. NuGet.exe pack, which can only work on a nuspec, the pack targets or msbuild /t:pack (dotnet pack) which runs on the csproj itself.
In the pack targets we will respect the `<Deterministic>true</Deterministic>` MSBuild property.
In NuGet.exe pack, we will add a -Deterministic switch.

## Implementation

The indeterminism of NuGet's pack operation can be grouped in 2 buckets.

1. Timestamps for the zip entries.
2. Guids used to generate the psmdcp.

As far as the timestamps go, they'll default to Zip format minimum date of 1/1/1980.
Instead of the Guids, we'll just use content hashes of the files in the package.

An obvious, but important disclaimer is that the determinism of pack will be affected by the determinism of all the tools that generate the files that end up getting packed.
