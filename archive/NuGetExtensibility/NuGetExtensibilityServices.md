# NuGet extensibility services

* Status: **Reviewed**
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)
* Issue: [8896](https://github.com/NuGet/Home/issues/9062) Guidelines for asynchronous NuGet extensibility services
* Type: Architecture

## Problem Background

NuGet has a set of IVs* APIs such as IVsPackageInstaller, IVsPackageUninstaller, IVsPackageSourceProvider etc.
These APIs were mostly designed and implemented during the Dev12-14 days when packages.config was style of choice.
Nearly all of these APIs are synchronous and are defined in an [embeddable](https://www.nuget.org/packages/NuGet.VisualStudio/) assembly.

According to the VS threading cookbook and [analyzers](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD010.md), most IVs synchronous services have threading requirements and should be invoked on the UI thread.
As such a lot of our customers as a pattern invoke the NuGet APIs from the UI thread.

This leads to a lot of performance and reliability issues with NuGet as the culprit.

Despite being synchronous IVs* some of our APIs can be invoked off the UI thread, but that's not consistently documented.
Given that most of our code is already asynchronous, there's no need why we cannot expose services that are asynchronous.

## Who are the customers

All Visual Studio users will reap the benefits.
The primary users of these new APIs will be extension authors and Visual Studio components like Roslyn.

## Requirements

* Asynchronous and performant NuGet extensibility services
* Ability to invoke these through RPC. These days there are components that are running out of devenv.exe

## Goals

* Define a guideline for designing asynchronous NuGet services
* Introduce a new assembly/package called `NuGet.VisualStudio.Contracts`
* Expose them through an extensibility mechanism to allow out of process invocation

## Non-Goals

* Define the APIs for all the services that will be migrated.

## Solution

All NuGet Visual Studio extensibility APIs should follow the guidelines below.

* The service and interface name should describe what, rather than how. Consider including the name NuGet in the service names. Do not include IVs* in the interface name.
* We will use the Visual Studio service broker to expose our service.
* The RPC contract will be defined as a C# interface.
* Expose the service descriptors through an extension method to help the discoverability of all Visual Studio services.
* All method parameters and return types consist of simple serializable types. No stateful types are allowed.
* Always use readonly collections.
* All methods are async with a mandatory CancellationToken as the last parameter.
* The contract will only be implemented by NuGet. The consumer is *not* allowed to implement the interface themselves. We want to be able to add new methods to the interface without considering that as a breaking change. With this approach, additive changes will not cause any breaking changes.
* RPC services cannot be singletons, so if we want to implement it as such, we need to implement one extra abstraction in our APIs.
* The RPC contract is versioned. We only change the version when making a breaking change to avoid SxS loading.
* Failure cases should be communicated through exceptions. Ensure that those exceptions are serializable.

Given all this, we will create a new assembly.
Currently our extensibility APIs are marked as ComImport for embedding purposes. We won't do that anymore.

* We will define a new contract assembly, NuGet.VisualStudio.Contracts.
* The assembly will version together with the rest of the NuGet components. Meaning this assembly will start for 5.5 or 5.6, because it will make associating the NuGet release easier.
* For performance purposes, we will binding redirect to the current version and use an append only approach to the contract assembly to avoid breaking dependencies.

Example of a Visual Studio contract.

```cs

// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using System;
using System.Threading.Tasks;

namespace NuGet.VisualStudio.Contracts
{
    public interface INuGetPackageInstaller
    {
        Task InstallPackageAsync(
            string source,
            string project,
            string packageId,
            string version,
            CancellationToken cancellationToken);
    }
}
```

We will annotate the Visual Studio Package as below:

```cs
[ProvideBrokeredService("Microsoft.VisualStudio.NuGetPackageInstaller", "1.0", Audience = ServiceAudience.Remote)]
    public sealed partial class NuGetPackage : AsyncPackage, IVsPackageExtensionProvider, IVsPersistSolutionOpts
```

```cs

IBrokeredServiceContainer brokeredServiceContainer = await this.GetServiceAsync<SVsBrokeredServiceContainer, IBrokeredServiceContainer>();
brokeredServiceContainer.Proffer(NuGetPackageInstallerServiceDescriptor, factory: ServicesUtility.GetPackageInstallerServiceFactory());
```

Then in the initialization step of our package we will request the service broker and proffer our service.
Note that each client will get their instance of the proffered service. It cannot be a singleton! Expect that it might be disposed. 

On the client side one would do:

```cs
    IBrokeredServiceContainer brokeredServiceContainer = await this.GetServiceAsync<SVsBrokeredServiceContainer, IBrokeredServiceContainer>();
    Assumes.Present(brokeredServiceContainer);
    IServiceBroker sb = brokeredServiceContainer.GetFullAccessServiceBroker();
    INuGetPackageInstaller client = await sb.GetProxyAsync<INuGetPackageInstaller>(NuGetPackageInstallerServiceDescriptor, this.DisposalToken);
```

### Free threaded services considerations

Performance is always one of the primary considerations.
Whether it's a service we expose for extensibility purposes, or just an internal NuGet bit, we should always strive to write async code, and minimize the UI thread dependencies if at all possible.
If our services do not have any UI thread dependencies in any scenario, then they are [free threaded](https://github.com/microsoft/vs-threading/blob/b680de515d6210c4028598b988187c3aed33aabc/doc/cookbook_vs.md#how-do-i-effectively-verify-that-my-code-is-fully-free-threaded) and should be marked as such, both in the API documentation and in the [VS SDK analyzers](https://github.com/microsoft/VSSDK-Analyzers/blob/b0c5ddf01e137c6c938e9f37806210b9445f814b/src/Microsoft.VisualStudio.SDK.Analyzers.CodeFixes/build/AdditionalFiles/vs-threading.MembersRequiringMainThread.txt) to help customers use the correct calling context.

Keep in mind that lots of our APIs won't need the UI thread unless we are initializing. See [VSPackageSourceProvider](https://github.com/NuGet/NuGet.Client/blob/f64621487c0b454eda4b98af853bf4a528bef72a/src/NuGet.Clients/NuGet.VisualStudio.Implementation/Extensibility/VsPackageSourceProvider.cs) for example. We will only initialize the VSSettings object when required. The VSSettings object might need to do a solution open check. It's super important to understand all scenarios before calling a service free threaded, because it will deadlock!

In general refer to [VS Threading cookbook](https://github.com/microsoft/vs-threading/blob/b680de515d6210c4028598b988187c3aed33aabc/doc/cookbook_vs.md) over anything written in this document about Visual Studio threading.

Refer to [IVsTestingExtension](https://github.com/NuGet/Entropy/tree/5215f3265663bd9c6f1c355b1d3190b803bd9600/IVsTestingExtension) for helpers for testing the threading patterns of your code. It also contains a ASYNC_FREETHREADED_CHECK option.

### Exposing services for discoverability

A boilerplate example for exposing services for discoverability by Visual Studio consumers.

```cs
namespace Microsoft.VisualStudio  // KEEP THIS NAMESPACE
{
    public static class NuGetServices  // CHANGE THIS CLASS NAME
    {
      private static ServiceRpcDescriptor Echo { get; } = new ServiceJsonRpcDescriptor(
        new ServiceMoniker("Microsoft.VisualStudio.Echo", new Version("1.0")),
        ServiceJsonRpcDescriptor.Formatters.UTF8,
        ServiceJsonRpcDescriptor.MessageDelimiters.HttpLikeHeaders);

      /// <summary>
      /// Gets the <see cref="ServiceRpcDescriptor"/> for the echo service.
      /// Use the <see cref="IEcho"/> interface for the client proxy for this service.
      /// </summary>
      public static ServiceRpcDescriptor Echo(this VisualStudioServices.VS2019_5Services svc) => Echo; // CHANGE SERVICE NAME
    }
}
```

### Deprecation of old services

Most of the initial extensibility service work will involve migrating existing services.
The old services should be marked as obsolete when the replacement ones are created.

## Considerations

* **Do not** use ValueTask/ValueTask<TResult> in our extensibility services. ValueTask/ValueTask<TResult> has an advantage of Task/Task<TResult> in that it incurs fewer allocations, but the reality is that our code despite being asynchronous, maybe be invoked from some synchronous code paths. Furthermore, our response will frequently be serialized, defeating the allocation savings from ValueTask/ValueTask<TRest>.
For reference see:
[Understanding the whys whats and whens of valuetask](https://devblogs.microsoft.com/dotnet/understanding-the-whys-whats-and-whens-of-valuetask/
)
Design discussion [issue](https://github.com/dotnet/corefx/issues/27445)
