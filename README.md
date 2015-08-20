![NuGet logo](https://raw.githubusercontent.com/NuGet/Home/master/resources/nuget.png)

-----

# NuGet Home

The Home repository is the starting point for people to learn about NuGet, the project. If you're new to NuGet, and want to add packages to your own projects, [check our docs](http://docs.nuget.org). This repo contains pointers to the various GitHub repositories used by NuGet and allows folks to learn more about what's coming in NuGet.

NuGet is being actively developed by the .NET Foundation. NuGet is the package manager for the Microsoft development platform including .NET. The [NuGet client tools (on CodePlex)](http://nuget.codeplex.com) provide the ability to produce and consume packages. The [NuGet Gallery](https://github.com/NuGet/NuGetGallery) is the central package repository used by all package authors and consumers and has a live deployment at [www.nuget.org](https://www.nuget.org).

## Documentation and Further Learning

### [NuGet Docs](http://docs.nuget.org)

The NuGet Docs are the ideal place to start if you are new to NuGet. They are categorized in 3 broader topics:

* [Consume NuGet packages](http://docs.nuget.org/consume) in your projects;
* [Create NuGet packages](http://docs.nuget.org/create) to learn about packaging and publishing your own NuGet Packages;
* [Contribute to NuGet](http://docs.nuget.org/contribute) gives an overview of how you can contribute to the various NuGet projects.

### [NuGet Blog](http://blog.nuget.org/)

The NuGet Blog is where we announce new features, write engineering blog posts, demonstrate proof-of-concepts and features under development.

## Repos and Projects

In the legacy department, we have the following repos:

* [NuGet (on CodePlex)](http://nuget.codeplex.com) - the NuGet command-line tool, Visual Studio Extension and PowerShell CmdLets
* [NuGetGallery](https://github.com/NuGet/NuGetGallery) - the current NuGet Gallery

We are working hard to make NuGet a modern package manager for .NET. The repos where the action around that is happening:

* [NuGet.CommandLine](https://github.com/NuGet/NuGet.CommandLine) - the NuGet command-line tool
* [NuGet.VisualStudioExtension](https://github.com/NuGet/NuGet.VisualStudioExtension) - the NuGet Visual Studio Extension and PowerShell CmdLets
* [NuGet.Gallery](https://github.com/NuGet/NuGetGallery) - the new NuGet Gallery
* [NuGet.NuGet3](https://github.com/NuGet/NuGet3) - the NuGet API v3 protocol client, NuGet's implementation of package versioning, NuGet's configuration implementation, readers for nupkgs, nuspecs, packages.config and various other NuGet packaging files.
* [NuGet.PackageManagement](https://github.com/NuGet/NuGet.PackageManagement) - reading and writing manifests of installed packages

NuGet is backed by several core services:

* [NuGet.Services.Metadata](https://github.com/NuGet/NuGet.Services.Metadata) - NuGet's Metadata Service
* [NuGet.Services.Search](https://github.com/NuGet/NuGet.Services.Search) - NuGet's Search Service
* [NuGet.Services.Messaging](https://github.com/NuGet/NuGet.Services.Messaging) - NuGet's Messaging Service
* [NuGet.Services.Metrics](https://github.com/NuGet/NuGet.Services.Metrics) - NuGet's Metrics Service

While building NuGet, we sometimes need something that can be used outside of NuGet, too. Examples are:

* [json-ld.net](https://github.com/NuGet/json-ld.net), a JSON-LD processor for .NET ([json-ld.net on NuGet](https://www.nuget.org/packages/json-ld.net/))
* [PoliteCaptcha](https://github.com/NuGet/PoliteCaptcha), a spam prevention library for ASP.NET MVC ([PoliteCaptcha on NuGet](https://www.nuget.org/packages/PoliteCaptcha/))
* [WebBackgrounder](https://github.com/NuGet/WebBackgrounder), a proof-of-concept of a web-farm friendly background task manager meant to just work with a vanilla ASP.NET web application ([WebBackgrounder on NuGet](https://www.nuget.org/packages/WebBackgrounder/))

A [full list of all the repos](https://github.com/NuGet) is available as well.

## How to build NuGet VisualStudio extension
Prerequistes:
- VisualStudio 2015
- VisualStudio 2015 SDK
- Git
- Powershell
- Add the directory of msbuild 14, e.g. C:\Program Files (x86)\MSBuild\14.0\Bin, to PATH
- Download the latest version of nuget, www.nuget.org/nuget.exe, and add its directory to PATH

Steps to build:
- Start powershell. Create a directory, cd into that directory
- Run `git clone https://github.com/NuGet/Home.git`
- Run `Home\clone-repos.ps1`
- Run `Home\build-nuget.ps1`. The generated vsix will be  NuGet.VisualStudioExtension\src\VsExtension\bin\Debug\NuGet.Tools.vsix.

## NuGet Packages by the NuGet team

We dogfood all of our stuff. NuGet uses NuGet to build NuGet, so to speak. All of our NuGet packages, which you can use in your own projects as well, are available from [our NuGet.org profile page](https://www.nuget.org/profiles/nuget).

## Feedback

If you're having trouble with the NuGet.org Website, file a bug on the [NuGet Gallery Issue Tracker](https://github.com/nuget/NuGetGallery/issues). 

If you're having trouble with the NuGet client tools (the Visual Studio extension, NuGet.exe command line tool, etc.), file a bug on [NuGet Home](https://github.com/nuget/home/issues).

Check out the [contributing](http://docs.nuget.org/contribute) page to see the best places to log issues and start discussions. Note that not all of our repositories are open for contribution yet. Ping us if unsure.
