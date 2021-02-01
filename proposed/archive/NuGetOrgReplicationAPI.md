### Replicating NuGet.org going forward

#### Intro

Current replication techniques against NuGet.org utilize the OData feed, and use mechanisms such as paging. These are extremely expensive and as an aggregate of all clients replicating simultaneously consumes a large part of the the server resources (both SQL and Lucene).

The goal is to replace this mechanism with a more modern mechanism that relies solely on storage and CDN, so it doesn't impact any compute resources, and is relatively cheap to maintain.

#### Design considerations/Top level items
1. As first phase - Using the current NuGet.org infrastructure - Without any code changes to the server
2. As second phase - Add endpoints that enable snapping the whole view of what package Ids are available in one go. This could be described in either a catalog rollup, or a completely separate and simple endpoint that describes all ids + versions, and a cursor pointing the where it was generated at the catalog level. This will require a job to produce the rolled up view.
3. A public C# API that can walk the catalog and provide all the ids and versions
4. A public C# API that gets all the versions of a known set of Ids
5. a program (executable, either nuget.exe or another tool) that can be used to replicate a set of packages from nuget.org and update them regularly by only downloading the diffs.

#### Public APIs
1. An API to walk the catalog

###### Filters
1. Owner
2. Author
3. Globbing pattern of package name
4. Latest version only
5. Globbing of versions
6. Stable or also pre-release
7. General callback with user code accessing the metadata?
8. Start cursor

###### Returns
1. Package metadata
2. Download link
3. Link to all versions of the package
4. Cursor that can be stored

```c#
// insert a snippet here
```

2. API to get all versions of a package Id

This is really just a point to the flat container {packageId}/index.json

#### Program

1. Need to debate if this is part of nuget.exe or can rev on its own. My general preference is a standalone tool, so it can rev on its own cadence. It impacts a lot smaller set of customers, so it should be able to live on its own. However it is going to be less discoverable this way. We could consider it as an extension to NuGet.exe
2. Prototype command

XXX.exe Replicate -Source https://api.nuget.org/v3/index.json -Cursor File.Cursor -Output {folder/pushserveruri} -Structure {flat/v3(default)} -glob {e.g. microsoft.*} -owner {microsoft|aspnet} -allVersions (default is latest) -PreRelease

#### Samples

* ng.exe’s Lightning command (to regenerate registration blobs) has an example of fetching the latest state of all packages from catalog: https://github.com/NuGet/NuGet.Services.Metadata/blob/searchcloud/src/Ng/Lightning.cs#L172

#### Notes

* The service index.json has a Catalog/3.0.0 entry which can be used to determine the catalog root.