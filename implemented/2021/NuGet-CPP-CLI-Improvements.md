# NuGet C++/CLI support

- NuGet uses 2 properties to infer frameworks, TargetFrameworkMoniker (Ex: `.NETCoreApp,Version=v5.0`) & TargetPlatformMoniker  (Ex: `Windows,Version=10.0.19041.0`). Both these properties are derived from the equivalently named properties with Identifier and Version instead of Moniker.
- Some of the relevant compatibility rules in NuGet, note that framework is first the check, while platform is the second check. Compat rules are all or nothing. There's no partial compat.
  - net7.0 can depend on net6.0
  - net7.0-windows10.0.19041 can depend on net7.0
  - net7.0 cannot depend on net7.0-windows10.0.19041
  - net7.0-windows10.0.20000 can depend on net7.0-windows10.0.19041
  - net7.0-windows10.0.19041 can depend on net7.0-windows10.0.20000
- The compatibility rules at many layers, not just NuGet. That includes the .NET SDK, MSBuild, and in general the compat library ships as it's own feature.

Today, when determining the framework for C++/CLI projects, NuGet only reads the TargetFrameworkMoniker (this was a decision we jointly made after the initial version of the feature shipped).
This prevents a C++/CLI project from referencing a C# project targeting windows.

Given the following scenario:

C# (net7.0-windows) -> C++/CLI -> C# (net7.0-windows)

The C++/CLI project cannot reference the C# project.

Proposal:

- NuGet will start reading the TargetPlatformMoniker and use it in it's compat rules above.
- C++/CLI projects will need a TargetPlatformVersion set that's compatible with the C# projects that are being referenced.
  - The reasoning why this version needs to exist is that when the 1st C# project references the C++/CLI project, it receives all it's transitive references, so the C# projects both need to be compatible with one another.
  - If TargetPlatformMoniker or TargetPlatformVersion are properties *used* in C++/CLI projects, we can consider an alternative property for NuGet to read for C++/CLI projects only.

Drawbacks:

- The end-user may need to manage a value in their C++/CLI project that has no true meaning for the C++/CLI project itself.
