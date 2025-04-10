* Status: **Reviewed**
* Author(s): [Karan Nandwani](https://github.com/karann-msft) ([@karann9](https://twitter.com/karann9))

## Issue
The work for this feature and the discussion around the spec is tracked by 3 issues
* Icon - **Package Icon should be able to come from inside the package [#352](https://github.com/NuGet/Home/issues/352)**
* License - **Package trust - Licenses [#4628](https://github.com/NuGet/Home/issues/4628)**
* Documentation - **Nuspec - documentation / readme url [#6873](https://github.com/NuGet/Home/issues/6873)**

## Problem
* Icons - package authors are required to find a place to host an image, only to point to it for the package icon. Additionally, loading images from external URLs have potential security and privacy concerns for package consumers.
* License -  it is possible to update the page contents at the referred license URL raising legal concerns for package consumers. 
* Documentation - it is not possible for package authors to update the documentation on the package details page without going to NuGet.org. This information is not surfaced in Visual Studio to package consumers.

## Who is the customer?
* NuGet package consumers that consume packages using Visual Studio package manager UI (VS-PMUI) from NuGet.org (v3 feed) and folder based feeds
* NuGet package authors that push to NuGet.org

## Solution

[Packaging Icon within the nupkg](https://github.com/NuGet/Home/wiki/Packaging-Icon-within-the-nupkg)

[Packaging License within the nupkg](https://github.com/NuGet/Home/wiki/Packaging-License-within-the-nupkg)

[Packaging Documentation within the nupkg](https://github.com/NuGet/Home/wiki/Packaging-Documentation-within-the-nupkg)