
# Floating Versions in the Package Manager UI

* Status: In Review
* Author(s): [Martin Ruiz](https://github.com/martinrrm)
* Issue: [3788](https://github.com/NuGet/Home/issues/3788) PackageReference with a star in version is displayed under the updates tab/incorrectly represented in the installed tab

## Problem Background

Currently the user can specify a version range or a floating version, but the current behavior of the package manager UI has poor support for this, displaying an incorrect installed version. If the user indicates a floating version in any package (eg `5.*`) the PM UI will display the minimum version possible (`5.0.0`) as installed even though the resolved version could be different of the resolved version in the command `dotnet list package`. Furthermore the user cannot specify a version range free hand.

### Current behavior

### Updates Tab

With the current behavior even if the user indicated a floating version, such as `*`, for the package version, the UI will tell the user that there is an update available which is misleading.

#### Project File and Solution Explorer

![SolutionExplorer](../resources/FloatingVersionsInPMUI/ProjectFile&SolutionExplorer.png)

#### Project Manager UI

![Package UI](../resources/FloatingVersionsInPMUI/PackageManagerUI.png)

![Project UI](../resources/FloatingVersionsInPMUI/PackageManagerForSolution.png)

```
The requested and installed versions are not correct because dotnet list package shows a different installed version.
```

## Who are the customers

All customers that use the Package Manager UI to install or update packages.

## Goals

* Allow users see the correct version of the package installed while using floating versions in the Package Manager UI in Project View.

* Allow users to input floating versions to install in the Package Manager UI.

* Allow users to distinguish between requested and resolved package versions in the Solution View.

## Non-Goals

* Any multi targeting improvements overall.

## Solution

### Installed Tab

Display the correct resolved version of each package in this tab will correct the displayed version in this tab and avoid the package being listed in the `Updates Tab`.

### Floating Version Display in Project View

When searching for a package in the `Browse Tab` or `Installed Tab` the user is not able to select a floating or range version to install. We will implement a `Combo Box` that will autocomplete the available version of the package with the user input.

This feature will enable the option `*` and ranges to be selected while installing/updating a package. Also enables scenarios beyond floating version and improves the UX.

#### Floating Version

![Floating Version](../resources/FloatingVersionsInPMUI/FloatingVersionInPMUI.png)

#### Range Version

![Range Version](../resources/FloatingVersionsInPMUI/RangesInPMUI.png)

#### ComboBox

![Combo Box](../resources/FloatingVersionsInPMUI/ComboBox1.png)

![Combo Box Gif](../resources/FloatingVersionsInPMUI/ComboBoxGif.gif)

### Floating Version Display in Solution View

We will add a new column to show the requested version to match the behavior of `dotnet list package` command. Show correct highest resolved version in the solution in the package list view.

![Solution View](../resources/FloatingVersionsInPMUI/SolutionView.png)

## Future Work

* Indicate the resolved version in the solution explorer.

## Open Questions

Should we show available updates for packages that use custom version ranges or floating versions that don’t resolve to the latest version?

### Example

![Update](../resources/FloatingVersionsInPMUI/ShouldUpdateRanges.png)

## Considerations

Should we allow people to install package versions within a custom range without overwriting the project file?

We will not allow users to install package versions within a custom range without overwriting the project file. The project file version is a statement of intent and the version resolved should be resolved the same regardless whether you are installing it through the Package Manager UI, the command line or hand editing.

### References

[NuGet Build Integrated Project handling of floating versions and ranges in Visual Studio Client](https://github.com/NuGet/Home/wiki/%5BSpec%5D-NuGet-Build-Integrated-Project-handling-of-floating-versions-and-ranges-in-Visual-Studio-Client)

[NuGet Version Tool](https://nugettoolsdev.azurewebsites.net/5.4.0/find-best-version-match?versionRange=%5B1.*%2C+2.*%29&versions=3.5.8%0D%0A4.0.1)

[PackageReference with a star in version is displayed under the updates tab/incorrectly represented in the installed tab](https://github.com/NuGet/Home/issues/3788)
