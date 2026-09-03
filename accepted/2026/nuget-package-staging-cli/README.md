# NuGet Package Staging CLI JSON Schemas

These schemas define the public JSON written to standard output by
`dotnet nuget stage ... --format json`.

They do **not** define:

- HTTP request or response bodies exchanged by the NuGet client and server.
- The staging server's OpenAPI contract.
- Server persistence models.
- Server-only validation states or error details.

The settled server endpoints still need their request and response schemas
written down with the NuGet server team. The CLI schemas are a separate,
client-owned contract and do not pass server response objects through directly.

## Versioning

Schemas are grouped by CLI JSON contract major version:

```text
schemas/
`-- v1/
```

All version 1 documents emit `"version": 1`.

The version 1 envelope requires `version`, `command`, `result`, and
`problems`. Removing or changing one of those fields requires a new
major-version folder. Additional top-level properties are not allowed, so
adding one also requires a new major-version folder.

## Schema index

| CLI command | Schema |
|---|---|
| `stage push` | [`push.schema.json`](schemas/v1/push.schema.json) |
| `stage list` | [`list.schema.json`](schemas/v1/list.schema.json) |
| `stage view` | [`view.schema.json`](schemas/v1/view.schema.json) |
| `stage delete` | [`delete.schema.json`](schemas/v1/delete.schema.json) |
| `stage group create` | [`group-create.schema.json`](schemas/v1/group-create.schema.json) |
| `stage group list` | [`group-list.schema.json`](schemas/v1/group-list.schema.json) |
| `stage group add` | [`group-add.schema.json`](schemas/v1/group-add.schema.json) |
| `stage group remove` | [`group-remove.schema.json`](schemas/v1/group-remove.schema.json) |
| `stage group delete` | [`group-delete.schema.json`](schemas/v1/group-delete.schema.json) |

The shared envelope is defined in
[`envelope.schema.json`](schemas/v1/envelope.schema.json).
