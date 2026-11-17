# NuGet Package Staging CLI

- [Nigusu](https://github.com/Nigusu-Allehu)
- [GitHub Issue #15014](https://github.com/NuGet/Home/issues/15014)
- [Grouping and listing issue #15015](https://github.com/NuGet/Home/issues/15015)

## Summary

`dotnet package stage` lets publishers prepare packages privately before deciding to publish them.
Publishers can upload packages and symbols, find their staged work whether or not they created a release group, inspect validation progress and promotion blockers, and remove unwanted staged content.
The commands support release preparation without making the packages available to consumers or publishing them.

## Motivation

Publishers need to upload packages privately, inspect validation state, organize release groups, and remove staged content from automated workflows.
A dedicated staging command family separates this preparation from ordinary publication.

## Explanation

### Functional explanation

The examples use a configured staging source named `StagingFeed`.
A staging group is an optional named collection of related packages and symbols, such as the outputs intended for one release.
Publishers staging one or several independent packages do not need to create a group.

#### Stage and inspect a package before publication

A build produces `Contoso.Core` version `1.0.0`.
The publisher wants to upload it privately while keeping publication as a separate step.
They run this command locally or from the build job:

```console
dotnet package stage push artifacts\Contoso.Core.1.0.0.nupkg --source StagingFeed
```

The command uploads the package and a matching sibling symbols file, if present.
Successful upload means the files were accepted; server-side validation may still be running.
The publisher checks their current state:

```console
dotnet package stage view Contoso.Core@1.0.0 --source StagingFeed
```

The result distinguishes the package from its symbols and shows their validation state, promotion eligibility, and any blockers.
Inspection reports the current state; it does not wait for validation to finish.

#### Find staged work without remembering every package identity

A publisher returns after staging several independent packages.
They want to see what is there and what needs attention, but do not remember every package ID and version.
They ask for an overview:

```console
dotnet package stage list --source StagingFeed
```

The overview separates named release groups from packages and symbols uploaded without a group.
For example:

```text
Groups
  ID              Name           Artifacts  Can promote
  release-1.0.0    Release 1.0.0  4          No

Ungrouped packages and symbols
  Identity                    Kind     Status             Can promote
  Contoso.Tools@2.0.0          package  ready             Yes
  Contoso.Tools@2.0.0          symbols  validating        No
  Contoso.Utility@1.2.0        package  validationFailed  No
  Contoso.Diagnostics@1.0.0   symbols  waitingForParent   No
```

Each named groups members are available through group inspection rather than expanded in the overview.
The publisher can inspect an independent candidate directly:

```console
dotnet package stage view Contoso.Tools@2.0.0 --source StagingFeed
```

#### Prepare a release containing several packages

The release owner is preparing `Contoso.Core` and `Contoso.Extensions` version `1.0.0`.
They create a group so the related uploads can be found and reviewed together:

```console
dotnet package stage group create release-1.0.0 --name "Release 1.0.0" --source StagingFeed
```

The group is created before uploading its members.
A coordinating release job can create it once and pass the group ID to the jobs producing each package:

```console
dotnet package stage push artifacts\Contoso.Core.1.0.0.nupkg --group release-1.0.0 --source StagingFeed
dotnet package stage push artifacts\Contoso.Extensions.1.0.0.nupkg --group release-1.0.0 --source StagingFeed
```

Each package and its automatically discovered symbols are uploaded into the specified group.

#### Find and review an existing release group

A release owner wants to browse named releases without the independent uploads shown in the overview.
Running the group command without a subcommand lists the available groups:

```console
dotnet package stage group --source StagingFeed
```

They select a group and inspect its contents:

```console
dotnet package stage group view release-1.0.0 --source StagingFeed
```

Group inspection shows the group's information, its full package and symbols membership, and promotion blockers.
The release owner can see what arrived and which artifacts need attention in one place.
For more information about a particular package and its symbols, they drill down by identity:

```console
dotnet package stage view Contoso.Extensions@1.0.0 --source StagingFeed
```

#### Remove an abandoned candidate

A publisher has accumulated several independent candidates and wants to remove one they no longer intend to publish.
They find `Contoso.Tools@2.0.0` in `stage list` and inspect it with `stage view Contoso.Tools@2.0.0` before deleting it.
They then remove its package and symbols artifacts:

```console
dotnet package stage delete Contoso.Tools@2.0.0 --source StagingFeed
```

If they only want to remove its staged symbols, they can leave the package in place:

```console
dotnet package stage delete Contoso.Tools@2.0.0 --symbols-only --source StagingFeed
```

### Technical explanation

#### Commands

```text
dotnet package stage
|-- push <PACKAGE_PATH> [--group <GROUP_ID>] [--no-symbols]
|-- list [-v|--verbosity <LEVEL>]
|-- view <PACKAGE_ID@VERSION>
|-- delete <PACKAGE_ID@VERSION> [--symbols-only]
`-- group [-v|--verbosity <LEVEL>]
    |-- create <GROUP_ID> [--name <DISPLAY_NAME>]
    `-- view <GROUP_ID>
```

`stage list` provides the combined overview.
`stage group` without a subcommand lists only real groups; it does not require a separate `group list` subcommand.
`stage group --help` displays usage instead of listing groups.
When a group subcommand is supplied, only that operation runs.

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

#### List staged work

`stage list` displays two sections: named group summaries and ungrouped package and symbols artifacts.
It does not expand named groups into their members.
Each ungrouped artifact is shown separately with its kind, so a package and its symbols are distinguishable and symbols-only uploads remain discoverable.

The CLI retrieves all pages of the group, package, and symbols inventories.
Each section explicitly reports when it has no results.

#### View artifacts

`stage view <PACKAGE_ID@VERSION>` displays detailed information for both package and symbols artifacts, identifying an absent counterpart when the other exists.
It shows each artifact's identity, kind, status, group, promotion eligibility, and available owner, upload, expiration, listing, blocker, and management URL information.

#### Delete artifacts

`stage delete <PACKAGE_ID@VERSION>` attempts package deletion first, then symbols deletion.
With `--symbols-only`, it deletes only symbols and leaves the package staged.

#### Group IDs

Group IDs must contain 1-64 ASCII letters, digits, periods, underscores, or hyphens, beginning and ending with a letter or digit.
NuGet.Client validates the entire ID against this regular expression:

```regex
^[A-Za-z0-9](?:[A-Za-z0-9._-]{0,62}[A-Za-z0-9])?$
```

The CLI rejects invalid IDs before accessing the source and sends valid IDs unchanged.

#### Create a group

`stage group create <GROUP_ID> [--name <DISPLAY_NAME>]` explicitly creates a group.
The name defaults to the group ID when omitted.
IDs are immutable, case-insensitive, and unique per owner.

Display names are trimmed and must contain 1-128 characters.
The CLI rejects invalid IDs and names before accessing the source.

#### List and view groups

`stage group` without a subcommand displays all group summaries without membership details or ungrouped artifacts.
It retrieves all group pages and displays summary detail according to `--verbosity`.
It does not retrieve the package and symbols inventories.
If there are no visible groups, it reports that no groups were found rather than showing help.

`stage group view <GROUP_ID>` displays the selected group's metadata and full member collection.
Group information includes its identity, name, artifact count, promotion eligibility, blockers, and available owner, creation, expiration, and management URL information.

#### Response output

`stage list` and the default `stage group` listing accept `-v|--verbosity <minimal|normal|detailed>`, defaulting to `normal`.
Verbosity controls result fields, not the number of results.
Every level lists every returned group and, for the combined overview, every returned ungrouped artifact.

| Model | `minimal` | `normal` | `detailed` |
| --- | --- | --- | --- |
| Group | `id` | Minimal fields plus `name`, `itemCount`, `canPromote` | Normal fields plus `owner`, `created`, `expires`, `blockers`, `managementUrl` |
| Ungrouped artifact | `id`, `version`, `kind` | Minimal fields plus `status`, `canPromote` | Normal fields plus `owner`, `uploaded`, `expires`, `listed`, `blockers`, `managementUrl` |

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
| `stage list` | `GET groups`, `GET package`, and `GET symbols` | Group pages and separate package and symbols Artifact pages |
| `stage view <id@version>` | `GET package/{id}/{version}/status` and `GET symbols/{id}/{version}/status` | Single Artifact for each kind found |
| `stage delete <id@version>` | `DELETE package/{id}/{version}` and `DELETE symbols/{id}/{version}` | No body on success |
| `stage delete <id@version> --symbols-only` | `DELETE symbols/{id}/{version}` | No body on success |
| `stage group create <group>` | `POST groups` | Single Group |
| `stage group` without a subcommand | `GET groups` | Group page |
| `stage group view <group>` | `GET groups/{groupId}` | Group detail with paged artifacts |

## Prior Art

This design builds on [`Release staging and deprecation`](https://github.com/NuGet/Home/pull/12874) and the [refreshed NuGet staging proposal](https://github.com/NuGet/Home/pull/14978).

The management operations are implemented server-side in [NuGet/NuGetGallery#11056](https://github.com/NuGet/NuGetGallery/pull/11056).
The upload command and protocol foundation are implemented in [NuGet/NuGet.Client#7712](https://github.com/NuGet/NuGet.Client/pull/7712) and [NuGet/NuGet.Client#7703](https://github.com/NuGet/NuGet.Client/pull/7703).

## Unresolved Questions

## Future Possibilities

- JSON output for consuming list and view results in automation.
- `stage group delete <GROUP_ID>` to delete a group and its staged artifacts
- Staging all packages in a folder
