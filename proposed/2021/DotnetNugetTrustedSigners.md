# dotnet nuget trust command

- Author Name [Kat Marchan (@zkat)](https://github.com/zkat)
- Start Date 2021-03-04
- GitHub Issue: https://github.com/NuGet/Home/issues/10634
- GitHub PR: https://github.com/NuGet/Home/pull/10628

## Summary

This specifies the syntax and behavior for the `dotnet nuget trust` command.

## Motivation

This is part of a larger effort to reach full parity between `nuget` and
`dotnet` for NuGet-related operations.

## Explanation

### Functional explanation

#### `> dotnet nuget trust`

```
Manage the trusted signers. By default, NuGet accepts all authors and repositories. You can restrict this to just authors or repositories you trust using this command.

USAGE:
    dotnet nuget trust [COMMAND] [OPTIONS]

COMMANDS:
    list
    author <name> <package>...
    repository <name> <package>...
    source <name> [source-url]
    certificate <name> <fingerprint>
    remove <name>
    sync <name>
```

#### `> dotnet nuget trust list`

```
Lists all the trusted signers in the configuration. This option will include all the certificates (with fingerprint and fingerprint algorithm) each signer has. If a certificate has a preceding [U], it means that certificate entry has allowUntrustedRoot set as true.

USAGE:
    dotnet nuget trust list [OPTIONS]

EXAMPLE:
    $ dotnet nuget trust list
    Registered trusted signers:

    1.   nuget.org [repository]
        Service Index: https://api.nuget.org/v3/index.json
        Owners: microsoft, aspnet, nuget
        Certificate fingerprint(s):
            SHA256 - 0E5F38F57DC1BCC806D8494F4F90FBCEDD988B46760709CBEEC6F4219AA6157D

    2.   microsoft [author]
        Certificate fingerprint(s):
            SHA256 - 3F9001EA83C560D712C24CF213C3D312CB3BFF51EE89435D3430BD06B5D0EECE
            SHA256 - AA12DA22A49BCE7D5C1AE64CC1F3D892F150DA76140F210ABD2CBFFCA2C18A27

    3.   myUntrustedAuthorSignature [author]
        Certificate fingerprint(s):
            [U] SHA256 - 518F9CF082C0872025EFB2587B6A6AB198208F63EA58DD54D2B9FF6735CA4434

OPTIONS:
    -h, --help                          Prints help information.
    -v, --verbosity <LEVEL>             Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
        --interactive                   Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.
```

#### `> dotnet nuget trust sync`

```
Requests the latest list of certificates used in a currently trusted repository to update the the existing certificate list in the trusted signer.

Note: This gesture will delete the current list of certificates and replace them with an up-to-date list from the repository.

USAGE:
    dotnet nuget trust sync [OPTIONS] <name>

OPTIONS:
    -h, --help                          Prints help information.
    -v, --verbosity <LEVEL>             Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
        --interactive                   Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.
```

#### `> dotnet nuget trust remove`

```
Removes any trusted signers that match the given name.

USAGE:
    dotnet nuget trust remove [OPTIONS] <name>

OPTIONS:
    -h, --help                          Prints help information.
    -v, --verbosity <LEVEL>             Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
        --interactive                   Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.
```

#### `> dotnet nuget trust author`

```
Adds a trusted signer with the given name to the config, based on the author signature(s) of one or more packages. If <name> already exists in the configuration, the signature(s) will be appended.

USAGE:
    dotnet nuget trust author [OPTIONS] <name> <package>...

EXAMPLE:
    dotnet nuget trust author Contoso ./contoso.library.nupkg

OPTIONS:
        --allow-untrusted-root          Specifies if the certificate for the trusted signer should be allowed to chain to an untrusted root.
    -h, --help                          Prints help information.
    -v, --verbosity <LEVEL>             Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
        --interactive                   Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.
```

##### NOTE

For `trust author` and `trust repository`, `<package>` may be a glob/wildcard.
This must be consistent across platforms, so the Windows version must expand
these wildcards when it receives them as arguments.

#### `> dotnet nuget trust repository`

```
Adds a trusted signer with the given name to the config, based on the repository signature(s) or countersignature(s) of one or more packages. If <name> already exists in the configuration, the signature(s) will be appended.


USAGE:
    dotnet nuget trust repository [OPTIONS] <name> <package>...

EXAMPLE:
    dotnet nuget trust repository Contoso ./contoso.library.nupkg

OPTIONS:
        --allow-untrusted-root          Specifies if the certificate for the trusted signer should be allowed to chain to an untrusted root.
        --owners                        Semi-colon separated list of trusted owners to further restrict the trust of a repository.
    -h, --help                          Prints help information.
    -v, --verbosity <LEVEL>             Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
        --interactive                   Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.
```

##### NOTE

For `trust author` and `trust repository`, `<package>` may be a glob/wildcard.
This must be consistent across platforms, so the Windows version must expand
these wildcards when it receives them as arguments.

#### `> dotnet nuget trust certificate`

```
Adds a trusted signer with the given name to the config, based on a certificate fingerprint.

Note: If a trusted signer with the given name already exists, the certificate item will be added to that signer. Otherwise a trusted author will be created with a certificate item from given certificate information.

USAGE:
    dotnet nuget trust certificate [OPTIONS] <name> <fingerprint>

OPTIONS:
        --allow-untrusted-root          Specifies if the certificate for the trusted signer should be allowed to chain to an untrusted root.
        --algorithm                     Specifies the hash algorithm used to calculate the certificate fingerprint. Defaults to SHA256. Values supported are SHA256, SHA384 and SHA512
    -h, --help                          Prints help information.
    -v, --verbosity <LEVEL>             Set the MSBuild verbosity level. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
        --interactive                   Allows command to stop and wait for user input or action.
        --configfile                    The NuGet configuration file. If specified, only the settings from this file will be used. If not specified, the hierarchy of configuration files from the current directory will be used.
```

#### `> dotnet nuget trust source`

```
Adds a trusted signer based on a given package source.

If only `<name>` is provided without `<source-url>`, the package source from your NuGet configuration files with the same name will be added to the trusted list.

If a `<source-url>` is provided, it MUST be a v3 package source URL (like https://api.nuget.org/v3/index.json). Other package source types are not supported.

If <name> already exists in the configuration, the package source will be appended to it.

USAGE:
    dotnet nuget trust source <name> [source-url]

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

The exception here is the `add` command, which has been split into separate
commands that otherwise have the same behaviors, since options and semantics
can vary significantly.

I don't know if there's any significant implementation above just remapping
command invocations for dotnet.

Additionally, `trust author` and `trust repository` must both not just accept
multiple `<package>` arguments, but must manually expand globbed arguments on
Windows, since powershell and cmd.exe don't do glob/wildcard expansions at the
shell level like \*nix shells do.

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
