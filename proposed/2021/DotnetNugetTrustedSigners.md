# dotnet nuget trusted-signers command

- Author Name [Kat Marchan (@zkat)](https://github.com/zkat)
- Start Date 2021-03-04
- GitHub Issue: https://github.com/NuGet/Home/issues/10634
- GitHub PR: https://github.com/NuGet/Home/pull/10628

## Summary

This specifies the syntax and behavior for the `dotnet nuget trusted-signers` command.

## Motivation

This is part of a larger effort to reach full parity between `nuget` and
`dotnet` for NuGet-related operations.

## Explanation

### Functional explanation

#### `dotnet nuget trusted-signers`

```
Provides the ability to manage the list of trusted signers.

USAGE:
    dotnet nuget trusted-signers [OPTIONS] [COMMAND]

COMMANDS:
    list (default)
    trust-package <name> <package>...
    trust-source <name> [source-url]
    trust-certificate <name> <fingerprint>
    remove <name>
    sync <name>
```

#### `dotnet nuget trusted-signers list`

```
Lists all the trusted signers in the configuration. This option will include all the certificates (with fingerprint and fingerprint algorithm) each signer has. If a certificate has a preceding [U], it means that certificate entry has allowUntrustedRoot set as true.

USAGE:
    dotnet nuget trusted-signers [OPTIONS] list

OPTIONS:
    -h, --help                          Prints help information.
    -v, --verbosity <LEVEL>             Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
        --interactive                   Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.

EXAMPLE:
    $ dotnet nuget trusted-signers list
    Registered trusted signers:

    1.   nuget.org [repository]
        Service Index: https://api.nuget.org/v3/index.json
        Certificate fingerprint(s):
            SHA256 - 0E5F38F57DC1BCC806D8494F4F90FBCEDD988B46760709CBEEC6F4219AA6157D

    2.   microsoft [author]
        Certificate fingerprint(s):
            SHA256 - 3F9001EA83C560D712C24CF213C3D312CB3BFF51EE89435D3430BD06B5D0EECE
            SHA256 - AA12DA22A49BCE7D5C1AE64CC1F3D892F150DA76140F210ABD2CBFFCA2C18A27

    3.   myUntrustedAuthorSignature [author]
        Certificate fingerprint(s):
            [U] SHA256 - 518F9CF082C0872025EFB2587B6A6AB198208F63EA58DD54D2B9FF6735CA4434
```

#### `dotnet nuget trusted-signers sync`

```
Requests the latest list of certificates used in a currently trusted repository to update the the existing certificate list in the trusted signer.

Note: This gesture will delete the current list of certificates and replace them with an up-to-date list from the repository.

USAGE:
    dotnet nuget trusted-signers sync [OPTIONS] <name>

OPTIONS:
    -h, --help                          Prints help information.
    -v, --verbosity <LEVEL>             Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
        --interactive                   Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.
```

#### `dotnet nuget trusted-signers remove`

```
Removes any trusted signers that match the given name.

USAGE:
    dotnet nuget trusted-signers remove [OPTIONS] <name>

OPTIONS:
    -h, --help                          Prints help information.
    -v, --verbosity <LEVEL>             Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
        --interactive                   Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.
```

#### `dotnet nuget trusted-signers trust-package`

```
Adds a trusted signer with the given name to the config, based on one or more packages.

USAGE:
    dotnet nuget trusted-signers trust-package [OPTIONS] <name> <package>...

OPTIONS:
        --allow-untrusted-root          Specifies if the certificate for the trusted signer should be allowed to chain to an untrusted root.
        --author                        Specifies that the author signature of the package(s) should be trusted. This option is mutually exclusive with --repository.
        --repository                    Specifies that the repository signature or countersignature of the package(s) should be trusted. This option is mutually exclusive with --author.
        --owners                        Semi-colon separated list of trusted owners to further restrict the trust of a repository. Only valid when using the --repository option.
    -h, --help                          Prints help information.
    -v, --verbosity <LEVEL>             Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
        --interactive                   Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.
```

#### `dotnet nuget trusted-signers trust-certificate`

```
Adds a trusted signer with the given name to the config, based on a certificate fingerprint.

Note: If a trusted signer with the given name already exists, the certificate item will be added to that signer. Otherwise a trusted author will be created with a certificate item from given certificate information.

USAGE:
    dotnet nuget trusted-signers trust-certificate [OPTIONS] <name> <fingerprint>

OPTIONS:
        --allow-untrusted-root          Specifies if the certificate for the trusted signer should be allowed to chain to an untrusted root.
        --algorithm                     Specifies the hash algorithm used to calculate the certificate fingerprint. Defaults to SHA256. Values supported are SHA256, SHA384 and SHA512
    -h, --help                          Prints help information.
    -v, --verbosity <LEVEL>             Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
        --interactive                   Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.
```

#### `dotnet nuget trusted-signers trust-source`

```
Adds a trusted signer based on a given source.

If only `<name>` is provided without `<source-url>`, the package source from your NuGet configuration files with the same name will be added to the trusted list.

If a `<source-url>` is provided, it MUST be a v3 package source URL (like https://api.nuget.org/v3/index.json). Other source types are not supported.

USAGE:
    dotnet nuget trusted-signers trust-source <name> [source-url]

OPTIONS:
        --allow-untrusted-root          Specifies if the certificate for the trusted signer should be allowed to chain to an untrusted root.
        --owners                        Semi-colon separated list of trusted owners to further restrict the trust of a repository.
    -h, --help                          Prints help information.
    -v, --verbosity <LEVEL>             Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
        --interactive                   Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.

```

### Technical explanation

For the most part, these commands map pretty directly to their nuget
counterparts, and most of their implementations should be reusable (removing
`#if IS_DESKTOP` as needed, from the various TrustedSigners classes).

The exception here is the `add` command, which has been split into the various
`trust-*` commands that otherwise have the same behaviors.

I don't know if there's any significant implementation above just remapping
command invocations for dotnet.

## Drawbacks

This whole feature is very complicated, but it's important for parity.

## Rationale and alternatives

I think the only one that might have a reasonable alternative here would be
the `add` command. I found the command as a whole to be inscrutable, and thus
decided splitting its behavior to be the best way forward. We could have, of
course, mostly just copied the behavior from `nuget trusted-signers add`.

## Prior Art

This spec is based on [`nuget trusted-signers`](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-trusted-signers).

## Unresolved Questions

Is this the right UX? Does the naming make sense? This is a fairly complex/complicated feature and we want to make sure we deliver something to customers that makes sense and gives an overall good experience.

## Future Possibilities

N/A
