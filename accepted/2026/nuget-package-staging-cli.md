# NuGet Package Staging CLI

- [Nigusu](https://github.com/Nigusu-Allehu)
- [GitHub Issue #15014](https://github.com/NuGet/Home/issues/15014)

## Summary

Add a `dotnet nuget stage` command family for preparing NuGet packages without publishing them immediately.
The CLI allows users and CI systems to upload packages to private staging, list and inspect staged packages, organize packages into release groups, and delete staged content.
Promotion is excluded from the initial CLI and remains a NuGet Gallery action.

## Motivation

`dotnet nuget push` sends a package directly into the public publication pipeline.
Publishers cannot use it to privately upload and validate packages before a release, discover validation failures early, or prepare a coordinated release group.

The staging server introduces a private package lifecycle, but users need an automation-friendly CLI to operate it.
The expected outcome is that publishers can prepare and validate packages before release day, privately organize related packages, and retain an explicit human approval boundary before publication.

This proposal focuses on the CLI parts of package staging.
It builds on the earlier [`Release staging and deprecation`](https://github.com/NuGet/Home/pull/12874) design and the [`refreshed NuGet staging proposal`](https://github.com/NuGet/Home/pull/14978).

## Explanation

### Functional explanation

The feature introduces a separate command family:

```text
dotnet nuget stage
|-- push <PACKAGE_PATH> [--group <GROUP_ID>] [--unlisted]
|-- list [--kind <package|symbols>]
|-- view <PACKAGE_ID@VERSION> [--kind <package|symbols>]
|-- delete <PACKAGE_ID@VERSION> [--kind <package|symbols>]
`-- group
    |-- create <GROUP_ID> [--name <DISPLAY_NAME>] [--kind <package|symbols>]
    |-- list [--kind <package|symbols>]
    |-- add <GROUP_ID> <PACKAGE_ID@VERSION> [--kind <package|symbols>]
    |-- remove <GROUP_ID> <PACKAGE_ID@VERSION> [--kind <package|symbols>]
    `-- delete <GROUP_ID> [--kind <package|symbols>]
```

#### Common options

**`-s|--source <SOURCE>`**

The source may be a configured source name or a V3 service-index URL.
If omitted, the CLI uses `DefaultPushSource`.
The command fails before making a staging request when neither is available.

**`-k|--api-key <API_KEY>`**

The API key is used to authenticate with the staging resource.
API-key resolution and precedence are defined in the technical explanation.

**`--configfile <FILE>`**

When `--configfile` is supplied, only that NuGet configuration file is used.
Otherwise, the normal configuration hierarchy is used.

**`--interactive`**

`--interactive` allows NuGet credential providers to prompt while accessing the selected source or staging resource.

**`--allow-insecure-connections`**

HTTP sources are rejected unless `--allow-insecure-connections` is supplied.
The CLI warns when this option is used.

**`--format <console|json>`**

`console` is the default, and `json` selects the machine-readable CLI contract.

#### Commands

##### **`stage push`**

**Synopsis**

```text
dotnet nuget stage push <PACKAGE_PATH> [--group <GROUP_ID>] [--unlisted]
```

**Options**

- **`--group <GROUP_ID>`** uploads the artifact directly into the specified package or symbol group based on the file extension.
- **`--unlisted`** sets the package's listed intent to `false`.
  This option is valid only when uploading a `.nupkg`.
  Using it with a `.snupkg` fails before a staging request is sent.

`dotnet nuget stage push` uploads one `.nupkg` or `.snupkg` to private staging.
It returns when the server accepts the upload and does not wait for validation to finish.
Each invocation uploads exactly one artifact.
The file extension selects the package or symbol staging endpoint.

Package uploads use a listed intent of `true` by default.
`--unlisted` changes that intent to `false`.
Listed intent does not affect the privacy of staged content; it determines whether the
package is listed if it is later promoted and published.

```console
dotnet nuget stage push artifacts/Contoso.1.0.0.nupkg
dotnet nuget stage push artifacts/Contoso.1.0.0.nupkg --unlisted
```

Symbols can be uploaded directly:

```console
dotnet nuget stage push artifacts/Contoso.1.0.0.snupkg
```

An artifact can be uploaded directly into a group of the corresponding kind:

```console
dotnet nuget stage push artifacts/Contoso.1.0.0.nupkg \
  --group august-release

dotnet nuget stage push artifacts/Contoso.1.0.0.snupkg \
  --group august-release
```

##### **`stage list`**

**Synopsis**

```text
dotnet nuget stage list [--kind <package|symbols>]
```

**Options**

- **`--kind <package|symbols>`** selects packages or symbols and defaults to `package`.

`dotnet nuget stage list` returns the complete artifact inventory for the selected kind visible to the supplied API key.
Each entry contains the artifact ID and version.
The command automatically requests every page before producing a successful result.

```console
dotnet nuget stage list
dotnet nuget stage list --kind symbols
```

Group summaries are available separately through `dotnet nuget stage group list`.
Each group summary contains group metadata and an artifact count, but not membership.

##### **`stage view`**

**Synopsis**

```text
dotnet nuget stage view <PACKAGE_ID@VERSION> [--kind <package|symbols>]
```

`--kind` defaults to `package`.
`dotnet nuget stage view` displays the detailed server-provided state for one artifact:

```console
dotnet nuget stage view Contoso@1.0.0
dotnet nuget stage view Contoso@1.0.0 --kind symbols
```

##### **`stage delete`**

**Synopsis**

```text
dotnet nuget stage delete <PACKAGE_ID@VERSION> [--kind <package|symbols>]
```

**Options**

- **`--kind <package|symbols>`** selects the artifact kind and defaults to `package`.

Staged content can be deleted by identity.
Symbols can be deleted independently while leaving the parent package staged:

```console
dotnet nuget stage delete Contoso@1.0.0
dotnet nuget stage delete Contoso@1.0.0 --kind symbols
```

Package, symbol, and group deletion do not prompt for confirmation.
Authentication and authorization are enforced by the server.

##### **`stage group create`**

**Synopsis**

```text
dotnet nuget stage group create <GROUP_ID> [--name <DISPLAY_NAME>] [--kind <package|symbols>]
```

**Options**

- **`--name <DISPLAY_NAME>`** assigns a human-readable display name to the group.
  When omitted, the display name defaults to `<GROUP_ID>`.
- **`--kind <package|symbols>`** selects the group kind and defaults to `package`.

Groups use a user-selected, immutable ID for commands and API routes.
The CLI always sends both the group ID and display name in the create request.
Package and symbol groups are independent.
The same group ID may exist once for each kind.
The CLI requires a non-empty group ID and URL-escapes it.
The server validates group ID syntax, normalization, uniqueness, and reserved values.

```console
dotnet nuget stage group create august-release \
  --name "August Release"
```

##### **`stage group list`**

**Synopsis**

```text
dotnet nuget stage group list [--kind <package|symbols>]
```

`--kind` defaults to `package`.
`dotnet nuget stage group list` returns summaries for the selected group kind without membership details.

##### **`stage group add`**

**Synopsis**

```text
dotnet nuget stage group add <GROUP_ID> <PACKAGE_ID@VERSION> [--kind <package|symbols>]
```

`--kind` defaults to `package`.
An existing staged artifact can be added or moved to a group:

```console
dotnet nuget stage group add august-release Contoso@1.0.0
dotnet nuget stage group add august-release Contoso@1.0.0 --kind symbols
```

##### **`stage group remove`**

**Synopsis**

```text
dotnet nuget stage group remove <GROUP_ID> <PACKAGE_ID@VERSION> [--kind <package|symbols>]
```

`--kind` defaults to `package`.
`group remove` removes an artifact from the selected group:

```console
dotnet nuget stage group remove august-release Contoso@1.0.0
dotnet nuget stage group remove august-release Contoso@1.0.0 --kind symbols
```

##### **`stage group delete`**

**Synopsis**

```text
dotnet nuget stage group delete <GROUP_ID> [--kind <package|symbols>]
```

`--kind` defaults to `package`.
`group delete` sends one request to delete the selected group.
The server defines this operation as deleting the group and all staged artifacts in it;
the CLI does not enumerate or delete group members individually.

```console
dotnet nuget stage group delete august-release
```

### Technical explanation

#### Protocol resource

The CLI discovers a supported `PackageStaging` resource from the selected source's V3 service index using standard NuGet resource-provider selection.
The first supported contract is:

```json
{
  "@type": "PackageStaging/1.0.0",
  "@id": "https://api.example.com/v3/staging/"
}
```

If the source does not advertise a supported staging resource, the command fails.
It must never fall back to `PackagePublish/2.0.0` or invoke ordinary push, because doing so could publish content that the caller intended to keep private.

The implementation should introduce equivalents of:

```text
PackageStagingResource
PackageStagingResourceV3Provider
StageRunner
```

The staging implementation reuses existing NuGet infrastructure for source resolution, V3 service-index access, API-key lookup, HTTPS enforcement, `HttpSource`, HTTP upload handling, timeout handling, logging, cancellation, and secret redaction.

#### Authentication and ownership

API-key resolution uses:

```text
-k|--api-key
NUGET_STAGE_API_KEY
NuGet.config key for the staging endpoint
```

`NUGET_API_KEY` is not used by staging commands.
The NuGet.config key is mapped to the `@id` of the discovered `PackageStaging` resource.
The same staging API key is used for package and symbol operations.
The CLI treats the API key as opaque and provides no `--owner` or `--organization` option.
The credential must carry the dedicated staging permission.
Ordinary push permission does not imply staging permission.
The CLI sends the resolved key in the `X-NuGet-ApiKey` header.
Trusted Publishing must exchange its identity token for a short-lived staging API key before invoking the command.

Because staged content is private, list and view operations require authentication and return only content the authenticated identity is authorized to access.

#### API mapping

The server-side design is defined in the [`PackageStaging/1.0.0` API contract](https://devdiv.visualstudio.com/DevDiv/_git/NuGet.Services?path=/docs/specs/2026/StagingAPIContracts.md&version=GBjaparson/staging-spec&_a=preview).
Derived from that design, the CLI's own expected request and response contract for each route is specified in [`package-staging-api-contract-md.md`](package-staging-api-contract-md.md).
The following table maps the CLI commands to those server operations.

| CLI command | Server operation |
| --- | --- |
| `stage push <nupkg> [--unlisted]` | `PUT package` |
| `stage push <snupkg>` | `PUT symbols` |
| `stage list --kind package` | `GET package` |
| `stage list --kind symbols` | `GET symbols` |
| `stage view <id@version> --kind package` | `GET package/{id}/{version}` |
| `stage view <id@version> --kind symbols` | `GET symbols/{id}/{version}` |
| `stage delete <id@version> --kind package` | `DELETE package/{id}/{version}` |
| `stage delete <id@version> --kind symbols` | `DELETE symbols/{id}/{version}` |
| `stage group create <group> --kind <kind>` | `POST groups/{kind}` |
| `stage group list --kind <kind>` | `GET groups/{kind}` |
| `stage group add <group> <id@version> --kind <kind>` | `PUT groups/{kind}/{groupId}/items/{id}/{version}` |
| `stage group remove <group> <id@version> --kind <kind>` | `DELETE groups/{kind}/{groupId}/items/{id}/{version}` |
| `stage group delete <group> --kind <kind>` | `DELETE groups/{kind}/{groupId}` |

Package and symbol uploads use separate multipart requests.
The package request sends one `.nupkg`.
When `--unlisted` is supplied, the package request includes `listed: false`.
Otherwise, the CLI omits `listed` and the server default of `true` applies.
The symbol request sends one `.snupkg`.

Artifact identities supplied on the command line use `<PACKAGE_ID>@<VERSION>`.

The CLI does not issue a preflight request or determine replacement behavior.
The server decides whether an upload creates, replaces, ignores, or rejects content.
The CLI reports the server's HTTP outcome.

#### Listing and pagination

`stage list` uses the package or symbol collection selected by `--kind`.
It returns the staged artifacts of that kind visible to the authenticated identity.
List requests use `page` and `pageSize`.
The default server page size is 100 and the maximum is 500.
The CLI requests up to 500 items per page and aggregates all returned pages into one result.
If any page fails, the command fails without returning a partial result.

The initial CLI does not expose `--page` or `--page-size` because staging inventories
are expected to be small enough for automatic aggregation.

#### Output

Console output is the default.
Structured output is selected with `--format json`.

JSON output is a versioned CLI contract rather than a direct copy of the server response.
The version 1 command combinations and output shapes are defined in [`nuget-package-staging-cli-json-output.md`](nuget-package-staging-cli-json-output.md).
This contract applies only to CLI standard output and does not define server request or response JSON.

Every command emits one document shaped like:

```json
{
  "version": 1,
  "command": "list",
  "result": {},
  "problems": []
}
```

Warnings and errors are listed in `problems`, using the same `text` and `problemType` shape as `dotnet package search`.
Failed commands return `result: null`.
Credentials and authorization headers must never appear in output, logs, or telemetry.

Commands return exit code `1` for invalid usage or when `problems` contains an `Error`.
Successful commands and commands containing only `Warning` problems return exit code `0`.

#### Errors and retries

Any `2xx` response is successful.
Non-`2xx` responses use existing `HttpSource` failure and retry handling.
The CLI does not require or parse a staging-specific error envelope.
List, view, and group-list commands deserialize successful response bodies.

## Rationale and alternatives

### Alternative: `dotnet nuget push --stage`

This would make initial upload familiar, but it cannot naturally represent listing, viewing, deletion, or group management.

## Future Possibilities

- Add `--page` and `--page-size` to `stage list` and `stage group list` if automatic
  aggregation becomes impractical for large staging inventories.
- Add `stage push --wait` with timeout and polling controls.
- Allow `stage push` to accept multiple package paths and file globs.
- Allow `stage group add` to accept a package path and upload it directly into the group.
- Add `stage push --disable-buffering` if staging measurements show meaningful memory pressure for large packages.
- Add group display-name updates.