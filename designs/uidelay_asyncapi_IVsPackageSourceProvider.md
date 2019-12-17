# UI Delay during ISettings initialization

* Status: **Draft**
* Author(s): [Kartheek Penagamuri](https://github.com/kartheekp-ms)

## Issue

[8675](https://github.com/nuget/home/issues/8675) - UI delay while instantiation of NuGet.Configuration.ISettings type

## Problem Background

VS IDE customers are experiencing UI Delays when NuGet tries to initialize [`NuGet.Configuration.ISettings`](https://github.com/NuGet/NuGet.Client/blob/0c59e87628fbcbd158162ebb61638ce20e0dc75c/src/NuGet.Clients/NuGet.PackageManagement.VisualStudio/IDE/ExtensibleSourceRepositoryProvider.cs#L63) (Lazy type) in constructor of [`VsPackageSourceProvider`](https://github.com/NuGet/NuGet.Client/blob/0c59e87628fbcbd158162ebb61638ce20e0dc75c/src/NuGet.Clients/NuGet.VisualStudio.Implementation/Extensibility/VsPackageSourceProvider.cs#L25) type on the main UI thread. As per the ETL trace, this UI delay is due to realization of exports(all the disk I/O from assembly loads, JIT time) on the main thread.

## Who are the customers

All VS IDE customers

## Solution

[Andrew Arnott](https://github.com/AArnott) mentioned following important points in an offline conversation.
* MEF parts are not supposed to have any thread affinity, so moving the realization of exports (all the disk I/O from assembly loads, JIT time) and other non-UI code to a background thread could dramatically reduce the UI delay.
* Moving the heavyweight code that’s in the MEF activation path out of that path and into other methods that can be made asynchronous.

### Solution

* Partner teams can request MEF exports from a background thread so any I/O is not blocking the main thread.

* Create a new async version of [`IVsPackageSourceProvider`](https://docs.microsoft.com/en-us/nuget/visual-studio-extensibility/nuget-api-in-visual-studio#ivspackagesourceprovider-interface) interface. Modify [`VsPackageSourceProvider`](https://github.com/NuGet/NuGet.Client/blob/0c59e87628fbcbd158162ebb61638ce20e0dc75c/src/NuGet.Clients/NuGet.VisualStudio.Implementation/Extensibility/VsPackageSourceProvider.cs) to implement new async interface. Goal is to make `IVsPackageSourceProvider` interface implementation free threaded and NuGet can switch to main thread within the context of JTF as and when required.

```cs
public interface IVsAsyncPackageSourceProvider
{
    /// <summary>
    /// Provides the list of package sources.
    /// </summary>
    /// <param name="includeUnOfficial">Unofficial sources will be included in the results</param>
    /// <param name="includeDisabled">Disabled sources will be included in the results</param>
    /// <returns>The task object representing the asynchronous operation. Key: source name Value: source URI</returns>
    Task<IEnumerable<KeyValuePair<string, string>>> GetSourcesAsync(bool includeUnOfficial, bool includeDisabled);

    /// <summary>
    /// Raised when sources are added, removed, disabled, or modified.
    /// </summary>
    event AsyncEventHandler SourcesChanged;
}
```
* Partner teams such as Roslyn can consider using [`AsyncLazy<T>`](https://docs.microsoft.com/en-us/dotnet/api/microsoft.visualstudio.threading.asynclazy-1?view=visualstudiosdk-2019#methods) API to lazy intialize `IVsAsyncPackageSourceProvider` implementation in asynchronous way.