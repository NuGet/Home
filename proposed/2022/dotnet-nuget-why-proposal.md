# dotnet nuget why command

- Status: **Draft**
- Author: [Kartheek Penagamuri](https://github.com/kartheekp-ms)
- GitHub Issue [11782](https://github.com/NuGet/Home/issues/11782)

## Problem Background

Developers are often confused with top-level & transitive dependencies in their project. A developer should be able understand where every package originated from. A user should be able to promote a transitive dependency quickly & easily to a top-level dependency in the case there is a security concern on the package version depended on or if promoting to a top-level package will resolve a conflict.

Knowing how a package is being included in a project helps a developer diagnose many problems. It also provides them with an opportunity to understand complex dependency chains they may have within their projects. There is not a great solution that exists to understand the nature of top-level packages and their transitive dependencies. The solution explorer in Visual Studio does the best job at allowing a user to dive into each NuGet package & see all transitive dependencies from the top-level dependency.

![](../../meta/resources/TransitiveDependencies/SolutionView.png)

The dotnet CLI does not provide the insight into “why” a transitive dependency is listed, although it does list everything that has been resolved.

![](../../meta/resources/TransitiveDependencies/DotNetCLI.png)

We could have considered a minor tweak to the existing experience of “dotnet list package --include-transitive” to provide the user with a sense of where the package came from. This could be a new column next to “Resolved” which says “Transitively Referenced” or “Referenced” and has a list of the top-level packages that requested the dependency. Tracking issue can be found here: https://github.com/NuGet/Home/issues/11625. Unfortunately, this solution doesn't provide an easy way to identify the dependency graph `(starting from project -> top-level package -> transitive-dependency (1) -> ..-> transitive dependency (n))` for a particular package.

![](../../meta/resources/TransitiveDependencies/TransitiveDotNetCLI.png)

Within Visual Studio, there will be a new panel within the Visual Studio Package Manager UI named “Transitive Packages” in which all transitive packages will be displayed to the user. For the sake of not confusing the user, there will additionally be a header titled “Top-level Packages” where the current experience is today for top-level packages.

When a user highlights a transitive package, they will see a pop-up that displays how the transitive dependency originated & what top-level package(s) are bringing it in.

![](../../meta/resources/TransitiveDependencies/TransitiveVSPMUI.png)

Sadly, we don’t have any further CLI or visualizing tool today to answer `Running 'dotnet restore' on a (large) .sln file restores a certain problematic package. How do I know which project(s) in the solution is causing that package to be restored?` question.

## Goals
The main goal is to add `dotnet nuget why` command to .NET CLI to help customers understand the dependency graph of a given package for PackageReference projects.

Projects that use `packages.config` format are out of scope for this effort because the XML file contains a flat list of both direct and transitive package dependencies. Customers cannot visualize the dependency graph from the file itself but it would be easy to update the package version of transitive depedency incase if there is any security vulnerability in the current version.

## Customers
We are building this for .NET users to be successful with understanding dependency graph for a given package.

## Solution
`dotnet nuget why` command prints the dependency graph of a package for PackageRefernce projects to the console host.

```
dotnet nuget why [<PROJECT>|<SOLUTION>] package <PACKAGE_NAME>
    [-f|--framework <FRAMEWORK>]
    [--version <VERSION>]
    [-v|--verbosity <LEVEL>]

dotnet nuget why -h|--help
```
#### Arguments

- PROJECT | SOLUTION

The project or solution file to operate on. If not specified, the command searches the current directory for one. If more than one solution or project is found, an error is thrown.

- PACKAGE_NAME

The package for whom the dependency graph has to be identified. Package name wildcards are not supported.

#### Options

- -f|--framework <FRAMEWORK>

Search package depdnency graph only for a specific target framework.

- -?|-h|--help

Prints out a description of how to use the command.

- --version <VERSION>

Version of the package. See NuGet package versioning.

- -v|--verbosity <VERSION>

Sets the verbosity level of the command. Allowed values are q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic]. The default is minimal. For more information, see [LoggerVerbosity](https://docs.microsoft.com/en-us/dotnet/api/microsoft.build.framework.loggerverbosity).

#### Examples

- List depdency graph for a specific package.

```
dotnet nuget why package
```

