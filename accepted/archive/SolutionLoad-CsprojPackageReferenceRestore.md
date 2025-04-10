
# Spec Name

* Status: In Review
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)
* Issue: [9986](https://github.com/NuGet/Home/issues/9986) Implement a pre-registration mechanism for legacy PR projects that call restore at solution open

## Problem Background

SDK based projects are tightly integrated with PackageReference and as such they can't really function without an assets file and by extension restore.
For that purpose the nomination workflow was design, where SDK based projects that get loaded in the Managed Languages project-system (eventually this functionality will be CPS) notify NuGet of every relevant project load/change. In turn NuGet will run a restore for said project if necessary. [See IVsSolutionRestoreService](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Clients/NuGet.SolutionRestoreManager.Interop/IVsSolutionRestoreService.cs).

PackageReference is not only supported with SDK projects, but csproj.dll or legacy projects too.
Certain project types that work with PackageReference wanted a similar experience on solution load, so their project-systems similarly would call a *similar* API that simulates a nomination and thus causing NuGet to run restores on solution load. [See IVsSolutionRestoreService2](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Clients/NuGet.SolutionRestoreManager.Interop/IVsSolutionRestoreService2.cs).

### Different models for getting reference information in Visual Studio

In PackageReference style projects, there are 2 inputs to restore and that's the NuGet configuration and the project's references, in particular PackageReference and ProjectReference.

While the configuration is calculated in an equivalent way, the approach for getting the package and project references is different:

* SDK-based projects follow a push model (i.e. nomination)
* csproj.dll projects follow a pull model (i.e. IVsProject4 PackageReference and ProjectReference apis)

### Nomination API Caveat

The nominate API leading to a restore is a leaky abstraction. For SDK based projects, it's not supposed to lead to a restore. It's supposed to ensure that the project is up to date as far as NuGet is concerned. The fact that a restore is run is an implementation detail that ideally wasn't communicated to project-system implementers.

While NuGet knows how to coordinate solution load restore for SDK based projects, it doesn't know how to do the same for these csproj.dll projects and these could lead to a few extra restores.
While this functionality was added consciously by NuGet, it was not easily obvious what this could lead to.

### Current implementation

In 16.8, we made various improvements to allow us to run only 1 run on solution load. This required changing the batching logic for solution load.

A bit of background around solution load and the activities happening there as of 16.8 P4.

* At solution load, NuGet is able to identify and classify *all* projects in the solution (by listening to the SolutionEvents ProjectAdded).
* NuGet now knows all projects in the solution that are expected to nominate.
* When the first nomination comes in, NuGet starts waiting for *all projects* to be nominated.
* In order to ensure that we don't wait for forever, NuGet has a 10s sliding window. This means that even if all the projects were *not* nominated yet, NuGet will still try to restore as long as 10s since the last nomination have passed.

### What happens when there's a mix of csproj.dll and SDK based projects

Take the NuGet.Client solution for example, where there are ~70 SDK projects and ~10 csproj.dll PackageReference projects.
Out of those 10 projects, 3 have implemented a logic that will call the nomination API whenever said project has been loaded.
Due to the solution structure, this leads to 3 restores at solution load almost consistently.

Now you're likely asking yourself, how do we have 3 restores?

Even if NuGet doesn't expect a nomination from certain projects, it will *still* batch the restores ran for that nomination call because they might've happened before the last nomination call for an SDK based project.

Given that VS loads projects in the order in which they are defined in the project file, it happens almost consistently that the nomination calls from those 2 VSIX projects come after the last SDK based project nomination.

While, there's many csproj.dll projects supporting PackageReference, we have so far identified that Xamarin and VSIX projects are the ones that do call nomination on solution load.

### What are the consequences

Wasted resources. Reasoning about `solution load` is very difficult and because VS loads projects in parallel and in order in which they were declared in the solution, this means that not all legacy projects are guaranteed to nominate in that window, so we're likely to do restores that have no effective impact. 
Note that this now means that we're running an extra optimized partial restore, but for legacy projects this can still be expensive.

## Who are the customers

Customers with csproj.dll based PackageReference projects.

## Goals

* Propose a coordination mechanism to avoid extra restores.
* Given that this is likely to be a multi-component, track those project-systems and drive the changes to adopt this new mechanism.

## Non-Goals

## Solution

What makes solution load running predictable in SDK based projects situation is that NuGet knows what projects are supposed to nominate. As described above, NuGet can't even restore an SDK based project if the nomination has not come in, because the data is pushed to NuGet.

The proposal is to extend this `knowledge` to NuGet in csproj.dll projects.
In particular, we are proposing that NuGet tracks the `nominate` call for those projects and waits for all the nominations similarly to how we wait for SDK based projects.
The reference data will still be read through the poll model. The reason for this is if those projects could move to new model, they would've already. We are looking for a minimal investment approach here.

### How do projects pre-register

Project-systems have capability model. Whenever NuGet detects a project that's csproj.dll-based PackageReference, it can check for an additional capability that will indicate that a project is expected to call nominate at solution load.

### What capability in particular

We *might* be able to re-use some existing capabilities, but we need to be able to correctly identify and bucketize the right groups of project.
The particular capability name is up for discussion at this point.

[See Open Questions](#open-questions)

## Future Work

* Once the design has been agreed on, this will require changes in potentially multiple project-systems. The changes should be minimal and low effort.

## Open Questions

* What should be the capability name?

`PackageReferences` is a capability we can consider. I am not confident whether `PackageReference` suggests a communication method with NuGet (ie. push vs pull for getting the references). Is redefining a meaning of a capability acceptable?

## Considerations

No other solutions for batching were considered.

We can argue inaction as the extra restore are not going to happen consistently.

### References

* [Visual Studio partial restore optimization](https://github.com/NuGet/Home/blob/756e168725e720491f3a1e013e30a73281b224c2/designs/VisualStudio-PartialRestoreOptimization.md)
* [Project Capabilities](https://github.com/microsoft/VSProjectSystem/blob/master/doc/overview/project_capabilities.md)
