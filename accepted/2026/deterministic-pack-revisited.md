# Deterministic Pack Revisited

- Author: [omajid](https://github.com/omajid)
- GitHub Issue: [#8601](https://github.com/NuGet/Home/issues/8601)

## Summary

Make NuGet pack deterministic. When enabled, all operations that produce nuget
packages - dotnet CLI commands, nuget CLI command and msbuild tasks - will
produce nuget packages that are deterministic and, optionally, bit-by-bit
reproducible.

## Motivation

Deterministic packages provide a very nice set of security
advantages to a piece of software:

- Security and verification: It becomes possible to detect and deal with a
  whole new class of attacks in the supply chain - including on build servers.
  It becomes easier to verify items like SBOMs.

- Increasing user trust: Users can trust the binaries they have matches the
  sources, reducing risks of backdoors and other vulnerabilities.

- Auditing and Compliance: It becomes easier to verify that the sources and
  binaries match for compliance reasons.

Users are already trying to make packages deterministic on their own; providing
a first class feature will make it easier for them and everyone else to adapt
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
non-deterministic to being deterministic in package contents, and optionally to
being bit-by-bit deterministic.

### Functional explanation

From an implementation point of view there are 3 levels to deterministic-ness
in NuGet:

0. Always enabled and already the default.

   Some things that help make nuget packages more deterministic are already
   enabled and the default, and can't be turned off. For example order of files
   in the nuget package archive is already fully deterministic
   ([NuGet.Client#6963](https://github.com/NuGet/NuGet.Client/pull/6963)).

1. Can be enabled or made the default with low risk

   This includes the names of some files, which are otherwise random and based
   on a GUID. The names will now be based on a hash of the file contents.

   This is tied to the `Deterministic` property. Use it like this:

   - For `dotnet pack`:

     Use the `/p:Deterministic=true` argument. For example:

     `dotnet pack /p:Deterministic=true`

   - For msbuild project files:

     Use the property `Deterministic`. For example:

     `<Deterministic>true</Deterministic>`

     This is already the default for recent versions of .NET, at least as far
     as .NET Core 3.0.

   - For `NuGet.exe`:

     Use the `-Deterministic` argument. For example:

     `nuget pack packageA.nuspec -Deterministic`

   - For `PackageBuilder` API:

     There is no change in the `NuGet.Packaging.PackageBuilder` API. It already
     contains support for this via the `deterministic` constructor.

2. Enabling introduces slight risk

   Some things improve deterministic-ness. However, they violate assumptions
   that other/external tools may rely on as contracts. There's a risk
   that changes in this bucket can break tools and users.

   The only known instance of this is embedded timestamps in the zip metadata
   in the nuget archives.  This is controlled via the new (optional)
   `DeterministicTimestamp` property.  Use it like this:

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

     This will accept a string-ified version of `{DATE_TIME}`.

   `DeterministicTimestamp` must be either a full date/time string
   specified in the RFC3339 format, or a single number indicating the
   number of seconds since the unix epoch (`Jan 1 1970, 00:00:00 UTC`).

### Technical explanation

- `Deterministic` is a boolean. When `Deterministic` is set to true, a single
  deterministic time is used as the file modification time for all the files
  inside the nuget archive. Which time is used depends on whether
  `DeterministicTimestamp` is set or not

- `DeterministicTimestamp` must be either a full date/time string specified in
  the RFC3339 format, or a single number indicating the number of seconds since
  the unix epoch.

  If `Deterministic=false`, then `DeterministicTimestamp` is ignored.

  If `DeterministicTimestamp` is not set but `SOURCE_DATE_EPOCH` is set,
  `DeterministicTimestamp` will use that value.

  If neither `DeterministicTimestamp` nor `SOURCE_DATE_EPOCH` is set, but
  `Deterministic=true` then the current UTC time is used.

  In other words, the precedence is:

  1. Value of `DeterministicTimestamp`
  2. Value of `SOURCE_DATE_EPOCH`
  3. Value of `DateTimeOffset.UtcNow`

- The standard `SOURCE_DATE_EPOCH` variable is used to make nuget package
  creation more consistent with other tools:
  https://reproducible-builds.org/docs/source-date-epoch/

- The value of `DeterministicTimestamp` and `SOURCE_DATE_EPOCH` must be in the
  range of valid ZIP archive file modification date and times.

## Drawbacks

- We enabled this in the past with fixed 1980-based timestamps. Customers
  reported deployments failing. Their tools used the time to determine whether
  a file was newer, which returned bad results with fixed timestamps. For more
  details see [dotnet/core#3388](https://github.com/dotnet/core/issues/3388).
  To mitigate this, this proposal uses real wall-clock-based-timestamps by
  default, and allows developers to override the timestamp.

- This feature makes the code more complex.

- The implicit use of `SOURCE_DATE_EPOCH` as an environment variable can lead
  to action-at-a-distance issues. To mitigate this, we will reading this
  variable using msbuild which should make the variable's usage and value
  available through the binlog.

- Package signing breaks the possibility of bit-by-bit reproducibility, due to
  embedding a timestamp. Nuget has the concept of a contnet hash, that can
  mitigate this somewhat, by comparing the contents of two packages.  A command
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

- We considered making `DeterministicTimestamp` the default, but it is risky.

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

## Unresolved Questions

- Is `DeterministicTimestamp` the best name?

## Future Possibilities

- With `Deterministic=true` by default, support for `Deterministic=false` could
  be fully dropped, and the code paths simplified

- Should turning off `Deterministic=true` produce warnings or errors?
