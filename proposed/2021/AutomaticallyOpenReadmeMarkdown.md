# Automatically Open README.md after package installation in the Visual Studio Package Manager UI - Technical Spec

* Status: **In Review**
* Author(s): [Jean-Pierre Briedé](https://github.com/jebriede)
* Issue: [10353](https://github.com/NuGet/Home/issues/10353) Automatically Open readme.md Files
* Type: Feature

## Problem Background

Package authors should be able to show a richer, rendered markdown README file in Visual Studio to users who install their package as an alternative to the plain text README file. Currently, only a README.txt plain text file can be shown to a user that installs a package.

## Who are the customers

* All users that install a NuGet package with a README.md markdown file included.
* All package authors that want to include a README.md markdown file to be shown to users after they install the NuGet package to their project.

## Requirements

* The README.md file will automatically be displayed in the Visual Studio docwell after the user installs a package that includes a README.md file.
* [Markdig](https://www.nuget.org/packages/Markdig.Signed/) and [Markdig.WPF](https://www.nuget.org/packages/Markdig.Wpf.Signed/) will be used to as the markdown processor to translate markdown into a WPF Flow Document.
* Style the ToolWindow and the rendered markdown to fit the selected Visual Studio theme.
* Add or update unit tests to cover the functionality of opening a markdown README.md as well as maintain support for a plain text README.txt.

## Goals

* Automatically show a read-only, rendered markdown README.md file in Visual Studio for a NuGet package to the user that installs the package to their project.
* The README.md markdown will be displayed in a tool window in the docwell in Visual Studio.
* Maintain existing support for displaying README.txt files in a text editor after package installation.

## Non-Goals

* Make the README.md file editable
* Show the README.md file in the package details before installing the package
* Supporting a special flavor of Markdown processing. Only CommonMark will be supported
* Providing package authors with README.md authoring tools

## Solution

The NuGetPackageManager has a method called OpenReadmeFile that is called at the end of a package installation. OpenReadmeFile attempts to open a README.txt file if it exists and if the file does exist, a call is made to the ICommonOperations to OpenFile. There is a VS implementation that uses DTE to call OpenFile and VS handles how to open and display a given file. This will be expanded to support looking for and displaying a rendered README.md file if one exists and there is no README.txt file.

A new ToolWindowPane will be created that will host the Markdig.WPF control in its pane to display the rendered markdown as a WPF Flow Document. The NuGetPackage and ExecutionContext implementations will be expanded to support opening the new ToolWindow to display the given README.md file. The ToolWindow will contain a WPF View that will host the Markdig.WPF control and a ViewModel that will contain the markdown in a property for the View to bind to the Markdig.WPF control for rendering.

The functionality to display a README.txt file must be maintained. In the event that both a README.txt and README.md file exist, the README.txt file will be opened. Unit tests will need to be added/updated validate this behavior.

## Considerations

* What will happen if the README.md file is very large? Is this a reasonable scenario or are NuGet packages limited in size to where this is unlikely or even impossible? There should be prior art for the README.txt file.
* Markdig.WPF allows for styling of the markdown. The default styling may need to be overridden to ensure the style fits well in the Visual Studio IDE.