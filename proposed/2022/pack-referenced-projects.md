# Pack referenced projects

- Author Name (https://github.com/maxkoshevoi)
- Start Date (2022-03-28)
- GitHub Issue (https://github.com/NuGet/Home/issues/3891)
- GitHub PR (-)

## Summary

Allow referenced projects' artifacts to be packed inside the NuGet.

## Motivation

When SDK-style project is being packed as a NuGet, all projects that it references are considered as NuGet themselves that this NuGet depends on.
This is not always a desired behavior, sometimes user needs artifacts from referenced project(s) to be packed into the NuGet.
Currently there's no easy way to override this behavior except for ditching `crproj`, and  going back to `nuspec`, which becomes another source of truth and all that good stuff.

## Explanation

### Functional explanation

Proposed solution is to take into account `IsPackable` property of the referenced projects. If it's `True` or not present (to preserve backward compatibility) - consider the project as a NuGet dependency, if it's `False` - pack its artifacts in.

Second part is introduce new project-wide `PackReferencedProjects` property that would switch pack behavior for all `ProjectReferencees` inside a single project.

This one is so people won't need to remember put `<IsPackable>False</IsPackable>` everywhere (they can use `Directory.Build.props`, but still).

### Technical explanation

When NuGet is being created from `csproj` file:

1) See if `PackReferencedProjects` is defined.
2) If it's and it's value is `False` - preserve behavior that have existed before introduction of this feature (don't include artifacts of referenced projects into the NuGet, and consider them as NuGet-dependencies).
3) If it's and it's value is `True` - include artifacts of referenced projects into the NuGet
4) If it's not defined, look at the `IsPackable` value of each referenced project and use behavior describe on step 2 or 3 according to it.

## Drawbacks

This is a breaking change for projects that have `IsPackable` set to `False`, and are referenced by project that is packed into NuGet.
Currently they are being considered an NuGet-dependency, even though it's not possible to pack them as NuGets.

I cannot think of a single case where existing behavior would be a desirable one for such projects.

On the other hand, there might be projects with `IsPackable` to set `True` (and being distributed as a NuGet), and don't want to be shown as a dependency. But I cannot think of any such case too.

## Rationale and alternatives

- If using `IsPackable` to switch the behavior is too breaking, new `Pack` property could be added to `ProjectReference` instead, so there would be no breaking changes (`<ProjectReference Include="..." Pack="True" />`).

I like this approach less, since it requires introducing another new "thing", while `IsPackable` already exists, and is designed to indicate whether project can be packed as a NuGet or not.
Also if some project is always supposed to be packed into dependent projects' NuGets, it would require to specify `Pack="True"` every time it's referenced.

- Also new project-wide `PackArtifactsIntoDependantProjects` (or something) property can be introduced to be used in this proposal instead of `IsPackable`.

Like this even less, since it's also `another new "thing"`, but it's also really similar to `IsPackable`.

- Another solution is to introduce a `IncludeReferencedProjects` switch for `nuget` CLI.

Downsides are: Behavior of individual projects (if packing is performed in bulk) and `ProjectReferencees` cannot be changed, and it's not obvious how to properly pack any specific project (I thought we are consolidating all the information in `csproj` now)

## Prior Art

This design flaw have been a pain for the community for more than 5 years now. It was such an issue that even third party solution was created - [nugetizer](https://github.com/devlooped/nugetizer).

I haven't used it, so don't have much to comment here, but community clearly [expressed a desire for out of the box solution](https://github.com/NuGet/Home/issues/3891#issuecomment-1080044314).

## Unresolved Questions

Using `IsPackable` for per-`ProjectReference` behavior switching is an open question. It is a breaking change that can be avoided by introducing a new property here or there, but I've yet to see an example of what it would actually break.

## Future Possibilities

This proposal would allow users more flexibility in choosing what is being packed as part of a NuGet, and how it's dependencies look like.
