# Spec Name

* Status: In Review
* Author(s): [Martin Ruiz](https://github.com/martinrrm)
* Issue: [4699](https://github.com/NuGet/Home/issues/4699) dotnet add package - support for NuGet "Pre" version

## Problem Background

Customers want to add the latest version of a package to their project, even if the latest version is prerelease.

## Who are the customers

All dotnet.exe customers

## Goals

Allow dotnet CLI users to install the latest version of a NuGet package, including prerelease versions. This can be accomplished by adding an option to the existing command `add package` that enables installing the last version, including prerelease versions.

## Non-Goals

## Solution

Add the option `--prerelease` in the command `add package`. This command will get the latest version of the package available even if it is not a stable version.

When searching for the latest version available, only listed packages will be considered.

### Scenarios

Packages available

```
Contoso.Library 2.0.0
Contoso.Library 3.0.0
Contoso.Library 3.3.1-preview.3
```

| Command | Result | Description |
|---------|--------|--------------|
| `dotnet.exe add Contoso.Library` | 3.0.0 | latest stable version of package |
| `dotnet.exe add Contoso.Library --prerelease` | 3.3.1-preview.3 | latest version of package |
| `dotnet.exe add Contoso.Library --prerelease --version 3.0.0` | error | The user cannot use this commands at the same time |

Packages available

```
Contoso.Library 2.0.0
Contoso.Library 3.0.0
Contoso.Library 3.3.1-preview.3
Contoso.Library 3.4.0
```

| Command | Result | Description |
|---------|--------|--------------|
| `dotnet.exe add Contoso.Library` | 3.4.0 | latest stable version of package |
| `dotnet.exe add Contoso.Library --prerelease` | 3.4.0 | latest version of package |

## Future Work

* When the design has been approved, we will create an issue with the [dotnet.exe team](https://github.com/dotnet/sdk)

## Open Questions

* Do we need to add a shorthand version for prerelease? `--p`

## Considerations

### References

* [dotnet add package reference](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-add-reference)
