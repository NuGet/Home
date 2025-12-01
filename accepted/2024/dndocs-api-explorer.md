# ***DNDocs API Explorer***
<!-- Replace `Title` with an appropriate title for your design -->

- Author Name https://github.com/NeuroXiq
- GitHub Issue: https://github.com/NuGet/NuGetGallery/issues/10055

## Summary

New url on nuget.org package page titled "Open in DNDocs API Explorer": 
**`https://docs.dndocs.com/n/{PackageName}/{PackageVersion}/api/index.html`** 

---
For example I generated 29,000 package version documentations: \
https://docs.dndocs.com/n/Microsoft.EntityFrameworkCore/8.0.3/api/index.html \
https://docs.dndocs.com/system/projects/29 \
https://docs.dndocs.com/system/projects/28 \
https://docs.dndocs.com/system/projects/27 \
etc...


## Motivation 
1. This can be useful
2. Existing issues on NuGet: https://github.com/NuGet/NuGetGallery/issues/6946 , https://github.com/NuGet/NuGetGallery/issues/9776
3. June 2024 survey shows people want API docs for packages
4. NuGet does not have documentation generator for nuget packages

## Explanation
This is a temporary solution. Until NuGet introduce package documentation generator tool 
this is not possible to see package documentation (`<summary>, <code>`  tags etc.)

### Functional explanation
New url on the right showing "Open in DNDocs API Explorer". When user
click:
1. If docs already generated, docs are show immediately
2. If does are not generated, user is redirected to dndocs.com generator page, wait for generator, after generation completed automatically redirected back to ready docs.dndocs page after two seconds 

## Drawbacks
1. This is temporary solution until NuGet will introduce own package explorer. This link will be removed in future anyway.
2. DNDocs will not work with all package types (will work with Dependency packages, other types for example DotNetTool is not supported).
3. Probably problems with other languages than C# (need to investigate, it generate something)

## Rationale and alternatives
1. FuGet (if online)
2. NuGet API generator (when implemented - there are plans for this but not ready yet)

## Prior Art
FuGet org is other solution.
Differences:
1. DNDocs cache all generated docs (store in db)
2. DNDocs use DocFX generator
3. DNDocs does not have API diff tool

## Unresolved Questions

1. Sometimes this does not work because I made a mistake in the code
2. Sometimes this does not work because DocFX has bugs
3. Right now DocFX has at least one bug that I found and I probably found a solution.
4. Rate limit for generator per IP? (to block e.g. generating 1000 packages by single IP)
5. I will probably remove login feature (do not login to dndocs.com, nothing works correctly right now)

## Additional informations
https://github.com/NeuroXiq/DNDocs \
https://github.com/NeuroXiq/src-dndocs
