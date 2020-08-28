# Spec Name

- Status: In Review
- Author(s): [Kat Marchán](https://github.com/zkat)
- Issue: [9010](https://github.com/NuGet/Home/issues/9010) Signing: Design dotnet package signing commands

## Problem Background

We recently released [cross-platform signature verification during
restore](#todo) for `dotnet.exe`. This means `dotnet.exe` users are going to
start relying on this feature during restore for security. Unfortunately,
`nuget.exe` has some signing-related commands that are not yet available in
`dotnet.exe`, making the experience essentially incomplete for these
customers.

## Who are the customers

This feature is for `dotnet.exe` users who want to take advantage of more
package signing-related features of nuget without needing to install
`nuget.exe`.

## Goals

Design and implement equivalent commands for the following `nuget.exe` commands:

- `nuget.exe sign`
- `nuget.exe verify`
- `nuget.exe trusted-signers`

These commands should have `dotnet.exe`-compatible syntax and ergonomics, and
feel like proper `dotnet.exe` commands.

## Non-Goals

Adding additional signing-related commands, or significantly
changing/improving the behavior of the commands as currently designed.

## Solution

The following commands will be implemented in the `dotnet.exe` CLI.

Options marked with `*` indicate a notable change in behavior/naming.

### `dotnet nuget sign`

```
Signs a NuGet package at <package-path> with the specified certificate.

USAGE:
    dotnet nuget sign [OPTIONS] <package-path>

OPTIONS:
    -o, --output* <output-directory>    Directory where the signed package should be saved. By default, the original package is overwritten by the signed package.
        --certificate-path              File path to the certificate to be used while signing the package.
        --certificate-store-name        Name of the X.509 certificate store. (...)
        --certificate-store-location    Name of the X.509 certificate store to use to search for the certificate.
        --certificate-subject-name      Subject name of the certificate used to search a local certificate store for the certificate.
        --certificate-fingerprint       SHA-1 fingerprint of the certificate used to search a local certificate store for the certificate.
        --certificate-password          Password for the certificate, if needed.
        --hash-algorithm                Hash algorithm to be used to sign the package. Defaults to SHA256.
        --timestamper                   URL to an RFC 3161 timestamping server.
        --timestamp-hash-algorithm      Hash algorithm to be used by the RFC 3161 timestamping server. Defaults to SHA256.
        --overwrite                     Switch to indicate if the current signature should be overwritten.
    -h, --help                          Prints help information.
    -v, --verbosity* <LEVEL>            Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
        --interactive*                  Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.

EXAMPLES:

    dotnet nuget sign --timestamper https://foo.bar MyPackage.nupkg

    dotnet nuget sign --timestamper https://foo.bar --output ../signed ../MyPackage.nupkg
```

Notable deviations from `nuget.exe` version:

- No `-ForceEnglishOutput` equivalent. `dotnet.exe` doesn't seem to do this at all.
- Use MSBuild verbosity levels for `--verbosity` instead of NuGet levels.
- Use `--interactive` instead of `--non-interactive`, because that's how `dotnet.exe` does it.
- Use `--output` instead of `--output-directory` for consistency with `dotnet.exe`.

### `dotnet nuget verify`

```
Verifies a signed NuGet package at <package-path>.

USAGE:
    dotnet nuget verify [OPTIONS] <package-path>...*

OPTIONS:
        --all*                                  Specifies that all verifications possible should be performed on the package(s). By default, only signatures are verified.
        --certificate-fingerprint <fingerprint> Verify that the signer certificate matches with one of the specified SHA256 fingerprints. This option may be supplied multiple times to provide multiple fingerprints.
    -h, --help                                  Prints help information.
        --interactive*                          Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.
```

Notable deviations from `nuget.exe` version:

- `-Signatures` has been removed and is now default. Use `--all` to perform `-All`.
- Multiple position arguments can be passed in to verify multiple packages, instead of only supporting globbing.
- No `-ForceEnglishOutput` equivalent. `dotnet.exe` doesn't seem to do this at all.
- Use MSBuild verbosity levels for `--verbosity` instead of NuGet levels.
- Use `--interactive` instead of `--non-interactive`, because that's how `dotnet.exe` does it.

## Future Work

For now, we're not doing `trusted-signer`, and specifying all the behavior
probably deserves its own spec because of the complexity of the command and
the ergonomic expectations of `dotnet.exe`. Below is an initial stab at a
design that should NOT be considered normative, but establishes some
direction. Most notably, it splits the very complicated `add`, which has
multiple gestures, into multiple, more specific subcommands with their own
options and behavior.

### `dotnet nuget trusted-signer`

```
Provides the ability to manage the list of trusted signers.

USAGE:
    dotnet nuget trusted-signer [OPTIONS] [COMMAND]

COMMANDS:
    list (default)
    add-repository <name> <repository> [<package>...]
    add-author <name> <author> [<package>...]
    add-service-index <name> <index>
    add-certificate <name> <fingerprint>
    remove <name>
    sync <name>
```

## Open Questions

Is there any precedent at all in `dotnet.exe` for a `--config-file` option? Anywhere?

## Considerations

### References
