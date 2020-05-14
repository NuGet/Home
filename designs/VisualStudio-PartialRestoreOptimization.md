
# Visual Studio - Partial restore optimization

* Status: In Review
* Author(s): [nkolev92](https://github.com/nkolev92)
* Issue: [9513](https://github.com/NuGet/Home/issues/9513) Visual Studio partial restore for PR projects (noop++) prototype

## Problem Background

### Restore and performance requirements

In PackageReference the restore gesture is everything. Given a project state, a restore generates the assets file and all the outputs as necessary.
Additionally PackageReference based projects cannot build without an assets file, which means the restore operation is invoked very frequently, as frequently as build is if one is using `dotnet.exe` or `Visual Studio` with [automatic](https://docs.microsoft.com/en-us/nuget/reference/nuget-config-file#packagerestore-section) or `On Build` restore enabled.
As a consequence restore needs to be as fast as possible. More specifically, a point of interest is what's often referred to as no-op restore.

## Who are the customers

All NuGet Visual Studio customers with PackageReference projects

## Goals

Propose a design for a faster, more aggressive no-op check to improve the performance/

## Non-Goals

* packages.config restore is not considered.
* Optimization for restores after package installations are not considered.

## Solution

A lot about the restore command is incremental. From the frequently referred to [no-op restore](https://github.com/NuGet/Home/wiki/NuGet-Restore-No-Op), the global packages folder being shared across projects, to the resolution algorithm which favors the lowest applicable version and the prioritization of local sources over http sources.
Finally all restores are project based an independent. While project A might depend on project B, it does not need project B to be restored, it merely needs the project B state, it's PackageReference, ProjectReference etc.

The restore implementation across all NuGet restore capable products is shared. The only difference is how the information about the project is gathered. In commandline scenarios, it's MSBuild, in Visual Studio scenarios, it's the project systems.

### Visual Studio and restore

Unlike command line restores, where it's 1 process, 1 restore operation, Visual Studio is a long lived process.
All restores in Visual Studio are solution based. What this means is we just run restore for every loaded project. Every restore operation in Visual Studio has the same scope.

If you refer to [no-op restore](https://github.com/NuGet/Home/wiki/NuGet-Restore-No-Op), and apply the implementation context, we could really simplify the relevant for no-op restore down to:

* Project inputs (evaluated project file, PackageReference & all ProjectReference). That includes the inputs for all children projects. The PackageSpec models contains the settings, etc.
* Project specific restore outputs like assets file, msbuild files & the lock file
* The needed packages on disk/packages folder.

The first 2 are fewer and change more frequently.
The last one is infrequently changed. It requires customers to delete the global packages folder or any of the fallback folders.

The current no-op optimization can be disabled, through a force switch on the commandline and certain gestures in Visual Studio.

#### Visual Studio restore gestures

There are 2 technical ways the restores are run in.
The `SolutionRestoreJob` which handles the command, automatic and on build restores.
Package installation through the PM UI & PMC also runs restore, but it doesn't not run through the `SolutionRestoreJob`.
The reference change flows will never no-op, so as such they are not the focus.

The NuGet in Visual Studio restore is now considering 3 different gestures:

* OnBuild - Runs before build
* Explicit - Solution restore command
* Implicit - Auto restore

All of that is captured below:

| Gesture | OperationSource | Is no-op allowed | Notes |
|---------|-----------------|------------------|-------|
| Project Nomination cause by a project edit, or a project reload | Implicit | Yes | |
| Build, both project & solution build | OnBuild | Yes | |
| Rebuild, both project & solution build | OnBuild | No | Rebuild defeating no-op is a legacy behavior. Currently, there's no gesture in Visual Studio to force NuGet to reevaluate. |
| Clean project/solution, then Build | OnBuild | Yes | This technically allows no-op but will not no-op because clean right now deletes the no-op cache on disk.|
| Restore command | Explicit | Yes | User requested restore. It allows no-op. |

### SolutionUpToDateChecker

Understanding we can't cover the complete implementation of restore here, it is notable to mention the PackageSpec and DependencyGraphSpec concepts in PackageReference restore.
PackageSpec represents the single project inputs.
DependencyGraphSpec represents many project inputs. Additionally it also contains a list of projects that are being restored.
For example the DependencyGraphSpec for project A with dependencies to projects B and C, will contain the PackageSpecs for A, B, C & A as a restore target.

Reiterating from above, the 3 relevant inputs to restore are:

* Project inputs
* Project level restore outputs like assets file, msbuild files & the lock file.
* The needed packages on disk/packages folder.

In the below, we tackle each one individually and examine whether they can be tackled together.

#### Project inputs

When the solution restore in VS runs, the check is done for every project individually.
Prior to any project restore being run, in Visual Studio (and really in all products), we generate a complete DependencyGraphSec. See [SolutionRestoreJob](https://github.com/NuGet/NuGet.Client/blob/788bc01a1b063a37841cdd6d035feb320e90e475/src/NuGet.Clients/NuGet.SolutionRestoreManager/SolutionRestoreJob.cs#L329) in VS. See [RestoreTask](https://github.com/NuGet/NuGet.Client/blob/788bc01a1b063a37841cdd6d035feb320e90e475/src/NuGet.Core/NuGet.Build.Tasks/RestoreTask.cs#L136) for MSBuild/Dotnet.exe
Given the transitive nature of restore, the full project closure of project inputs is required.
Today that's done by cloning the project inputs and including them in DependencyGraphSpec for the project restore.
That can be expensive. Given that all the package specs are known before any restore is run we can attempt to do a solution based restore.

#### Project level restore outputs like assets file, msbuild files & the lock file

Currently we only verify that the files exist on disk for our no-op check.
Given the deterministic nature of the number of files, this is not the expensive part.
Handled in the [NoOpRestoreUtilities](https://github.com/NuGet/NuGet.Client/blob/788bc01a1b063a37841cdd6d035feb320e90e475/src/NuGet.Core/NuGet.Commands/RestoreCommand/Utility/NoOpRestoreUtilities.cs#L123).

#### The needed packages on disk/packages folder

All the packages in the closure need to be on disk, either in the global packages folder or the fallback folders.
Currently  in the [NoOpRestoreUtilities](https://github.com/NuGet/NuGet.Client/blob/788bc01a1b063a37841cdd6d035feb320e90e475/src/NuGet.Core/NuGet.Commands/RestoreCommand/Utility/NoOpRestoreUtilities.cs#L123), in the same way as the project level restore outputs.
Given how infrequently these are deleted, the proposal is to avoid this check during the Visual Studio fast no-op check.

### Putting it all together - partial restore

Each one of the 3 above markers represents something that defeats no-op.
The proposal is that we do not watch for the global packages folder.

* Any inputs change affects the current project and it's parents.
* Any outputs change affects the current project only.

Given that we have all solution inputs, we do the PackageSpec checks individually instead of the DependencyGraphSpec level.
This allows us to do 1 comparison for each package spec instead of N, where N is the number of closures the PackageSpec appears in.

If a PackageSpec or input is `dirty` then we treat the projects referencing it as dirty as well.
If a output is dirty, then only said project is considered dirty.

Lastly the status needs to be reported in order to ensure we are not no-op a failed project.
A project could fail due to an ambient state, such as sources or security access. This is consistent with the current implementation of no-op.

### Caveats

* We are not gonna watch the packages folder. A delete in the global packages folder will not defeat the partial restore optimization.
* At the beginning of every Visual Studio restore operation, we remove all NuGet related errors and warnings from the error list. When a project no-ops the warnings raised during the previous restore need to replayed. Currently those are persisted in the assets and cache files. In SDK based projects, the project-system surfaces the warnings in the error list. In csproj.dll PackageReference based projects, they are written to the error log again by NuGet. So this optimization will not work with LegacyPackageReferenceProjects for now.

## Future Work

* Replay the warnings for LegacyPackageReference projects and enable the partial restore optimization
* Profile the allocations improvement by this change. Specifically compare 16.6 to 16.7.
* Analyze changing the user gestures that defeat no-op. Specifically the lack of a specific gesture to reevaluate the packages lock file and floating versions. Rebuild as a gesture seems counterintuitive.
* Analyze the frequency of restores and understand the likely root cause

## Open Questions

* TBD

## Considerations

* Checking the timestamp of all the package directories was considered but ultimately went against that adds a lot of memory overhead and decreases the wins 

### References

* Links to no-op, the future work, the current implementation.

# TODO NK - Really focus on input/outs.
