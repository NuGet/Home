# Spec Name

* Status: In Review
* Author(s): [Martin Ruiz](https://github.com/martinrrm)
* Issue: [4699](https://github.com/NuGet/Home/issues/4699) dotnet add package - support for NuGet "Pre" version

## Problem Background

Customers want to add the latest version of a package to their project, even tough it is a prerelease version.

## Who are the customers

All dotnet.exe customers

## Goals

Add an option to the command `add package` enable installing latest prerelease version.

## Non-Goals

## Solution

Add the option `--prerelease` in the command `add package`. This command should get the latest version of the packet available even if it is not a stable version.

```package 2.0.0
package 3.0.0
package 3.3.1-preview.3
```

| Command | Result | Description |
|---------|--------|--------------|
| `dotnet.exe add package` | 3.0.0 | latest stable version of package |
| `dotnet.exe add package --prerelease` | 3.3.1-preview.3 | latest version of package |
| `dotnet.exe add package --prerelease --version 3.0.0` | error | The user cannot use this commands at the same time |

```package 2.0.0
package 3.0.0
package 3.3.1-preview.3
package 3.4.0
```

| Command | Result | Description |
|---------|--------|--------------|
| `dotnet.exe add package` | 3.4.0 | latest stable version of package |
| `dotnet.exe add package --prerelease` | 3.4.0 | latest version of package |

## Future Work

## Open Questions

## Considerations

### References

* <https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-add-reference>
