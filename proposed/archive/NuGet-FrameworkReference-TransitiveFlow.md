# FrameworkReference in NuGet

* Status: **Implemented**
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)

## Issue

[7342](https://github.com/NuGet/Home/issues/7988) - FrameworkReference Transitive flow

## Background

When designing the original `FrameworkReference` NuGet experience, one scenario was not well understood. 
The SDK really has a concept of `base` FrameworkReference such as a netcoreapp & a netstandard FrameworkReference. 
This throws a wrench into the current design as there are no ways to exclude `FrameworkReference` from flowing transitively through restore. 
It also complicates the `compatibility` scenario from netstandard to the netcoreapp framework family.
We need to rethink https://github.com/NuGet/Home/wiki/%5BSpec%5D-FrameworkReference-in-NuGet#what-happens-in-the-future-ifwhen-frameworkreference-are-added-to-other-frameworks. 


## Who are the customers

All .NET Core customers.

## Requirements

* FrameworkReferences such as the base netcoreapp and netstandard references need a way to be suppressed transitively.  

## Solution

There are 2 directions this solution can go in. 
* FrameworkReference attributes
* Different item for the base framework reference. 

## FrameworkReference attribute

Currently the `Pack` attribute is used to specify whether the framework reference gets packed into the package. 
Some suggestions regarding the approach here were: 

* Pack is respected by restore
    * This is confusing, and we still have the flexibility to come up with a better approach.
* Private attribute instead of pack
    * There are other usages of this attribute name like CopyLocal. 
    * A new NuGet name.
* PrivateAssets attribute
    * Already known attribute used with PackageReference
    * Confusing since the only options  are `all` and `none`.

Currently the proposed approach is PrivateAssets, `all` and `none`. 
This is not something that will be user facing, so the risk is more minimal. 

## Different FrameworkReference item for *base* framework references

This does negate the need for an attribute controlling the transitive flow for the optional FrameworkReference items.
However it does ensure that unwanted framework references are never written in the assets file or packages.
This does not have any additional concerns since the SDK reads the FrameworkReference items for the current project directly through MSBuild and not going through NuGet. 
This also allows for a seamless implementation of the transitive flow for optional framework references if/when are added.
Finally, the base and optional framework references are similar, but ultimately different concepts, and should be represented as such to avoid future confusion. 

## Pack scenarios

The NuGet.Build.Tasks.Pack will consider the FrameworkReference item and pack accordingly.
The packing of a specific FrameworkReference can also be disabled by specifying `PrivateAssets="all"`.
The default will be `none`. 

```xml
<FrameworkReference Include="Microsoft.NetCore.App" PrivateAssets="all"/>
```

The nuspec pack will work similarly, validating the standard target framework validation.

### Validation

NuGet will treat the framework references as case insensitive strings. NuGet will not do any further validation during pack or restore.

The SDK will handle `not applicable` FrameworkReference errors. [Task](https://github.com/dotnet/sdk/issues/3011)

## Considerations

### What happens in the future if/when FrameworkReference are added to other frameworks

Would there be *framework* specific *FrameworkReference*s? Notable that cross framework family transitivity is not an issue because .NET Core is not a dependant of any framework family in the frameworks matrix.
Say .NET Standard becomes non monolithic and we add optional shared frameworks such as WPF. Every implementer will need to support the shared frameworks that the standard declares. The scenario becomes more complex when the frameworks in question are not the standard + implementer. And while there’s no plans for this changing it’s worth considering now so if needed we can account for it early.