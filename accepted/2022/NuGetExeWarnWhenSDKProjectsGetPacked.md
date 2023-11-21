# Show error when using NuGet.exe to pack an SDK csproj

- [Nikolche Kolev](https://github.com/nkolev92)
- GitHub Issue <https://github.com/NuGet/Home/issues/7778>

## Summary

NuGet.exe does not support packing SDK-based, or PackageReference projects in general.
If you run NuGet.exe pack on an SDK-based csproj, it might pack, but it will do it incorrectly.
The proposal is to `error` whenever a SDK-based csproj pack is attempted, instructing the user to use `msbuild /t:pack` or `dotnet.exe pack` instead.

## Motivation

NuGet.exe does not support packing SDK-based, or PackageReference projects in general.
If you run NuGet.exe pack on an SDK-based csproj, it might pack, but it will do it incorrectly.
The pack SDK experience for PackageReference projects knows how to automatically manage the dependencies and makes multitargeted projects extremely easy to pack.
It is recommended that SDK projects are managed by using `dotnet.exe` instead.

## Explanation

### Functional explanation

#### How packing and SDK-based project with NuGet.exe behaves today

Scenario 1: Single target framework SDK based projects, with .NET SDK installed on the machine.

```console
Attempting to build package from 'SDK.csproj'.
MSBuild auto-detection: using msbuild version '17.4.0.37601' from 'C:\Program Files\Microsoft Visual Studio\2022\Preview\MSBuild\Current\Bin\amd64'.
Packing files from 'C:\Code\Temp\SDK\bin\Debug\net6.0'.
WARNING: NU5115: Description was not specified. Using 'Description'.
WARNING: NU5115: Author was not specified. Using 'Roki2'.
WARNING: NU5128: Some target frameworks declared in the dependencies group of the nuspec and the lib/ref folder do not have exact matches in the other location. Consult the list of actions below:
- Add a dependency group for net6.0 to the nuspec
Successfully created package 'C:\Code\Temp\SDK\SDK.1.0.0.nupkg'.
```

The command packages the single assembly, but does not generate the correct dependencies or any other metadata in the same way that the pack SDK would.

Scenario 2: Multiple target framework SDK based projects, with .NET SDK installed on the machine.

```console
Attempting to build package from 'SDK.csproj'.
MSBuild auto-detection: using msbuild version '17.4.0.37601' from 'C:\Program Files\Microsoft Visual Studio\2022\Preview\MSBuild\Current\Bin\amd64'.
Error NU5012: Unable to find 'bin\Debug\SDK\bin\Debug\'. Make sure the project has been built.
```

NuGet.exe does not understand the concept of multitargetting and just merges the output paths.

Scenario 3: SDK-based project, without the .NET SDK installed

```console
The SDK 'Microsoft.NET.Sdk' specified could not be found.  C:\Code\Temp\SDK\SDK.csproj
```

The parsing fails early.

### Proposal

When someone attempts to run pack on an SDK-based project, NuGet will fail with the following error:

```console
Error NU5049: The `pack` command for SDK-style projects is not supported, use `dotnet pack` to pack this project instead. You may set the ENABLE_LEGACY_NUGETEXE_CSPROJ_PACK environment variable to revert to the previous packing behavior.
```

This *breaking change* will be announced via blog well before the NuGet.exe carrying the change ships.

### Technical explanation

As described above, whenever there's no SDK installed, there's simply no accurate way for NuGet to detect that a project is SDK-based.
We can do some XML parsing, but it is likely to be error prone. `NuGet.exe pack` is not the only command that will fail, so the customer will likely figure out that they need to install the .NET SDK. After that the same scenarios with the installed .NET SDK will follow.

To determine whether a project is `.NET SDK` based, we will evaluate the project (part of the normal pack operation), and check for the `UsingMicrosoftNETSDK` property being set. If the property is set, then the project is presumed to be .NET SDK based and will be blocked from packing.

## Drawbacks

- The proposal here would be `breaking` for customers, but it's more than likely that the scenario for which they used nuget.exe pack on an SDK based project never worked correctly.

## Rationale and alternatives

- Do nothing. This would mean just acknowledging that SDK-based projects support in NuGet.exe would not be added and not do anything to help migrate users to `dotnet.exe pack` and `msbuild /t:pack`.
- Add full pack SDK support into NuGet.exe. While not impossible, this creates maintainability considerations. dotnet.exe has a more involved support for the SDK-based PackageReference projects, and as such is considered to be the `right tool for the job`.
- Call `msbuild /t:pack` from NuGet.exe. This has the same considerations as the previos approach that `dotnet.exe` should be recommended as the right tool for the job.
This is also likely to quietly change the behavior for certain users and change the type of package they're generating.
A change like this likely has a lot more merit in 2018, than 2022 given how long dotnet.exe has been the recommended tool for SDK based projects..
- Add a warning and proceed packing.
  - A behavior change to an error in a minor version can be considered disruptive. This is one of those special cases where the disruption might be warranted.
  Instead of an error, we could add a warning instead. Given that NuGet.exe pack by default will usually raise a bunch of warnings, it is likely that if warnings were good enough, the customers would have reviewed said warnings and figured out that all those warnings cannot be addressed correctly.
- Add an information message and proceed warning. Given that the information this tool is not the right one for the job is critical, this is not likely to move the needle enough.

## Prior Art

N/A

## Unresolved Questions

## Future Possibilities

- We can consider *warning* or *erroring* when `NuGet.exe pack` is being used on csproj PackageReference projects. Given that you need to undergo a manual migration to PackageReference, this isn't likely to be a priority scenario.
