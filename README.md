![NuGet logo](https://raw.githubusercontent.com/NuGet/Home/dev/resources/nuget.png)

-----

# NuGet Home

The Home repository is the starting point for people to learn about NuGet, the project. If you're new to NuGet, and want to add packages to your own projects, [check our docs](http://docs.nuget.org). This repo contains pointers to the various GitHub repositories used by NuGet and allows folks to learn more about what's coming in NuGet.

NuGet is being actively developed by the .NET Foundation. NuGet is the package manager for the Microsoft development platform including .NET. The [NuGet client tools](https://github.com/nuget/nuget.client) provide the ability to produce and consume packages. The [NuGet Gallery](https://github.com/NuGet/NuGetGallery) is the central package repository used by all package authors and consumers and has a live deployment at [www.nuget.org](https://www.nuget.org).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Documentation and Further Learning

### [NuGet Docs](http://docs.microsoft.com/en-us/nuget)

The NuGet Docs are the ideal place to start if you are new to NuGet. They are categorized in 3 broader topics:

* [Consume NuGet packages](https://docs.nuget.org/ndocs/consume-packages/overview-and-workflow) in your projects;
* [Create NuGet packages](https://docs.nuget.org/ndocs/create-packages/overview-and-workflow) to learn about packaging and publishing your own NuGet Packages;
* [Contribute to NuGet](https://github.com/NuGet/Home/wiki/Contribute-to-NuGet) gives an overview of how you can contribute to the various NuGet projects.

### [NuGet Blog](http://blog.nuget.org/)

The NuGet Blog is where we announce new features, write engineering blog posts, demonstrate proof-of-concepts and features under development.

## Repos and Projects

* [NuGet client tools](https://github.com/nuget/nuget.client) - this repo contains the following clients:
  * NuGet command-line tool 4.0 and higher
  * Visual Studio Extension (2017 and later)
  * PowerShell CmdLets
 
[NuGet.org](https://www.nuget.org/) is backed by several core services:

* [NuGetGallery](https://github.com/NuGet/NuGetGallery) - the current NuGet Gallery
* [NuGet.Services.Metadata](https://github.com/NuGet/NuGet.Services.Metadata) - NuGet's Metadata Service
* [NuGet.Jobs](https://github.com/NuGet/NuGet.Jobs) - NuGet's back-end jobs

[NuGet.Server](https://github.com/NuGet/NuGet.Server) is a lightweight standalone NuGet server.

[NuGet Documentation](https://github.com/NuGet/docs.microsoft.com-nuget) contains NuGet's documentation. 

A [full list of all the repos](https://github.com/NuGet) is available as well.

## NuGet Packages by the NuGet team

We dogfood all of our stuff. NuGet uses NuGet to build NuGet, so to speak. All of our NuGet packages, which you can use in your own projects as well, are available from [our NuGet.org profile page](https://www.nuget.org/profiles/nuget).

## Feedback

If you're having trouble with the NuGet.org Website, file a bug on the [NuGet Gallery Issue Tracker](https://github.com/nuget/NuGetGallery/issues). 

If you're having trouble with the NuGet client tools (the Visual Studio extension, NuGet.exe command line tool, etc.), file a bug on [NuGet Home](https://github.com/nuget/home/issues).

Check out the [contributing](https://github.com/NuGet/Home/wiki/Contribute-to-NuGet) page to see the best places to log issues and start discussions.  You are welcome to respond to any issues that are marked as ['Up for Grabs'](https://github.com/NuGet/Home/issues?q=is%3Aopen+is%3Aissue+label%3A%22Up+for+Grabs%22) with appropriate pull-requests to address them.  Note that not all of our repositories are open for contribution yet. Ping us if unsure.
