# Package Staging Upload Contract

Resource type: `PackageStaging/1.0.0`

## Scope

This document describes the HTTP requests and response handling used by the `dotnet package stage push` command.
It is a client upload contract, not a complete server API reference.

## Resource discovery

The source's V3 service index advertises:

```json
{
  "@type": "PackageStaging/1.0.0",
  "@id": "https://api.example.com/v3/staging/"
}
```

The client appends `package` or `symbols` to the advertised endpoint path, preserving any query string.
The upload endpoint must not use insecure HTTP.
A source without the staging resource fails discovery rather than falling back to the publication endpoint.

## Requests

| Upload | Method | Route relative to resource `@id` | Required file part |
| --- | --- | --- | --- |
| Package | `PUT` | `package` | `package` |
| Symbols | `PUT` | `symbols` | `symbols` |

Both operations use `multipart/form-data` with chunked transfer encoding.
Each request contains exactly one file part with `Content-Type: application/octet-stream` and the local filename.
The client streams the file contents without extracting package identity.

The optional `groupId` form field contains the user-supplied group ID.
It is omitted when `--group` is not supplied.
The CLI validates the ID as described in the [CLI design](nuget-package-staging-cli.md#options), but does not check whether the group exists or create it.

When a non-empty API key is resolved, the client sends it in the `X-NuGet-ApiKey` header.
Otherwise, that header is omitted.
Authentication and authorization requirements are enforced by the service.

Package and symbols uploads are separate requests.
For automatic sibling-symbol upload, the package request must succeed before the symbols request is sent.
Both requests carry the same API key and, when supplied, group ID.
Each request uses a five-minute timeout and existing NuGet HTTP retry handling.

## Responses

The client accepts any `2xx` status as upload success.
It neither requires nor reads a response body, so this client contract defines no required success-response JSON fields.
An empty or otherwise unread response body does not change a successful HTTP outcome.

For a non-`2xx` response, the client uses existing NuGet HTTP failure diagnostics and retry handling.
It does not parse or display staging-specific JSON error objects.
The service determines duplicate, replacement, group-assignment, and authorization outcomes.

An accepted upload is not a claim that asynchronous package validation or publication has completed.
