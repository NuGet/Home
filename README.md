![NuGet logo](https://raw.githubusercontent.com/NuGet/Home/master/resources/nuget.png)

-----

# NuGet Home

The Home repository is the starting point for people to learn about NuGet, the project. If you're new to NuGet, and want to add packages to your own projects, [check our docs](http://docs.nuget.org). This repo contains pointers to the various GitHub repositories used by NuGet and allows folks to learn more about what's coming in NuGet.

NuGet is being actively developed by the Outercurve Foundation. NuGet is the package manager for the Microsoft development platform including .NET. The [NuGet client tools (on CodePlex)](http://nuget.codeplex.com) provide the ability to produce and consume packages. The [NuGet Gallery](https://github.com/NuGet/NuGetGallery) is the central package repository used by all package authors and consumers and has a live deployment at [www.nuget.org](https://www.nuget.org).

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
* [NuGet.Gallery](https://github.com/NuGet/NuGet.Gallery) - the new NuGet Gallery
* [NuGet.Protocol](https://github.com/NuGet/NuGet.Protocol) - the NuGet API v3 protocol client 
* [NuGet.Versioning](https://github.com/NuGet/NuGet.Versioning) - NuGet's implementation of package versioning
* [NuGet.Configuration](https://github.com/NuGet/NuGet.Configuration) - NuGet's configuration implementation 
* [NuGet.Packaging](https://github.com/NuGet/NuGet.Packaging) - Readers for nupkgs, nuspecs, packages.config and various other NuGet packaging files.
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
- Add msbuild (e.g. C:\Program Files (x86)\MSBuild\12.0\Bin) to PATH
- latest version of nuget (www.nuget.org/nuget.exe)

Steps to build:
- Clone NuGet Repos. Note that they need to be under the same directory (say c:\RootDirectory),
  without their names (i.e. directories) changed since the directories are hard coded in the build
  script. The repos to clone are:
  - NuGet.Configuration (https://github.com/NuGet/NuGet.Configuration.git)
  - NuGet.PackageManagement (https://github.com/NuGet/NuGet.PackageManagement.git)
  - NuGet.Packaging (https://github.com/NuGet/NuGet.Packaging.git)
  - NuGet.Protocol (https://github.com/NuGet/NuGet.Protocol.git)
  - NuGet.Versioning (https://github.com/NuGet/NuGet.Versioning.git)
  - and NuGet.VisualStudioExtension (https://github.com/NuGet/NuGet.VisualStudioExtension.git).

  Some background info: the K build system is used by NuGet.Configuration, NuGet.Packaging, NuGet.Protocol and
  NuGet.Versioning, while MSBUILD system is used by NuGet.PackageManagement and
  NuGet.VisualStudioExtension. This separation is the reason why building NuGet is kind of messy today.

- Switch the branch to dev in all the repos.
 
- Get the build script build-nuget.ps1.

- Under the root directory, execute
  ```
  build-nuget.ps1 -configuration <configuration> -clean
  ```
  where _configuration_ is either `debug` or `release`. The build script builds all solutions,
  except NuGet.VisualStudioExtension. The result is that the output nupkg files are copies into directory RootDirectory\nupkgs.

- Now it's time to compile the extension. cd into root directory\NuGet.VisualStudioExtension, run 
  ```
  nuget restore -source c:\RootDirectory\nupkgs\
  ```

  If there are errors that some packages cannot be restored (this is the case when the repo is cleaned), run
  ```
  nuget restore
  ```
  to restore them from other sources.
  
  After all packages are restored, you can open the solution file in VisualStudio 2015 to compile and debug the extension.

## NuGet Packages by the NuGet team

We dogfood all of our stuff. NuGet uses NuGet to build NuGet, so to speak. All of our NuGet packages, which you can use in your own projects as well, are available from [our NuGet.org profile page](https://www.nuget.org/profiles/nuget).

## Feedback

If you're having trouble with the NuGet.org Website, file a bug on the [NuGet Gallery Issue Tracker](https://github.com/nuget/NuGetGallery/issues). 

If you're having trouble with the NuGet client tools (the Visual Studio extension, NuGet.exe command line tool, etc.), file a bug on [NuGet Home](https://github.com/nuget/home/issues).

Check out the [contributing](http://docs.nuget.org/contribute) page to see the best places to log issues and start discussions. Note that not all of our repositories are open for contribution yet. Ping us if unsure.
