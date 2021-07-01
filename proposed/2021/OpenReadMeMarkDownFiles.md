# Automatically Open `README.md` Files When Installing a NuGet Package in Visual Studio Spec

* Status: **In Review**
* Author(s): [David Cueva Cortez](https://github.com/dcc7497)
* Issue: [10353](https://github.com/NuGet/Home/issues/10353) Feature Request: Automatically Open `readme.md` Files
* Type: Feature

## Problem Background

When developers install packages from Visual Studio&#39;s package manger and if that package has a README file, Visual Studio will automatically open a `README.txt` file. However, Visual Studio does not have a way of opening a rendered `README.md` file, just a text version of the README. While the README allows for the developer to get more information about the package, having a rendered markdown file open automatically allows for information to be displayed in an organized manner. When rendered, the markdown file has links one can follow, different sections can be clearly marked with headers, among other things. It provides the same information as a txt file with the added benefit of being rendered in an easier to follow format.

## Who are the customers

* Developers who use Visual Studios and install packages via the NuGet package manager who want detailed information about the package they&#39;re installing.

## Requirements

* markdown files open automatically after the user has installed the NuGet package in Visual Studio, if available.
* When opened, `README.md` will be rendered as a markdown.
* markdown file opens in the doc well of Visual Studio.

## Goals

* Display a rendered `README.md` file in the Visual Studio doc well after a package has been installed on the NuGet package manager.

## Non-Goals

* Packages that were downloaded from a web browser and installed into their projects will not have their `README.md` files open automatically in Visual Studio.
* Packages that have their `README.md` file in a location other than the package install directory will not be opened or rendered.
* txt files will not be rendered.

## Solution

I will be using a Model View ViewModel (MVVM) approach to solve this problem. Opening the README does not have much in terms of abstraction of data sources, so no model will be implemented. The view will be defined as a XAML and have the rendered README bonded to it. I will be using the ToolWindowPane to display a WPF that renders a markdown viewer and this will occur in the Visual Studio doc well. I will be rendering the markdown using the [Markdig.wpf](https://www.nuget.org/packages/Markdig.Wpf/) package from NuGet. The ViewModel will oversee creating a path for the README file if it exists in the package install directory and opening/rendering the file at said path.

## Considerations

* As a stretch goal I have is to add in functionality to be able to open a `README.md` file that does not reside in the package install directory.