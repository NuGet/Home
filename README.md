![NuGet logo](https://raw.githubusercontent.com/NuGet/Home/master/resources/nuget.png)

-----

# NuGet Home

The Home repository is the starting point for people to learn about NuGet, the project. If you're new to NuGet, and want to add packages to your own projects, [check our docs](http://docs.nuget.org). This repo contains pointers to the various GitHub repositories used by NuGet and allows folks to learn more about what's coming in NuGet.

NuGet is being actively developed by the .NET Foundation. NuGet is the package manager for the Microsoft development platform including .NET. The [NuGet client tools](https://github.com/nuget/nuget.client) provide the ability to produce and consume packages. The [NuGet Gallery](https://github.com/NuGet/NuGetGallery) is the central package repository used by all package authors and consumers and has a live deployment at [www.nuget.org](https://www.nuget.org).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Documentation and Further Learning

### [NuGet Docs](http://docs.nuget.org)

The NuGet Docs are the ideal place to start if you are new to NuGet. They are categorized in 3 broader topics:

* [Consume NuGet packages](http://docs.nuget.org/consume) in your projects;
* [Create NuGet packages](http://docs.nuget.org/create) to learn about packaging and publishing your own NuGet Packages;
* [Contribute to NuGet](http://docs.nuget.org/contribute) gives an overview of how you can contribute to the various NuGet projects.

### [NuGet Blog](http://blog.nuget.org/)

The NuGet Blog is where we announce new features, write engineering blog posts, demonstrate proof-of-concepts and features under development.

## Repos and Projects

* [NuGet client tools](https://github.com/nuget/nuget.client) - this repo contains the following clients:
  * NuGet command-line tool 3.0 and higher
  * Visual Studio 2015 Extension
  * PowerShell CmdLets

* [NuGet V2](https://github.com/NuGet/NuGet2) - this repo contains the following clients:
  * NuGet command-line tool 2.9
  * Visual Studio Extension (Previous versions e.g. Visual studio 2013)
  * PowerShell  CmdLets
  * NuGet.Core

[NuGet.org](https://www.nuget.org/) is backed by several core services:

* [NuGetGallery](https://github.com/NuGet/NuGetGallery) - the current NuGet Gallery
* [NuGet.Services.Metadata](https://github.com/NuGet/NuGet.Services.Metadata) - NuGet's Metadata Service
* [NuGet.Jobs](https://github.com/NuGet/NuGet.Jobs) - NuGet's back-end jobs

[NuGet.Server](https://github.com/NuGet/NuGet.Server) is a lightweight standalone NuGet server.

A [full list of all the repos](https://github.com/NuGet) is available as well.

## How to build NuGet VisualStudio extension

###Prerequisites:
- [VisualStudio 2015](https://www.visualstudio.com/)
- [VisualStudio 2015 SDK](https://msdn.microsoft.com/en-us/library/bb166441.aspx)
- [Windows 10 SDK](https://dev.windows.com/en-US/downloads/windows-10-sdk)
- Git 
- Powershell

###Steps to build the clients tools repo:
- Clone [NuGet.Client](https://github.com/nuget/nuget.client) Repo by running the following command `git clone https://github.com/NuGet/NuGet.Client`
- Start powershell
- CD into the clone repo directory
- Run `.\build.ps1 -CleanCache`

######In case you have build issues please clean the local repo using `git clean -xdf` and retry building

####Notable .\build.ps1 switches
- `-SkipDev14` - builds only binaries targeting Visual Studio 15 (Dev15)
- `-SkipDev15` - builds only binaries targeting Visual Studio 2015 (Dev14)

Note that if only one of Visual Studio 2015 (Dev14) or Visual Studio 15 (Dev15) is installed, neither of the above switches is necessary - the script will build according to the installed version.

- `-SkipXProj` - skips building the NuGet.Core XProj projects
- `-SkipTests` - builds binaries, skips running tests
- `-SkipRestore` - builds without restoring first
- `-SkipSubmodules` - builds without updating submodules
- `-SkipILMerge` - builds without creating an ILMerged nuget.exe
- `-Fast` - skips tests, submodule updates, and ILMerged nuget.exe

###Build Artifacts
- (RepoRootFolder)\Artifacts - this folder will contain the Vsix and NuGet command-line
- (RepoRootFolder)\Nupkgs - this folder will contain all our projects packages

## NuGet Packages by the NuGet team

We dogfood all of our stuff. NuGet uses NuGet to build NuGet, so to speak. All of our NuGet packages, which you can use in your own projects as well, are available from [our NuGet.org profile page](https://www.nuget.org/profiles/nuget).

## Feedback

If you're having trouble with the NuGet.org Website, file a bug on the [NuGet Gallery Issue Tracker](https://github.com/nuget/NuGetGallery/issues). 

If you're having trouble with the NuGet client tools (the Visual Studio extension, NuGet.exe command line tool, etc.), file a bug on [NuGet Home](https://github.com/nuget/home/issues).

Check out the [contributing](http://docs.nuget.org/contribute) page to see the best places to log issues and start discussions.  You are welcome to respond to any issues that are marked as ['Up for Grabs'](https://github.com/NuGet/Home/issues?q=is%3Aopen+is%3Aissue+label%3A%22Up+for+Grabs%22) with appropriate pull-requests to address them.  Note that not all of our repositories are open for contribution yet. Ping us if unsure.
