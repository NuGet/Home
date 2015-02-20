![NuGet logo](http://cdn.meme.am/instances/55368401.jpg)

-----

# NuGet Home

The Home repository is the starting point for people to learn about NuGet. This repo contains pointers to the various GitHub repositories used by NuGet and allows folks to learn more about what's coming in NuGet.

NuGet is being actively developed by the Outercurve Foundation. NuGet is the package manager for the Microsoft development platform including .NET. The [NuGet client tools (on CodePlex)](http://nuget.codeplex.com) provide the ability to produce and consume packages. The [NuGet Gallery](https://github.com/NuGet/NuGetGallery) is the central package repository used by all package authors and consumers and has a live deployment at [www.nuget.org](https://www.nuget.org).

## Documentation and Further Learning

### [NuGet Docs](http://docs.nuget.org)

The NuGet Docs are the ideal place to start if you are new to NuGet. They are categorized in 3 broader topics:

* [Consume NuGet packages](http://docs.nuget.org/consume) in your projects;
* [Create NuGet packages](http://docs.nuget.org/create) to learn about packaging and publishing your own NuGet Packages;
* [Contribute to NuGet](http://docs.nuget.org/contribute) gives an overview of how you can contribute to teh various NuGet projects.

### [NuGet Blog](http://blog.nuget.org/)

The NuGet Blog is where we announce new features, write engineering blog posts, demonstrate proof-of-conepts and features under development.

## Repos and Projects

In the legacy department, we have the following repos:

* [NuGet (on CodePlex)](http://nuget.codeplex.com) - the NuGet command-line tool, Visual Studio Extension and PowerShell CmdLets
* [NuGetGallery](https://github.com/NuGet/NuGetGallery) - the current NuGet Gallery

We are woring hard to make NuGet a modern package manager for .NET. The repos where the action around that is happening:

* [NuGet.CommandLine](https://github.com/NuGet/NuGet.CommandLine) - the NuGet command-line tool
* [NuGet.VisualStudioExtension](https://github.com/NuGet/NuGet.VisualStudioExtension) - the NuGet Visual Studio Extension and PowerShell CmdLets
* [NuGet.Gallery](https://github.com/NuGet/NuGet.Gallery) - the new NuGet Gallery
* [NuGet.Protocol](https://github.com/NuGet/NuGet.Protocol) - the NuGet API v3 protocol client 
* [NuGet.Versioning](https://github.com/NuGet/NuGet.Versioning) - NuGet's implementation of package versioning
* [NuGet.Configuration](https://github.com/NuGet/NuGet.Configuration) - NuGet's configuration implementation 

NuGet is backed by several core services:

* [NuGet.Services.Metadata](https://github.com/NuGet/NuGet.Services.Metadata) - NuGet's Metadata Service
* [NuGet.Services.Search](https://github.com/NuGet/NuGet.Services.Search) - NuGet's Search Service
* [NuGet.Services.Messaging](https://github.com/NuGet/NuGet.Services.Messaging) - NuGet's Messaging Service
* [NuGet.Services.Metrics](https://github.com/NuGet/NuGet.Services.Metrics) - NuGet's Metrics Service

While building NuGet, we sometimes need something that can be used outside of NuGet, too. Examples are:

* [json-ld.net](https://github.com/NuGet/json-ld.net), a JSON-LD processor for .NET ([json-ld.net on NuGet](https://www.nuget.org/packages/json-ld.net/))
* [PoliteCaptcha](https://github.com/NuGet/PoliteCaptcha), a spam prevention library for ASP.NET MVC ([PoliteCaptcha on NuGet](https://www.nuget.org/packages/PoliteCaptcha/))

A [full list of all the repos](https://github.com/NuGet) is available as well.

## NuGet Packages by the NuGet team

We dogfood all of our stuff. NuGet uses NuGet to build NuGet, so to speak. All of our NuGet packages, which you can use in your own projects as well, are available from [our NuGet.org profile page](https://www.nuget.org/profiles/nuget).

## Feedback

Check out the [contributing](about:todo) page to see the best places to log issues and start discussions.
