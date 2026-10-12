
# Package Staging CLI Request and Response Expectations

Resource Type: PackageStaging/1.0.0

## Scope

This document defines the requests the NuGet CLI sends and the response data it consumes or requires when using `PackageStaging/1.0.0`.
It is a client contract and is not an exhaustive description of every capability supported by the server.
Server implementations may accept request fields or return response fields that are not documented here when the CLI does not depend on them.
In this document, a required response field is one the CLI requires to process the response.
An optional response field may be consumed when present, but its absence does not cause the CLI operation to fail.

The server-side design is defined in the [`PackageStaging/1.0.0` API contract](https://devdiv.visualstudio.com/DevDiv/_git/NuGet.Services?path=%2Fdocs%2Fspecs%2F2026%2FStagingAPIContracts.md&version=GBjaparson%2Fstaging-spec&_a=preview).

## Objects

This section defines shared object shapes referenced by name wherever they apply below.

### Artifact

A shared object shape returned by any route that describes a staged package or symbol
package. Referenced by name (`Artifact`) wherever it applies below.

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | |
| `version` | string | yes | |
| `kind` | string | yes | One of `package`, `symbols`. |
| `status` | string | yes | One of `waitingForParent`, `validating`, `ready`, `validationFailed`, `promoting`, `succeeded`, `promotionFailed`. |
| `group` | object, nullable | yes | `null` when ungrouped. Otherwise, a `GroupSummary`. |
| `listed` | boolean | no | Only applies when `kind` is `package`. |
| `canPromote` | boolean | yes | |
| `blockers` | array | no | Array of `Blocker` objects, may be empty. See `Blocker` below. |
| `owner` | string | no | |
| `uploaded` | string | no | ISO 8601 timestamp of when the artifact was staged. |
| `validated` | string, nullable | no | ISO 8601 timestamp of when validation completed successfully. `null` until then. |
| `expires` | string | no | ISO 8601 timestamp of when the staged artifact will be automatically removed if not promoted. |
| `managementUrl` | string | no | URL for managing the staged artifact in the source's web UI. |


### GroupSummary

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | Group ID. |
| `name` | string | yes | Group display name. |

### Group

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | Immutable, case-insensitive, unique per owner. |
| `name` | string | yes | Display name. |
| `canPromote` | boolean | yes | |
| `itemCount` | number | no | Number of member artifacts. |
| `blockers` | array | no | Array of `Blocker` objects, may be empty. |
| `owner` | string | no | |
| `created` | string | no | ISO 8601 timestamp of when the group was created. |
| `expires` | string | no | ISO 8601 timestamp, if the group has its own expiry separate from its members. |
| `managementUrl` | string | no | URL for managing the staged group in the source's web UI. |

### Blocker

| Field | Type | Required |
|---|---|---|
| `code` | string | yes |
| `message` | string | yes |

### Error

| Field | Type | Required | Description |
|---|---|---|---|
| `code` | string | yes | Machine-readable error code. |
| `message` | string | yes | User-facing error message. |
| `target` | string | no | Request field associated with the error. |

Every failure response body is JSON containing an `error` property whose value is an `Error` object.
If the body is missing or cannot be read, the CLI falls back to the status code and reason phrase.

### Quota

| Field | Type | Required | Description |
|---|---|---|---|
| `usedArtifacts` | number | yes | Number of artifacts currently using the staging quota. |
| `limit` | number | yes | Maximum number of staged artifacts. |

## Stage packages

- **Method:** `PUT`
- **Route:** `{@id}/package`
- **Content-Type:** `multipart/form-data`
- **Auth:** `X-NuGet-ApiKey: <token>`

### Parts

- **`package`** (required)
  - The `.nupkg` file being staged.
  - The part's `filename` is not authoritative; identity comes from the `.nuspec` inside.

- **`groupId`** (optional)
  - Assigns the package (and its symbols) to this group.
  - Omitted entirely (not an empty string) when no group is targeted.
  - When supplied by the CLI, it contains at least one non-whitespace character.
  - The CLI sends the user-supplied value without a preliminary group lookup or create request.
  - The CLI assumes the group exists and forwards any resulting server error to the user.

### Response

- **Success**
  - `201 Created` when a new artifact is staged.
  - `200 OK` when an artifact is replaced or the upload is identical.
  - Body is a single `Artifact`.
- **Failure**
  - Any non-`2xx` status code.

## Stage symbols

- **Method:** `PUT`
- **Route:** `{@id}/symbols`
- **Content-Type:** `multipart/form-data`
- **Auth:** `X-NuGet-ApiKey: <token>`

### Parts

- **`symbols`** (required)
  - The symbol package file being staged.
  - The part's `filename` is not authoritative; identity comes from the package inside.

- **`groupId`** (optional)
  - Same client behavior as `package`'s `groupId`.

### Response

- **Success**
  - `201 Created` when a new artifact is staged.
  - `200 OK` when an artifact is replaced or the upload is identical.
  - Body is a single `Artifact`.
- **Failure:** any non-`2xx` status code.

## List staged packages

- **Method:** `GET`
- **Route:** `{@id}/package`
- **Auth:** `X-NuGet-ApiKey: <token>`

### Query parameters

- **`page`** (optional): defaults to `1`.
- **`pageSize`** (optional): defaults to `100`.

### Response

- **Success**
  - Status: `200`.
  - Body:

    | Field | Type | Required | Description |
    |---|---|---|---|
    | `items` | array | yes | Array of `Artifact`, may be empty. |
    | `page` | number | yes | Echoes the requested (or defaulted) `page`. |
    | `pageSize` | number | yes | Echoes the requested (or defaulted) `pageSize`. |
    | `totalCount` | number | yes | Total number of items across all pages. |
    | `quota` | object | no | Staging quota information. See `Quota`. |
- **Failure**
  - Any non-`2xx` status code.

## List staged symbols

- **Method:** `GET`
- **Route:** `{@id}/symbols`
- **Auth:** `X-NuGet-ApiKey: <token>`

Same request and response shape as **List staged packages**, scoped to symbols.

## View a staged package

- **Method:** `GET`
- **Route:** `{@id}/package/{id}/{version}`
- **Auth:** `X-NuGet-ApiKey: <token>`

### Response

- **Success:** `200`. Body is a single `Artifact`.
- **Failure**
  - `404 Not Found` if not found or not visible to the caller.
  - Any other non-`2xx` status code.

## View staged symbols

- **Method:** `GET`
- **Route:** `{@id}/symbols/{id}/{version}`
- **Auth:** `X-NuGet-ApiKey: <token>`

Same shape as **View a staged package**, scoped to symbols.

## Delete a staged package

- **Method:** `DELETE`
- **Route:** `{@id}/package/{id}/{version}`
- **Auth:** `X-NuGet-ApiKey: <token>`

### Response

- **Success:** `204 No Content`.
- **Failure**
  - `404 Not Found` when the artifact is already absent or not visible.
  - Any other non-`2xx` status code.

## Delete staged symbols

- **Method:** `DELETE`
- **Route:** `{@id}/symbols/{id}/{version}`
- **Auth:** `X-NuGet-ApiKey: <token>`

Same shape as **Delete a staged package**, scoped to symbols.

## Create a group

- **Method:** `POST`
- **Route:** `{@id}/groups`
- **Content-Type:** `application/json`
- **Auth:** `X-NuGet-ApiKey: <token>`

### Body

- **`id`** (required): immutable, case-insensitive, unique per owner.
- **`name`** (required): display name.

*Note: this route explicitly creates a group before it is referenced by an upload or
membership operation.*

### Response

- **Success:** `201 Created`. Body is the created `Group`.
- **Failure:** any non-`2xx` status code.

## List groups

- **Method:** `GET`
- **Route:** `{@id}/groups`
- **Auth:** `X-NuGet-ApiKey: <token>`

### Query parameters

- **`page`** (optional): defaults to `1`.
- **`pageSize`** (optional): defaults to `100`.

### Response

- **Success**
  - Status: `200`.
  - Body:

    | Field | Type | Required | Description |
    |---|---|---|---|
    | `items` | array | yes | Array of `Group`, may be empty. |
    | `page` | number | yes | Echoes the requested (or defaulted) `page`. |
    | `pageSize` | number | yes | Echoes the requested (or defaulted) `pageSize`. |
    | `totalCount` | number | yes | Total number of items across all pages. |
- **Failure**
  - Any non-`2xx` status code.

## Get a group and its members

- **Method:** `GET`
- **Route:** `{@id}/groups/{groupId}`
- **Auth:** `X-NuGet-ApiKey: <token>`

### Query parameters

- **`page`** (optional): defaults to `1`.
- **`pageSize`** (optional): defaults to `100`.

### Response

- **Success**
  - Status: `200`.
  - Body:

    | Field | Type | Required | Description |
    |---|---|---|---|
    | `group` | object | yes | The `Group`. |
    | `items` | array | yes | Array of `Artifact` (the group's members), may be empty. |
    | `page` | number | yes | Echoes the requested (or defaulted) `page`. |
    | `pageSize` | number | yes | Echoes the requested (or defaulted) `pageSize`. |
    | `totalCount` | number | yes | Total number of members across all pages. |
- **Failure**
  - `404 Not Found` if not found or not visible.
  - Any other non-`2xx` status code.

## Rename a group

- **Method:** `PATCH`
- **Route:** `{@id}/groups/{groupId}`
- **Content-Type:** `application/json`
- **Auth:** `X-NuGet-ApiKey: <token>`

### Body

- **`name`** (required): new display name.

### Response

- **Success:** `200 OK`. Body is the updated `Group`.
- **Failure:** any non-`2xx` status code.

## Delete a group

- **Method:** `DELETE`
- **Route:** `{@id}/groups/{groupId}`
- **Auth:** `X-NuGet-ApiKey: <token>`

Deletes the group and all its members.

### Response

- **Success:** `204 No Content`.
- **Failure**
  - `404 Not Found` when the group is already absent or not visible.
  - Any other non-`2xx` status code.

## Add or move a package into a group

- **Method:** `PUT`
- **Route:** `{@id}/groups/{groupId}/items/{id}/{version}`
- **Auth:** `X-NuGet-ApiKey: <token>`

No body; the route parameters fully identify the target. Adds the package identity (and its
symbols) to the group, moving it if it already belongs to a different group.

### Response

- **Success:** any `2xx`. No required body.
- **Failure:** any non-`2xx` status code.

## Remove a package from a group

- **Method:** `DELETE`
- **Route:** `{@id}/groups/{groupId}/items/{id}/{version}`
- **Auth:** `X-NuGet-ApiKey: <token>`

Removes the package identity (and its symbols) from the group without deleting the staged
artifacts themselves.

### Response

- **Success:** any `2xx`. No required body.
- **Failure:** any non-`2xx` status code.
