# Show NuGet Package Vulnerabilities in the Visual Studio Package Manager UI

- Author(s): [Chris Gill](https://github.com/chgill-MSFT)
- Issue: 
- Type: Feature
- Status: Implemented

## Description: What is it?

When a vulnerability in a NuGet package is discovered, surface an indicator of the vulnerability in the Package Manager UI to alert developers and help them take the appropriate action.

## Problem: What problem is this solving?

Vulnerabilities in packages can be leveraged by malicious actors to do harm to developers and their users. At the time of writing this, there are 113 NuGet advisories in the [GitHub Advisory Database](https://github.com/advisories?query=ecosystem%3Anuget). While package vulnerabilities can be found on NuGet.org and with the dotnet list command, most developer interactions with NuGet occur in the Visual Studio package manager UI where no vulnerability information is currently available.

## Why: How do we know this is a real problem worth solving?

NuGet hosts over 200,000 packages that developers use today. Most packages depend on another package, to which the attack vector / blast radius of any security vulnerability can be catastrophic in any package management ecosystem.

## Success: How do we know if we've solved this problem?

We will use the following to measure the success of this feature:

* We see a significant decrease in direct installations for vulnerable packages versions after surfacing vulnerability indicators in the PMUI.
* We see a significant increase in updates and/or uninstalls for directly installed vulnerable package versions after surfacing vulnerability indicators in the PMUI.
    * After we enable customers to view transitively installed packages, we will also measure this update/uninstall rates for vulnerable transitive packages.
* Qualitative feedback from customer interviews following the release of this feature show that customers find this feature very helpful for securing their NuGet packages.

## Audience: Who are we building for?

We are building this for Visual Studio users who manage and install packages through the package manager UI.

## Scope

**The MVP of this feature will be focused on enabling the following scenarios for Visual Studio .NET developers:**

- Users can discover when they have top level packages that have a known vulnerabilities in the PMUI.
- Users can see when a package search result in the Browse tab has a known vulnerability, to help them make informed decisions when choosing packages.
- Users can find which installed top level packages have a vulnerability, to help them take the appropriate action.
- Minor changes to the deprecation UX to align with necessary vulnerability UX.

The following scenarios will not be in the MVP, but will be considered for next iterations:

- Users can discover if they have installed packages with vulnerabilities through indicators in the solution explorer.
- A bolded warning will be shown at the bottom on the package list item to make it more noticeable when a package is deprecated or vulnerable.
- Deprecated and vulnerable packages will automatically be shown at the top of the installed package list in alphabetical order. The rest of the packages will be below in alphabetical order.
- The version dropdown list will show “(Vulnerable)” beside the relevant versions.
    - If a package is vulnerable and deprecated, it will show “(Vulnerable, Deprecated)"
- Users can see which transitively installed packages have vulnerabilities.
- Users have a 1-click or wizard experience to “fix” vulnerabilities.
- Plumbing deprecation and vulnerability data into the search API for a performance improvement.
- Users must explicitly confirm that they would like to install a deprecated or vulnerable package version.
- Users can choose to sort their installed packages such that deprecated or vulnerable packages rise to the top.
- All deprecation UX changes requested in Home/VSdeprecationfeature.md at dev · NuGet/Home (github.com).

The following scenarios are considered separate from this feature but may considered in another spec:
- Users can discover if they have installed packages with vulnerabilities through warnings in restore.
- Users can discover if they have installed packages with vulnerabilities through warning messages or dialogues outside of the PMUI.

## MVP Design

- Like deprecation, a warning sign will appear on the Installed tab header when a top-level deprecated package is installed.
    - The warning sign on the Installed tab header will display the number of vulnerable and deprecated packages in the tooltip.
    - The warning icon will appear for all levels of vulnerabilities – consistent with the behavior on NuGet.org.
- We will use the same warning sign for vulnerabilities as we do for deprecation to avoid the “lucky charms” effect where symbols get ignored because there are too many.
- The package details window will display a more detailed vulnerability message that includes the total count of advisories and the severities and links to the advisories.
    - If a package is both deprecated and has a vulnerability, we will display both detailed messages with the vulnerability message on top and the deprecation message below it.

![image](https://user-images.githubusercontent.com/15097183/127079047-84277da4-cbfe-44d3-b882-37b7a486f63a.png)

## Prior Art

### NuGet.org

Example: [NuGet Gallery | Microsoft.ChakraCore 1.11.23](https://www.nuget.org/packages/Microsoft.ChakraCore/1.11.23)

![image](https://user-images.githubusercontent.com/15097183/126356821-09aa43d1-424f-42ee-8d31-6e937e7ab328.png)

### dotnet list package --vulnerable

![image](https://user-images.githubusercontent.com/15097183/126356934-e7894fb8-9839-47dc-b437-bc601ac5e09d.png)

## Related specs/proposals

- [Original spec/proposal to surface package vulnerabilities in the PMUI (outdated)](https://github.com/NuGet/Home/blob/dev/proposed/2020/PackageVulnerability/FlagVulnerablePackages.md#display-vulnerabilities-in-visual-studio-pmui)
- [NuGet.org Vulnerabilities - Phase 1](https://github.com/NuGet/Home/blob/dev/proposed/2020/PackageVulnerability/NuGet.orgVulnerabilitiesPhase1.md)
- [VS Deprecation Feature Improvements proposal by Meera Haradisa](https://github.com/NuGet/Home/blob/dev/proposed/2021/VSdeprecationfeature.md)



