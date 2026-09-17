# NuGet Package Staging CLI

- [Nigusu](https://github.com/Nigusu-Allehu)
- [GitHub Issue #15014](https://github.com/NuGet/Home/issues/15014)

## Summary

Add a `dotnet nuget stage` command family for preparing NuGet packages without publishing them immediately.
The CLI allows users and CI systems to upload packages to private staging, list and inspect staged packages, organize packages into release groups, and delete staged content.
Promotion is excluded from the initial CLI and remains a NuGet Gallery action.

> **Note:** Of the commands described in this proposal, only `dotnet nuget stage push` is targeted for .NET 11 RC 2, including its options and automatic sibling-symbol discovery.

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
|-- push <PACKAGE_PATH> [--group <GROUP_ID>] [--no-symbols]
|-- list [--group <GROUP_ID>]
|-- view <PACKAGE_ID@VERSION>
|-- delete <PACKAGE_ID@VERSION> [--symbols-only]
`-- group
    |-- create <GROUP_ID> [--name <DISPLAY_NAME>]
    |-- list
    |-- view <GROUP_ID>
    |-- rename <GROUP_ID> --name <DISPLAY_NAME>
    |-- add <GROUP_ID> <PACKAGE_ID@VERSION>
    |-- remove <GROUP_ID> <PACKAGE_ID@VERSION>
    `-- delete <GROUP_ID>
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

#### Commands

##### **`stage push`**

**Synopsis**

```text
dotnet nuget stage push <PACKAGE_PATH> [--group <GROUP_ID>] [--no-symbols]
```

**Options**

- **`--group <GROUP_ID>`** uploads the artifact directly into the specified group.
  The CLI assumes the user has supplied an existing group and does not verify or create it before uploading.
  The group ID must contain at least one non-whitespace character and follow `^[A-Za-z0-9](?:[A-Za-z0-9._-]{0,62}[A-Za-z0-9])?$` regular expression.
- **`--no-symbols`** prevents automatic discovery and staging of a sibling symbols package.

`dotnet nuget stage push` accepts one `.nupkg`, `.snupkg`, or legacy `.symbols.nupkg` path.
It returns when the server accepts the upload and does not wait for validation to finish.
When `<PACKAGE_PATH>` is a `.nupkg`, the CLI stages it first and, unless `--no-symbols` is supplied, looks in the same directory for a sibling symbols package with the same filename stem.
The CLI prefers `.snupkg`, falls back to `.symbols.nupkg` only when no matching `.snupkg` exists, and stages at most one symbols package in a second request.
The file extension selects the package or symbol staging endpoint.


```console
dotnet nuget stage push artifacts/Contoso.1.0.0.nupkg
```

Symbols can be uploaded directly:

```console
dotnet nuget stage push artifacts/Contoso.1.0.0.snupkg
dotnet nuget stage push artifacts/Contoso.1.0.0.symbols.nupkg
```

An artifact can be uploaded directly into a group:

```console
dotnet nuget stage push artifacts/Contoso.1.0.0.nupkg \
  --group august-release

dotnet nuget stage push artifacts/Contoso.1.0.0.snupkg \
  --group august-release
```

##### **`stage list`**

**Synopsis**

```text
dotnet nuget stage list [--group <GROUP_ID>]
```

**Options**

- **`--group <GROUP_ID>`** limits the result to artifacts in the specified group.

`dotnet nuget stage list` outputs all package and symbol artifacts returned by the staging endpoints.
The CLI does not add filtering based on whether an artifact was promoted or published.
The CLI displays staging quota information when the server provides it.
When `--group` is supplied, the CLI uses the group detail endpoint and returns all members.
The command automatically requests every page before producing a successful result.

```console
dotnet nuget stage list
dotnet nuget stage list --group august-release
```

Group summaries are available separately through `dotnet nuget stage group list`.
Each group summary contains group metadata and an artifact count, but not membership.

##### **`stage view`**

**Synopsis**

```text
dotnet nuget stage view <PACKAGE_ID@VERSION>
```

`dotnet nuget stage view` displays the detailed server-provided state for the package and symbols artifacts with the requested identity:
The command succeeds when either artifact exists and displays every artifact found.
A `404` for one artifact is treated as an absent counterpart.
The command fails when neither artifact exists or when either request fails for another reason.

```console
dotnet nuget stage view Contoso@1.0.0
```

##### **`stage delete`**

**Synopsis**

```text
dotnet nuget stage delete <PACKAGE_ID@VERSION> [--symbols-only]
```

**Options**

- **`--symbols-only`** deletes the symbols artifact while leaving the package staged.

Without `--symbols-only`, the command deletes the package and its symbols using separate requests.
With `--symbols-only`, the command deletes only the symbols artifact and leaves the package staged.
If one deletion succeeds and the other fails, the CLI reports the partial deletion and exits with code `1`.

```console
dotnet nuget stage delete Contoso@1.0.0
dotnet nuget stage delete Contoso@1.0.0 --symbols-only
```

Package, symbol, and group deletion do not prompt for confirmation.
Authentication and authorization are enforced by the server.

##### **`stage group create`**

**Synopsis**

```text
dotnet nuget stage group create <GROUP_ID> [--name <DISPLAY_NAME>]
```

**Options**

- **`--name <DISPLAY_NAME>`** assigns a human-readable display name to the group.
  When omitted, the display name defaults to `<GROUP_ID>`.

Groups use a user-selected, immutable ID for commands and API routes.
The CLI always sends both the group ID and display name in the create request.
Groups contain packages and symbols together.
The CLI requires a non-empty group ID and URL-escapes it.
The server enforces the API contract's group identity and uniqueness rules.

```console
dotnet nuget stage group create august-release \
  --name "August Release"
```

##### **`stage group list`**

**Synopsis**

```text
dotnet nuget stage group list
```

`dotnet nuget stage group list` returns group summaries without membership details.
Each summary includes the server-provided `canPromote` value and blockers explaining why promotion is unavailable.
The command automatically requests every page before producing a successful result.

##### **`stage group view`**

**Synopsis**

```text
dotnet nuget stage group view <GROUP_ID>
```

`dotnet nuget stage group view` displays the selected group's metadata and status without its members.

##### **`stage group rename`**

**Synopsis**

```text
dotnet nuget stage group rename <GROUP_ID> --name <DISPLAY_NAME>
```

`stage group rename` changes the display name without changing the immutable group ID.

##### **`stage group add`**

**Synopsis**

```text
dotnet nuget stage group add <GROUP_ID> <PACKAGE_ID@VERSION>
```

An existing staged package identity can be added or moved to a group.
The operation moves its staged symbols with it when symbols exist.
The package and symbols must both be ungrouped or belong to the same group.

```console
dotnet nuget stage group add august-release Contoso@1.0.0
```

##### **`stage group remove`**

**Synopsis**

```text
dotnet nuget stage group remove <GROUP_ID> <PACKAGE_ID@VERSION>
```

`group remove` removes a package identity and its staged symbols from the selected group without deleting the artifacts:

```console
dotnet nuget stage group remove august-release Contoso@1.0.0
```

##### **`stage group delete`**

**Synopsis**

```text
dotnet nuget stage group delete <GROUP_ID>
```

`group delete` sends one request to delete the selected group.
The server defines this operation as deleting the group and all staged artifacts in it.
The CLI does not enumerate or delete group members individually.

```console
dotnet nuget stage group delete august-release
```

### Technical explanation

#### Protocol resource

The CLI discovers `PackageStaging/1.0.0` from the selected source's V3 service index using standard NuGet resource-provider selection.
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
NUGET_API_KEY
NuGet.config API key
```

This is the same precedence used by `dotnet nuget push`: an explicit option takes priority, followed by the environment variable, followed by configured keys.
Configured API-key lookup considers both the configured source or service-index URL and the discovered `PackageStaging` resource URL, using the same fallback behavior as push.
The same staging API key is used for package and symbol operations.
The CLI treats the API key as opaque and provides no `--owner` or `--organization` option.
The credential must carry the dedicated staging permission.
Ordinary push permission does not imply staging permission.
The CLI sends the resolved key in the `X-NuGet-ApiKey` header.
Trusted Publishing must exchange its identity token for a short-lived staging API key before invoking the command.

Because staged content is private, list and view operations require authentication and return only content the authenticated identity is authorized to access.

#### API mapping

The server-side design is defined in the [`PackageStaging/1.0.0` API contract](https://devdiv.visualstudio.com/DevDiv/_git/NuGet.Services?path=/docs/specs/2026/StagingAPIContracts.md&version=GBjaparson/staging-spec&_a=preview).
Based on that design, the request and response schemas that the NuGet CLI expects for each route are defined in [`package-staging-api-contract-md.md`](package-staging-api-contract-md.md).
The following table maps the CLI commands to those server operations.

| CLI command | Server operation |
| --- | --- |
| `stage push <nupkg> [--no-symbols]` | `PUT package`, followed by `PUT symbols` when a sibling symbols package is discovered |
| `stage push <snupkg-or-symbols.nupkg>` | `PUT symbols` |
| `stage list` | `GET package` and `GET symbols` |
| `stage list --group <group>` | `GET groups/{groupId}` member collection |
| `stage view <id@version>` | `GET package/{id}/{version}` and `GET symbols/{id}/{version}` |
| `stage delete <id@version>` | `DELETE package/{id}/{version}` and `DELETE symbols/{id}/{version}` |
| `stage delete <id@version> --symbols-only` | `DELETE symbols/{id}/{version}` |
| `stage group create <group>` | `POST groups` |
| `stage group list` | `GET groups` |
| `stage group view <group>` | `GET groups/{groupId}` group metadata |
| `stage group rename <group> --name <name>` | `PATCH groups/{groupId}` |
| `stage group add <group> <id@version>` | `PUT groups/{groupId}/items/{id}/{version}` |
| `stage group remove <group> <id@version>` | `DELETE groups/{groupId}/items/{id}/{version}` |
| `stage group delete <group>` | `DELETE groups/{groupId}` |

Package and symbol uploads use separate multipart requests.
The package request contains one `package` file part and may contain a separate `groupId` form field.
The symbol request contains one `symbols` file part and may contain a separate `groupId` form field.
Package and symbol files are never combined in the same request.
When a package push discovers a sibling symbols package, the CLI waits for the package response before sending the symbols request.
If the package succeeds but the symbols request fails, the package remains staged, the CLI reports both outcomes, and the command exits with code `1`.

Artifact identities supplied on the command line use `<PACKAGE_ID>@<VERSION>`.

The CLI does not issue a preliminary existence check or determine replacement behavior.
The server decides whether an upload creates, replaces, ignores, or rejects content.
The CLI reports the server's HTTP outcome.

#### Listing and pagination

Without `--group`, `stage list` requests both the package and symbol collections.
With `--group`, `stage list` requests the selected group's member collection.
`stage group list` requests the group collection.
These requests use `page` and `pageSize`.
The default server page size is 100.
The CLI requests 100 items per page and aggregates all returned pages into one result.
If any page fails, the command fails without returning a partial result.

The initial CLI does not expose `--page` or `--page-size` because staging collections are expected to be small enough for automatic aggregation.

#### Output

The initial CLI writes human-readable console output.
Credentials and authorization headers must never appear in output, logs, or telemetry.

Commands return exit code `1` for invalid usage or failed operations.
Successful commands return exit code `0`.

#### Errors and retries

Success requires the status and body defined for the route.
Missing or invalid required response bodies fail the command.
Bodyless operations accept any `2xx`.
Non-`2xx` responses use existing `HttpSource` failure and retry handling.
When the response contains the staging error shape, the CLI displays `error.code` and `error.message`.
The CLI does not add error-code-specific behavior.

## Rationale and alternatives

### Alternative: `dotnet nuget push --stage`

This would make initial upload familiar, but it cannot naturally represent listing, viewing, deletion, or group management.

## Future Possibilities

- Add `--page` and `--page-size` to `stage list` and `stage group list` if automatic
  aggregation becomes impractical for large staging inventories.
- Add `stage push --wait` with timeout and polling controls.
- Allow `stage push` to accept multiple package paths and file globs.
- Add `stage push --unlisted` if the server contract supports setting listed intent and customer demand justifies exposing it in the CLI.
- Add versioned machine-readable JSON output.
- Add interactive confirmation for group deletion with an explicit non-interactive override for automation.
- Allow `stage group add` to accept a package path and upload it directly into the group.
- Add `stage push --disable-buffering` if staging measurements show meaningful memory pressure for large packages.
