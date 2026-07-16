# Respect package version constraints in Package Manager UI

- [Martin Ruiz](https://github.com/martinrrm)
- [Adam Stachowicz](https://github.com/Saibamen)
- [NuGet/Home#6566](https://github.com/NuGet/Home/issues/6566)
- [NuGet/NuGet.Client#7323](https://github.com/NuGet/NuGet.Client/pull/7323)

## Summary

Visual Studio Package Manager UI (PM UI) will respect upper-bounded and
floating PackageReference version ranges when finding and applying updates.

Automatic updates will stay inside the authored range. An in-range update will
preserve the range, while setting its lower bound to the selected version when
applicable.

If the customer explicitly selects a concrete version outside the range, PM UI
will replace the range with that minimum-only version. For example:

```text
[8.0.0, 9.0.0) + selected 9.1.0 -> 9.1.0
```

This explicit selection does not require an additional confirmation.

This proposal applies only to PM UI. Package Manager Console,
`dotnet package update`, and other update entry points are outside its scope.
It is intentionally a partial solution to
[NuGet/Home#6566](https://github.com/NuGet/Home/issues/6566).

## Motivation

Customers use upper-bounded ranges to stay on a supported package release
train:

```xml
<PackageReference Include="Contoso.Logging"
                  Version="[8.0.0, 9.0.0)" />
```

Today, PM UI can update the package to an allowed version but replace the range
with a minimum-only version:

```xml
<PackageReference Include="Contoso.Logging" Version="8.0.4" />
```

This silently removes the `9.0.0` ceiling. Customers must then repair the
project file or risk a later update moving to an unintended major version.

PM UI should preserve the boundary for routine in-range updates, while still
allowing a deliberate version selection outside the range.

## Explanation

### Functional explanation

#### Scope

This proposal covers:

- project and solution Package Manager UI;
- top-level PackageReference dependencies (transitive packages do not support `VersionRange`);
- project-local `PackageReference` versions;
- and centrally managed `PackageVersion` versions.

#### In-range selection

For a non-floating upper-bounded range, PM UI sets the lower bound to the
selected version and preserves the original upper bound and inclusivity:

| Before | Selected | After |
| --- | --- | --- |
| `[8.0.0, 9.0.0)` | `8.0.4` | `[8.0.4, 9.0.0)` |
| `(8.0.0, 9.0.0]` | `8.0.4` | `[8.0.4, 9.0.0]` |
| `(, 9.0.0)` | `8.0.4` | `[8.0.4, 9.0.0)` |

The selected version becomes an inclusive lower bound. NuGet can normalize the
range when writing it.

#### Out-of-range selection

Out-of-range versions remain visible in the package details version picker,
but are excluded from automatic Updates tab recommendations.

Selecting a concrete out-of-range version replaces the existing range with the
selected minimum-only version:

| Before | Selected | After |
| --- | --- | --- |
| `[8.0.0, 9.0.0)` | `9.1.0` | `9.1.0` |
| `8.*` | `9.1.0` | `9.1.0` |
| `[8.0.0]` | `9.1.0` | `9.1.0` |

PM UI does not infer a new upper bound, widen the old range, or create an exact
pin. Selecting the concrete version is the explicit request to replace the
constraint, so no confirmation is required.

#### Project and solution views

Project view applies the rules above to the current project.

Solution view evaluates each selected project independently. For example:

```text
ProjectA: [8.0.0, 9.0.0)
ProjectB: [8.0.0, 10.0.0)
Selected: 9.0.0
```

The result is:

```text
ProjectA: 9.0.0
ProjectB: [9.0.0, 10.0.0)
```

ProjectA replaces its out-of-range constraint. ProjectB preserves its
in-range upper bound.

#### Central Package Management

PM UI applies the same behavior to the effective central `PackageVersion`.

An in-range update:

```xml
<PackageVersion Include="Contoso.Logging"
                Version="[8.0.0, 9.0.0)" />
```

becomes:

```xml
<PackageVersion Include="Contoso.Logging"
                Version="[8.0.4, 9.0.0)" />
```

An explicit out-of-range selection writes the minimum-only version:

```xml
<PackageVersion Include="Contoso.Logging" Version="9.1.0" />
```

### Technical explanation

PM UI already receives the effective requested range for each installed
package. It will use that range when calculating the highest applicable update
for each project.

When the customer selects a concrete version, PM UI determines the resulting
range per project:

| Condition | Resulting range |
| --- | --- |
| No upper-bound or floating constraint | Existing behavior |
| Selected version satisfies a floating range | Preserve the floating range |
| Selected version satisfies an upper-bounded range | Set the lower bound and preserve the upper bound |
| Selected version is outside the range | Replace it with the selected minimum-only version |

The resulting range is carried through preview restore and the final project
write. Existing project-system behavior determines whether it is written to the
project file or `Directory.Packages.props`.

No new MSBuild metadata, feature flag, or `SdkAnalysisLevel` gate is proposed.
Implementations may use shared package-management code, but behavior changes to
non-PM UI callers are outside this proposal.

## Drawbacks

- Package Manager Console and command-line update behavior remain inconsistent
  until addressed separately.
- An explicit out-of-range selection removes the previous constraint without
  an additional confirmation.
- PM UI does not infer a replacement upper bound for the new release train.
- Solution updates can preserve a range in some projects while replacing it in
  others.

## Rationale and alternatives

### Preserve ranges only for in-range updates

Routine updates should not erase a customer's authored boundary. Setting the
lower bound records the update while retaining the upper-bound policy.

### Replace the range for an explicit out-of-range selection

Selecting an out-of-range concrete version is an explicit request to leave the
current constraint. Replacing it with the normal minimum-only PackageReference
version is predictable and does not require PM UI to infer a new policy.

### Do not shift or widen the range automatically

PM UI could infer `[9.1.0, 10.0.0)` or widen the old range, but either behavior
guesses the customer's intended upper bound. The customer can author a new
range separately when needed.

### Do not add a confirmation

Selecting a concrete version in the package details pane is already an explicit
update gesture. An additional confirmation would add friction to a deliberate
selection.

### Use the existing PackageReference range

Using the existing `Version` or `PackageVersion` range avoids a new project
model contract. A future update-only constraint could separate update policy
from restore semantics, but that is outside this proposal.

## Prior Art

- `packages.config` stores `allowedVersions` separately from the installed
  version, allowing updates without erasing the policy.
- Solution-level PM UI already calculates allowed updates per project before
  combining results.
- The archived
  [Floating Versions in the Package Manager UI](../archive/FloatingVersions-In-PMUI.md)
  design treated a selected version as new intent. This proposal keeps that
  behavior for out-of-range selections, while preserving ranges for routine
  in-range updates.

## Unresolved Questions

1. Should solution view preview which projects will preserve their ranges and
   which will replace them?
1. Should custom range input be allowed to replace an existing constraint?

## Future Possibilities

- Extend compatible behavior to Package Manager Console and
  `dotnet package update`.
- Define behavior for `VersionOverride`, transitive pinning, and
  `GlobalPackageReference`.
