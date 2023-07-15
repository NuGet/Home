# Support excluding projects from transitive dependencies

- Author Name [Greybird](https://github.com/Greybird)
- Start Date 2023-07-11
- GitHub Issue [12585](https://github.com/NuGet/Home/issues/12585)
- GitHub PR https://github.com/NuGet/NuGet.Client/pull/5302

## Summary

Currently, when listing transitive packages using `dotnet list package --include-transitive`, both project and packages dependencies are reported. The goal of this proposal is to provide a way to filter the projects out of the report.

## Motivation 

While packages and projects are very close - packages being packed projects -, packages differ from project because they can be published to a package repository. This package repository allows metadata not included in the package initially, to be added as a decoration - for deprecation or vulnerabilities for example -. In turn, these additional metadata can be consumed to take decisions.

The `list package` command already supports filtering the results to retrieve only deprecated (`--deprecated`), vulnerable (`--vulnerable`), or not up-to-date (`--outdated`) packages. These commands only return actual packages, which is understandable as the underlying information used to choose what to report is managed by the _package_ manager, aka nuget.

When `list package` is used without any of these flags,
* using `--include-transitive` lists `direct` project dependencies as transitive.
* not using `--include-transitive` does not list project dependencies at all.

Allowing to remove projects from the output would allow users to get an accurate view of their package dependencies. This would ensure that the output of the command can be processed in an uniform way by either a user, or a piece of software - through the machine readable output - to support any report, or process associated with packages, even those with no issues related to deprecation, vulnerabilities, or up-to-dateness.

## Explanation

### Functional explanation

A new `--exclude-project` option will be added to the `list` command. This option will ensure that no project will be reported in the output when used with `--include-transitive`.

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

Adding `--exclude-project` to the command would make `dotnet list solution.sln package --include-transitive --exclude-project` produce the following output:
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

Adding the `--exclude-project` option to a command already using a `--deprecated`, `--vulnerable`, or `--outdated` option will result in a warning.
Running `dotnet list solution.sln package --include-transitive --vulnerable --exclude-project` will result in the following output:
```
warn : The command option '--exclude-project' is ignored by this command.

The following sources were used:
   https://api.nuget.org/v3/index.json

The given project `projectA` has no vulnerable packages given the current sources.
The given project `projectB` has no vulnerable packages given the current sources.
```

### Technical explanation

Currently, the implementation determines a [ReportType](https://github.com/NuGet/NuGet.Client/blob/d9d5a38c6e0c3ccc36b1b21cb8fa468474690080/src/NuGet.Core/NuGet.CommandLine.XPlat/Commands/PackageReferenceCommands/ListPackage/ReportType.cs#L6) based on the presence of options:
| Option              | Resulting ReportType  |
| ------------------- | --------------------- |
| --deprecated        | ReportType.Deprecated |
| --outdated          | ReportType.Outdated   |
| --vulnerable        | ReportType.Vulnerable |
| _none of the above_ | ReportType.Default    |

MSBuild version resolver is then called with the `includeProject` parameter set to `false` for all values except `Default`, where it is set to `true`.

The implementation would consist or changing the value to `false` when the `exclude-project` option is set.

## Drawbacks

It adds a new option to a command, which could result in it being more difficult to use.

## Rationale and alternatives

This design is retro compatible with the previous behavior of the command. It also limits the output of the command to the expected results.

Other approaches could have been taken:
* Considering that including projects into the output is a bug, and fixint it.
* Considering that projects are part of the output, and ensuring that direct (resp. transitive) project references are reported as direct (resp. transitive). In this case, adding a flag to be able to retrieve only package is probably worth it, like mentioned below.
* Adding a `--include-project` option and modifying the default behavior of the list command: this would have made the whole command consistent, whether a `--deprecated`, `--vulnerable`, or `--outdated` option is passed or not. However, this would create a breaking change with previous behavior
* Adding the type of dependency to the output: this would have made the output filterable afterwards, without adding flags. However, this could break console output parsing - which could be acceptable -, and could force an `output-version` increment as the machine-readable format would change. It would also require an active filtering process after the command is run. Whether this proposal is implemented, this could be an interesting option if consequences are accepted.

If we do not implement this option, then users of the command will have to be able to filter projects out of the output. However, this is not an easy task, and it is subject to errors if for example a project and a package have the same name.

## Prior Art

* [Machine readable JSON output for dotnet list package](https://github.com/NuGet/Home/blob/a6fea29b47359df9a1a03c381459e2b72c6062e9/proposed/2022/DotnetListPackageMachineReadableJsonOutput.md)

## Unresolved Questions

* Should the nature of the dependency (project or package) be included in the command output (or at least in the machine-readable one) ?

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
