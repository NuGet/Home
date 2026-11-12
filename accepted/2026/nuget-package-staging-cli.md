# NuGet Package Staging CLI

- [Nigusu](https://github.com/Nigusu-Allehu)
- [GitHub Issue #15014](https://github.com/NuGet/Home/issues/15014)
- [Grouping and listing issue #15015](https://github.com/NuGet/Home/issues/15015)

## Summary

`dotnet package stage` uploads NuGet packages and symbols to private staging, lists and inspects staged content, organizes release groups, and deletes staged artifacts.
Publishers can prepare packages without making them available to consumers.

## Motivation

Publishers need to upload packages privately, inspect validation state, organize release groups, and remove staged content from automated workflows.
A dedicated staging command family separates this preparation from ordinary publication.

## Explanation

### Functional explanation

#### Commands

```text
dotnet package stage
|-- push <PACKAGE_PATH> [--group <GROUP_ID>] [--no-symbols]
|-- list [--group <GROUP_ID>] [-v|--verbosity <LEVEL>]
|-- view <PACKAGE_ID@VERSION>
|-- delete <PACKAGE_ID@VERSION> [--symbols-only]
`-- group
    |-- create <GROUP_ID> [--name <DISPLAY_NAME>]
    |-- list [-v|--verbosity <LEVEL>]
    `-- view <GROUP_ID>
```

#### Group IDs

Group IDs must contain 1-64 ASCII letters, digits, periods, underscores, or hyphens, beginning and ending with a letter or digit.
NuGet.Client validates the entire ID against this regular expression:

```regex
^[A-Za-z0-9](?:[A-Za-z0-9._-]{0,62}[A-Za-z0-9])?$
```

The CLI rejects invalid IDs before accessing the source and sends valid IDs unchanged.

#### Common options

| Option | Behavior |
| --- | --- |
| `-s\|--source <SOURCE>` | Configured source name or V3 service-index URL. Defaults to `DefaultPushSource`; fails if neither is supplied. |
| `-k\|--api-key <API_KEY>` | API key for the staging service. Takes precedence over the environment variable and configured keys. |
| `--configfile <FILE>` | Uses only the specified NuGet configuration file. Without it, uses the normal configuration hierarchy for the current working directory. |
| `--interactive` | Allows NuGet credential providers to prompt for credentials. |

#### Upload artifacts

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
| `--group <GROUP_ID>` | Sends the group ID with each upload. The CLI assumes the group exists and does not look it up or create it. |
| `--no-symbols` | Disables automatic discovery and upload of a sibling symbols package. A symbols file supplied directly is still uploaded. |

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

#### List artifacts

`stage list` returns package and symbols artifacts from their respective staging inventories.

`--group` instead lists the selected group's packages and symbols.
The command retrieves all pages before displaying results.

```console
dotnet package stage list
dotnet package stage list --group august-release
dotnet package stage list --verbosity minimal
```

#### View artifacts

`stage view <PACKAGE_ID@VERSION>` displays status for both package and symbols artifacts.

```console
dotnet package stage view Contoso@1.0.0
```

#### Delete artifacts

`stage delete <PACKAGE_ID@VERSION>` attempts package deletion first, then symbols deletion.
With `--symbols-only`, it deletes only symbols and leaves the package staged.

```console
dotnet package stage delete Contoso@1.0.0
dotnet package stage delete Contoso@1.0.0 --symbols-only
```

#### Create a group

`stage group create <GROUP_ID> [--name <DISPLAY_NAME>]` explicitly creates a group.
The name defaults to the group ID when omitted.
IDs are immutable, case-insensitive, and unique per owner.

Display names are trimmed and must contain 1-128 characters.
The CLI rejects invalid IDs and names before accessing the source.

```console
dotnet package stage group create august-release --name "August Release"
```

#### List and view groups

`stage group list` displays all group summaries without membership details.
It retrieves all pages and displays summary detail according to `--verbosity`.

`stage group view <GROUP_ID>` displays the selected group's metadata and status, not its members.
Use `stage list --group <GROUP_ID>` for the full member collection.

```console
dotnet package stage group list
dotnet package stage group view august-release
```

#### Response output

`stage list` and `stage group list` accept `-v|--verbosity <minimal|normal|detailed>`, defaulting to `normal`.
Verbosity controls result fields, not the number of results.
Every level lists every returned item.

| Model | `minimal` | `normal` | `detailed` |
| --- | --- | --- | --- |
| Artifact | `id`, `version`, `kind` | Minimal fields plus `status`, group ID, `canPromote` | Normal fields plus `owner`, group name, `uploaded`, `expires`, `listed` when applicable, `blockers`, `managementUrl` |
| Group | `id` | Minimal fields plus `name`, `itemCount`, `canPromote` | Normal fields plus `owner`, `created`, `expires`, `blockers`, `managementUrl` |

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
Both the source URL and discovered staging endpoint reject insecure HTTP.
There is no CLI option to allow insecure connections.

##### Credentials

The CLI resolves the API key in this order:

1. `--api-key`.
2. `NUGET_API_KEY`.
3. NuGet configuration, looking up the discovered staging resource URL first, then the source URL, with the existing NuGet.org API-key fallback.

The same API-key resolution applies to all commands and to both package and symbols requests.
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

The [companion upload contract](package-staging-api-contract-md.md) describes the upload request details and response handling.

##### Read, delete, and group requests

All routes below are relative to the discovered resource.

| CLI operation | Server operation | Response model |
| --- | --- | --- |
| `stage list` | `GET package` and `GET symbols` | Artifact page for each kind |
| `stage list --group <group>` | `GET groups/{groupId}` | Group detail with paged artifacts |
| `stage view <id@version>` | `GET package/{id}/{version}/status` and `GET symbols/{id}/{version}/status` | Single Artifact for each kind found |
| `stage delete <id@version>` | `DELETE package/{id}/{version}` and `DELETE symbols/{id}/{version}` | No body on success |
| `stage delete <id@version> --symbols-only` | `DELETE symbols/{id}/{version}` | No body on success |
| `stage group create <group>` | `POST groups` | Single Group |
| `stage group list` | `GET groups` | Group page |
| `stage group view <group>` | `GET groups/{groupId}` | Group detail with paged artifacts |

Artifact pages contain `items`, `page`, `pageSize`, `totalCount`, and owner-wide `quota`.
Group pages contain the same paging fields and Group items, without quota.
Group detail contains a `group` object and a paged Artifact collection.
Group creation and view display the Group object; only `stage list --group` aggregates and displays members.

## Prior Art

This design builds on [`Release staging and deprecation`](https://github.com/NuGet/Home/pull/12874) and the [refreshed NuGet staging proposal](https://github.com/NuGet/Home/pull/14978).

The management operations are implemented server-side in [NuGet/NuGetGallery#11056](https://github.com/NuGet/NuGetGallery/pull/11056).
The upload command and protocol foundation are implemented in [NuGet/NuGet.Client#7712](https://github.com/NuGet/NuGet.Client/pull/7712) and [NuGet/NuGet.Client#7703](https://github.com/NuGet/NuGet.Client/pull/7703).

## Unresolved Questions

## Future Possibilities

- JSON output for consuming list and view results in automation.
- `stage group delete <GROUP_ID>` to delete a group and its staged artifacts