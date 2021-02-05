# Runtime Identifier Graph From Project

* Status: **Reviewing**
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)

## Issue

[8369](https://github.com/NuGet/Home/issues/8369) - Metrics to track the refresh rate of the PM UI.

## Background

The general consensus among customers is that the PM UI is not very response and does too much work.
The 3 general categories of issues are:

* Start up.
* Too much UI thread work.
* Too frequent refreshes.

The goal in the last week had been the "too frequent" refreshes.
We're now adding telemetry to track the improvements we have made, and to help us understand user behavior and other potential issues we might have.

## Who are the customers

All NuGet in Visual Studio customers.

## Requirements

* A mechanism for the SDK to deliver NuGet the Runtime Identifier Graph

## Solution

We will analyze all the codepaths that trigger some sort of a potentially heavy refresh operation and add telemetry about it.
We will introduce a new event `/vs/nuget/PMUIRefresh`.
All events in a PM UI session (defined as the period between the opening and closing of the UI) will have the same guid.
Furthermore this event will contain the following properties:

* IsSolutionLevel - specifies whether the PM UI session is solution or project based.
* RefreshSource - which code path triggered the change. See below.
* RefreshStatus - the refresh status. See below.
* Tab - Which tab is open. All, Installed, UpdatesAvailable, Consolidate are the options. Equivalent to the ItemFilter enum/
* TimeSinceLastRefresh - How much time since the last refresh event was triggered. This is a niche use, as it will help us figure out if certain events can be batched. Ideally all events are user-action driven and as minimal as possible.

All of this information will help us understand the amount of refresh events skipped by our work.
If there are any other patterns of refresh events that warrant investigation.
It will also allow us to understand the most frequent source of refreshes.

### Refresh source

| Refresh sources | Reasoning |
|-|-|
| ActionsExecuted | A NuGet Package Manager action has been executed. That could be install/uninstall/update using the PM UI, or an IVS/PMC call. |
| CacheUpdated | A nomination has happened and it has updated the NuGet VS project cache. |
| CheckboxPrereleaseChanged | The prelease checkbox changed. |
| ClearSearch | The customer cleared the search text. |
| ExecuteAction | A NuGet package manager action has completed. This is an extra refresh added to minimize the performance impact of nominations and ActionsExecuted events on the PM UI.|
| FilterSelectionChanged | The tab changed. |
| PackageManagerLoaded | The PM UI has been loaded. This could be the opening the PM UI, or it could be a user switching back to the UI after having it open in the background. |
| PackageSourcesChanged | The package sources have changed. This means the customer likely edited the sources in the sources UI. |
| ProjectsChanged | A project was loaded/unloaded/renamed. |
| RestartSearchCommand | The refresh button. |
| SourceSelectionChanged | The customer changed the source from the dropdown. |
| PackagesMissingStatusChanged | The customer restored a previously unrestored solution and now certain packages are available. Specific to packages.config projects. |

### Refresh status

| Refresh status | Reasoning |
|-|-|
|Success | A refresh has been triggered |
| NotApplicable | An event happened, but it was not applicable for this current UI, likely because it was for a different project. |
| NoOp | A refresh event deemed unnecessary as it'd be doing duplicate work. See better performance |

### Validation

Manual only. We don't have further telemetry tests.

## Considerations

### What about performance

Lots of these events are sent on the UI thread. The flip side is that, this is relatively cheap.

### Why not include the project name

It's PII. We also have a unique guid for the active project in the generic VS telemetry.
