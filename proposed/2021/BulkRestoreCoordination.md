# Bulk restore coordination

- [Nikolche Kolev](https://github.com/nkolev92)
- Start Date 2021-05-03
- GitHub Issue [10678](https://github.com/NuGet/Home/issues/10678)
- GitHub PR [4058](https://github.com/NuGet/NuGet.Client/pull/4058)

## Summary

<!-- One-paragraph description of the proposal. -->
When a solution with SDK based projects is loaded, NuGet uses a sliding window to coordinate the number of restores being run to avoid extra restore/design time build loops.
When a solution is loaded, any future changes will trigger a restore eagerly. Operations such as branch switch are one example.
This proposal tackles the addition of a new API to coordinate the restore during the bulk changes operations.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->

There are a few scenarios where a bulk project edit may happen that affects NuGet restore.

- Branch switch
- Directory.Build.props or other shared file edits
- Find and replace in csproj

These operations are currently not very efficient and may run extra restores and design time builds. In some cases, re-opening a solution may be more efficient than a partial branch switch.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

There are no functional changes to any experiences.
The user actions are all the same, the changes have a performance focus.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->
#### Target scenario

Ex:
Given a solution with 3 projects.
Proj A -> Proj B -> Proj C.

Say a Directory.Build.Props is edited that affect *all* projects.
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

#### New interfaces

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

## Drawbacks

<!-- Why should we not do this? -->

The *risks* of this implementation are that there's a chance restore could be delay for too long, or indefinitely.
All these risks can be assessed through telemetry.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

We should definitely *do* something to fix the overall problem.
There is no workaround and this is a huge performance burden.

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
