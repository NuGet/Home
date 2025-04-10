# Transitive Dependencies in the Visual Studio Package Manager UI - Technical Spec

* Status: **In Review**
* Author(s): [Jean-Pierre Briedé](https://github.com/jebriede)
* Issue: [10184](https://github.com/NuGet/Home/issues/10184) Show transitive dependencies in PMUI for PackageReference projects
* Type: Feature

## Problem Background

Developers can only see their top-level packages in their PackageReference project in the Package Manager UI. Transitive dependencies are not visible in the NuGet Package Manager. This makes it difficult for a developer to fully understand all of the NuGet package dependencies their project relies on. Furthermore, there is currently no way to see in the Package Manager UI what top-level dependency depends on each of the included transitive dependencies.

A developer may want to install a transitive dependency as a top-level one to specify what version they want to include in their project if there is a security concern, vulnerability, or version conflict with the dependant version of a transitive dependency. The developer should have a quick and easy way to do this from the Package Manager UI in Visual Studio.

## Who are the customers

* All developers using Visual Studio and PackageReference projects will benefit from the additional information about the transitive dependencies and the top-level package that depend on them.
* Developers that have installed packages that depend on transitive dependencies with security concerns, vulnerabilities, or version conflicts with other transitive dependencies will benefit from the ability to quickly install a transitive dependency as a top-level dependency and specify its version.

## Requirements

* UI is accessible and allows screen readers to announce pertinent information about the transitive dependencies and the top-level packages that depend on them
* UI is localizable. All strings are in appropriate resource files and available for translation
* Reading transitive package information is done asynchronously to minimize the impact on the responsiveness of the UI

## Goals

* Show transitive dependencies in the Project-level NuGet Package Manager

### UI behavior goals:
* Display a flat list of transitive depedencies along with the installed, top-level packages in the Visual Studio NuGet Package Manager UI
* Allow the user to collapse and expand the list of transitive dependencies
* Collapse the transitive dependencies list by default
* For each transitive dependency, show the top-level package(s) that depend(s) on it in a tooltip, displayable on hover and readable by screen reader
* Show the package details when a transitive dependency is selected and allow the ability to install a specific version of the transitive dependency which will promote it to a top-level package

### Technical goals:
* Enhance the InfiniteScrollList to support grouping its list content based on a field in the list item data context
* Allow the InfiniteScrollList grouping to be enabled or disabled by the consumer so it can still be shared by the Browse, Installed, Updates tabs
* Create an API to read transitive dependency information from the assets file, including the top-level package information for each transitive dependency
* Cache the transitive dependency information read from the assets file so it is only read when the assets file changes

## Non-Goals

* Show transitive dependencies for the Solution Package Manager
* Build transitive dependencies into the NuGet command-line interface
* Redesign how the assets file is read
* Design a new pattern for how the assets file information is cached
* Add significant infrastructure for A/B experimentation
* Build complete transitive dependency management into the Package Manager UI
* Rebuild the PMUI or restructure to use the MVVM pattern. Attempts will be made to use MVVM where possible but it is not the goal to change the structure or patterns used in the PMUI to use the MVVM pattern where it is currently not
* Redesign how metadata for installed packages is queried. Transitive packages will use the existing mechanism for pulling in metadata about installed packages

## Solution

### InfiniteScrollList

**The InfiniteScrollList will be enhanced to optionally enable grouping its items by a given property and will be styled to have the group headers have an expander and a count of the elements in the group.**

The `InfiniteScrollList` will have a new `DependencyProperty` called `GroupByItemProperty` that will allow the consumer of the `InfiniteScrollList` to specify the name of the property on the List Item's data context object (`PackageItemViewModel`) that will be used to group the items in the list. If the property is not specified, grouping will be disabled. This will make the grouping functionality be general purpose for the `InfiniteScrollList` and allow any view to enable or disable grouping. For example, it will allow the Installed tab to enable grouping and specify what item property will be used for the group while all other tabs (Browse and Updates, for example) can disable grouping but still use the same list control.

The `PackageItemViewModel` will have a new, public property that indicates if the package is a top-level package or a transitive package. This property will be used to determine how to group the item -- whether it belongs in the top-level packages or transitive packages group.

Grouping is defined in WPF on a `CollectionView`. The `InfiniteScrollList` will have a `CollectionViewSource` and its View will define the grouping property. The View will be used in the data binding on the `InfiniteScrollListBox`'s ItemSource rather than binding to the Items property `ObservableCollection` directly.

The ControlTemplate for the `InfiniteScrollListBox` will be enhanced to include a ListBox GroupStyle that will be used to define the look and feel of the grouping. The grouping style will include an expander that allows the user to expand/collapse the group, a header which indicates if the package is top-level or transitive, a count of the total number of elements in the group, and a tooltip on the items that will display the top-level package that ultimately depends on the transitive package.

### Reading Transtitive Dependencies

**Transitive dependencies will be read from the project.assets.json file**

The transitive dependencies information read from the assets file will be cached and the cache will only be rebuilt if the assets file has changed when reading transitive dependencies and its origin package. For each transitive package in the target framework, the list of top-level packages will need to be visited and their depedencies walked until the package is found to determine what top-level package brought the transitive dependency into the project.

There will be an additional property on the PackageItemViewModel that will expose the a list of top-level packages in the dependency graph that originally brought in the transitive dependency. For top-level packages, this property will be an empty list. This list will be used to build the tooltip on transitive packages.

### Transitive Packages details pane

The Details pane will be populated for transitive packages in the same way that it is populated for other installed packages. The same mechanism will be reused for transitive packages so the user package metadata, select a version, and click the Install button to install the package which will promote it to a top-level package. There should not need to be many changes to support adding details for transitive packages.

### A/B Experimentation

**The Transitive Dependencies feature will be rolled out to customers as an A/B Experiment.**

This document is not intended to outline the full details of the A/B Experiment but to highlight some key points about releasing the feature as an experiment.

Running an A/B Experiment with the transitive dependencies feature will allow us to take a data-driven approach to deciding if the feature we built sufficently addresses the desired goal or if we need further investment to positively impact the user experience.

It also allows us the ability to turn off the experiment remotely if we find significant regressions in the experience or remotely broaden the audience if the data shows a positive impact.

We will make use of existing engagement metrics to determine the feature's impact on the user's interaction with the PMUI. Namely, we will look closely at NuGet Actions (Package installs, updates, and uninstalls), as well as PMUI Refresh events on each of the tabs. We will consider adding additional metrics specific to transitive dependencies in consultation with the VS Experimentation team.


## Considerations

* The transitive packages list should be collapsed by default because the user may not need to see transitive package information every time they view the Installed tab. There is a potential opportunity to delay processing or querying transitive dependency or the top-level packages that installed the transitive dependencies until after the list is expanded. However, doing so would be premature optimization so this will only be considered if it is shown to have a significant impact on performance. Since the assets file is read from disk into memory, and processing will occur on that in-memory representation, I do not anticipate a significant impact, but this consideration can be visited as an option if we see otherwise.
* Transitive dependencies and the top-level packages that caused them to be installed are to be read from the assets file on disk. If that file is not present when the PMUI is loaded and installed packages are displayed, we will need to understand the impact it will have on this scenario and devise a solution. It is difficult to anticipate what the best options are without reaching that point, but some options may include doing a restore to create the file, prompting the user, or not displaying transitive dependencies and informing the user why they are not visible until after a restore is completed and the assets file is created.
* Transitive packages/dependencies from referenced projects will not be shown in PM UI in the first iteration. Additional feature/customer development is tracked here: https://github.com/NuGet/Home/issues/11624