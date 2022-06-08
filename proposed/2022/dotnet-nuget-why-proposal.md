# dotnet nuget why command

- Status: **Draft**
- Author: [Kartheek Penagamuri](https://github.com/kartheekp-ms)
- GitHub Issue [11782](https://github.com/NuGet/Home/issues/11782)

## Problem: What problem is this solving?

Developers are often confused with top-level & transitive dependencies in their project. A developer should be able understand where every package originated from. A user should be able to promote a transitive dependency quickly & easily to a top-level dependency in the case there is a security concern on the package version depended on or if promoting to a top-level package will resolve a conflict.

## Why: How do we know this is a real problem and worth solving?

Knowing how a package is being included in a project helps a developer diagnose many problems. It also provides them with an opportunity to understand complex dependency chains they may have within their projects. There is not a great solution that exists to understand the nature of top-level packages and their transitive dependencies. The solution explorer in Visual Studio does the best job at allowing a user to dive into each NuGet package & see all transitive dependencies from the top-level dependency.

![](../../meta/resources/TransitiveDependencies/SolutionView.png)

The dotnet CLI does not provide the insight into “why” a transitive dependency is listed, although it does list everything that has been resolved.

![](../../meta/resources/TransitiveDependencies/DotNetCLI.png)
