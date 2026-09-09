# NuGet Package Staging CLI JSON Output

Common options do not change JSON output.
`--kind package` is the default and is not listed separately.
Empty collections use `[]` and `totalCount: 0`.
Package push results include the effective `listed` intent.
Symbol push results do not include `listed`.

## `stage push package.nupkg --format json`

```json
{
  "version": 1,
  "command": "push",
  "result": {
    "path": "package.nupkg",
    "kind": "package",
    "listed": true,
    "groupId": null
  },
  "problems": []
}
```

## `stage push package.nupkg --group release --format json`

```json
{
  "version": 1,
  "command": "push",
  "result": {
    "path": "package.nupkg",
    "kind": "package",
    "listed": true,
    "groupId": "release"
  },
  "problems": []
}
```

## `stage push package.nupkg --unlisted --format json`

```json
{
  "version": 1,
  "command": "push",
  "result": {
    "path": "package.nupkg",
    "kind": "package",
    "listed": false,
    "groupId": null
  },
  "problems": []
}
```

`--group release` uses the same output with `"groupId": "release"`.

## `stage push package.snupkg --format json`

```json
{
  "version": 1,
  "command": "push",
  "result": {
    "path": "package.snupkg",
    "kind": "symbols",
    "groupId": null
  },
  "problems": []
}
```

## `stage push package.snupkg --group release --format json`

```json
{
  "version": 1,
  "command": "push",
  "result": {
    "path": "package.snupkg",
    "kind": "symbols",
    "groupId": "release"
  },
  "problems": []
}
```

## `stage list --format json`

```json
{
  "version": 1,
  "command": "list",
  "result": {
    "kind": "package",
    "totalCount": 1,
    "items": [
      {
        "id": "Contoso",
        "version": "1.0.0",
        "kind": "package",
        "status": "ready",
        "groupId": null
      }
    ]
  },
  "problems": []
}
```

## `stage list --kind symbols --format json`

```json
{
  "version": 1,
  "command": "list",
  "result": {
    "kind": "symbols",
    "totalCount": 1,
    "items": [
      {
        "id": "Contoso",
        "version": "1.0.0",
        "kind": "symbols",
        "status": "ready",
        "groupId": null
      }
    ]
  },
  "problems": []
}
```

## `stage view Contoso@1.0.0 --format json`

```json
{
  "version": 1,
  "command": "view",
  "result": {
    "id": "Contoso",
    "version": "1.0.0",
    "kind": "package",
    "owner": "contoso",
    "status": "ready",
    "groupId": null,
    "uploaded": "2026-09-01T12:00:00Z",
    "validated": "2026-09-01T12:05:00Z",
    "expires": "2026-10-01T12:00:00Z",
    "listed": true,
    "canPromote": true,
    "blockers": [],
    "validationIssues": [],
    "galleryUrl": "https://www.nuget.org/account/staging/..."
  },
  "problems": []
}
```

## `stage view Contoso@1.0.0 --kind symbols --format json`

```json
{
  "version": 1,
  "command": "view",
  "result": {
    "id": "Contoso",
    "version": "1.0.0",
    "kind": "symbols",
    "owner": "contoso",
    "status": "ready",
    "groupId": null,
    "uploaded": "2026-09-01T12:01:00Z",
    "validated": "2026-09-01T12:06:00Z",
    "expires": "2026-10-01T12:01:00Z",
    "parent": {
      "id": "Contoso",
      "version": "1.0.0",
      "status": "ready"
    },
    "canPromote": true,
    "blockers": [],
    "validationIssues": [],
    "galleryUrl": "https://www.nuget.org/account/staging/..."
  },
  "problems": []
}
```

## `stage delete Contoso@1.0.0 --format json`

```json
{
  "version": 1,
  "command": "delete",
  "result": null,
  "problems": []
}
```

## `stage delete Contoso@1.0.0 --kind symbols --format json`

```json
{
  "version": 1,
  "command": "delete",
  "result": null,
  "problems": []
}
```

## `stage group create release --name "Release" --format json`

```json
{
  "version": 1,
  "command": "group create",
  "result": {
    "id": "release",
    "name": "Release",
    "kind": "package"
  },
  "problems": []
}
```

## `stage group create release --kind symbols --format json`

```json
{
  "version": 1,
  "command": "group create",
  "result": {
    "id": "release",
    "name": "release",
    "kind": "symbols"
  },
  "problems": []
}
```

## `stage group list --format json`

```json
{
  "version": 1,
  "command": "group list",
  "result": {
    "kind": "package",
    "totalCount": 1,
    "groups": [
      {
        "id": "release",
        "name": "Release",
        "kind": "package",
        "owner": "contoso",
        "created": "2026-09-01T12:00:00Z",
        "expires": "2026-10-01T12:00:00Z",
        "itemCount": 1,
        "canPromote": true,
        "galleryUrl": "https://www.nuget.org/account/staging/..."
      }
    ]
  },
  "problems": []
}
```

`stage group list --kind symbols` uses the same shape with `kind: "symbols"`.

## `stage group add release Contoso@1.0.0 --format json`

```json
{
  "version": 1,
  "command": "group add",
  "result": {
    "groupId": "release",
    "id": "Contoso",
    "version": "1.0.0",
    "kind": "package"
  },
  "problems": []
}
```

## `stage group add release Contoso@1.0.0 --kind symbols --format json`

```json
{
  "version": 1,
  "command": "group add",
  "result": {
    "groupId": "release",
    "id": "Contoso",
    "version": "1.0.0",
    "kind": "symbols"
  },
  "problems": []
}
```

## `stage group remove release Contoso@1.0.0 --format json`

```json
{
  "version": 1,
  "command": "group remove",
  "result": null,
  "problems": []
}
```

`--kind symbols` uses the same output.

## `stage group delete release --format json`

```json
{
  "version": 1,
  "command": "group delete",
  "result": null,
  "problems": []
}
```

`--kind symbols` uses the same output.

## Command failure

```json
{
  "version": 1,
  "command": "push",
  "result": null,
  "problems": [
    {
      "problemType": "Error",
      "text": "The package could not be staged."
    }
  ]
}
```
