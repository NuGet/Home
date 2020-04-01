# net5.0 TFM Platform and PlatformVersion implementation

This document is meant to describe the various parts of the code that need to be updated in order to support platforms in net5.0 target framework identifiers. That is, the optional part after a `-` following `net5.0`. For example, `net5.0-ios14.1`. Note that this ONLY covers the platform part, because [initial support for `net5.0` has already been added](https://github.com/NuGet/NuGet.Client/pull/3265).

For more details on the feature itself, please refer to [the full spec](https://github.com/terrajobst/designs/blob/master/accepted/2020/net5/net5.md).

## class NuGetFramework

Source: src/NuGet.Core/NuGet.Frameworks/NuGetFramework.cs

### Fields

Three additional fields will be added:

```csharp
        /// <summary>
        /// Framework Platform (net5.0+)
        /// </summary>
        public string Platform
        {
            get;
            private set;
        }

        /// <summary>
        /// Framework Platform Version (net5.0+)
        /// </summary>
        public Version PlatformVersion
        {
            get;
            private set;
        }

        /// <summary>
        /// True if platform is non-empty (net5.0+)
        /// </summary>
        public bool HasPlatform
        {
            get { return !string.IsNullOrEmpty(Platform); }
        }

        /// <summary>
        /// True if platform version is non-empty (net5.0+)
        /// </summary>
        public bool HasPlatformVersion
        {
            get { return IsNet5Era && !(PlatformVersion.Major == 0 && PlatformVersion.Minor == 0); }
        }
```

### Constructors

An additional constructor should be added that accepts `Version platformVersion` as its 4th argument. The current code in `NuGetFramework/3` should be moved to this new constructor, and `string profile` should be renamed to `string profileOrPlatform`. This field will be EITHER a legacy profile or, if net5.0+, a platform identifier.

```csharp
        public NuGetFramework(string framework, Version version, string profileOrPlatform)
            : this(framework, version, profileOrPlatform, FrameworkConstants.EmptyVersion)
        {
        }

        private const int Version5 = 5;

        public NuGetFramework(string frameworkIdentifier, Version frameworkVersion, string profileOrPlatform, Version platformVersion)
        {
            if (frameworkIdentifier == null)
            {
                throw new ArgumentNullException("frameworkIdentifier");
            }

            if (frameworkVersion == null)
            {
                throw new ArgumentNullException("frameworkVersion");
            }

            _frameworkIdentifier = frameworkIdentifier;
            _frameworkVersion = NormalizeVersion(frameworkVersion);

            IsNet4Era = (_frameworkVersion.Major >= Version5 && StringComparer.OrdinalIgnoreCase.Equals(FrameworkConstants.FrameworkIdentifiers.NetCoreApp, _frameworkIdentifier));

            _frameworkProfile = IsNet5Era ? profileOrPlatform ?? string.Empty : string.Empty;
            Platform = IsNet5Era ? profileOrPlatform ?? string.Empty : string.Empty;
            PlatformVersion = NormalizeVersion(platformVersion ?? FrameworkConstants.EmptyVersion);
        }
```

### GetDotNetFrameworkName

This method needs to be updated to append the Platform and PlatformVersion. I believe the format is supposed to be:

```csharp
string.Format(CultureInfo.InvariantCulture, "Platform={0},PlatformVersion={0}", framework.Platform, framework.PlatformVersion);
```

### GetShortFolderName

This method needs to be updated such that when `IsNet5Era` is `true` and `Platform` is not `null`, `"-{Platform}[PlatformVersion]` is appended to the `net5.0` short tfm. This should be similar to how profiles are appended.

## class NuGetFrameworkFactory

Source: src/NuGet.Core/NuGet.Frameworks/NuGetFrameworkFactory.cs

### ParseFrameworkName

This seems to be the core of the "long" tfm parsing logic. This needs to be modified to detect `Platform=` and `PlatformVersion=` and extract those accordingly. It should also skip parsing out `Profile` if it detects that the framework it's currently parsing is net5.0+. If an invalid Platform is detected, it should error out.

### ParseFolder

This seems to be the core of the "short" tfm parsing logic. As with `ParseFrameworkName`, this needs to be modified such that, when the identifier is net5.0+, it will check `FrameworkConstants.FrameworkPlatforms` and verify that the given platform is one of the accepted ones (per the net5.0 spec linked at top). If an invalid Platform is detected, it should error out.

### RawParse

This... mostly seems to do what I think it needs to do? It should probably have a big fat comment noting that we're piggybacking off profile parsing (keeping the net5.0+ dependent logic in `ParseFolder`). Maybe renaming variables to `profileOrPlatform` for clarity.

## class FrameworkConstants

Source: src/NuGet.Core/NuGet.Frameworks/FrameworkConstants.cs

### (new!) FrameworkPlatforms

A new `internal static HashSet<string> FrameworkPlatforms` field should be added and populated with all valid platforms (`android`, `ios`, `macos`, `tvos`, `watchos`, `windows`). As of this writing, it's **unclear** what to do about Tizen and Unity, and whether they'll be regular Platforms or a TFI or whatever.

## class CompatibilityProvider

Source: src/NuGet.Core/NuGet.Frameworks/CompatibilityProvider.cs

### IsCompatibleWithTargetCore

This method needs to be modified such that if there's a Platform present in the `candidate`, the platform name has to match. Additionally, an `IsVersionCompatible(target.PlatformVersion, candidate.PlatformVersion)` should be made if both have a `PlatformVersion` included. This will need to check for null `PlatformVersion`s, as well.

## class NuGetFrameworkFullComparer

Source: src/NuGet.Core/NuGet.Frameworks/comparers/NuGetFrameworkFullComparer.cs

### Equals

An extra clause should be added here that checks that `Platform` and `PlatformVersion` are compared against.

Additionally, there's maybe some leftover work, as per [this comment in PR #3265](https://github.com/NuGet/NuGet.Client/pull/3265/files#r388004831) as far as what to do with `Unsupported`. This might be getting worked on separately?

## class CompatibilityTests

Source: test/NuGet.Core.Tests/NuGet.Frameworks.Test/CompatibilityTests.cs

`[Theory] Compatibility_FrameworksAreCompatible` data needs to be modified such that Platforms are supported, and all expected platforms are included in the tests.

## class NuGetFrameworkParseTests

Source: test/NuGet.Core.Tests/NuGet.Frameworks.Test/NuGetFrameworkParseTests.cs

`[Theory] NuGetFramework_Basic` needs additional test cases to make sure Platform and PlatformVersion are being parsed correctly from the "long" tfm format.

## class NuGetFrameworkTests

Source: test/NuGet.Core.Tests/NuGet.Frameworks.Test/NuGetFrameworkTests.cs

An additional test should be added to make sure things like `net50-android10` parse to `net5.0-android10.0`.

## Remaining work/questions

1. Ensure Pack target passes TargetPlatformVersion to .nuspec generator. (Use `0.0` as a sentinel)
1. Fail parsing/creation of `NuGetFramework` when an unknown OS flavor is being used -- slam an Unsupported tfi into it??

## Out of scope for this

1. We need to make sure there's some kind of information/warning available when `net50` is used, since [we're going to warn now if the `.` is missing, starting from `net5.0`](https://github.com/NuGet/Home/issues/9215). I'm not sure what level to do this at.
1. Design NuGet manifest entries for TargetPlatformVersion and TargetPlatformMinVersion (not sure what "design" is needed -- TPV should be treated as part of the tfm itself. TargetPlatformMinVersion is a separate, new attribute. This is a bit more involved than just passing it through.)
1. Ensure Pack target passes TargetPlatformMinVersion to .nuspec generator.
1. Fail pack when packing equivalent TFMs like net5.0-ios and net5.0-ios13.0 (note: we do want to eventually allow multi-targeting with equivalent TFMs, but that's out of scope for this work, and [seems to be a Big Task](https://github.com/NuGet/Home/issues/5154) -- also, we don't support them right now, so this isn't an issue yet)
1. Produce an error when a OS flavored .NET 5 TFM is consumed but the package has no TPV in either folder name of the manifest. Is this supposed to be during restore??
1. Produce a warning when a project consumes a library with a higher `TargetPlatformMinVersion` (related to 5154)
1. When present, msbuild props like `TargetPlatformIdentifier` and `TargetPlatformVersion` should supersede the corresponding data in `NuGetFramework` objects. (this is related to 5154, too)

## Follow-up

1. Compatibility tables need to be extended to include compatibility for all the Xamarin TFMs to appropriate `net5.0-xxxx1.2` TFMs. I'm not sure we do anything similar right now, so this might actually be new functionality? -- send an email to Immo because our understanding is that we're not actually doing this. cc nikolche/rob
1. Do we care about `netcoreapp5.0` and `net5.0` both being used? Are those the "equivalent TFMs" we should error on?
1. Produce a warning when a net5.0 project references netcoreapp3.1 (or earlier) with WPF/WinForms (what? How do we even do this????) -- we apparently did this previously, but we decided not to do it in our code and let the SDK take care of it?
