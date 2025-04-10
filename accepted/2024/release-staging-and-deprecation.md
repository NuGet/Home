# ***Release staging and deprecation***
<!-- Replace `Title` with an appropriate title for your design -->

- Author Name Artak Mkrtchyan ([mkArtakMSFT](https://github.com/mkArtakMSFT))
- GitHub Issue <https://github.com/NuGet/NuGetGallery/issues/3931>

## Summary

This proposal introduces a concept for grouping packages that are published to NuGet.
This will allow one to easily identify all the packages released as part of a single group as well as request bulk-processing
 for all packages which belong to the same group. For example, all packages published as part of .NET 8 release will be staged
 together and then also can be deprecated together by a single call to NuGet APIs.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Many products (Apps / Tools / Frameworks / Utilities / etc. ...) consist of multiple interdependent packages which should be published together as a single set.
 Currently, NuGet provides no functionality for defining / grouping packages into such sets.
 This results in package owners having to keep track of these package sets on their own.
 There are three specific sets of scenarios which this feature will simplify dramatically:
1. When preparing a release, product owners would like to have a mechanism to pre-stage their product packages,
 so that the release will consist only of a single action of marking the set of packages as `published`,
 which would result all the packages in the set to be marked as published at the same time.
2. Sometimes developers have to take a dependency on several related packages in their projects, which are part of the same "release".
 Without having a concept of the `release` developers have to guess which versions of those packages are compatible.
 As a result, most of the time developers would simply pick the latest version of all these packages, which sometimes can lead to incompatibility issues down the road.
3. Keeping a package healthy on NuGet also means keeping the list of packages aligned with it support policy.
Hence, package owners try to deprecate packages which are out of support. Without ability to group packages,
 package owners end up keeping track of all the packages which belong to the same release and run the deprecation over a discrete set of packages when necessary. Being able to group packages together would enable deprecating a whole release at once, knowing that all the packages which belong to that release will get deprecated.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
A new NuGet CLI command option `stage` will be added to the `push` command, which will allow a user to stage a package to a NuGet server, specifying a group identifier. (dotnet nuget push --stage [group-id])
 Staged packages will be uploaded to NuGet server and will be validated as part of the staging process, so that if a package being staged fails validation, the staging fails. After uploading multiple packages, the user can then call `nuget push --group [group-id]`
 command to request all the packages from the earlier group to become available on the server as `published`.
Note, that the `group` information will only be stored on the server and has nothing to do with how a package was built.

Groups are scoped to an owner. So a package published by `Owner 1` into `Group 1` has nothing to do with another package published
 to `Group 1` by `Owner 2`, as these should be treated as two separate groups.

Groups can expand over time, by publishing new packages to the same group in the future. There is no concept of a "deprecated group"
 as group by itself is stateless. It's just a collection of packages. A package can belong only to a single group.
 This group expansion functionality will be handy for the error situation described above, where during staging a package staging fails.
 This will result in only some packages being staged. The user will need to address the issues related to the failed package
 and stage the remaining packages using the same command. Note, that if a package is staged, the operation should be idempotent,
 and a request to stage the same package again should only result in a warning message (package is already staged) and the package shouldn't be uploaded again.

Groups can later be used in the future when it's time to deprecate a set of packages. The package author can request to
 deprecate a `group` by calling a single command on the nuget CLI and all the packages that belong to that group will be marked as `deprecated`.
 This particular functionality depends on the support of the NuGet Deprecation command, which is not yet publicly available.

With this information in place, new set of NuGet APIs / extensions will be needed to allow a user to run the following actions:
- **Stage** a package for later publishing
- **Publish an earlier staged group**
- **Deprecate a group** using the group id 
- **Discard a staged release** using the group id

Note, that the user is required to be the owner / co-owner of the packages which are in the group,
otherwise the request to make any modification to a non-owned package will fail.

#### Package staging
When a package is staged, the id of the package is reserved at that point, and no other user can introduce a package with the same name.

Also, to avoid abuse, only a limited number of packages can be staged within a single group. While this can potentially be defined as a configurable value per organization / owner, there is no such requirement at the moment. Hence, this can be set to 1000 packages for now or not defined at all. Will leave this for potentially future consideration.

When staged, packages will not be visible / accessible to anyone but the co-owners. The co-owners will be able to see the current staged list for a given group using `nuget list --stage [group-id]` command. 


#### Group Ownership

A questions arises regarding group ownership. What does group ownership mean?
Groups should have no concept of ownership. The concept ownership is applicable only to packages and those rules are what control and guide the decisions of operations applied to groups.
Imagine a scenario where user A and userB are co-owners of a package. Any one of them can stage that package and the other one can handle any operation with the group the package has been associated with. If userB discards the stage, then userA won't be able to find that package in the stage any more.

Think about all this ownership thing from data model perspective.
The NuGet server will associate group id with each package that's staged / published. So when asking the question which packages belong to this group depending on which packages you have access to you will be getting a subset from the whole list.

Below are a few interesting scenarios that derieve from the above:
1. The user has staged a package to a group for later publishing, but the ownership has changed, and the user is no longer
 an owner for that package. At this point, publishing request should fail with a message that the group has been modified
 from its original set, and the outcome of the request may be different from what the user was expecting, indicating the package
 that was moved out of the group. If the user is aware of the problem and still wants to move forward with the change,
 they will have to pass an additional `--force` parameter to the publish command: `nuget push --stage <group-id> --force`.
2. The group to be published no longer has any packages in it. In this case the command should fail detailing the reason for the failure.
3. This will be the same but for deprecation. Essentially, any bulk operation using groups, where the set of the packages in the group
 have changed after staging, should result in an error with details about the change. The `--force` flag should again be used
 to ignore the change and move forward with execution of the request (either publishing or deprecation). To summarize,
 the fundamental principle is that a user cannot deprecate a package they don't own.

#### Lifespan of a staged group
If users keep staging packages but do nothing with them, NuGet server will become an ever-growing package graveyard,
 incurring higher and higher costs over time simply for storing these packages. To avoid this problem, stages should be time-limited.
 That is, there should be a maximum lifespan for a stage. Any updates to the stage will reset its TTL date to some amount (let's say 30 days). If within the next 30 days no changes are made to the stage, the NuGet server should then remove the stage (all its packages basically).

#### Expanding groups
It should be possible for a group to expand over time. This is currently a real scenario, where .NET GA SDK ships a set of packages,
 and then follow-up SDK updates ship updated packages which still belong to the same .NET 8 package group.
 Here how this will play out with the tooling support described above:
1. During GA release, the release team will stage the set of RTM packages for the release. (nuget stage --group-id "net8.0" --package-id <package-file-path>)
2. Then on the day of the release, all the staged packages will be published using `nuget push --group "net8.0"` command.
   At this point, the group with id `net8.0` will be empty.
3. Later, as new builds are being prepared for a patch release, a new set of packages will be staged, to be later published to the same group.
As there can be multiple candidate builds for a release, there is a need for functionality to discard a stage for a given group `nuget delete --stage "net8.0"`.
This will remove all the staged but not published packages from the net8.0 group.
4. A new set of packages will be staged for the 8.0 group, until the final build is known. At this point, there is only one unified set of related packages is staged.
5. On the release date, the release team will call `nuget push --group "net8.0"` again, and only the staged packages will be published, resulting in an expanded set of published packages in the net8.0 group.
6. Some time in the future, when the release is already out of support, somebody from the .NET team will call
 `nuget deprecate --stage "net8.0"` and all the packages which have ever been published to that group will be deprecated.
 Those packages, which has already been deprecated because of whatever reason, will not be altered.


### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

### Alternatives considrered
Utilizing **package tags** was considered as an alternative to solve the grouping problem.
 Unfortunately, this has issues and can't be used for this purpose. Below are some of them:
- There are currently no restrictions on tags usage, so anyone can use the same tag for a random package and "interfere" with a set
- tags were introduced mostly for description and discovery purposes and are expected to be
 hints on their own, so customers can utilise them in their searches. If a package author decides to use a tag to identify a release,
 they may end up using a GUID as a tag, and that will introduce some user-friendliness related issues on NuGet.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

Below are two problems from Microsoft, where due to lack of this feature teams are struggling and have to come up with potential alternative solutions.

### .NET Release publishing

The .NET team has a monthly release cadance for their products. As part of each release we publish hundreds of packages to NuGet.
This is generally a very time-sensitive effort, especially when it comes to security releases. Many teams within Microsoft
 wait for our releases before they can move forward with publishing their patches immediately after, because with security releases
 we will also document the security fixes the release contains. Unfortunately, what happens sometimes, is that
 during publishing NuGet sometimes blocks certain packages due to some new validation rules or some other reason, which
 wasn't something the team could have foreseen earlier. As a result, the the releases get delayed and partner teams delay
 their releases awaiting a green light from the .NET team, which results in a tense / stressfull effort of patching the impacting
 packages on the last minute to address the faced issues.
Besides the security releases, there are also GA releases, which have a similar risk characteristics.
Many times there are conferences scheduled the same day when a release is planned. And during such a conference the presenter
 expectes the release to be published (a few hours earlier) so that they can demo some new feature(s).
 And it happened in the past that the releases didn't succeed in time and impacted the presentations in a negative way.
 expectes the release to be published (a few hours earlier) so that they can demo some new feature(s).
 And it happened in the past that the releases didn't succeed in time and impacted the presentations in a negative way.

Having a mechanism to stage / pre-publish packages ahead of time and then only to `notify` NuGet to make a release available
 would reduce such risks dramatically, as issues would have been caught earlier during package staging,
 which can happen days before the actual scheduled release.

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

### Asynchronous behavior

As both publishing and deprecation commands can take some time, these will run asynchronously.
 So the CLI command for both operations will return immediately, giving the user some token which can later be used to
 track the current state of the request.
There are no critical scenarios for deprecation to happen within specific time period, however, publishing is somewhat
 critical and is being orchestrated in many cases. Hence, NuGet server should provide some guarantees for how much time the operation
 can take in the worst case. As of right now, having 10 minutes deadline for the publishing request should be reasonable.

This requirement brings a need for a new NuGet command for querying the status of an asynchronous operation. This particular requirement should be treated as a stretch goal, and it can be implemented in a later release.
Let's assume that the group publishing and deprecation commands will return some "operation id" for later state inquriry by the client.

The below command for tracking progress should be treated as a P2 ask, and can be implemented later.
`nuget status --operation-id` command can be used to track the progress of an asynchronous operation.
This can return the following results:
- `success` : when successful, the operation should also return the time when the operation was completed.
- `failed` : operation failed
When failed, the result of the command shuold also produce detailed information about what went wrong.
