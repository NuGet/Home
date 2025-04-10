
# Visual Studio - Partial restore optimization

* Status: In Review
* Author(s): [nkolev92](https://github.com/nkolev92)
* Issue: [9513](https://github.com/NuGet/Home/issues/9513) Visual Studio partial restore for PR projects (noop++) prototype

## Problem Background

### Restore and performance requirements

In PackageReference the restore gesture is everything. Given a project state, a restore generates the assets file and all the outputs as necessary.
PackageReference based projects cannot build without an assets file, which means the restore operation is invoked very frequently, as frequently as build is if one is using `dotnet.exe` or `Visual Studio` with [automatic](https://docs.microsoft.com/en-us/nuget/reference/nuget-config-file#packagerestore-section) or `On Build` restore enabled.

As a consequence restore needs to be as fast as possible. More specifically, a point of interest is what's often referred to as no-op restore. The original design for no-op is captured in [no-op restore](https://github.com/NuGet/Home/wiki/NuGet-Restore-No-Op).
The no-op check is a per project check that ensures the input/outputs have not changed.
No file writes will occur when the no-op check succeeds.

## Who are the customers

All NuGet Visual Studio customers with PackageReference projects

## Goals

Propose a design for a faster, more aggressive no-op check to improve the performance/

## Non-Goals

* packages.config restore is not considered.
* Optimization for restores after package installations are not considered.

## Solution

A lot about the restore command is incremental. From the frequently referred to [no-op restore](https://github.com/NuGet/Home/wiki/NuGet-Restore-No-Op), the global packages folder being shared across projects, to the resolution algorithm which favors the lowest applicable version and the prioritization of local sources over http sources.

All restores are project based and independent. While project A might depend on project B, it does not need project B to be restored, it merely needs the project B state, it's PackageReference, ProjectReference etc.

The restore implementation across all NuGet restore capable products is shared. The only difference is how the information about the project is gathered. In commandline scenarios, it's MSBuild, in Visual Studio scenarios, it's the project systems.

### Visual Studio and restore

Unlike command line restores, where it's 1 process, 1 restore operation, Visual Studio is a long lived process.
All restores in Visual Studio are solution based. What this means is we just run restore for every loaded project. Every restore operation in Visual Studio has the same scope.

If you refer to [no-op restore](https://github.com/NuGet/Home/wiki/NuGet-Restore-No-Op), we can simplify the no-op relevant information to:

* Inputs
  * Evaluated project file, PackageReference & all ProjectReference
  * That includes the inputs for all children projects.
  * NuGet settings, such as sources, global packages folders.
* Outputs
  * Project specific
    * assets file
    * msbuild files
    * the lock file
    * the cache file
  * Shared
    * required packages on disk

The inputs change quite frequently.
The project specific outputs can be affected by common user gestures such as "git clean", removing the obj folder.

The shared outputs such as the packages from the global packages folder change infrequently. It requires customers to delete the global packages folder or any of the fallback folders.

The current no-op optimization can be disabled, through a force switch on the commandline and certain gestures in Visual Studio.

#### Visual Studio restore gestures

From a technical perspective, restore can be different in 2 different ways.

* `SolutionRestoreJob` which handles the command, automatic and on build restores.
* Package installation through the PM UI & PMC also runs restore, but it doesn't not run through the `SolutionRestoreJob`.

The PMUI/PMC command flows will never no-op, so as such they are not the focus.

The NuGet in Visual Studio restore has 3 different gestures:

* OnBuild - Runs before build
* Explicit - Solution restore command
* Implicit - Auto restore

Those can further be captured in the below table.

| Gesture | OperationSource | Is no-op allowed | Notes |
|---------|-----------------|------------------|-------|
| Project Nomination cause by a project edit, or a project reload | Implicit | Yes | |
| Build, both project & solution build | OnBuild | Yes | |
| Rebuild, both project & solution build | OnBuild | No | Rebuild defeating no-op is a legacy behavior. Currently, there's no gesture in Visual Studio to force NuGet to reevaluate. |
| Clean project/solution, then Build | OnBuild | Yes | This technically allows no-op but will not no-op because clean right now deletes the no-op cache on disk.|
| Restore command | Explicit | Yes | User requested restore. It allows no-op. |

### SolutionUpToDateChecker

We can't cover the complete implementation of restore here, it is notable to mention the PackageSpec and DependencyGraphSpec concepts in PackageReference restore.

PackageSpec represents the single project inputs.
DependencyGraphSpec represents many project inputs. Additionally it also contains a list of projects that are being restored.

For example the DependencyGraphSpec for project A with dependencies to projects B and C, will contain the PackageSpecs for A, B, C & A as a restore target.

#### Project inputs

When the solution restore in VS runs, the check is done for every project individually.

Prior to any project restore being run, in Visual Studio (and really in all products), we generate a complete DependencyGraphSec. See [SolutionRestoreJob](https://github.com/NuGet/NuGet.Client/blob/788bc01a1b063a37841cdd6d035feb320e90e475/src/NuGet.Clients/NuGet.SolutionRestoreManager/SolutionRestoreJob.cs#L329) in VS. See [RestoreTask](https://github.com/NuGet/NuGet.Client/blob/788bc01a1b063a37841cdd6d035feb320e90e475/src/NuGet.Core/NuGet.Build.Tasks/RestoreTask.cs#L136) for MSBuild/Dotnet.exe
Given the transitive nature of restore, the full project closure of project to be restored is required.
Today that's done by cloning the project inputs and including them in DependencyGraphSpec for the project restore.
That can be expensive. Given that all the package specs are known before any restore is run we can attempt to do a solution based restore. See [DependencyGraphSpecRequestProvider](https://github.com/NuGet/NuGet.Client/blob/253a77105feba2fdc481efc041e0f01242902087/src/NuGet.Core/NuGet.Commands/RestoreCommand/RequestFactory/DependencyGraphSpecRequestProvider.cs#L83) for reference.

#### Outputs

##### Project specific

Currently we only verify that the files exist on disk for our no-op check.
Given the deterministic nature of the number of files, this is not the expensive part.
Handled in the [NoOpRestoreUtilities](https://github.com/NuGet/NuGet.Client/blob/788bc01a1b063a37841cdd6d035feb320e90e475/src/NuGet.Core/NuGet.Commands/RestoreCommand/Utility/NoOpRestoreUtilities.cs#L123).

##### Shared

All the packages in the closure need to be on disk, either in the global packages folder or the fallback folders.
Currently  in the [NoOpRestoreUtilities](https://github.com/NuGet/NuGet.Client/blob/788bc01a1b063a37841cdd6d035feb320e90e475/src/NuGet.Core/NuGet.Commands/RestoreCommand/Utility/NoOpRestoreUtilities.cs#L123), in the same way as the project level restore outputs.
Given how infrequently these are deleted, the proposal is to avoid this check during the Visual Studio fast no-op check.

### Putting it all together - partial restore

The proposal is that we do not validate all the packages from the global packages folder.
However we will validate the existence of the global packages folder itself.

* Any inputs change affects the current project and it's parents.
* Any outputs change affects the current project only.

Given that we have all solution inputs, we do the PackageSpec checks individually instead of the DependencyGraphSpec level.
This allows us to do 1 comparison for each package spec instead of N, where N is the number of closures the PackageSpec appears in.

If the input is `dirty` then we treat the projects referencing it as dirty as well.
If a output is dirty, then only said project is considered dirty.

Lastly the status needs to be reported in order to ensure we are not no-op a failed project.
A project could fail due to an ambient state, such as sources or security access. This is consistent with the current implementation of no-op.

### Caveats

* We are not gonna watch the packages folder. A delete in the global packages folder will not defeat the partial restore optimization.
* At the beginning of every Visual Studio restore operation, we remove all NuGet related errors and warnings from the error list. When a project no-ops the warnings raised during the previous restore need to replayed. Currently those are persisted in the assets and cache files. In SDK based projects, the project-system surfaces the warnings in the error list. In csproj.dll PackageReference based projects, they are written to the error log again by NuGet. So this optimization will not work with LegacyPackageReferenceProjects for now.
* The global packages folder existence check can cause a false negative in some situations, where there are no packages required but a project is PackageReference based, but even in that case, the project level no-op check offers an out.

### Scenarios that improve

This is a far reaching change and will affect the restore experience in Visual Studio quite dramatically. In this section, we summarize the scenarios where the impact will be most noticeable.

* *Frequent builds with restore enabled* - A common user workflow is, code, code, build. This is usually a complete no-op. This would reduce the overhead restore adds to the build operation. This is currently the most frequent way a restore is run.

* *Unit test scenarios* - This might also be consider a subset of the above, but it's worth calling out that when a developer is writing unit tests, with all the defaults enabled, the restore overhead to the unit test execution (due to the build run) is reduced.

* *Manually editing the csproj* - With the birth of .NET Core & SDK based projects, much of the tooling has evolved, so that now customers can manually edit the csproj to add/change references. With this change, the project based restore would only be run for the edited project and it's parents. Before it was run for all the projects in the solution. Example: Say you have 80 projects(NuGet.sln), and you edit the PackageReference for one project, (say NuGet.PackageManagement.UI), then the project based will be run only for maybe 5 of the 80 projects in the solution.
Notable to mention that the overhead of the restore for the projects that actually change, would likely exceed the `savings` this improvement nets, so the overall impact is more limited.

* *Start-up for extra large solutions* - When loading a large solution where the majority of the projects are SDK-based, NuGet would run a restore at a certain point. Given the size of the solution, currently, the timing of when that restore happens is not perfect, so we sometimes find ourselves doing 2, 3 or even more restores. While that on its own needs work, this change allows for the 2nd, 3rd and every subsequent restore to be significantly more efficient.

### Success metrics

Given that this is an optimization affecting the large majority of PackageReference projects, the success metrics are straightforward.

* An improvement of the restore no-op performance across the board. Specifically the difference should be noticeable for large solutions.
* Add a metric to track the number of projects that are up to date in the solution based check. We'd normally expect the numbers to remain equivalent to the current number of projects that noop.
* Add a metric to track the overhead of this check. Ideally this check remains minimal. The overhead added should be justified by the fact that project level restores will not be frequent (beyond solution load).

## Future Work

* Replay the warnings for LegacyPackageReference projects and enable the partial restore optimization [9565](https://github.com/NuGet/Home/issues/9565)
* Profile the allocations improvement by this change. Specifically compare 16.6 to 16.7.[314](https://github.com/NuGet/Client.Engineering/issues/314)
* Analyze changing the user gestures that defeat no-op. Specifically the lack of a specific gesture to reevaluate the packages lock file and floating versions. Rebuild as a gesture seems counterintuitive. [6987](https://github.com/NuGet/Home/issues/6987)
* Analyze the frequency of restores and understand the likely root cause. [9566](https://github.com/NuGet/Home/issues/9566), [9567](https://github.com/NuGet/Home/issues/9567), [9568](https://github.com/NuGet/Home/issues/9568)
* Analyze the success of the solution based partial restore optimization [315](https://github.com/NuGet/Client.Engineering/issues/315)

## Open Questions

## Considerations

* Checking the timestamp of all the package directories was considered but ultimately went against that adds a lot of memory overhead and decreases the wins.

### References

* [Original no-op restore spec](https://github.com/NuGet/Home/wiki/NuGet-Restore-No-Op)
