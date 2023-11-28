# Title

- Author Name [Matthias Koch (@matkoch)](https://github.com/matkoch)
- Start Date 2021-04-21
- GitHub Issue https://github.com/NuGet/Home/issues/10784
- GitHub PR https://github.com/NuGet/Home/pull/10782
- Status: Implemented

## Summary

Add package installation instructions for using .NET tools with NUKE.

## Motivation

Conventionally, users add references to packages using the common `PackageReference` approach. This has two downsides: Firstly, it doesn't allow to reference multiple versions. Secondly, it sometimes breaks the build project, when packages ship more than just the `./tools` folder. This has been the case for `DocFX` for instance.

The command helps developers to add a NuGet package in the _right_ way. So I personally expect less confusion on their side, and as a nice bonus it will also teach more folks about the existence of the `PackageDownload` feature.

## Explanation

### Functional explanation

NUKE ships with a lot wrapper APIs for third-party tools, like `ReportGenerator`, `GitVersion.Tool` and many more. These APIs are available, but could fail at runtime, because the required package is not referenced. When I want to use the `ReportGeneratorTasks` for instance, I may head over to NuGet.org, check what particular version I need, copy the command, and execute it in my terminal from whereever I am. It doesn't have to be the build project directory. The command can be used repository-wide, as there is only one build project.

### Technical explanation

There are no technical details for NuGet other that we might need to set a `NUGET_USER_AGENT` or similar.

On our side, the command simply adds the `PackageReference` item to the `csproj` file using `Microsoft.Build` infrastructure, and then performs a `dotnet restore` on the build project which triggers the download to the global NuGet cache. It is only converted to `PackageDownload` if the package contains a `./tools` directory.

## Drawbacks

NUKE is not strictly a NuGet package manager. The instructions however _are_ useful for package consumers.

## Rationale and alternatives

The alternative is to provide a `dotnet packagedownload` command. However, this command might be confusing in relation to the existing `dotnet package` command. Also, even compared to this hypothetical command, `nuke :add-package` covers a broader range, since it can be called from any directory in the repository, and the command will know where to add the `PackageDownload`.

## Prior Art

The Paket team successfully pioneered adding a new tab. The Cake team has successfully pushed [their proposal](https://github.com/NuGet/NuGetGallery/issues/8381). As I already mentioned in the issue, I'm not particularly fond of showing installation instructions for build-irrelevant packages. In any case, I'm limiting my proposal to packages with `DotnetTool` as a `packageType`. For everything else, i.e. `PackageReference`, the IDE capabilities should suffice.

## Unresolved Questions

If the NuGet team needs usage statistics, we would need to allow setting the `User-Agent` from outside the dotnet CLI process. NUKE uses a minimal bootstrapping and native tooling with the benefit of having less places that could potentially break.

## Future Possibilities

I'm looking forward for the NuGet team to add more metadata to packages. This way we might also show the instructions for packages that have a `./tools` folder.

One more future possibility unrelated to NuGet, is that we may add a `nuke :update-packages` command or similar.

