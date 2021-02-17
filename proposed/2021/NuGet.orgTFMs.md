# NuGet Target Frameworks on Package Details Page 

- Author Name (https://github.com/jcjiang)
- Start Date (2021-02-16)
- GitHub Issue (https://github.com/NuGet/NuGetGallery/issues/8387)
- GitHub PR ()

## Summary

When a developer opens the package details page or tab on NuGet.org or NuGet rooling, they will see what frameworks the package can support. 

## Motivation

### Problem: What problem is this solving? 

Developers cannot use the package details page to determine what frameworks a NuGet package can support. In 2021, we live in a world where there are three evolutions of .NET coexisting on NuGet; .NET Framework, .NET Core, and .NET 5.  

Developers should be able to determine whether a package works for their project without having to first download it or rely on the author’s documentation. 

### Why: How do we know this is a real problem and worth solving? 

Finding a package that is compatible with your project is a challenge for the average developer in the .NET ecosystem. Over 21% of developers fail to install a package today. One of the top NuGet errors issued in telemetry is [NU1202](https://docs.microsoft.com/en-us/nuget/reference/errors-and-warnings/nu1202), which shows that we allow developers to install packages that are not compatible with their project or solution’s target framework. 

### Success: How do we know if we’ve solved this problem? 

- By measuring the change in the percentage of successful installs and lowering the amount of [NU1202](https://docs.microsoft.com/en-us/nuget/reference/errors-and-warnings/nu1202) errors in telemetry. 
- By measuring the usage of target framework & supported platform filters on NuGet.org & Visual Studio. 
- By gauging excitement/disappointment after blogging about this feature & analyzing sentiment on Twitter/GitHub/DevCom/etc. 

### Audience: Who are we building for? 

We are building this for the .NET developer who is browsing & making decisions about including a NuGet package into their project based on target framework & supported platform criteria. 

## Explanation

### Functional Explanation

#### Context and Scope 
When a developer accesses the details page for a NuGet package, they will see information on target frameworks in a dropdown menu. The framework information will be surfaced from the package. In cases where versions are not specified (such as .net) or other unexpected scenarios, ‘Version Not Specified’ or similar messages will be surfaced. 

##### Minimal Requirements 
- List of Frameworks on NuGet.org

##### Non-Requirements 
- List of Platforms on NuGet.org
  - Users interviewed did not express need for supported platform information 
  - Cannot be surfaced directly from package data and would require additional layer of soft calculation from engineering (no clear mapping scheme currently exists between target frameworks and supported platforms) 
  - Can be revisited in future 
- Filters for Frameworks on NuGet.org
    - Users interviewed were ambivalent on filters, requires further investigation. Can be revisited in future 
- Filters for Platforms on NuGet.org
  - Users interviewed were ambivalent on filters, requires further investigation. Can be revisited in future 

Although Target Frameworks & Supported Platforms are relatively similar in general contexts and often have overlap, we must clearly define each of these items based on their differences. Today we live in an ecosystem where Target Frameworks can represent both a supported platform, or a subset of supported platforms. 

**Target Framework** – A target framework is a specification of the APIs available to an application or library. 

Example: .NET Framework, .NET Core, .NET Standard, .NET 5 are target frameworks. 

**Supported Platform** – A supported platform is a target that the APIs can be ran on. 

Example: iOS, Android, Windows are platforms. 

### Solution 

- A .NET developer can view Frameworks of a package on NuGet.org: 
![](../../meta/resources/NuGet.orgTFMs/PackageDetailsWithTFMs.png)

### Goals and Non-Goals 

#### Goals 

Make it clear to developers whether a package can be installed or updated for their project or solution based on a target framework. 

#### Non-Goals 

Over-complicate what it means to be a compatible package. One target framework + one target platform = compatible package. 

### Design 

#### Target Framework List 

- .NET Framework (net) 
- Xamarin/Mono (monoandroid, monotouch, xamarinios, monomac, xamarinmac, xamarinwatchos, xamarintvos) 
- .NET Core (netcoreapp) 
- .NET Standard (netstandard) 
- .NET 5 (net5.0) 

### Technical Explanation

Packages whose layout follow our [guidelines](https://docs.microsoft.com/en-us/nuget/create-packages/supporting-multiple-target-frameworks) will be examined when uploaded and validated, prior to listing. Target Frameworks will be determined and displayed here.

Note that packages which do not follow the guidelines may have inconsistent results.

### Unresolved questions
- Will the "Frameworks" section be expanded by default? Should the "Frameworks" section explain how the customer should use this information? Should we add a link to docs? Consider moving up the "Frameworks" section. I would suggest "Documentation" first, followed by "Frameworks". The "Version History" table is noisy and it can be difficult to see what's below it. The "Dependencies" and "Used By" sections are useful information, but would claim "Frameworks" is more important.