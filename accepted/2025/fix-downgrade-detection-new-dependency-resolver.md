# Fix downgrade detection in `DependencyGraphResolver` for direct dependencies with `CentralPackageTransitivePinningEnabled`

- [Jeff Kluge](https://github.com/jeffkl)
- [#14737: New dependency resolver can miss detecting downgrade](https://github.com/NuGet/Home/issues/14737)

## Summary

The new dependency resolver (`DependencyGraphResolver`) can miss detecting package downgrades when `CentralPackageTransitivePinningEnabled` is enabled and a package is both a direct dependency and a transitive requirement at a higher version.
The fix ensures that a package with a direct `PackageReference` in the project is not exempt from downgrade detection, even when `CentralPackageTransitivePinningEnabled` is `true`.

## Motivation

When using Central Package Management (CPM) with `CentralPackageTransitivePinningEnabled=true`, users may inadvertently specify a lower version of a package as a direct dependency than what is required by a transitive dependency.
The new `DependencyGraphResolver` silently resolves to the lower version without raising the expected downgrade error.

The legacy dependency resolver correctly detects this as a downgrade and raises an error:

```
Detected package downgrade: System.ClientModel from 1.8.0 to 1.0.0. Reference the package directly from the project to select a different version.
  ClassLibrary1 -> Azure.Core 1.50.0 -> System.ClientModel (>= 1.8.0)
  ClassLibrary1 -> System.ClientModel (>= 1.0.0)
```

Users are forced to opt out of the new resolver with `RestoreUseLegacyDependencyResolver=true` to get the correct behavior.
Without downgrade detection, users can silently end up with a version of a package that does not satisfy the requirements of their dependencies, potentially causing build or runtime failures.

## Explanation

### Functional explanation

Consider the following setup:

**`ClassLibrary1.csproj`**
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Azure.Core" />
    <PackageReference Include="System.ClientModel" />
  </ItemGroup>
</Project>
```

**`Directory.Packages.props`**
```xml
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    <CentralPackageTransitivePinningEnabled>true</CentralPackageTransitivePinningEnabled>
  </PropertyGroup>
  <ItemGroup>
    <PackageVersion Include="Azure.Core" Version="1.50.0" />
    <PackageVersion Include="System.ClientModel" Version="1.0.0" />
  </ItemGroup>
</Project>
```

`Azure.Core 1.50.0` depends on `System.ClientModel >= 1.8.0`.
`System.ClientModel` is also referenced directly at version `1.0.0`.
Since `1.0.0 < 1.8.0`, this is a downgrade and should be detected as an error.

With the new `DependencyGraphResolver`, this downgrade is not detected.
The fix ensures the error is raised so users are aware they need to update their central version to at least `1.8.0`.

### Technical explanation

When `CentralPackageTransitivePinningEnabled=true`, the `DependencyGraphResolver` may treat packages listed in `Directory.Packages.props` as centrally-pinned and exempt them from the standard downgrade detection logic.

The root cause is that the resolver does not distinguish between:

1. A package that is **only** transitively pinned via a `PackageVersion` entry (i.e., not directly referenced), which is legitimately centrally managed.
2. A package that has an **explicit** `PackageReference` in the project, which is a direct dependency.

A direct dependency—one with a `PackageReference` in the project file—is **not** a transitively pinned package.
For a direct dependency, the downgrade detection must be applied regardless of whether `CentralPackageTransitivePinningEnabled` is `true`.

The fix in `DependencyGraphResolver` is to check whether the resolved package has a direct `PackageReference` in the project.
If it does, the package must not be exempt from downgrade detection.
When the resolved version (from the direct dependency) is lower than the minimum version required by a transitive dependency, a downgrade error must be raised.

## Drawbacks

This change restores behavior that already exists in the legacy dependency resolver, so there are no new drawbacks.
Projects that were silently using a downgraded version will begin to see a restore error, which is the correct behavior.

## Rationale and alternatives

- **Do nothing**: Users must continue using `RestoreUseLegacyDependencyResolver=true` to detect downgrades, which defeats the purpose of the new resolver.
- **Warn instead of error**: A warning could be raised instead of an error, but since a downgrade may result in a broken build or runtime failure, an error is the appropriate severity level, consistent with the legacy resolver behavior.

The correct fix is to apply the same downgrade detection logic in `DependencyGraphResolver` that the legacy resolver already uses for direct dependencies.

## Prior Art

The legacy dependency resolver (`LegacyPackageReferenceProject`) correctly detects this downgrade and raises an error with the message:

```
Detected package downgrade: {packageId} from {higherVersion} to {lowerVersion}. Reference the package directly from the project to select a different version.
```

This behavior should be preserved in `DependencyGraphResolver`.

## Unresolved Questions

None.

## Future Possibilities

None.
