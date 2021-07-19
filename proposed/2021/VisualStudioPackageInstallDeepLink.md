# Visual Studio Package Install Deep Link

- Author Name: Chris Gill ([chgill-MSFT](https://github.com/chgill-MSFT))
- Start Date: 07/19/2021
- GitHub Issue: https://github.com/NuGet/Home/issues/11032
- GitHub PR: N/A

## Summary

Support deep links for NuGet.org packages that, when clicked, open the package in the Visual Studio NuGet Package Manager UI (PMUI) for a 1 click install experience.

Applications:

* Add “Install with Visual Studio” link to package README, documentation, or tutorials
* Deep link suggested alternative package for deprecated packages in Visual Studio for an easier transition experience
* Share install link with coworkers
* Include “Install with Visual Studio” option on NuGet.org

## Motivation 

Today, customers must copy a CLI command to install a NuGet package to their project from NuGet.org, or search for the package in Visual Studio. We should enable customers to directly install the package from the Visual Studio package manager UI so they can continue to use their preferred package management tool.

From our NuGet.org survey, 70% of our respondents reported using the Visual Studio NuGet UI to install packages. Additionally, 87% of our respondents use Visual Studio for developing .NET apps. 

Since users prefer installing packages via the VS package manager UI by a large margin relative to CLI methods, we should support that as a first-class experience.

## Success metric

We will use telemetry the measure % of VS package installs that come from a deep link and surveys to understand satisfaction with available installation options for NuGet packages.

## Scope

* Generate a deep link URL that opens the NuGet package in the Visual Studio PMUI
* Handler is just for Visual Studio
* Only NuGet.org packages are supported

## Scenarios

1.	Visual Studio isn’t open
2.	Visual Studio is open without a solution selected
3.	A solution is open, but the PMUI isn’t
4.	Project level PMUI is open
5.	Solution level PMUI is open

## Design

### Deep link design

* Must specify package ID
* Can specify version
* No version specified defaults to latest version available
* Structure: TBD

* Example from VS Code extension deep link: [vscode:extension/dracula-theme.theme-dracula](vscode:extension/dracula-theme.theme-dracula)

### Scenario 1 - Visual Studio isn’t open

1. Deep link URL is clicked.
2. Open Visual Studio to solution selector window and wait for solution selection
   ![Visual Studio solution selection menu](./meta/resources/VisualSutdioPackageInstallDeepLink/Solution%20selection%20menu.png)
3. When a solution is selected, open the solution level PMUI to the Browse tab.
    1. Search query for [PackageId: “PackageName”] is prepopulated – yielding only the target package as a result.
    2. Target package should be pre-selected with its package details open to the target version from NuGet.org.
    ![Solution level PMUI Browse tab filtered to target package](.\meta/resources/VisualSutdioPackageInstallDeepLink/Filtered%20Package%20Search%20Results.jpg)
4. User chooses relevant projects and installs the package as desired.

### Scenario 2 - Visual Studio is open without a solution selected

1. Deep link URL is clicked.
2. Visual Studio solution selection window is already open, wait for solution selection.
3. When a solution is selected, open the solution level PMUI to the Browse tab.
    1. Search query for [PackageId: “PackageName”] is prepopulated – yielding only the target package as a result.
    2. Target package should be pre-selected with its package details open to the target version from NuGet.org.
4. User chooses relevant projects and installs the package as desired.

### Scenario 3 - A solution is open, but the PMUI isn’t

1.	Deep link URL is clicked.
2.	Solution is already selected and open.
3. Open the solution level PMUI to the Browse tab.
    1. Search query for [PackageId: “PackageName”] is prepopulated – yielding only the target package as a result.
    2. Target package should be pre-selected with its package details open to the target version from NuGet.org.
4. User chooses relevant projects and installs the package as desired.

### Scenario 4 - Solution level PMUI is open

1.	Deep link URL is clicked.
2.	Solution is already selected and open.
3.	Solution level PMUI is already open.
4. Go to Browse tab of the solution level PMUI.
    1. Search query for [PackageId: “PackageName”] is prepopulated – yielding only the target package as a result.
    2. Target package should be pre-selected with its package details open to the target version from NuGet.org.
5. User chooses relevant projects and installs the package as desired.

### Scenario 5 - Project level PMUI is open

1.	Deep link URL is clicked.
2.	Solution is already selected and open.
3.	Project level PMUI is already open.
4. In the PMUI window that is currently open/ in focus, open the Browse tab.
    1. Search query for [PackageId: “PackageName”] is prepopulated – yielding only the target package as a result.
    2. Target package should be pre-selected with its package details open to the target version from NuGet.org.
   ![Project level PMUI Browse tab filtered to target package](./meta/resources/VisualSutdioPackageInstallDeepLink/Project%20level%20filtered%20package%20results.png)
5. User chooses relevant projects and installs the package as desired.

## Drawbacks

* Older versions of Visual Studio won't support this.
* Current proposal is limited to NuGet.org packages - generalizing to packages from any feed will increase engineering complexity significantly as we would need a custom way to isolate the target package in the Browse tab.

## Prior Art

### Download VS Code extension from VS Marketplace

Example Extension: [Dracula Official - Visual Studio Marketplace](https://marketplace.visualstudio.com/items?itemName=dracula-theme.theme-dracula)

Deep link for Dracula Official: [vscode:extension/dracula-theme.theme-dracula](vscode:extension/dracula-theme.theme-dracula)

Behavior: Click the deep link opens VS Code and the extension details page for the target extension, making it a 1 click install experience from there.

![Download Dracula Official from VS Marketplace website](./meta/resources/VisualSutdioPackageInstallDeepLink/Dracula%20Official.png)

## Unresolved Questions

**Q: What should the structure of the deep link URL?**

**Q: If a project level PMUI window is already open or in focus, should we open the package there or open the solution level PMUI anyway for a consistent experience?**

*Pending customer development*

**Q: What happens if NuGet.org is not enabled as a source?**

* Option 1: Open a dialogue explaining to the customer “You are attempting to install a package from NuGet.org but you do not have it enabled as a source. Would you like to enable it or cancel?”
* Option 2: Switch feed setting to “All” automatically

**Q: What package types should support downloading in Visual Studio (library, template, etc.)?**

Currently, anything but library packages fail to install through the PMUI and don’t make sense to install through the PMUI. 

**Q: What Visual Studio operation can we use as prior art?**

•	Open repo in Visual Studio on GitHub.
•	Download extension from VS Marketplace website only downloads the VSIX file locally and does not have a VS handler.
•	Others?

**Q: Can/should we generalize this feature to allow deeplinking of packages from any feed?** This would mean we can’t use the “PackageId:” search filter since it’s NuGet.org specific.

## Resolved Questions

**Q: What happens if the package exists on multiple feeds?**

We follow today’s normal installation behavior, though imperfect, and install the package from whichever feed responds. This is an inherent risk of package version duplication across multiple feeds and addressing the issue is not within the scope of this feature.

We plan to address the dependency confusion issue with the upcoming [package namespaces feature](https://github.com/NuGet/Home/blob/dev/proposed/2021/PackageNamespaces.md).

**Q: What happens if the package is already installed?**

The user flow should proceed exactly as it would if the package were not already installed. This is consistent with today’s behavior where we show installed packages in the Browse tab.

## Future Possibilities

* Display a button to "Open in Visual Studio" on NuGet.org.
* User a similar feature design to open Visual Studio extensions from deep link
