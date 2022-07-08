# dotnet nuget why command

- Author: [Kartheek Penagamuri](https://github.com/kartheekp-ms), [Pragnya Pandrate](https://github.com/pragnya17)
- GitHub Issue [11782](https://github.com/NuGet/Home/issues/11782)

## Summary

Currently, there is not a great solution for developers to understand the nature of top-level packages and their transitive dependencies. The solution explorer in Visual Studio does a decent job at allowing a user to dive into each NuGet package & see all transitive dependencies from the top-level dependency.

![](../../meta/resources/TransitiveDependencies/SolutionView.png)

However, in comparison to Visual Studio, the dotnet CLI does not provide insight into “why” a transitive dependency is listed, although it does list everything that has been resolved as seen below.

![](../../meta/resources/TransitiveDependencies/DotNetCLI.png)

## Motivation

A developer should be able to understand where every package in a solution/project originated from. This can help them understand complex dependency chains they may have within their projects. Having this understanding can help a developer promote a transitive dependency quickly & easily to a top-level dependency in case there is a security concern or conflict. The `dotnet nuget why` command aims to help developers understand package dependency chains.

## Explanation

### Functional Explanation

The NuGet restore operation generates a `project.assets.json` file under the `obj` folder for `PackageReference` style project. This file maintains a project's dependency graph. Therefore, this file can be used in order to produce a dependency graph when the `dotnet nuget why` command is called. 

### Technical Explanation

The `dotnet nuget why` command will print out the dependency graph of a given package only if it is part of the final graph.

```
dotnet nuget why [<PROJECT>|<SOLUTION>] <PACKAGE_NAME>
    [-f|--framework <FRAMEWORK>]

dotnet nuget why -h|--help
```
#### Arguments

- PROJECT | SOLUTION

The project or solution file to operate on. If not specified, the command searches the current directory for one. If more than one solution is found, an error is thrown. If more than one project is found, the dependency graph for each project is printed. 

- PACKAGE_NAME

The package for whom the dependency graph has to be identified. Package name wildcards are not supported.

#### Options

- -f|--framework <FRAMEWORK>

Search package dependency graph for a specific target framework.

- -?|-h|--help

Prints out a description of how to use the command.

#### Examples

- List dependency graph of a package given `package id`.

```
dotnet nuget why packageA

Project 'projectNameA' has the following dependency graph for 'packageA'
   [net6.0]: Microsoft.ML (1.0.0) -> Microsoft.ML.Util (1.0.0) -> packageA (1.0.0)
   [net472] Microsoft.ML (1.0.0) -> Microsoft.ML.Util (1.0.0) -> packageA (1.0.0)

Project 'projectNameB' has the following dependency graph for 'packageA'
   [net6.0]: Microsoft.ML (1.1.0) -> Microsoft.ML.Util (1.1.0) -> packageA (1.1.0)
   [net472] Microsoft.ML (1.1.0) -> Microsoft.ML.Util (1.1.0) -> packageA (1.1.0)
```

- List dependency graph of a package given `package id` when there is a diamond dependency (a package is brought in by more than one path).

```
dotnet nuget why packageA

Project 'projectNameA' has the following dependency graph for 'packageA'
   [net6.0]: Microsoft.ML (1.0.0) -> Microsoft.ML.Util (1.0.0) -> packageA (1.0.0)
   [net6.0] Microsoft.ML (1.0.0) -> Microsoft.ML.SampleUtils (1.0.0) -> packageA (1.0.0)
```

- List dependency graph of a package given `package id` and `target framework`.

```
dotnet nuget why packageA -f net6.0

Project 'projectNameA' has the following dependency graph for 'packageA'
   [net6.0]: Microsoft.ML (1.0.0) -> Microsoft.ML.Util (1.0.0) -> packageA (1.0.0)

Project 'projectNameB' has the following dependency graph for 'packageA'
   [net6.0]: Microsoft.ML (1.1.0) -> Microsoft.ML.Util (1.1.0) -> packageA (1.1.0)
```

## Drawbacks 

The contents of the `project.assets.json` will be helpful in understanding the dependency graph of a given package but there are a few limitations:

-  There may be some packages in the file that are not part of the final graph because the NuGet restore operation downloads other packages during dependency resolution. The absence of a package id and version in the `project.assets.json` file indicates that a package was downloaded during dependency resolution but is not part of the final dependency graph.
- Packages acquired through `PackageDownload` are not tied to the project in any way beyond acquisition. These packages are not recorded in the final graph that `project.assets.json` maintains, however they are recorded under project -> frameworks -> {frameworkName} -> downloadDependencies.

## Rationale and Alternatives

We could have considered a minor tweak to the existing experience of “dotnet list package --include-transitive” to provide the user with a sense of a package's dependencies. This could have been a new column next to “Resolved” called “Transitively Referenced” that had a list of the top-level packages that requested the dependency. The corresponding tracking issue can be found here: https://github.com/NuGet/Home/issues/11625. Unfortunately, this solution doesn't provide an easy way to identify the dependency graph `(starting from project -> top-level package -> transitive-dependency (1) -> ..-> transitive dependency (n))` for a particular package.

![](../../meta/resources/TransitiveDependencies/TransitiveDotNetCLI.png)

## Prior Art

Within Visual Studio, there will be a new panel within the Visual Studio Package Manager UI named “Transitive Packages” in which all transitive packages will be displayed to the user. For the sake of not confusing the user, there will be an additional header titled “Top-level Packages”.

When a user highlights a transitive package, they will see a pop-up that displays how the transitive dependency originated & what top-level package(s) are bringing it in.

![](../../meta/resources/TransitiveDependencies/TransitiveVSPMUI.png)

## Additional improvements

Add a [--version <VERSION>] option to the command if the user wants to print dependency graphs for a specific version of the package. See NuGet package versioning for more information.

Allow the customer to look up transitive dependencies of more than one package. For example: `dotnet nuget why [<PROJECT>|<SOLUTION>] packages package1, package2` or `dotnet nuget why [<PROJECT>|<SOLUTION>] package 'nuget.*'`.

Allow the customer to transitive dependencies of more than one framework. For example: `--framework net6.0 --framework netstandard2.0`.

Create a better visualization of the dependency graph that is printed by the `dotnet nuget why` command by displaying a tree rather than just printing out a list of dependencies. 

## Appendix

- https://github.com/NuGet/Home/blob/dev/proposed/2020/Transitive-Dependencies.md
- [npm-why](https://github.com/amio/npm-why#npm-why-)
- [cargo-tree](https://doc.rust-lang.org/cargo/commands/cargo-tree.html)
- [mvn dependency:tree](https://maven.apache.org/plugins/maven-dependency-plugin/usage.html#dependency:tree)

