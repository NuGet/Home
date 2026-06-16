# ***Warn when creating packages with non-ASCII characters in the package ID***

- Nikolche Kolev <https://github.com/nkolev92>
- [Pack Warning when Package ID doesn't meet the standards](https://github.com/NuGet/Home/issues/14949)

## Summary

Raise a NuGet pack warning when the package ID being authored contains characters outside of the ASCII range.
The warning is opt-out via `NoWarn`, framework agnostic, and applies to both the MSBuild `Pack` target (`dotnet pack` / `msbuild /t:Pack`) and `nuget.exe pack`.
This is the client-side companion to the nuget.org change that blocks new pushes with non-ASCII package IDs.
See [Strengthening NuGet Security with Package ID Standards](https://github.com/NuGet/Announcements/issues/75).

## Motivation

As announced in [Strengthening NuGet Security with Package ID Standards](https://github.com/NuGet/Announcements/issues/75), nuget.org now enforces stricter package ID rules. New package IDs must match `^[A-Za-z0-9_](?!.*[.-]{2})[A-Za-z0-9.-]{0,99}$`, and starting July 15th, even existing IDs that don't conform will be blocked from pushing new versions.

Without a corresponding client-side signal, authors only learn about the restriction at `dotnet nuget push` time - typically late in the release process, after CI has produced a `.nupkg` they cannot ship.
Warning at pack time gives authors the earliest possible signal, before any artifact is uploaded, and avoids late-stage release surprises.

The longer-term plan is to promote this warning to an error in a later .NET SDK release (targeted at .NET 12).
See [Strengthening NuGet Security with Package ID Standards](https://github.com/NuGet/Announcements/issues/75) for the broader rollout plan and timelines.

## Explanation

### Functional explanation

When a user runs `dotnet pack` (or any other entry point that invokes the NuGet `Pack` task) on a project whose effective package ID contains characters outside the ASCII range, NuGet emits a warning:

```text
warning NU5052: The package ID 'Contöso.Utilities' contains non-ASCII characters. Non-ASCII characters in package IDs are not allowed and will become an error in a future release. Consider renaming the package to use ASCII characters only.
```

The warning:

- Is raised once per pack invocation, against the package being built.
- Honors `NoWarn`, `TreatWarningsAsErrors`, `WarningsNotAsErrors`, and `WarningsAsErrors` like any other NuGet pack warning.

The warning is enabled by default gated by `SdkAnalysisLevel`:

- `SdkAnalysisLevel` >= 11.0.100 (or unset, per the rules in the [NuGet feature guide](https://github.com/NuGet/NuGet.Client/blob/dev/docs/feature-guide.md#warnings-and-defaults)) → warning is on by default.
- `SdkAnalysisLevel` < 11.0.100 → warning is off.
- Non-SDK projects (`nuget.exe pack`, `msbuild /t:Pack` without `Microsoft.NET.Sdk`) → warning is on by default.

#### Examples

| Package ID | Warns? | Notes |
|------------|--------|-------|
| `Contoso.Utilities` | No | All ASCII. |
| `Contöso.Utilities` | Yes | `ö` is outside ASCII. |
| `Contoso.Ütil` | Yes | `Ü` is outside ASCII. |
| `Сontoso.Utilities` (Cyrillic `С`) | Yes | Homoglyph. |
| `My.Package-1.0` | No | Hyphen and digits are ASCII. |

The check applies only to the **package ID**.

## Drawbacks

- The nuget.org rule enforcement is not necessarily going to apply to all other feeds.
- Local feeds do not apply the same rules.

## Rationale and alternatives

### Why warn in `pack`, rather than rely solely on the nuget.org push block

- Earliest possible feedback to the author - the issue is caught locally before CI even produces an artifact, instead of failing late at `dotnet nuget push`.
- Reaches authors who push to feeds other than nuget.org (Azure Artifacts, GitHub Packages, internal feeds), where the nuget.org-side block does not apply.

The pack warning and the nuget.org push block are complementary, not alternatives.

## Prior Art

- [Package ID validation today](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.Packaging/PackageCreation/Utility/PackageIdValidator.cs) - the existing regex-based check that this warning slots in next to.
- [SdkAnalysisLevel design](https://github.com/dotnet/designs/blob/main/proposed/sdk-analysis-level.md) - the gating mechanism we use here, per the [NuGet feature guide](https://github.com/NuGet/NuGet.Client/blob/dev/docs/feature-guide.md#warnings-and-defaults).
- npm has restricted new package names to a [strict character set](https://github.com/npm/validate-npm-package-name) (URL-safe ASCII) for years.
- PyPI [PEP 541](https://peps.python.org/pep-0541/) addresses name squatting administratively rather than via name restrictions, which has been less effective at preventing homoglyph attacks.
- Crates.io restricts crate names to ASCII alphanumerics, `-`, and `_`.

## Unresolved Questions

- **Patch back to .NET 10.0.400 / 10.0.100.** Given the nuget.org push block is already in effect, should we patch the warning into the .NET 10.0.400 SDK to reach more customers sooner? Should we also patch .NET 10.0.100 to reach Linux customers earlier in the rollout?
- **Which .NET SDK band makes the warning an error?** The current plan is .NET 12 (one major after the warning ships in .NET 10/11), but the exact `SdkAnalysisLevel` value and band need to be confirmed with the .NET SDK team.

## Future Possibilities

- **Restore time non-ASCII character validation**
- **Promote to error in .NET 12.** Once telemetry shows the warning is being seen and acted on, promote `NU5052` from warning to error under a higher `SdkAnalysisLevel`.
- **Surface in Visual Studio pack UI.** A more prominent in-IDE prompt when authoring a new package project with a non-ASCII ID.
