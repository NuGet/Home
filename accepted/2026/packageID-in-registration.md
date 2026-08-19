# **Adding Package ID-Level Metadata to the Registration API**

- Author: [@kalebfik](https://github.com/kalebfik)
- GitHub Issue: [NuGet/Home#15038](https://github.com/NuGet/Home/issues/15038)

## Summary

This proposal adds package ID-level metadata to the Registration API.
The metadata is published once in an optional `metadata` object at the root of the registration index.

## Motivation

The Registration API is currently scoped by version.
Certain metadata, such as sponsorship information, applies to a package ID independently of any one package version.
Adding package ID-level metadata through the existing version-scoped model would require any metadata changes to fan out to every version of a package, producing a catalog leaf and registration updates for each version.
Publishing package ID-level metadata at the Registration index root provides one place where ID-specific information is stored, with one catalog event per change rather than multiple catalog leaves being written for each change.

## Goals

- Support optional package ID-level metadata in the Registration index root.
- Publish and persist package ID-level changes once per package ID rather than per version.
- Keep package ID-level data separate from existing Search metadata.
- Maintain compatibility with clients that do not recognize the optional package ID-level metadata.
- Ensure package ID-level metadata is included in Registration reflow, backfill, replication, and failover processes.

## Non-Goals

- Client-side consumption UX (changes to client side functionality or user experience).
- Changes to authorization or validation of data.

## Explanation

### Functional explanation

This proposal extends the existing `RegistrationBaseUrl`.
Package ID-level metadata will be published as an optional `metadata` object at the root of the Registration index.

**Example addition of metadata information**

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| `count` | integer | yes | The number of registration pages in the index |
| `metadata` | object | no | Package ID-level metadata |
| `items` | array of objects | yes | The registration pages |

**Example `metadata` registration root entry with `sponsorshipUrls` added:**

```json
{
  "@id": "https://api.nuget.org/v3/registration5-gz-semver2/contoso.webapi.client/index.json",
  "@type": [
    "catalog:CatalogRoot",
    "PackageRegistration",
    "catalog:Permalink"
  ],
  "commitId": "afa91af1-9505-41b8-ad75-eab8e613db14",
  "commitTimeStamp": "2026-04-10T00:15:25.1492389+00:00",
  "count": 2,
  // ** Start of proposal ** //
  "metadata": {
    "sponsorshipUrls": [
      "https://github.com/sponsors/contoso"
    ]
  }
  // ** End of proposal **//
}
```

**Behavior**

- The `metadata` object is optional and written once per package ID on the Registration index root.
- Changes update the index once rather than being reflected in every package version.
- Rewrites must preserve package ID-level metadata when version-level metadata changes.
- Metadata must participate in the same publication, replication, reflow, backfill, and recovery processes as version-level metadata.
- Network, authentication, and protocol failures remain errors and are not represented as empty metadata.

### Technical explanation

A detailed technical explanation can be found here: [Technical implementation for adding package ID-level metadata to Registration](https://devdiv.visualstudio.com/DevDiv/_git/NuGet.Services?version=GBkalebfik-sponsorshipV3-spec&path=/docs/specs/2026/SponsorshipV3Spec.md&_a=preview) (internal).

## Drawbacks

- Third-party feeds need to implement the optional Registration root contract to publish their own package ID-level metadata.

## Rationale and alternatives

The following client access patterns inform where package ID-level metadata should be published:

| Client workflow | Existing API path | Relevance |
| --- | --- | --- |
| Discovery: Visual Studio Package Manager UI Browse and `dotnet package search` | Search | Search is used to discover packages across a source. |
| Known-package metadata: Package Manager UI package details, Updates, and Consolidate | Registration through `PackageMetadataResource` | These experiences already fetch metadata for a known package ID from its registration index. |
| Package Manager UI Installed | Installed identities come from project assets. Metadata is read locally first and falls back to Registration. | Registration is already the network metadata path for known installed package IDs when local metadata is unavailable. |
| `dotnet package list` | The `--outdated`, `--deprecated`, and `--vulnerable` reports retrieve per-package metadata from Registration, unless the separate vulnerability audit-source path is selected. | The proposed sponsorship report follows the same known-installed-package pattern and can retrieve package ID-level metadata from Registration. |

Registration aligns with client experiences that request metadata for a known package ID.
For `dotnet package list`, its existing metadata report modes already query Registration for installed package IDs, so sponsorship can extend that path rather than introduce a Search or full-dataset lookup.

### Alternative considered: Publish through the Search endpoint

One alternative is to add package ID-level metadata to `SearchDocument` and the Azure Search index schema.
Initial Search index builds would populate the field, and later changes could be handled by a new subcommand modeled on the existing package-owner update path.
This would reuse the existing Search publication pipeline, avoid a new package ID-level catalog leaf type, and make the metadata available to discovery experiences such as Package Manager UI Browse.

This alternative was not selected mainly because it would add optional and infrequently consumed data to the high-frequency Search path.
The field would be retrieved, serialized, and transferred with applicable Search results even when the client does not use it.

Registration is also a better fit for the initial installed-package scenarios.
Package Manager UI installed-package experiences and existing `dotnet package list` metadata reports already use Registration for network metadata, so a Search-only design would require an additional client lookup.

### Alternative considered: Publish a vulnerability-style dataset

Another alternative is to add a standalone V3 service-index resource and publication job containing package ID-level metadata for the entire source, modeled on the vulnerability-data resource.
Clients would download the dataset and build a local package ID lookup instead of requesting one Registration index per package ID.

This approach offers one cacheable lookup, explicit source capability detection, and no disclosure of individual installed package IDs through per-ID requests.
It would also require a new V3 resource type and complete server, client, monitoring, and third-party-feed implementation.
Every participating client would download and maintain metadata for the full source even when it needs information for only a small set of packages.

A separate full-source resource is justified for vulnerability data because that data is safety-critical and must be broadly available to restore and audit workflows.
Sponsorship information is optional, non-blocking display metadata.

### Comparing the approaches

| | Registration | Search | Vulnerability-style dataset |
| --- | --- | --- | --- |
| **Implementation cost** | Add the package ID-level catalog lane, collector cursor, typed root model, and recovery support; no new service-index resource | Extend the Search schema, full-build seeding, and auxiliary update pipeline; can avoid a new catalog leaf type | Add a new V3 resource type, publication job, monitoring, and client resource implementation |
| **Client fit** | Matches known and installed package workflows, including existing `dotnet package list` metadata reports | Matches discovery workflows such as Package Manager UI Browse | Matches clients that need to evaluate most or all packages from a source |
| **Network shape** | Cached request per relevant package ID and source; can require many requests for large solutions | Adds the field to applicable Search results on a frequently used, non-disk-cached query path | One cacheable dataset, but clients download metadata for the entire source |
| **Pros** | Fetches only requested IDs; reuses existing known-package client paths | Reuses the Search pipeline; can avoid a new catalog type | Explicit support signal; no per-ID disclosure; efficient repeated local lookups |
| **Cons** | Requires a new ID-level Registration publication lane; unsupported and empty sources are indistinguishable | Repeated optional payload cost; installed clients need another lookup | Disproportionate whole-source transfer and new protocol surface for optional display metadata |

## Unresolved Questions

None at this time.

## Future Possibilities

- Add other package ID-level fields to the Registration root `metadata` object.
- Extend client tooling such as the Visual Studio Package Manager UI experiences to consume package ID-level metadata.