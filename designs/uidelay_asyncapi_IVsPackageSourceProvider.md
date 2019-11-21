# UI Delay during ISettings initialization

* Status: **Draft**
* Author(s): [Kartheek Penagamuri](https://github.com/kartheekp-ms)

## Issue

[8675](https://github.com/nuget/home/issues/8675) - UI delay while initializing NuGet.Configuration.ISettings type

## Problem Background

VS IDE customers are experiencing UI Delays when NuGet tries to initialize [`NuGet.Configuration.ISettings`](https://github.com/NuGet/NuGet.Client/blob/0c59e87628fbcbd158162ebb61638ce20e0dc75c/src/NuGet.Clients/NuGet.PackageManagement.VisualStudio/IDE/ExtensibleSourceRepositoryProvider.cs#L63) (Lazy type) in constructor of [`VsPackageSourceProvider`](https://github.com/NuGet/NuGet.Client/blob/0c59e87628fbcbd158162ebb61638ce20e0dc75c/src/NuGet.Clients/NuGet.VisualStudio.Implementation/Extensibility/VsPackageSourceProvider.cs#L25) type on the main UI thread.

## Who are the customers

All VS IDE customers

## Solution

[Andrew Arnott](https://github.com/AArnott) mentioned following important points in an offline conversation.
* MEF parts are not supposed to have any thread affinity, so moving the realization of exports (all the disk I/O from assembly loads, JIT time) and other non-UI code to a background thread could dramatically reduce the UI delay.
* Moving the heavyweight code that’s in the MEF activation path out of that path and into other methods that can be made asynchronous.

### Short-Term solution

* As per [this](https://github.com/NuGet/NuGet.Client/blob/ba2a72ac9afd9e7260798a6ad14088297570b350/src/NuGet.Clients/NuGet.VisualStudio/Extensibility/IVsPackageSourceProvider.cs#L23) remark, it is not required to invoke `IVsPackageSourceProvider` API on UI thread. Modify Roslyn implementation to call NuGet API on a background thread. NuGet can switch to main thread within the context of JTF as and when required.

### Long-Term solution

* WIP

## Implementation
