# ***Release staging and deprecation***
<!-- Replace `Title` with an appropriate title for your design -->

- Author Name Artak Mkrtchyan ([mkArtakMSFT](https://github.com/mkArtakMSFT))
- GitHub Issue <https://github.com/NuGet/NuGetGallery/issues/3931>

## Summary

This proposal introduces a concept of a logical grouping for packages published to NuGet.
This will allow one to easily identify all the packages released as part of a single product version release as well as request bulk-processing for a set of packages which belong to the same release.
For example, all packages published as part of .NET 8 Preview 5 release will be staged together and then also can be deprecated together by a single call to NuGet APIs.

## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Many products (Apps / Tools / Frameworks / Utilities / etc. ...) consist of multiple interdependent packages which should be published together as a single set. Currently, NuGet provides no functionality for definding / grouping packages into such sets. This results in package owners having to keep track of these package sets on their own. There are three specific sets of scenarios which this feature will simplify dramatically:
1. When preparing a release, product owners would like to have a mechanism to pre-stage their product packages, so that the release will consist only of a single action of marking the set of packages as `published`, which would result all the packages in the set to be marked as published at the same time.
2. Sometimes developers have to take a dependency on several related packages in their projects, which are part of the same "release". Without having a concept of the `release` developers have to guess which versions of those packages are compatible. As a result, most of hte time developers would simply pick the latest version of all these packages, which somtimes can lead to incompatibility issues down the road.
3. Keeping a package healthy on NuGet also means keeping the list of packages aligned with it support policy. Hence, package owners try to deprecate packages which are out of support. Without ability to group packages, package owners end up keeping track of all the packages which belong to the same release and run the deprecation over a discrete set of packages when necessary. Being able to group packages together would enable deprecating a whole release at once, knowing that all the packages which belong to that release will get deprecated.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
There is a new field in the package metadata named `release`, which indicates the unique release of the product the package belongs to.
Server implementations are expected to treat each `release` as scoped to an account or similar concept, depending on the server's implementation details.
For example, on nuget.org, User1 and User2 can both use a `release` named `V1.0.0`, but when User1 operates on their `V1.0.0` release, it does not affect User2's release with the same name.

When a package is being built, that field in the metadata is set to the same value for all the related packages, that are built together.

Now, with this information in place, new set of NuGet APIs / extensions allow the user to run the following actions:
- **Search / Query for packages based on a release** for a given publisher
- **Deprecate a relase** for current publisher
- **Stage** a package for later publishing
- **Publish an earlier staged release**

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

### Alternatives considrered
Utilizing **package tags** was considered as an alternative to solve this problem. Unfortunately, this has issues and can't be used for this purpose. Below are some of them:
- There are currently no restrictions on tags usage, so anyone can use the same tag for a random package and "interfere" with a set
- tags were introduced mostly for description and discovery purposes and are expected to be hints on their own, so customers can utilise them in their searches. If a package author decides to use a tag to identify a release, they may end up using a GUID as a tag, and that will introduce some user-friendliness related issues on NuGet.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

Below are two problems from Microsoft, where due to lack of this feature teams are struggling and have to come up with potential alternative solutions.

### .NET Release publishing

The .NET team has a monthly release cadance for their products. As part of each release we publish hundreds of packages to NuGet.
This is generally a very time-sensitive effort, especially when it comes to security releases. Many teams within Microsoft wait for our releases before they can move forward with publishing their patches immediately after, because with security releases we will also document the security fixes the release contains. Unfortunately, what happens sometimes, is that during publishing NuGet sometimes blocks certain packages due to some new validation rules or some other reason, which wasn't something the team could have foreseen earlier. As a result, the the releases get delayed and partner teams delay their releases awaiting a green light from the .NET team, which results in a tense / stressfull effort of patching the impacting packages on the last minute to address the faced issues.
Besides the security releases, there are also GA releases, which have a similar risk characteristics. Many times there are confrerences schedueld the same day when a release is planned. And during such a conference the presenter expectes the release to be published (a few hours earlier) so that they can demo some new feature(s). And it happened in the past that the releases didn't succeed in time and impacted the presentations in a negative way.

Having a mechanism to stage / pre-publish packages ahead of time and then only to `notify` NuGet to make a release available would reduce such risks dramatically, as issues would have been caught earlier during package staging, which can happen days before the actual scheduled release.

### .NET release deprecation
As part of the .NET product support policy, releases go out of support after a certain period of time. When that happens, the team has some automation to "find out" what were all the packages that were released as part of the release and then utilizes a custom built solution / tool to deprecate all these packages by calling multiple NuGet APIs per each package to do so. This is also a stressful process, such, that we had to introduce some artificial delays in the code to avoid stressing the servers.
Besides this, it's quite a challenge to keep track of all the packages that have been published as part of a single release. As build systems the .NET organization uses gets updated over the years, so does the way the information about those published packages. Hence, the deprecation tooling has to keep updating from release to release to support different stages of the build system that was used to produce a specific release that is being deprecated. This is a lot of work and many times ends up being a "guess work".
Obviously, this is a problem which can be solved by a stable solution, but instead of doing that, having a single API from NuGet for doing this in a consistent way would be a life-saver.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

In addition to the above core scenarios, this will also enable NuGet tooling scenarios, where projects can have a consistent set of dependencies. That is, NuGet can warn / suggest customers to fix inconsistent dependencies may they have such in their projects.