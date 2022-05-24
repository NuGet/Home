# H1 Adding Dotnet CLI support to projects onboarded with Central Package Management

## H2 Problem Background
The dotnet add package command allows users to add or update a package reference in a project file through the Dotnet CLI. However, when this command is used in a project that has been onboarded to Central Package Management (CPM), it poses an issue. 

Projects onboarded to CPM use a `Directory.packages.props` file in the root of the repo where package versions are defined centrally. Ideally, when the `dotnet add package` command is used, the package version should only be added to the corresponding package in the `Directory.packages.props` file. However, currently the command attempts to add the package version to the <PackageReference /> in the project which conflicts with the CPM requirements that package versions must only be in the `Directory.packages.props` file.


