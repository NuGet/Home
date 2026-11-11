# NuGet Package Staging CLI

- [Nigusu](https://github.com/Nigusu-Allehu)
- [GitHub Issue #15014](https://github.com/NuGet/Home/issues/15014)

## Summary

`dotnet package stage push` uploads a NuGet package or symbols package to a source's private staging service without publishing it.
It can assign the upload to an existing staging group and automatically upload a sibling symbols package.

This document describes the initial implementation merged in [NuGet/NuGet.Client#7712](https://github.com/NuGet/NuGet.Client/pull/7712), using the protocol foundation from [NuGet/NuGet.Client#7703](https://github.com/NuGet/NuGet.Client/pull/7703).

## Motivation

Publishers need to upload packages privately before making them available to consumers.
A dedicated staging command gives CI systems an explicit upload operation separate from ordinary publication.

## Explanation

### Functional explanation

#### Command

```text
dotnet package stage push <PACKAGE_PATH>
    [-s|--source <SOURCE>]
    [-k|--api-key <API_KEY>]
    [--group <GROUP_ID>]
    [--no-symbols]
    [--configfile <FILE>]
    [--interactive]
```

##### Argument

`<PACKAGE_PATH>` is one existing `.nupkg`, `.snupkg`, or legacy `.symbols.nupkg` file.
File-extension matching is case-insensitive.
The CLI validates the path and supported extension before accessing the source.
The file extension selects the package or symbols upload operation.

##### Options

| Option | Behavior |
| --- | --- |
| `-s|--source <SOURCE>` | Configured source name or V3 service-index URL. Defaults to `DefaultPushSource`; fails if neither is supplied. |
| `-k|--api-key <API_KEY>` | API key for the staging service. Takes precedence over the environment variable and configured keys. |
| `--group <GROUP_ID>` | Sends the group ID with each upload. The CLI assumes the group exists and does not look it up or create it. |
| `--no-symbols` | Disables automatic discovery and upload of a sibling symbols package. A symbols file supplied directly is still uploaded. |
| `--configfile <FILE>` | Uses only the specified NuGet configuration file. Without it, uses the normal configuration hierarchy for the current working directory. |
| `--interactive` | Allows NuGet credential providers to prompt for credentials. |

When supplied, a group ID must be 1-64 ASCII letters, digits, periods, underscores, or hyphens, beginning and ending with a letter or digit.
The CLI rejects invalid IDs before accessing the source and sends valid IDs unchanged.

##### Package and symbols behavior

For a `.nupkg`, the CLI uploads the package first.
After a successful package upload, unless `--no-symbols` is set, it looks in the same directory for a symbols file with the same filename stem.
It prefers `.snupkg`, falling back to `.symbols.nupkg` only when the matching `.snupkg` does not exist.

A directly supplied `.snupkg` or `.symbols.nupkg` is uploaded only to the symbols endpoint.
When `--group` is supplied, the same group ID is included in both package and sibling-symbol uploads.

If the package upload fails, no sibling-symbol upload is attempted.
If the package succeeds but its sibling-symbol upload fails, the package remains staged; the CLI reports the package success and symbols failure and returns exit code `1`.
It does not roll back the package upload.

The command completes after the upload requests succeed; it does not wait for server-side validation.

##### Examples

Upload a package and its sibling symbols package, if present:

```console
dotnet package stage push artifacts/Contoso.1.0.0.nupkg --source StagingFeed
```

Upload only the package into an existing group:

```console
dotnet package stage push artifacts/Contoso.1.0.0.nupkg --source StagingFeed --group august-release --no-symbols
```

Upload symbols directly:

```console
dotnet package stage push artifacts/Contoso.1.0.0.snupkg --source StagingFeed
```

### Technical explanation

#### Protocol and authentication

##### Discovery and HTTPS

The CLI discovers `PackageStaging/1.0.0` from the selected source's V3 service index.
For example:

```json
{
  "@type": "PackageStaging/1.0.0",
  "@id": "https://api.example.com/v3/staging/"
}
```

A source without this resource fails the command.
Both the source URL and discovered upload endpoint reject insecure HTTP.
There is no CLI option to allow insecure connections.

##### Credentials

The CLI resolves the API key in this order:

1. `--api-key`.
2. `NUGET_API_KEY`.
3. NuGet configuration, looking up the discovered staging resource URL first, then the source URL, with the existing NuGet.org API-key fallback.

The same key is used for package and symbols uploads.
A non-empty resolved key is sent as `X-NuGet-ApiKey`; without one, the header is omitted.
The CLI does not validate API-key permissions or select an owner.
Authorization is enforced by the service, and credential-provider interaction follows the `--interactive` setting.

##### Upload requests

| Artifact | Method and route relative to the discovered resource | File form part |
| --- | --- | --- |
| Package | `PUT package` | `package` |
| Symbols | `PUT symbols` | `symbols` |

Each upload is a separate `multipart/form-data` request containing one file and, when supplied, a `groupId` field.
Package and symbols files are never combined in one request.
The CLI makes no preliminary existence check; replacement and duplicate-upload behavior are determined by the service.
Each request uses a five-minute timeout and the existing NuGet `HttpSource` retry handling.

The [companion upload contract](package-staging-api-contract-md.md) describes the request details and response handling used by this implementation.

#### Output and errors

The command writes human-readable package and symbols upload outcomes.
It returns exit code `0` on success and `1` for invalid arguments or failed operations, including a failed sibling-symbol upload.

Any `2xx` upload response is accepted as success.
The CLI does not read or validate the response body and does not display server-side validation status.
Non-success responses use existing NuGet HTTP diagnostics and retry handling; the CLI does not parse staging-specific JSON error codes or messages.

## Prior Art

This design builds on [`Release staging and deprecation`](https://github.com/NuGet/Home/pull/12874) and the [refreshed NuGet staging proposal](https://github.com/NuGet/Home/pull/14978).
