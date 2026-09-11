
# Staging APIs

Resource Type: PackageStaging

This document describes the API contract that the CLI expects from any server implementing
`PackageStaging`. Server implementers should follow this design when building the endpoints
below.

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
| `group` | object, nullable | yes | `null` when ungrouped. See `Group` below. |
| `listed` | boolean | no | Only applies when `kind` is `package`. |
| `canPromote` | boolean | yes | |
| `blockers` | array | no | Array of `Blocker` objects, may be empty. See `Blocker` below. |
| `owner` | string | no | |
| `uploaded` | string | no | ISO 8601 timestamp of when the artifact was staged. |
| `validated` | string, nullable | no | ISO 8601 timestamp of when validation completed successfully. `null` until then. |
| `expires` | string | no | ISO 8601 timestamp of when the staged artifact will be automatically removed if not promoted. |


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

### Blocker

| Field | Type | Required |
|---|---|---|
| `code` | string | yes |
| `message` | string | yes |

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
  - Servers must create the group automatically if it does not already exist, and add the
    package to it.

### Response

- **Success**
  - Any `2xx` status code.
  - Body is a single `Artifact`.
- **Failure**
  - Any non-`2xx` status code.
  - The body must be JSON containing:
    - `error.code` (required)
    - `error.message` (required)
  - If the body is missing or cannot be read, the CLI falls back to the status code and
    reason phrase.

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
  - Same rules as `package`'s `groupId`: assigns to this group, auto-created if missing.

### Response

- **Success:** any `2xx` status code. Body is a single `Artifact`.
- **Failure:** any non-`2xx` status code. The body must be JSON containing:
  - `error.code` (required)
  - `error.message` (required)

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
- **Failure**
  - Same `error.code` / `error.message` rule as above.

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
- **Failure:** `404` if not found or not visible to the caller; otherwise same
  `error.code` / `error.message` rule as above.

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

- **Success:** any `2xx`. No required body.
- **Failure:** non-`2xx`, same `error.code` / `error.message` rule as above. A delete of an
  already-absent package is treated as success by the CLI (the desired end state is already
  reached), so servers should return a status the CLI can treat that way.

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

*Note: since **Stage packages** already auto-creates a group on push, this route is for
explicitly creating a group ahead of time, e.g. with a custom display name, or for creating
an empty group with no packages yet.*

### Response

- **Success:** any `2xx`. No required body.
- **Failure:** non-`2xx`, same `error.code` / `error.message` rule as above.

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
  - Same `error.code` / `error.message` rule as above.

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
  - `404` if not found or not visible.
  - Otherwise same `error.code` / `error.message` rule as above.

## Rename a group

- **Method:** `PATCH`
- **Route:** `{@id}/groups/{groupId}`
- **Content-Type:** `application/json`
- **Auth:** `X-NuGet-ApiKey: <token>`

### Body

- **`name`** (required): new display name.

### Response

- **Success:** any `2xx`. No required body.
- **Failure:** non-`2xx`, same `error.code` / `error.message` rule as above.

## Delete a group

- **Method:** `DELETE`
- **Route:** `{@id}/groups/{groupId}`
- **Auth:** `X-NuGet-ApiKey: <token>`

Deletes the group and all its members.

### Response

- **Success:** any `2xx`. No required body.
- **Failure:** non-`2xx`, same `error.code` / `error.message` rule as above.

## Add or move a package into a group

- **Method:** `PUT`
- **Route:** `{@id}/groups/{groupId}/items/{id}/{version}`
- **Auth:** `X-NuGet-ApiKey: <token>`

No body; the route parameters fully identify the target. Adds the package identity (and its
symbols) to the group, moving it if it already belongs to a different group.

### Response

- **Success:** any `2xx`. No required body.
- **Failure:** non-`2xx`, same `error.code` / `error.message` rule as above.

## Remove a package from a group

- **Method:** `DELETE`
- **Route:** `{@id}/groups/{groupId}/items/{id}/{version}`
- **Auth:** `X-NuGet-ApiKey: <token>`

Removes the package identity (and its symbols) from the group without deleting the staged
artifacts themselves.

### Response

- **Success:** any `2xx`. No required body.
- **Failure:** non-`2xx`, same `error.code` / `error.message` rule as above.
