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
|-- push <PACKAGE_PATH> [--group <GROUP_ID>] [--no-symbols]
|-- list [--group <GROUP_ID> | --ungrouped]
|-- view <PACKAGE_ID@VERSION>
|-- delete <PACKAGE_ID@VERSION> [--symbols-only]
`-- group
    |-- create <GROUP_ID> [--name <DISPLAY_NAME>]
    |-- list
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

**`--format <console|json>`**

`console` is the default, and `json` selects the machine-readable CLI contract.

#### Commands

##### **`stage push`**

**Synopsis**

```text
dotnet nuget stage push <PACKAGE_PATH> [--group <GROUP_ID>] [--no-symbols]
```

**Options**

- **`--group <GROUP_ID>`** uploads the package directly into the specified group.
- **`--no-symbols`** prevents upload of a matching sibling `.snupkg`.

`dotnet nuget stage push` uploads one `.nupkg` to private staging.
It returns when the server accepts the upload and does not wait for validation to finish.
If a matching sibling `.snupkg` exists, the CLI uploads it with the package unless `--no-symbols` is specified.
Symbol discovery reuses the existing `dotnet nuget push` behavior.

```console
dotnet nuget stage push artifacts/Contoso.1.0.0.nupkg
```

A package can be uploaded directly into a group:

```console
dotnet nuget stage push artifacts/Contoso.1.0.0.nupkg \
  --group august-release
```

##### **`stage list`**

**Synopsis**

```text
dotnet nuget stage list [--group <GROUP_ID> | --ungrouped]
```

**Options**

- **`--group <GROUP_ID>`** limits the result to packages in the specified group.
- **`--ungrouped`** limits the result to packages that are not in a group.

`dotnet nuget stage list` returns the complete package inventory visible to the supplied API key.
Each entry contains the package ID and version.
The command automatically follows all server continuation tokens before producing a successful result.

```console
dotnet nuget stage list
dotnet nuget stage list --group august-release
dotnet nuget stage list --ungrouped
```

`--group` and `--ungrouped` are mutually exclusive.
Group summaries are available separately through `dotnet nuget stage group list`.
Each group summary contains group metadata and a package count, but not package membership.
Use `stage list --group <GROUP_ID>` to list a group's packages.

##### **`stage view`**

**Synopsis**

```text
dotnet nuget stage view <PACKAGE_ID@VERSION>
```

`dotnet nuget stage view` displays the detailed server-provided state for one package:

```console
dotnet nuget stage view Contoso@1.0.0
```

##### **`stage delete`**

**Synopsis**

```text
dotnet nuget stage delete <PACKAGE_ID@VERSION> [--symbols-only]
```

**Options**

- **`--symbols-only`** deletes only the symbols while leaving the parent package staged.

Staged content can be deleted by identity.
Symbols can be deleted independently while leaving the parent package staged:

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

Groups use a user-selected, immutable ID for commands and API routes.
The valid ID syntax, including characters, casing, length, normalization, uniqueness, and reserved values, must be agreed with the NuGet server team before implementation.

```console
dotnet nuget stage group create august-release \
  --name "August Release"
