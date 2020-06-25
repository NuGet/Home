# Search CLI Tool for NuGet.exe and Dotnet.exe

* Status: **Implementing**
* Author(s): [Advay Tandon](https://github.com/advay26)
* Issue: [9704](https://github.com/NuGet/Home/issues/9704) - Search CLI Tool for NuGet.exe and Dotnet.exe

## Problem Background

Search functionality from the command line for NuGet.exe and the .NET Core CLI has been a feature request from the NuGet open source community for some time. Additionally, the NuGet API is already equipped to handle search requests, so an extension of this service to command line users would be both practical to implement and also highly valuable.

## Who are the customers

All NuGet.exe and .NET CLI users.

## Goals

* Providing search functionality for NuGet packages through the commandline
* Displaying the search results to users in a way that maximizes the visibility of the most relevant results.

## Solution

Th search feature leverages the search service provided by the NuGet API. Search targets multiple sources and displays all of their results one after the other. The command line interface is simple: __./NuGet.exe search \<query\>__.
```
PS C:\> ./NuGet.exe search logging
```

Each search result displays the name, version, number of downloads, and description of the package. Additionally, Search uses pagination to provide a clean viewing experience for users as they look at the results of their search. This ensures that users have access to the search results in order of decreasing relevance. A single page of results is shown at a time, and the user can look at the next page by pressing the __space__ key.

```
====================
Source: NuGet.org
--------------------
> Microsoft.Extensions.Logging.Abstractions | v5.0.0-preview.6.20305.6 | DLs: 345145935
Logging abstractions for Microsoft.Extensions.Logging.

Commonly Used Types:
Microsoft.Extensions.Logging.ILogger
Microsoft.Extensions.Logging.ILoggerFactory
Microsoft.Extensions.Logging.ILogger&lt;TCategoryName&gt;
Microsoft.Extensions.Logging.LogLevel
Microsoft.Extensions.Logging.Logger&lt;T&gt;
Microsoft.Extensions.Logging.LoggerMessage
Microsoft.Extensions.Logging.Abstractions.NullLogger

When using NuGet 3.x this package requires at least version 3.4.

--------------------
> Microsoft.Extensions.Logging | v5.0.0-preview.6.20305.6 | DLs: 243186566
Logging infrastructure default implementation for Microsoft.Extensions.Logging.
When using NuGet 3.x this package requires at least version 3.4.

--------------------
> Microsoft.IdentityModel.Logging | v6.6.0 | DLs: 120177247
Includes Event Source based logging support.

--------------------
> Microsoft.Extensions.Logging.Configuration | v5.0.0-preview.6.20305.6 | DLs: 63205816
Configuration support for Microsoft.Extensions.Logging.
When using NuGet 3.x this package requires at least version 3.4.

--------------------
> Microsoft.Extensions.Logging.Console | v5.0.0-preview.6.20305.6 | DLs: 61796431
Console logger provider implementation for Microsoft.Extensions.Logging.
When using NuGet 3.x this package requires at least version 3.4.

--------------------
> Microsoft.Extensions.Logging.Debug | v5.0.0-preview.6.20305.6 | DLs: 58643995
Debug output logger provider implementation for Microsoft.Extensions.Logging. This logger logs messages to a debugger monitor by writing messages with System.Diagnostics.Debug.WriteLine().
When using NuGet 3.x this package requires at least version 3.4.

--------------------
> Microsoft.Extensions.Logging.EventSource | v5.0.0-preview.6.20305.6 | DLs: 32121683
EventSource/EventListener logger provider implementation for Microsoft.Extensions.Logging.
When using NuGet 3.x this package requires at least version 3.4.

--------------------
> Serilog.Extensions.Logging | v3.0.2-dev-10280 | DLs: 43115462
-- More  --
```

## Future Work

* Enabling cross-platform functionality for the search feature
* Adding optional arguments that allow users to customize their search queries

## Open Questions

* What represents the most effective design choice for displaying the search results, in terms of spacing, demarcation, truncating package descriptions, and so on?

## Considerations

### 1. Combining the results from different sources

Initially, we considered consolidating all search results from the various sources and displaying them together, rather than separating them based on their source. However, users may wish to know where a particular package is located. Also, combining the search results for different sources leads to the complex problem of how to combine these results most effectively.

### 2. Displaying results by printing the output stream to the console without pagination

If we were to simply print the output to the console as a regular stream, the most visible results would be the ones at the end of the output stream, since these would be located right above the next command prompt in the terminal. Pagination, as proposed in this document, ensures that the most relevant results are shown to the users first.
