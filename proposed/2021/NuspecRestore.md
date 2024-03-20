# Title

- Author Name [Volodymyr Shkolka @(BlackGad)](https://github.com/BlackGad) 
- Start Date (2021-05-27)
- GitHub Issue (https://github.com/NuGet/Home/issues/10793)
- GitHub PR (https://github.com/NuGet/Home/pull/10899)

## Summary

Add ability to restore symbols from snupkg packages in same way as generic nupkg do.

## Motivation 

We need to simplify debugging process for applications which are used NuGet packaging.

## Explanation

### Functional explanation

[NuGet package management](https://en.wikipedia.org/wiki/NuGet) is a standart way for your code distribution. [In a few clicks](https://docs.microsoft.com/en-us/nuget/create-packages/overview-and-workflow) you can pack `nupkg` package with your brand new framework which solves everything in the world (at least it may try to do this) and share it to others.

Your framework working hard as the part of other products. And, of course, some of users cannot link their simple logic with your API. The easiest way to figure it out whats wrong is to debug code line by line with end user data. 

For proper debugging you need to provide [debug symbols](https://en.wikipedia.org/wiki/Debug_symbol). Call NuGet framework with [symbols packaging feature](https://docs.microsoft.com/en-us/nuget/create-packages/symbol-packages-snupkg) to rescue. Few more clicks and your symbols will be packed into separate `snupkg` package. 

With general `nupkg` and symbols `snupkg` packages end user is able to fulfil debugger with all required information.

#### Detailed instruction for the end user:
- Place general `nupkg` and symbols `snupkg` packages into discovarable feed ([local](https://docs.microsoft.com/en-us/nuget/hosting-packages/local-feeds) or any remote one). **Note**: `nupkg` can be located in one feed and `snupkg` in another but their id and version must be identical.
- Install ([nuget.exe install -Symbols](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-install), [dotnet add package --symbols](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-add-package?tabs=netcore2x)) or restore ([nuget.exe restore -Symbols](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-restore), [dotnet restore --symbols](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-restore)) NuGet package.
- Make sure your debugger consumed all required data.

Now end user can debug 3th party code line by line and finally close tone of its own issues :)

### Technical explanation

#### Things to add
Options that will **force** to restore `snupkg` as well as `nupkg`.
1. New `-Symbols` option to [nuget.exe restore](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-restore) command that will force to restore all available symbols for all installed packages.
2. New `-Symbols` option to [nuget.exe install](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-install) command will force to restore specific package symbols.
3. New `--symbols` option to [dotnet restore](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-restore) command that will force to restore all available symbols for all installed packages.
4. New `--symbols` option to [dotnet add package](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-add-package?tabs=netcore2x) command will force to restore specific package symbols.

**Optionally**: For proper integration into real project - symbols restore configuration can be placed in new file (similar to *nuget.config* for example *nuget.config.user*) on solution level. It is crucial to have ability to exclude it from subversion.
    
Inside Visual Studio in the **NuGet Package Manager** on **Installed** tab for every package add option for **symbols** install as well (configuration placed in *nuget.config.user*). Built-in **Restore** mechanism will respect this option in same way as common package miss situation.

#### As a result
[nuget.exe restore](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-restore) and [dotnet restore](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-restore) commands will do their job with symbols restore option only for configured packages.

Based on source project version above commands will:
1. For any project structure will download and place **package** and **symbols** content into the cache folders (if cache allowed). Default place for package content is `c:\Users\<user>\.nuget\packages\`. Default place for symbols content may be `c:\Users\<user>\.nuget\symbols\`.
2. In old project structure will merge **package** and **symbols** content into destination **packages** folder (in reverse to split pack operation).
3. In new project structure will do same the operation if **packages** folder set in `nuget.config` file.

Further symbols transport will be handled by **MSBuild**. In old project structure symbols will be copied as assembly satellites to output folder and in new project structure this action will be handled by `PackageReference` (copy satellites from external **packages** folder or gather assemblies and symbols from the cache).

Also it is important to implement symbols discovery operation in registries independent from package registries. This will allow to place `snupkg` files in local NuGet folder (local file based registry). 

**Hint**: Generic approach for **Visual Studio** is to use symbols from only one of [three places](https://docs.microsoft.com/en-us/visualstudio/debugger/specify-symbol-dot-pdb-and-source-files-in-the-visual-studio-debugger?view=vs-2019#symbol-file-locations-and-loading-behavior):
- The location that is specified inside the DLL or the executable (.exe) file.
- The same folder as the DLL or .exe file. (**We want to reuse this ability**)
- Debugger options for symbol files. (Implemented by official NuGet.org after `snupkg` file upload)

Because `snupkg` technically is the same `nupkg` but with limited content and limited metadata all internal code for the restoration and security can be reused. 

## Drawbacks

From my point of view this feature is missed part from the very beginning. Split package into assemblies and symbols and merge them back is atomic functionality. Split was implemented merge was not.

## Rationale and alternatives

### Pack symbols into generic package

For older projects you can pack `pdb` files into generic package. As a result your package size will be huge.

### Symbols server

Public feeds can provide [symbols server](https://docs.microsoft.com/en-us/windows/win32/dxtecharts/debugging-with-symbols) based on `snupkg` package on upload via well known entry
```json
{
  "version": "3.0.0",
  "resources": [
   {
      "@id": "https://www.nuget.org/api/v2/symbolpackage",
      "@type": "SymbolPackagePublish/4.9.0",
      "comment": "The gallery symbol publish endpoint."
    }
  ]
}
```

It is require additional feeds backend implementation.

### Manual

User can unpack `snupkg` as zip archive and manually place `pdb` files near the assemblies.

## Prior Art

Similar solutions:
- [Ubuntu Debug Symbol Packages](https://wiki.ubuntu.com/Debug%20Symbol%20Packages)
- [Opensuse debug info](https://old-en.opensuse.org/Packaging/Debuginfo)
- [MacOs Sentry's SDK](https://docs.sentry.io/platforms/apple/guides/macos/dsym/)

## Unresolved Questions

- New project structure uses `PackageReference` items. And they currently do not support [satellite files](https://github.com/NuGet/Home/issues/5926) distribution.
- NuGet feed v3 index has proper `publish` symbols endpoint but [have no](https://github.com/NuGet/Home/issues/10793#issuecomment-826388332) `download` version.
- Visual Studio integration

## Future Possibilities

This is basically first stop on the long road to resolving target issue https://github.com/NuGet/Home/issues/6579.