```

##### **`stage group list`**

**Synopsis**

```text
dotnet nuget stage group list
```

`dotnet nuget stage group list` returns group summaries containing group metadata and a package count, but not package membership.

##### **`stage group add`**

**Synopsis**

```text
dotnet nuget stage group add <GROUP_ID> <PACKAGE_ID@VERSION>
```

An existing staged package can be added to a group:

```console
dotnet nuget stage group add august-release Contoso@1.0.0
```

##### **`stage group remove`**

**Synopsis**

```text
dotnet nuget stage group remove <GROUP_ID> <PACKAGE_ID@VERSION>
```

`group remove` requests removal of a package's membership from a group:

```console
dotnet nuget stage group remove august-release Contoso@1.0.0
```

##### **`stage group delete`**

**Synopsis**

```text
dotnet nuget stage group delete <GROUP_ID>
```

`group delete` requests deletion of a group:

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

Every staging request, including reads, requires:

```http
X-NuGet-ApiKey: <key>
```

API-key resolution and precedence match `dotnet nuget push`:

```text
-k|--api-key
NUGET_API_KEY
NuGet.config key for the staging endpoint
NuGet.config key for the source
NuGet.config key for the default nuget.org Gallery URL
```

The CLI treats the API key as opaque and provides no `--owner` or `--organization` option.

Because staged content is private, list and view operations require authentication and return only content the authenticated identity is authorized to access.

#### API mapping

The server routes and HTTP methods in this table are settled and are relative to the discovered staging resource URL.
The remaining server-contract work is to document their request and response schemas.

| CLI command | Server operation |
| --- | --- |
| `stage push <path>` | `PUT package` |
| `stage list` | `GET package` |
| `stage view <id@version>` | `GET package/{id}/{version}` |
| `stage delete <id@version>` | `DELETE package/{id}/{version}` |
| `stage delete <id@version> --symbols-only` | `DELETE package/{id}/{version}/symbols` |
| `stage group create` | `POST group` |
| `stage group list` | `GET group` |
| `stage group add <group> <id@version>` | `PUT group/{groupId}/entries/{id}/{version}` |
| `stage group remove` | `DELETE group/{groupId}/entries/{id}/{version}` |
| `stage group delete` | `DELETE group/{groupId}` |

The package upload uses multipart form data.
It sends the `.nupkg`, an optional matching `.snupkg`, and an optional `stagingGroup` field.

Package identities supplied on the command line use `<PACKAGE_ID>@<VERSION>`.

The CLI does not define replacement behavior and must not issue a preflight read before upload.
It sends the upload and reports the server result.
The written server response schema must document how new, identical, conflicting, or replaced content is represented.

#### Listing and pagination

`stage list` mirrors `GET package`, not `GET group`.
With no filter, it returns all staged packages visible to the supplied API key, both grouped and ungrouped.
`--group` maps to the server's group filter, and `--ungrouped` maps to its ungrouped filter.

#### Output

Console output is the default.
Structured output is selected with `--format json`.

JSON output is a versioned CLI contract rather than a direct copy of the server response.
The normative version 1 envelope and command-result schemas are stored in [`nuget-package-staging-cli/schemas/v1`](nuget-package-staging-cli/schemas/v1), with an index and versioning policy in [`nuget-package-staging-cli/README.md`](nuget-package-staging-cli/README.md).
These schemas apply only to CLI standard output; they do not define server request or response JSON.

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
Every command returns a `result` object, including successful mutation commands that have no server response body.
Credentials, authorization headers, and continuation tokens must never appear in output, logs, or telemetry.

Commands return exit code `1` for invalid usage or when `problems` contains an `Error`.
Successful commands and commands containing only `Warning` problems return exit code `0`.

#### Errors and retries

The implementation parses the staging server's error contract and translates problems into the CLI output model.
Console output presents actionable messages.

The CLI reuses `HttpSource` for existing NuGet transport behavior.

#### Required server-contract dependency

Implementation of request and response models is blocked because the settled server endpoints do not yet have implementation-grade schemas written down.
Before client implementation begins, the server team must document exact JSON property names and casing, required and nullable fields, enum values, timestamp formats, pagination limits and defaults, error extensions, and success response bodies for every endpoint.
OpenAPI or JSON Schema is preferred.
This work does not reopen the routes or HTTP methods in the API mapping.

## Rationale and alternatives

### Alternative: `dotnet nuget push --stage`

This would make initial upload familiar, but it cannot naturally represent listing, viewing, deletion, or group management.

## Unresolved Questions

The following must be resolved before implementation:

1. What are the documented request and response schemas for every settled `PackageStaging/1.0.0` endpoint?
2. Which fields are required, optional, or nullable, and what compatibility rules apply to additive server fields?
3. Should staged symbols always use the discovered staging resource and package API key, or should staging support separate `--symbol-source` and `--symbol-api-key` options?
4. What group ID syntax and validation rules will the client and server share, including casing, length, normalization, uniqueness, and reserved values?
5. Can a staged package belong to more than one group, and how should the server handle `group add` when the package already belongs to a group?
6. After `group remove`, does the package remain staged and ungrouped, remain in other groups, or follow another server-defined lifecycle?
7. Does `group delete` remove only group metadata, remove memberships, or also delete staged package content?
8. How does `group create` respond when the requested group ID already exists?
9. How should staging integrate with Trusted Publishing, including whether OIDC exchange remains external to the command?
10. How does `stage push --group` behave when the requested group does not exist?

## Future Possibilities

- Add `stage push --wait` with timeout and polling controls.
- Allow `stage push` to accept multiple package paths and file globs.
- Allow `stage group add` to accept a package path and upload it directly into the group.
- Add `stage push --disable-buffering` if staging measurements show meaningful memory pressure for large packages.
- Add group display-name updates.
- Add approval or promotion commands