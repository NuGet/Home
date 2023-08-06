# Remove projects from list package command

- Author Name [Greybird](https://github.com/Greybird)
- Start Date 2023-07-11
- GitHub Issue [12585](https://github.com/NuGet/Home/issues/12585)
- GitHub PR https://github.com/NuGet/NuGet.Client/pull/5335

## Summary

Currently, when listing transitive packages using `dotnet list package --include-transitive`, both project and packages dependencies are reported. The goal of this proposal is to remove project dependencies from this command related to packages.

## Motivation 

While packages and projects are very close - packages being packed projects -, packages differ from project because they can be published to a package repository. This package repository enables the addition of metadata that wasn't included in the initial package, which can serve purposes like indicating deprecation or vulnerabilities. In turn, these additional metadata can be consumed to take decisions.

The `list package` command already supports filtering the results to retrieve only deprecated (`--deprecated`), vulnerable (`--vulnerable`), or not up-to-date (`--outdated`) packages. These commands only return actual packages, which is understandable as the underlying information used to choose what to report is managed by the _package_ manager, aka nuget.

When `list package` is used without any of these flags,
* using `--include-transitive` lists `direct` project dependencies as transitive.
* not using `--include-transitive` does not list project dependencies at all.

Removing projects from the output would allow users to get an accurate view of their package dependencies. This would ensure that the output of the command can be processed in an uniform way by either a user, or a piece of software - through the machine readable output - to support any report, or process associated with packages, even those with no issues related to deprecation, vulnerabilities, or up-to-dateness.

## Explanation

### Functional explanation

The `list package` default behavior will be changed to only return packages in the output.

Given a solution setup like the one below,
```
solution.sln
├── projectA.csproj
│   └── package1.nupkg (2.5.6)
│       └── package2.nupkg (1.0.0)
└── projectB.csproj
    ├── projectA.csproj
    └── package3.nupkg (30.0.1)
        └── package4.nupkg (1.0.5)
```

Running `dotnet list solution.sln package --include-transitive` produces the following output:
```
Project 'projectA' has the following package references
   [net7.0]:
   Top-level Package      Requested   Resolved
   > package1             2.5.6       2.5.6

   Transitive Package       Resolved
   > package2               1.0.0

Project 'projectB' has the following package references
   [net7.0]:
   Top-level Package      Requested   Resolved
   > package3             30.0.1      30.0.1

   Transitive Package       Resolved
   > package4               1.0.5
   > projectA               1.0.0
```

After the fix, the same command would produce the following output:
```
Project 'projectA' has the following package references
   [net7.0]:
   Top-level Package      Requested   Resolved
   > package1             2.5.6       2.5.6

   Transitive Package       Resolved
   > package2               1.0.0

Project 'projectB' has the following package references
   [net7.0]:
   Top-level Package      Requested   Resolved
   > package3             30.0.1      30.0.1

   Transitive Package       Resolved
   > package4               1.0.5
```

Machine-readable output will also reflect the change by not including the project in the output.

### Technical explanation

Currently, the implementation determines a [ReportType](https://github.com/NuGet/NuGet.Client/blob/d9d5a38c6e0c3ccc36b1b21cb8fa468474690080/src/NuGet.Core/NuGet.CommandLine.XPlat/Commands/PackageReferenceCommands/ListPackage/ReportType.cs#L6) based on the presence of options:
| Option              | Resulting ReportType  |
| ------------------- | --------------------- |
| --deprecated        | ReportType.Deprecated |
| --outdated          | ReportType.Outdated   |
| --vulnerable        | ReportType.Vulnerable |
| _none of the above_ | ReportType.Default    |

MSBuild version resolver is then called with the `includeProject` parameter set to `false` for all values except `Default`, where it is set to `true`.

As the current implementation incorrectly includes direct project dependencies as transitive, the parameter responsible for this behavior will be removed from the non-public method.
The code consuming the parameter will be update to behave as if the parameter would have been set to `false`

## Drawbacks

It might introduce a breaking change for a small number of use cases. However, the presence of a `list reference` command, working on projects, mitigates this risk

## Rationale and alternatives

The proposal considers the current behavior a bug, as determined by the project members review.

Other approaches could have been taken:
* Adding an `--exclude-project` option, to remove projects from the output. A proposal has been made, which has been closed as another solution has been chosen: https://github.com/NuGet/NuGet.Client/pull/5302
* Taking into account that projects are part of the output, and ensuring that direct (or transitive) project references are appropriately reported. In this case, adding a flag to be able to retrieve only package is probably worth it, like mentioned below.
* Adding a `--include-project` option and modifying the default behavior of the list command: this would have made the whole command consistent, whether a `--deprecated`, `--vulnerable`, or `--outdated` option is passed or not. However, this would create a breaking change with previous behavior
* Adding the type of dependency to the output: this would have made the output filterable afterwards, without adding flags. However, this could break console output parsing - which could be acceptable -, and could force an `output-version` increment as the machine-readable format would change. It would also require an active filtering process after the command is run. Whether this proposal is implemented, this could be an interesting option if consequences are accepted.

If we do not implement this option, then users of the command will have to be able to filter projects out of the output. However, this is not an easy task, and it is subject to errors if for example a project and a package have the same name.

## Prior Art

* [Machine readable JSON output for dotnet list package](https://github.com/NuGet/Home/blob/a6fea29b47359df9a1a03c381459e2b72c6062e9/proposed/2022/DotnetListPackageMachineReadableJsonOutput.md)

## Unresolved Questions

* Should the nature of the dependency (project or package) be included in the command output (or at least in the machine-readable one)?

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
