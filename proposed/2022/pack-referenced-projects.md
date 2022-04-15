# Pack referenced projects

- Author Name [maxkoshevoi](https://github.com/maxkoshevoi)
- Start Date (2022-03-28)
- GitHub Issue [3891](https://github.com/NuGet/Home/issues/3891)
- GitHub PR (-)

## Summary

Allow referenced projects' artifacts to be packed inside the NuGet.

## Motivation

When SDK-style project is being packed as a NuGet, all projects that it references are considered as NuGet themselves that this NuGet depends on.
This is not always a desired behavior, sometimes user needs artifacts from referenced project(s) to be packed into the NuGet.
Currently there's no easy way to override this behavior except for ditching `csproj`, and going back to `nuspec`. In many cases that involves piping lots of information from the `MSBuild` context into the `nuspec` evaluation via `key=value` parameters.  
Chaining together dozens of arguments to achieve parity with metadata usually automagically introduced by the SDK becomes tedious, which eventually weakens the otherwise rich set of information attached to a modern NuGet package.

## Explanation

### Functional explanation

Proposed solution is to add new `Pack` and `PackagePath` properties to `ProjectReference` (`<ProjectReference Include="..." Pack="True" PackagePath="tools" />`) and `PackageReference`. 
If `Pack` is `False` or not present - consider the project (or package) as a NuGet's dependency, if it's `True` - pack its artifacts in.
If `PackagePath` is not present - pack artifacts to the default location within the package. If it's present - pack them to the specified path.

For `PackageReference`s it's useful in case referenced package is from private feed, but NuGet that's being packed will be public.

### Technical explanation

When NuGet is being created from `csproj` file:

1) If `ProjectReference` doesn't have `Pack` property, or has it set to `False` - preserve behavior that have existed before introduction of this feature (don't include artifacts of referenced projects into the NuGet, and consider them as NuGet-dependencies).
2) If `ProjectReference` has `Pack` property and it's set to `True` - include it's artifacts into the NuGet.
3) Do the same steps for `PackageReference`s

## Drawbacks

None

## Rationale and alternatives

- Use `IsPackable` property from referenced project to determine it it's supposed to be packed or be a NuGet dependency.

It will be more automated, but won't fit some edge cases (also it will be a breaking change). And it isn't applicable to `PackageReferences`.

- Introduce new project-wide `PackReferencedProjects` property that would switch pack behavior for all `ProjectReference`s inside a single project.

This one is less flexible since it cannot switch on per-`ProjectReference` basis. And it isn't applicable to `PackageReferences`.

- Another solution is to introduce a `IncludeReferencedProjects` switch for `nuget` CLI.

Downsides are: Behavior of individual projects (if packing is performed in bulk) and `ProjectReference`s cannot be changed, and it's not obvious how to properly pack any specific project (I thought we are consolidating all the information in `csproj` now). And it isn't applicable to `PackageReferences`.

## Prior Art

This design flaw have been a pain for the community for more than 5 years now. It was such an issue that even third party solution was created - [nugetizer](https://github.com/devlooped/nugetizer).

I haven't used it, so don't have much to comment here, but community clearly [expressed a desire for out of the box solution](https://github.com/NuGet/Home/issues/3891#issuecomment-1080044314).

## Unresolved Questions

- **How do we flow/assign TFM based `lib`/`content` items?** (Is `PackagePath` a desired parameter?)
- **How is conflict resolution going to work with consumers taking in a dependency already present in the bundle?**
- Should license flow/validation be considered right from the start?
- **Should a `PackageReference` or `ProjectReference` tagged with `Pack="true"` be resolved transitively?**
- What happens to NuGets that are referenced in `PackageReference` tagged with `Pack="true"`? Do they become dependencies of the resulting NuGet or being packed into it.

## Future Possibilities

This proposal would allow users more flexibility in choosing what is being packed as part of a NuGet, and how it's dependencies look like.
