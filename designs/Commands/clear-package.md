# Clearing an specific package from NuGet cache

* Status: **Incubating**
* Author(s): [Fernando Aguilar](https://github.com/dominofire)

The purpose is to add a feature to `nuget locals` command to delete a package from NuGet cache folder


## Problem Background

There's some interest on having features to delete an specific package instead of clearing the whole cache.

- https://github.com/NuGet/Home/issues/5713 : Comments on deleting specific packages
- https://github.com/NuGet/Home/issues/4980 : Comments on cache handling polices
- https://github.com/chgill-MSFT/NuGetCleaner : A clean-up tool relying on last-acesss file metadata in NTFS file system

In PackageReference world, the global packages folders are shared across all restored projects. 

There's no current API or command to delete an specific package.


## Who are the customers

All `dotnet nuget locals` users.


## Goals

- Add command options to `dotnet nuget locals` to delete _one_ package from a NuGet cache folder, either _one_ or multiple versions.


## Non-Goals

- Cache expiration policies are not covered
- Deleting cached packages from an specific folder are not covered 
- `packages.config` projects are not covered. To delete a package, delete the pacakge folder from `packages` folder
- `nuget.exe` commands are not covered


## Solution Overview

From ideas described in [this comment](https://github.com/NuGet/Home/issues/5713#issuecomment-320560636), the following command options will delete an specific package. Exmples are listed below.

Delete a package from cache with an specific version:

```
dotnet nuget locals global-packages --clear --package a --version 1.3
```

Delete all package versions from cache:

```
dotnet nuget locals global-packages --clear --package a
```

Delete all versions of multiple packages:

```
dotnet nuget locals http-cache --clear --package a
dotnet nuget locals http-cache --clear --package b
dotnet nuget locals http-cache --clear --package c
dotnet nuget locals http-cache --clear --package d
```

Delete all versions of multiple packages (version 2):

```
dotnet nuget locals global-packages -clear -packages a,b,c,d,e
```

### Implementation details

1. Add command definitions at [src\NuGet.Core\NuGet.CommandLine.XPlat\Commands\LocalsCommand.cs](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.CommandLine.XPlat/Commands/LocalsCommand.cs)
1. Modify [src\NuGet.Core\NuGet.Commands\CommandRunners\LocalsCommandRunner.cs](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.Commands/CommandRunners/LocalsCommandRunner.cs) to delete an specific package 
1. Update help in `dotnet nuget locals` command


## Test Strategy

Add a test in `Dotnet.Integration.Test` project


## Future Work

Follow up on:

- https://github.com/NuGet/Home/issues/4980: A better clean-up cache policy
- https://github.com/NuGet/Home/issues/8204: Delete package from Visual Studio

### References

- Clear one package on StackOverflow. [Link](https://stackoverflow.com/questions/49935118/clear-just-one-package-from-npm-cache)
