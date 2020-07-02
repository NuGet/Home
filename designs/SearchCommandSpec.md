# Search CLI Tool for NuGet.exe

* Status: **Implementing**
* Author(s): [Advay Tandon](https://github.com/advay26)
* Issue: [9704](https://github.com/NuGet/Home/issues/9704) - Search CLI Tool for NuGet.exe

## Problem Background

Search functionality from the command line for NuGet.exe and the .NET Core CLI has been a feature request from the NuGet open source community for some time. Additionally, the NuGet API is already equipped to handle search requests, so an extension of this service to command line users would be both practical to implement and also highly valuable.

## Who are the customers

This targets all NuGet.exe users that want to be able to search for packages from the command line, rather than using NuGet Gallery or VS PMUI. Also, while `nuget.exe list` allows users to search different package sources for packages with a search query, the results are returned sorted by the package Id, rather than by relevance, as proposed for this Search command. Further, the Search command would provide more information on the packages than List currently does.

## Goals

* Providing search functionality for NuGet packages through the commandline for NuGet.exe
* Implementing a prototype of this feature for dotnet.exe
* Displaying the search results to users in a way that maximizes the visibility of the most relevant results
* Eventually replacing `list` with `search`

## Solution

The search feature leverages the search service provided by the NuGet API. Search targets multiple sources and displays all of their results, sorted by relevance, one source after another. The command line interface is simple: __./NuGet.exe search \<query terms\>__.

```
PS C:\> ./NuGet.exe search logging
```

Each search result displays the name, version, number of downloads, and a preview of the description of the package.

```
====================
Source: NuGet.org
--------------------
> Microsoft.Extensions.Logging.Abstractions | 5.0.0-preview.6.20305.6 | Downloads: 345,145,935
  Logging abstractions for Microsoft.Extensions.Logging.

  Commonly Used Types:
  Microsoft.Extensions.Lo...
--------------------
> Microsoft.Extensions.Logging | 5.0.0-preview.6.20305.6 | Downloads: 243,186,566
  Logging infrastructure default implementation for Microsoft.Extensions.Logging.
  When using NuGet 3....
--------------------
> Microsoft.IdentityModel.Logging | 6.6.0 | Downloads: 120,177,247
  Includes Event Source based logging support.
--------------------
> Microsoft.Extensions.Logging.Configuration | 5.0.0-preview.6.20305.6 | Downloads: 63,205,816
```

If a particular source returns no results for a query, it will display output that indicates this.

```
====================
Source: dotnet-msbuild
--------------------
No results found.
```

### Optional Arguments

Search provides users with some optional arguments that they can use to customize their search queries:

| Name | Description | Usage |
| ---  |     ---     |  :-:  |
| PreRelease | Pre-release packages are not included by default, but can be included by using this argument | -PreRelease |
| Source | Specific package source(s) to search instead of querying the default sources in __nuget.config__ | -Source `<Source URL>`|
| Take | The number of results to return. The default value is 20. | -Take `<positive integer>` |
| Verbosity | The level of detail to display in the output. The default is _normal_. (See the note below)  | -Verbosity `<quiet\|normal\|detailed>` |
| Help | Displays help information for the command | -Help |

__NOTE__

Verbosity Levels:

* _quiet_ - Package ID, Version
* _normal_ - Package ID, Version, Downloads, Preview of Description
* _detailed_ - Package ID, Version, Downloads, Full Description, Other information such as the query URL, and the arguments and filters applied to the search

## Future Work

* Integrating the Search feature into dotnet.exe
* Plan for the deprecation of `list`. Start redirecting users from `list` to `search`
* Adding further optional arguments that allow users to customize their search queries
* Using columns rather than `|` to display results
* Consider using pagination to display the search results

## Open Questions

* What represents the most effective design choice for displaying the search results, in terms of spacing, demarcation, truncating package descriptions, and so on?
* Would pagination (using the 'more' or 'less' commands) provide a better viewing experience for users? Would users prefer to pipe the search results to these commands themselves, or have Search do it for them? See _Considerations_ for more. 
* What, if any, additional information should be included for the packages returned by Search?

## Considerations

### 1. Combining the results from different sources

Initially, we considered consolidating all search results from the various sources and interleaving them together, rather than separating them based on their source. However, users may wish to know where a particular package is located. Also, combining the search results for different sources leads to the complex problem of how to combine these results most effectively.

### 2. Displaying results using pagination

Rather than simply printing the output to the console as a regular stream, using pagination (with the 'more' or 'less' commands) would ensure that users have access to the search results in order of decreasing relevance. They would see the most relevant results (at the top/beginning of the results) first. A single page of results would be shown at a time, and the user could look at the next page by pressing the __space__ key. If we were to simply print the output to the console as a regular stream, the most visible results would be the ones at the end of the output stream, since these would be located right above the next command prompt in the terminal.
