# Adding Dotnet CLI support to projects onboarded with Central Package Management

## Problem Background
The dotnet add package command allows users to add or update a package reference in a project file through the Dotnet CLI. However, when this command is used in a project that has been onboarded to Central Package Management (CPM), it poses an issue. 

Projects onboarded to CPM use a `Directory.packages.props` file in the root of the repo where package versions are defined centrally. Ideally, when the `dotnet add package` command is used, the package version should only be added to the corresponding package in the `Directory.packages.props` file. However, currently the command attempts to add the package version to the <PackageReference /> in the project which conflicts with the CPM requirements that package versions must only be in the `Directory.packages.props` file.

## Goals
The main goal is to add support for `dotnet add package` to be used with projects onboarded onto CPM. Regardless of whether the package has already been added to the project or not, the command should allow users to add packages or update the package version in the `Directory.packages.props` file.

## Customers
Users wanting to use CPM onboarded projects and dotnet CLI commands.

## Solutions
When `dotnet add package` is executed in a project onboarded to CPM any one of the following things should happen: 
- If the package does not already exist, it should be added along with the appropriate package version to `Directory.packages.props`. Only the package name (not the version) should be added to `<PackageReference>` in the project file.
- If the package already exists in `Directory.packages.props` the version should be updated in `Directory.packages.props`. The `<PackageReference>` in the project file should not change.

In all of the cases above, if no version is specified in the CLI command the latest version should be added to `Directory.packages.props`.



