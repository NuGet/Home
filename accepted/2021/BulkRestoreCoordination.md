# Bulk restore coordination

- [Nikolche Kolev](https://github.com/nkolev92)
- Start Date 2021-05-03
- GitHub Issue [10678](https://github.com/NuGet/Home/issues/10678)
- GitHub PR [4058](https://github.com/NuGet/NuGet.Client/pull/4058)
- Status: Implemented

## Summary

<!-- One-paragraph description of the proposal. -->
When a solution with SDK based projects is loaded, NuGet uses a sliding window to coordinate the number of restores being run to avoid extra restore/design time build loops.
When a solution is loaded, any future changes will trigger a restore eagerly. Operations such as branch switch are one example.
This proposal tackles the addition of a new API to coordinate the restore during the bulk changes operations.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->

There are a few scenarios where a bulk project edit may happen that affects NuGet restore.

- Branch switch (either in Visual Studio or commandline)
- Directory.Build.props or other shared file edits
- Find and replace in csproj

These operations are currently not very efficient and may run extra restores and design time builds. In some cases, re-opening a solution may be more efficient than a partial branch switch.

Some of these scenarios are detectable (Visual Studio branch switch), others may appear as ambient. For example, changing a branch on the commandline may appear equivalent to editing csproj files very quickly.
There are different levels of coordination between the components in play.
The primary goal is improving the branch switching scenario through Visual Studio.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

There are no functional changes to any experiences.
The user actions are all the same, the changes have a performance focus.

The user *may* be able to observe differences in any of the above mentioned scenarios, bulk edit, branch switch. 

The time it takes for the user to be able to do work should be shorter than before.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->
#### Target scenario

Ex:
Given a solution with 3 projects.
Proj A -> Proj B -> Proj C.

Say a Directory.Build.Props that affect *all* projects is edited.
Say the nominations come in the following order:

Proj B
Proj C
Proj A

- When the nomination for B comes in, NuGet will trigger a restore that will affect projects B & A, given that A depends on B.
- While that first restore runs, it possible that C & A nominations have arrived. When NuGet receives these nominations and the previous restore completes, which happens last, a new restore will be kicked off, with the nomination data for C & A.
- This second restore will affect A, B & C. Project A & B have been restored twice, thus causing unnecessary work.
- In the ideal scenario, only 1 restore for each 3 projects is done.

#### Restore batching

At solution load, project-system runs DT builds and call the `IVsSolutionRestoreService` to nominate a project.
NuGet is aware of *all* projects that are supposed to nominate, so NuGet can wait for *all* projects to be nominated.
Currently NuGet has a sliding window to account for potentially failed projects.

When the solution is loaded, NuGet doesn't have an additional heuristic to determine whether there are other projects that might need a restore done.
The proposal is that each time NuGet determines a restore might need run, it checks whether there are *any* projects with pending *design time builds*, that *might* nominate. If yes, NuGet will wait.
This will allow NuGet to remove the sliding window as NuGet can report progress or lackthereof on projects that are taking time to nominate.

#### New interfaces

- All these APIs are should be implemented free threaded.

##### IVsSolutionRestoreService4

```cs
    /// <summary>
    /// Represents a package restore service API for integration with a project system.
    /// Implemented by NuGet.
    /// </summary>
    [ComImport]
    [Guid("72327117-6552-4685-BD7E-9C40A04B6EE5")]
    public interface IVsSolutionRestoreService4
    {
        /// <summary>
        /// A project system can call this service (optionally) to register itself to coordinate restore. <br/>
        /// Each project can only register once. NuGet will call into the source to wait for nominations for restore. <br/>
        /// NuGet will remove the registered object when a project is unloaded.
        /// </summary>
        /// <param name="restoreInfoSource">Represents a project specific info source</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <exception cref="InvalidOperationException">If the project has already been registered.</exception>
        /// <exception cref="ArgumentNullException">If <paramref name="restoreInfoSource"/> is null. </exception>
        /// <exception cref="ArgumentException">If <paramref name="restoreInfoSource"/>'s <see cref="IVsProjectRestoreInfoSource.Name"/> is <see langword="null"/>. </exception>
        Task RegisterRestoreInfoSourceAsync(IVsProjectRestoreInfoSource restoreInfoSource, CancellationToken cancellationToken);
    }
```

##### IVsProjectRestoreInfoSource

```cs
    /// <summary>
    /// Represents a package restore service API for integration with a project system.
    /// Implemented by the project-system.
    /// </summary>
    [ComImport]
    [Guid("35AD5FF2-6AB7-48E9-BCC0-189042410FA6")]
    public interface IVsProjectRestoreInfoSource
    {
        /// <summary>
        /// Project Unique Name.
        /// Must be equivalent to the name provided in the <see cref="IVsSolutionRestoreService3.NominateProjectAsync(string, IVsProjectRestoreInfo2, CancellationToken)"/> or equivalent.
        /// </summary>
        /// <remarks>Never <see langword="null"/>.</remarks>
        string Name { get; }

        /// <summary>
        /// Whether the source needs to do some work that could lead to a nomination. <br/>
        /// Called frequently, so it should be very efficient.
        /// </summary> 
        bool HasPendingNomination { get; }

        /// <summary>
        /// NuGet calls this method to wait on a potential nomination. <br/>
        /// If the project has no pending restore data, it will return a completed task. <br/>
        /// Otherwise, the task will be completed once the project nominates. <br/>
        /// The task will be cancelled, if the source decide it no longer needs to nominate (for example: the restore state has no change) <br/>
        /// The task will be failed, if the source runs into a problem, and it cannot get the correct data to nominate (for example: DT build failed) <br/>
        /// </summary>
        /// <param name="cancellationToken">Cancellation token.</param>
        Task WhenNominated(CancellationToken cancellationToken);
    }
```

#### Implementation details

- Given that there are risks with this proposal, the NuGet implementation will have a means of disabling this feature.
- NuGet will only account for projects that have registered an IVsProjectRestoreInfoSource. A PackageReference based project does not have to register an IVsProjectRestoreInfoSource; however, not registering means that these projects will not participate in the bulk coordination and add a performance hit.
- At solution load time, NuGet should be able to remove the sliding window, and rely on reporting information to the customer about potentially delayed restores. The frequency and the means of reporting can be determined at a later point.
- In any non solution load scenario, NuGet can loop through all IVsProjectRestoreInfoSource objects, calling `HasPendingNomination`. When the first project reports `true` NuGet will call `WhenNominated` on that project. There is no need for NuGet to call `WhenNominated` on all pending projects.
It is likely that by the time the project in question has nominated, other projects would be done as well. If NuGet called `WhenNominated` at least once, then we'd need to check whether any projects have updated since then. In most relevant scenarios, this should never trigger another round of waiting for NuGet. If it does, it can be reported as a consideration.
- `HasPendingNomination` on the implementer's side (project-system) must be *very fast*, as it'll be called frequently and often. This is expected to be design time build version comparison. 

#### Measuring success

- Unlike the solution load scenario, the branch switching scenario does not have a natural technical end, so measuring it through telemetry is a work in progress.
- The operation progress API can track solution load, but the results are very flaky when trying to track the branch switch and related scenarios.
- For now the focus is on individual components measuring their own work.
- Some of the complexities of the branch switch scenario is that it may trigger a solution reload, project reload, or just a design time build.

NuGet will measure:

- The performance of the new `Is there any pending work` check.
- The amount of time NuGet spent delaying restore.

The number of restores after a branch switch and the distance between the start time of restore  - time of last restore end is of interest as well, albeit it's fairly difficult to monitor.

## Drawbacks

<!-- Why should we not do this? -->

The *risks* of this implementation are that there's a chance restore could be delayed for too long, or indefinitely.
All these risks can be assessed through telemetry.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

We should definitely *do* something to fix the overall problem.
There is no workaround and this is a huge performance burden.

Various other shapes of the API were considered.

- Having a single service that keep track of all projects so that NuGet could do something `WhenAllProjectsReady`.
  - There in no preexisting component that contains all this knowledge. The project system knows about a single project.
  - There's no easy answer for a component that would be best suited to handle this logic. Given that the rest of the APIs are defined by NuGet, it makes sense that these APIs are defined as well.

- Event driven, or push mechanism that would notify NuGet when design time builds are going on.
  - The architecture on CPS side is that there are no events for design time build progress. The managed languages project-system is the only component that knows of NuGet. Given that significant amount of this work is async and it was simpler to add an API that can track the design time builds scheduled and progress for NuGet only, rather than relying on a generic mechanism.

- The current API itself does not have any guarantees against race conditions between a project reporting as dirty and the likelihood of a change to have happened, as this is an implementation detail. We do not believe there's a design that can better mitigate these race conditions in every scenario.
  - A number of scenarios either will not or are likely not to suffer from race conditions.
    - When branch switching through the IDE, thanks for BulkFileOperation, all projects will know they are dirty, prior to NuGet ever receiving a nomination.
    - Find and Replace in csproj - CPS has a sliding window to detect changes. Unless the number of changes is extremely large it's very likely that by the time a design time build of relevant to NuGet has completed, the other instances have already triggered/scheduled a design time build.
    - Editing a single file such as Directory.Build.Props is likely to benefit as well, as the design time build for a project that may lead to the first nomination is likely to be longer than the sliding window for reevaluationthat CPS based projects have.
  - There are many design time builds running in a single VS session, but only a few affect a nomination and NuGet.
- Poll/Push is largely a different perspective to the same solution as most design time builds are not of a concern to NuGet. The difference between a Push and Pull API can be summarized as:
  - Do design time builds being run when they do not concern NuGet get processed? (DTB start/end notifications API)
  - Does NuGet do slightly more work to determine whether it's batching is good enough when it decides it needs a restore.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevent to this proposal? -->

N/A

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

N/A

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

There are *many* implementation details around this feature, which can include things such as reporting that restore has been delayed etc.
This API is designed with those opportunities in mind.

## References

- [Design time builds](https://github.com/dotnet/project-system/blob/main/docs/design-time-builds.md)
- [Restore to intellisense](https://github.com/nkolev92/restore-to-intellisense/), [presentation (Microsoft only)](https://msit.microsoftstream.com/video/e449a1ff-0400-9887-1aca-f1eb55f40c4b?channelId=8855a1ff-0400-a936-24ca-f1eaa053d9d5)
- [Branch switch effort](https://devdiv.visualstudio.com/DevDiv/_wiki/wikis/DevDiv.wiki/22071/Branch-Switch)
