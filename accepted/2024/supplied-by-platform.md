# ***Pruning platform provided packages***

- Nikolche Kolev <https://github.com/nkolev92>
- [7344](https://github.com/NuGet/Home/issues/7344)

## Summary

<!-- One-paragraph description of the proposal. -->

## Motivation

In the early versions of .NET (Core), individual assemblies from the runtime were shipped as packages.
Starting with .NET (Core) 3.0, targeting packs were used for delivering references assemblies. The reference assemblies are no longer represented in graphs the way Microsoft.NETCore.App, Microsoft.AspNetCore.App, and NETStandard.Library were.
When a .NET (Core) 3.0 or later project depends on these older platform packages, we want them to be ignored in the graph, as those APIs are supplied by the platform via other mechanisms, such as targeting packs at build time and runtime packs for self-contained deployments.

Even .NET 9, there are certain assemblies that ship as both packages, but are also part of certain shared frameworks such as ASP.NET. See details <https://github.com/dotnet/aspnetcore/issues/3609>. An example of such assembly/package is `Microsoft.Extensions.Logging`, which is [published on nuget.org](https://www.nuget.org/packages/Microsoft.Extensions.Logging/), but also part of the Microsoft.AspNetCore.App shared framework. Currently there's conflict resolution in the .NET SDK to ensure that the latest version is chosen.

There are a few benefits:

It is trivial to make the assumption that the fewer packages need to be downloaded, the better the performance will be.
Beyond that, the extra packages within the graph, do make the resolution step more challenging. Some of the targeting packs used to bring in such a large package graph, that affected the resolution performance significantly. See  and <https://github.com/NuGet/Home/issues/11993> for more details. Furthermore, certain versions of popular packages have taken dependencies on these targeting packs for historical reasons. Such an example is <https://www.nuget.org/packages/log4net/2.0.10> which performs significantly better than <https://www.nuget.org/packages/log4net/2.0.9> when installed in a .NET (Core) projects, see <https://github.com/NuGet/Home/issues/10030>.

Certain versions of these packages are no longer  part of the project graph, thus reducing the chances of false positive scanning.
This is especially important in the context of assemblies that are part of shared frameworks. The build time conflict resolution ensures that the most up to date version is used, despite the fact that the user referenced package may habe vulnerabilities.
Examples: <https://github.com/dotnet/sdk/issues/30659#issuecomment-2072567192>.

This changes significantly helps align what gets restored and what gets published. By avoiding packages that are simply not going to be used at runtime, what gets used at runtime becomes more transparent.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

## References

- <https://github.com/NuGet/Home/issues/3541> - NuGet claims downgrades (NU1605) for packages brought in through lineup
- <https://github.com/NuGet/Home/issues/8087> - NuGet Package Vulnerability Auditing