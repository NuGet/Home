# ***Make the pack command available in classic csproj, reduce .NET SDK size by merging pack & restore functionality***

- [nkolev92](https://github.com/nkolev92)
- [#14046](https://github.com/NuGet/Home/issues/14046)

## Summary

Make the pack targets available in classic csproj.
Merge the pack and restore functionality into 1 package/assembly, reducing technical debt and minimizing the size of the .NET SDK.

## Motivation

To run pack on a classic csproj, you need install the [NuGet.Build.Tasks.Pack](https://www.nuget.org/packages/NuGet.Build.Tasks.Pack) package. This makes the restore/build & pack tooling disjoint. In addition to upgrading the msbuild/VS versions, you need to remember to upgrade the NuGet.Build.Tasks.Pack package as well and that's simply not something people do frequently (similarly to how people don't always align NuGet.exe and the Visual Studio versions).
Within the .NET SDK, the restore & pack packages are not in the same folder. The restore targets and assemblies are in the root folder, while the pack assembly and targets are in an SDK folder (that has both .NET & .NET Framework assemblies ilmerged).
What this means is that we have multiple copies of the same assemblies, including resources, adding about 20MB to the total unzipped size of the .NET SDK.

## Explanation

### Functional explanation

The following table contains details about the behavior of how pack is run for each command.

| tool | Project Style | Result |
|---------|---------------|--------|
| dotnet | .NET SDK | Uses .NET SDK pack |
| dotnet | classic PackageReference | N/A |
| dotnet | classic csproj | N/A |
| msbuild | .NET SDK | Uses .NET SDK pack, which contains .NET Framework assemblies |
| msbuild | classic PackageReference | Fails with `The target "pack" does not exist in the project` |
| msbuild | classic csproj | Fails with `The target "pack" does not exist in the project` |

When using the dotnet commands, there are no proposed changes in behavior.
When using the msbuild commands, there are 2 changes:

- When running msbuild /t:pack on an .NET SDK based project, the pack targets from MSBuild will be imported. This allows us to avoid shipping the .NET Framework version of pack in the .NET SDK and unifies the restore & pack functionality compared to what we currently have which is build & pack are aligned. I don't think there's an easy answer here.
- When running classic csproj, we will need to make the pack target project style aware. What that means is that we will change the pack target to no-op when the project style is not PackageReference. This is a *change* compared to the previous behavior.

| tool | Project Style | Result |
|---------|---------------|--------|
| dotnet | .NET SDK | Uses .NET SDK pack |
| dotnet | classic PackageReference | N/A |
| dotnet | classic csproj | N/A |
| msbuild | .NET SDK | Uses .NET SDK pack, which contains .NET Framework assemblies |
| msbuild | classic PackageReference | Uses the new msbuild pack |
| msbuild | classic csproj | Completes successfully, but the target no-ops. |

The NuGet.Build.Tasks.Pack.targets imported order will be the same in .NET SDK based projects (meaning the NuGet.Targets will not import the NuGet.Build.Tasks.Pack.targets).
In MSBuild based projects, we will add a project level import for the pack targets similar to how the .NET SDK imports are done (TBD).

These changes also lead to the NuGet.Build.Tasks.Pack package no longer being published.
We will mark this package as deprecated and publish guidance for customers.

Today, when the NuGet.Build.Tasks.Pack is installed, it's preferred over the .NET SDK built in targets.
We could figure out a way to make the new imports be preferred, but that's not a priority right now.

In the .NET SDK project scenario, this does introduce some behavioral changes in the msbuild /t:pack scenarios.

| msbuild | .NET SDK | Result |
| new | 10.0.x | Uses the new msbuild pack |
| new | 9.0.x | Uses the 9.0.x .NET SDK pack |
| old | 10.0.x | Fails. |
| old | 9.0.x | Uses the 9.0.x .NET SDK pack |

Currently, the minimum MSBuild version for the .NET SDK 10.0.x is 17.13, so we would effectively be breaking someone using .NET 10 SDK with MSBuild 17.13 and 17.14 before we could add the pack targets in the next version of MSBuild.
We could add the .NET Framework implementation of pack in the package to enable the MSBuild /t:pack scenarios older MSBuild and the .NET 10 SDK.

### Technical explanation

The current layout of the .NET SDK & NuGet assets is:

```console
.\NuGet.Targets
.\NuGet.Build.Tasks.dll
.\NuGet.Commandline.Xplat.dll
.\NuGet.Commands.dll
.\NuGet.Build.Tasks.Pack\build\NuGet.Build.Tasks.Pack.targets
.\NuGet.Build.Tasks.Pack\buildCrossTargeting\NuGet.Build.Tasks.Pack.targets
.\NuGet.Build.Tasks.Pack\CoreCLR\NuGet.Build.Tasks.Pack.dll (ilmerged)
.\NuGet.Build.Tasks.Pack\Desktop\NuGet.Build.Tasks.Pack.dll (ilmerged)
```

The NuGet.targets and NuGet.Build.Tasks.Pack.targets are imported at different places in the classic csproj.
The NuGet.targets are imported in [Microsoft.Common.CurrentVersion.targets](https://github.com/dotnet/msbuild/blob/194c2e94475106f9727ede721bb057caf46dc0d3/src/Tasks/Microsoft.Common.CurrentVersion.targets#L7004-L7009), which is imported through Microsoft.Common.targets or Microsoft.language.targets in the Sdk.targets, around line 30.
The NuGet.Build.Tasks.Pack.targets are imported in the root of the [Sdk.Targets](https://github.com/dotnet/sdk/blob/e112eec856239964fa45211b096882a8b7ecbbd7/src/Tasks/Microsoft.NET.Build.Tasks/sdk/Sdk.targets#L48-L52), around line 50.

In the .NET SDK, we will keep the import order the same to minimize chances of breaking anyone.
In the classic csproj projects, we will add an import in <https://github.com/dotnet/msbuild/blob/194c2e94475106f9727ede721bb057caf46dc0d3/src/Tasks/Microsoft.Common.CurrentVersion.targets#L7005-L7011>.
The NuGet.targets are imported in the solution context as well, so this avoids any weirdness due to that.

To summarize, we will need to do the following technical work:

- Merge NuGet.Build.Tasks.Pack into NuGet.Build.Tasks.
- When the insertion into the .NET SDK happens, make the imports and layout changes in the .NET SDK.
- Make the Pack target project style aware, don't invoke it on non-PackageReference based projects.
- Add an import for the NuGet.Build.Tasks.Pack.targets into MSBuild, but make it .NET SDK aware to avoid double loading the targets.
  - When we have new msbuild and old SDK, we should ensure the pack targets are loaded from new msbuild by setting NuGetBuildTasksPackTargets to the MSBuild version and setting ImportNuGetBuildTasksPackTargetsFromSdk to false.

## Drawbacks

- Breaking change for some scenarios.

## Rationale and alternatives

- Make NuGet.targets import NuGet.Build.Tasks.Pack.targets
We could do this, but it is less disruptive for .NET SDK projects, the priority scenario to change up the import order.
- Keep the .NET Framework implementation of pack until the minimum MSBuild version is moved to the first version of MSBuild that contains the pack targets.

## Prior Art

## Unresolved Questions

- 

## Future Possibilities