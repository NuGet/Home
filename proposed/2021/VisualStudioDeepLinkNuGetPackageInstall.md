Visual Studio Package Install Deep Link Spec

- Status: **In Review**
- Author(s): [David Cueva Cortez](https://github.com/dcc7497)
- Issue: [11032](https://github.com/NuGet/Home/issues/11032) Deep Links in NuGet PM in Visual Studio
- Type: Feature

## Problem Background

Currently, customers have two main ways of installing NuGet packages: directly from the Visual Studio NuGet Package Manager UI (PMUI) and using a CLI command from nuget.org. This new feature allows customers to click on a deep link that will direct them to the package details page of the focus package in the PMUI. It is there that the customer can then install the focus package making installation a 2-step process. This feature allows for much more flexibility when installing packages as the link can be shared between people, can be embedded into documentation, among other things.

## Who are the customers

- Developers who want a quick and easy way to install packages directly from the PMUI with a click of a URL.

## Requirements

- If the project level PMUI is open, clicking the deep link will open the package details page of the target package.
- If the solution level PMUI is open, clicking the deep link will open the package details page of the target package.
- If the solution is open and the PMUI is not, clicking the link will open the solution level PMUI package details page of the target package.
- If Visual Studio is open but a solution is not, clicking the link will prompt the user to select a solution which will then be followed by opening the solution level PMUI package details page of the target package.
- If Visual Studio is not open, clicking the link will result in the following happening; open an instance of visual studio, prompt the user to select a solution, and finally opening the solution level PMUI package details page of the target package.

## Goals

- Clicking on a valid deep link should lead into a series of events that end with the user being at the PMUI package details page of the target package.

## Non-Goals

- Clicking on the link will not automatically install the packages for the customer.
- Clicking on the link will not lead to the package details page in nuget.org
- When the user clicks on the link and gets to the package details page in the PMUI, the install button will not be pressed for the user, they will have to perform that task themselves.

## Solution

For this feature, I will be splitting the work into two main sections, the first being the section that sets up and parses the URI and the second being the logic needed to open the PMUI in Visual Studio.

### URI Work

#### Setting Up URI

Since this feature requires a minimum version of Visual Studio to function, the first step will be to specify to the system what version of Visual Studio to use. I will then register the URI protocol with a .json file to our extension so that Visual Studio may register it. By adding a ProvideAppCommandLineAttribute in the package class, I can then access that URI.

#### Parsing URI

Depending on how the URI link is set up, that link will be split up into its key components that provide me with the information needed to describe a package. Each component will be sub stringed analyzed, and an object will be created with fields associated with said components such as package name and version number. This way, the information in the URI can live somewhere without having to expose the URI in places that it doesn&#39;t need to be.

##### URI Format

To provide context for the point above, the url will be formatted as follows: **vsph://OpenPackageDetails/<packageName>/<version>**, where *packageName* is the name of the NuGet package and *version* is the version number of the target NuGet package. 

### Opening the PMUI

#### Opening an Instance Visual Studio When One Isn&#39;t Already Open

(Still looking into ways to implement this) Looking into the code bases to see if there is a programmatic way of externally opening an instance of Visual Studio when the deep link is clicked. Continue to the next section &quot;Opening Solution When an Instance of Visual Studio is Open&quot;.

#### Opening Solution When an Instance of Visual Studio is Open

Instead of the traditional GetToCode window that prompts the user to select a folder or a solution to open, I will investigate offering the user that same GetToCode window experience only this time with only the ability to select solutions as folders cannot access the PMUI. Continue to the next section &quot;Opening Solution Level PMUI From an Open Solution Instance in Visual Studio&quot;.

#### Opening Solution Level PMUI From an Open Solution Instance in Visual Studio

I will invoke opening a ToolWindow that is the same type as the PMUI from an open solution. Continue to the next section &quot;Solution/Project Level PMUI is Open&quot;.

#### Solution/Project Level PMUI is Open

I will first traverse into the &quot;Browse&quot; tab of the PMUI. From there I will programmatically invoke a search for [PackageId: &quot;PackageName&quot;], where ideally one package should show up. Should no package show up, a search for just the package name will be invoked and I will search for an exact name in the results for the target package. Once a package is selected, its package details page will open. From there I&#39;ll invoke setting the package details page to the appropriate version number. From there, it is up to the user to press the install button to finish the process.

## Considerations
