# Deterministic Pack Revisited

- Author Name: [omajid](https://github.com/omajid)
- GitHub Issue: [#8601](https://github.com/NuGet/Home/issues/8601)

## Summary

Make NuGet packaging more deterministic by default. NuGet will start respecting
the existing `Deterministic` property, which already defaults to `true`.

Optionally, support making NuGet packages bit-by-bit deterministic and
reproducible through the new `DeterministicTimestamp` property.

This is targeted for .NET 11.

## Motivation

Deterministic packages provide a very nice set of security advantages to a
piece of software:

- Security and verification: It becomes possible to detect and deal with a
  whole new class of attacks in the supply chain - including on build servers.
  It becomes easier to verify items like SBOMs.

- Increasing user trust: Users can trust the binaries they have matches the
  sources, reducing risks of backdoors and other vulnerabilities.

- Auditing and Compliance: It becomes easier to verify that the sources and
  binaries match for compliance reasons.

Users are already trying to make packages deterministic on their own; providing
a first-class feature will make it easier for them and everyone else to adopt
this too.

Bit-by-bit reproducible nuget packages are more important than they might
appear at first because the hash of a nuget package is added to the deps.json
of a .NET application that depends on the nuget package. In other words, one
package not being reproducible can impact things that build on it.

This is also one of the pieces needed to make the .NET SDK build itself
deterministic and reproducible. For more details, see
https://github.com/dotnet/source-build/issues/4963

Note: this proposal uses "deterministic" and "reproducible" interchangeably
as synonyms. .NET uses the term deterministic. The wider ecosystem uses
reproducible too.

For more information on deterministic and reproducible builds, see:

- https://en.wikipedia.org/wiki/Reproducible_builds
- https://reproducible-builds.org/
- [Deterministic builds in Roslyn](https://blog.paranoidcoding.org/2016/04/05/deterministic-builds-in-roslyn.html)
- [DotNet.ReproducibleBuilds](https://github.com/dotnet/reproducible-builds)
- New SDL requirement: Enable deterministic builds (https://github.com/dotnet/arcade/issues/15910)

## Explanation

Abstractly, being deterministic or reproducible simply means the same inputs
produces the same outputs.

This proposal is for moving packages built by NuGet.Client from being
non-deterministic to being deterministic in package contents by default, and
optionally to being bit-by-bit deterministic.

### Functional explanation

From an implementation point of view there are 3 levels to deterministic-ness
in NuGet:

0. Always enabled and already the default.

   Some things that help make nuget packages more deterministic are already
   enabled and the default in already-released versions of NuGet.Client. Some
   can't be turned off. For example, the order of files within the nuget
   package archive is already fully deterministic
   ([NuGet.Client#6963](https://github.com/NuGet/NuGet.Client/pull/6963)).

1. New: Enable more determinism by default

   This includes using a single timestamp, based on the current wall clock
   time, for all files added to the archive. See the `DeterministicTimestamp`
   property below on how to override the timestamp, or how to opt out of this
   behaviour.

   Currently, this also includes making the names of psmdcp files
   deterministic, which are otherwise random and based on a GUID.

   In the future this might affect more things that are safe to enable by
   default.

   This is tied to the existing `Deterministic` property. Use it like this:

   - For `dotnet pack`:

     Use the `/p:Deterministic=true` argument. For example:

     `dotnet pack /p:Deterministic=true`

     This property is already set to `true` in recent versions of .NET, at
     least as far back as .NET Core 3.0.

   - For msbuild project files:

     Use the property `Deterministic`. For example:

     `<Deterministic>true</Deterministic>`

     This is property is already set to `true` in recent versions of .NET, at
     least as far as .NET Core 3.0.

   - For `NuGet.exe`:

     Use the `-Deterministic` argument. For example:

     `nuget pack packageA.nuspec -Deterministic`

     The `-Deterministic` flag is **not** the default.

   - For `PackageBuilder` API:

     There is a **behavioral change** in the `NuGet.Packaging.PackageBuilder`
     API: not explicitly setting the `deterministic` parameter in the
     constructor will use a default of `true` now. There is no change to the
     API itself: it already contains support for the `bool deterministic`
     constructor parameter.

2. New: Optionally enable things that introduces slight risk

   Some things improve deterministic-ness. However, they violate assumptions
   that other/external tools may rely on as contracts. There's a risk that
   changes in this bucket can break tools and users.

   The only known instance of this is embedded timestamps in the zip metadata
   in the nuget archives. This is controlled via the new (optional)
   `DeterministicTimestamp` property. Use it like this:

   - For `dotnet pack`:

     Use the `/p:DeterministicTimestamp={DATE_TIME}` argument. For example, in
     bash:

     `dotnet pack /p:DeterministicTimestamp=$(date --rfc-3339=seconds)`

   - For msbuild project files:

     Use `DeterministicTimestamp`. For example:

     ```
     <PropertyGroup>
       <DeterministicTimestamp>$(DATE_TIME)</DeterministicTimestamp>
     </PropertyGroup>
     ```

     If `DeterministicTimestamp` is not set, but `SOURCE_DATE_EPOCH` is set
     (eg, from environment variable), then `DeterministicTimestamp` is set to
     the value of `SOURCE_DATE_EPOCH`.

   - For `NuGet.exe`:

     Use the `-DeterministicTimestamp {DATE_TIME}` argument. For example:

     `nuget pack packageA.nuspec -DeterministicTimestamp $(date --rfc-3339=seconds)`

   - For `PackageBuilder` API:

     There's a new property:

     ```
     public string DeterministicTimestamp
     {
         init { ... }
     }
     ```

     This will accept a string-ified version of `{DATE_TIME}`. If
     `Deterministic` is explicitly set to `false`, this will not be used.

   `DeterministicTimestamp` must be one of:

     - The literal string `true` to indicate using `DateTime.UtcNow` as the
       timestamp for all files added to the archive.
     - The literal string `false` to use the original file modification times.
     - A full date/time string specified in the [RFC
       3339](https://www.rfc-editor.org/rfc/rfc3339) format
     - A a single number indicating the number of seconds since the unix epoch
       (`Jan 1 1970, 00:00:00 UTC`).

   The default value of `DeterministicTimestamp` is `true`.

## Drawbacks

- We enabled this in the past with fixed 1980-based timestamps. Customers
  reported deployments failing. Their tools used the time to determine whether
  a file was newer, which returned bad results with fixed timestamps. For more
  details see [dotnet/core#3388](https://github.com/dotnet/core/issues/3388).
  To mitigate this, this proposal uses real wall-clock-based-timestamps by
  default, and allows developers to override the timestamp.

- This feature makes the code more complex.

- The implicit use of `SOURCE_DATE_EPOCH` as an environment variable can lead
  to action-at-a-distance issues. To mitigate this, we will read this variable
  using msbuild which should make the variable's usage and value available
  through the binlog.

- Package signing breaks the possibility of bit-by-bit reproducibility, due to
  embedding a timestamp. Nuget has the concept of a content hash, which can
  mitigate this somewhat, by comparing the contents of two packages. A command
  to show a package's content hash is available starting in .NET 10.0.100:
  `dotnet nuget verify`.

- This doesn't auto-enable `DeterministicTimestamp` fallback handling in users
  of the `PackageBuilder` API. Users of that will need to explicitly specify
  the timestamp and re-implement handling of `SOURCE_DATE_EPOCH`.

## Rationale and alternatives

- We considered making what is now called `DeterministicTimestamp`
  automatically infer the timestamp of the last commit in the source repository
  through a change in sourcelink. This was deemed as too much code to maintain
  for a small benefit: https://github.com/dotnet/sourcelink/pull/1552.

- As an alternative, we can simply not implement this. This would make .NET's
  security story and positioning weaker than many other programming language
  stacks.

## Prior Art

- Deterministic builds were enabled in NuGet.Client in the past (see the
  [spec](https://github.com/NuGet/Home/wiki/%5BSpec%5D-Deterministic-Pack)) and
  had to be disabled due to regressions:
  https://github.com/NuGet/Home/issues/8601

- Deterministic builds are supported in many other .NET components, including
  [roslyn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-options/code-generation#deterministic)
  and [sourcelink](https://github.com/dotnet/sourcelink/issues/601)

- There is an effort to make the entire .NET SDK build end to end
  deterministic: https://github.com/dotnet/source-build/issues/4963

- Some Linux and \*nix distributions actively test all their distribution
  packages for reproduciblity and share the live status:
  https://reproducible-builds.org/citests/

- Some Linux distributions like Fedora expect all distro-packages, including
  .NET, to be deterministic. This proposal will support that.
  - https://fedoraproject.org/wiki/Changes/Package_builds_are_expected_to_be_reproducible

## Future Possibilities

- With `Deterministic=true` by default, support for `Deterministic=false` could
  be fully dropped, and the code paths simplified.

- Should turning off `Deterministic=true` produce warnings or errors?
