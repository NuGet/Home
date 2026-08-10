# **Adding PackageID Level Metadata into the Registration API**

- Author: [@kalebfik](https://github.com/kalebfik)
- GitHub Issue <!-- GitHub Issue link -->

## Summary

This proposal adds ID-level metadata to the Registration API, published once at the root of the registration index rather than inside any version's metadata.

## Motivation

Currently, metadata in registration is scoped by PackageID and version. 
For certain metadata, especially those that are not changed often, adding functionality for PackageID level metadata provides a way for that information to be expressed. 

An example of this is sponsorship information. 
Sponsorships are currently a PackageID scoped piece of metadata. 
If we were to provide a way to show sponsorship information in the Registration API, it would require it to be package id and version scoped, and that would fan out to every version of the package, essentially requiring a new catalog leaf for every version of that package.

Adding PackageID level metadata in the Registration API would allow there to be one place where that information is stored, with one one catalog event per change rather than multiple catalog leaf being written for each change.  

## Goals

- Enable package-ID data in the Registration API
- Avoid embedding package-ID level data within existing metadata documents 

## Non-Goals

- Client-side consumption UX (changes to client side functionality)
- Changes to authorization/validation of data

## Explanation

### Functional explanation

This is going to be extending Registration API (specifically `RegistrationBaseUrl`) rather than adding anything new. 
ID-level metadata is going to be published as an optional property on the root of the Registration Index. 

**Example addition of Sponsorships**

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| count | integer | yes | The number of registration pages in the index |
| `sponsorshipUrls` | array of strings | no | *(new)* Funding URLs for the package ID |
| items | array of objects | yes | The array of registration pages |


**Example registration root entry with `sponsorshipUrls` added:**

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
  "sponsorshipUrls": [
    "count": 1, 
    "items": [
    "https://github.com/sponsors/contoso"
    ]
  ],
  // ** End of proposal **//
}
```
**Behavior** 
- Property written once per Package ID.
- Changes to data are reflected once, instead of per-version.
- Additional cursors are created per data-type, to signal any changes to the database and are updated accordingly
- Data is written to the exisitng blob storage at its root, and consumers fetching the registration index will see the property.

### Technical explanation

A detailed technical explanation can be found here: [Technical Implementation for adding PackageID level metadata into Registration](https://devdiv.visualstudio.com/DevDiv/_git/NuGet.Services?version=GBkalebfik-sponsorshipV3-spec&path=/docs/specs/2026/SponsorshipV3Spec.md&_a=preview) (internal)

## Drawbacks

Third party feeds may need to create their own implementation of PackageID level metadata in order to see these changes.

## Rationale and alternatives

### Publish through the Search endpoint

Add a new PackageID-level metadata field to the existing `SearchDocument`/Azure Search index schema, populated by a new sub-command in the existing `Auxiliary2AzureSearchCommand` job, modeled on `UpdateOwnersCommand.cs`.

`SearchQueryService` fires on every Visual Studio Package Manager UI query.
Adding this data to `SearchDocument` would increase the serialization cost of every one of those high-volume, uncached queries, even for the vast majority that never touch the data at all.

### Publish all Package-ID level metadata (vulnerability-style)

Add a new, standalone V3 service-index resource modeled on the publication mechanics of `BlobStorageVulnerabilityWriter`, but with an ID-only schema.

This pattern exists because vulnerability data is safety-critical and needs to be checked against every package on every restore, so shipping the full dataset is justified there.
The expected metadata is a display-only, optional features that most consumers only need for a handful of packages at a time.
Requiring every consumer of this pattern to hold or reconcile an in-memory dataset of each package on nuget.org is disproportionate to the actual need.

### Comparing the approaches

| | 1: Registration (chosen) | 2: Search | 3: One-shot (vulnerability-style) |
| --- | --- | --- | --- |
| **Cost** | New DB trigger/cursor job + registration-root persistence logic; reuses existing catalog/Catalog2Registration infrastructure otherwise | New sub-command in existing `Auxiliary2AzureSearchCommand` job, modeled on `UpdateOwnersCommand`; no new job, but adds serialization cost to every high-volume, uncached `SearchQueryService` query | New standalone job + new V3 service-index resource, modeled on `BlobStorageVulnerabilityWriter`; every consumer must hold/reconcile a full in-memory dataset regardless of actual need |
| **Pros** | Naturally fits the V3 registration model clients already query per-ID; no new V3 resource type; publicly cacheable via existing CDN path | Reuses proven `UpdateOwnersCommand`-style DB-diff-vs-snapshot pattern — completely skips the catalog, so no new catalog `@type` needed; unrecognized field is safely ignored by existing clients | Simple cursor-driven full-republish recovery story; naturally ID-only |
| **Cons/Trade-offs** | Catalog is per-version by design; needs new DB trigger since no existing signal fires on registration-only edits; every catalog consumer needs new parsing logic if a new `@type` is introduced | Adds cost to every query even when unused; still requires new seeding logic for `Db2AzureSearchCommand` full rebuilds | Disproportionate to a display-only, optional, low-frequency-lookup use case; forces every consumer into whole-dataset reconciliation for no safety-critical reason |


## Unresolved Questions

How should absense of data be treated? 
When a source does not support the PackageID level metadata in Registration API, it would output the same result as if the package itself did not have the information. 
How should the difference between the two be noted? 

## Future Possibilities

- Extension to Client tooling
- Additions to PMUI 
