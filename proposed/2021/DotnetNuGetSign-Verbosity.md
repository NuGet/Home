# `dotnet nuget sign --verbosity`

* Status: **In Review**
* Author: [Heng Liu](https://github.com/heng-liu)
* Issue: [#11173](https://github.com/NuGet/Home/issues/11173) - No certificate info shows when running dotnet nuget sign on default verbosity

## Problem background

`dotnet nuget sign` command doesn't provide any output by default due to logical error in the implementation. If the user didn't pass value for `--verbosity` option, then the log level is set to [`LogLevel.Minimal`](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.CommandLine.XPlat/Commands/Signing/VerifyCommand.cs#L58). Customers need to know the results of signing.


## Who are the customers

Package consumers that use the `dotnet nuget sign` command to sign package.

## Goals

* Change the output of `dotnet nuget sign` command for various `--verbosity` options.

## Solution

The details that should be displayed on each verbosity level are described below. Each level should display the same as the level below plus whatever is specified in that level. In that sense, `quiet` will be give the least amount of information, while `diagnostic` the most.

​| `q[uiet]` | `m[inimal]` | `n[ormal]` | `d[etailed]` | `diag[nostic]`
----------------------------------| --------- | ----------- | ---------- | -----------| --------------
`Signing Certificate -> Subject name`   | ❌       | ❌          | ✔️          | ✔️         | ✔️
`Signing Certificate -> SHA1 Hash`   | ❌       | ❌          | ✔️          | ✔️         | ✔️
`Signing Certificate -> SHA256 Hash`   | ❌       | ❌          | ✔️          | ✔️         | ✔️
`Signing Certificate -> Issued By`   | ❌       | ❌          | ✔️          | ✔️         | ✔️
`Signing Certificate -> Validity period`   | ❌       | ❌          | ✔️          | ✔️         | ✔️
`Timestamper Information`  | ❌       | ❌          | ✔️         | ✔️         | ✔️
`Output Path`        | ❌       | ❌          | ✔️         | ✔️         | ✔️
`Signing command succeeds Information`| ❌       | ✔️          | ✔️         | ✔️         | ✔️


### Example output in success scenarios

This is output of the invocation of 
```
dotnet nuget sign test1.nupkg --certificate-path .\1A0BA119ABDE3BC428A15672ECF8CD31B4725A6D.pfx --certificate-password password --timestamper http://timestamper/test --output .\package\Signed\
```

#### `--verbosity quiet`

* No output unless there are any `errors` or `warnings`.

#### `--verbosity mimimal` | Default verbosity

```
Package(s) signed successfully.
```

#### `--verbosity normal`
```
Signing package(s) with certificate:
  Subject Name: CN=Test certificate for testing NuGet package signing
  SHA1 hash: 1A0BA119ABDE3BC428A15672ECF8CD31B4725A6D
  SHA256 hash: 54D4139CC924A50E8851C1B2ACAFECB09D7C48E927778C1F325B59DEE6272BBB
  Issued by: CN=Test certificate for testing NuGet package signing
  Valid from: 8/27/2021 10:19:48 AM to 8/28/2021 10:19:48 AM
Timestamping package(s) with:
http://timestamper/test
Signed package(s) output path:
.\package\Signed\
Package(s) signed successfully.
```

### Example output in failure scenarios
This is output of the invocation of 
```
dotnet nuget sign test1.nupkg --certificate-path .\213DE41592E1DB76549096C7EE3A23D932697E4C.pfx --certificate-password password --timestamper http://timestamper/test --output .\package\Signed\
```
(The signing certificate is not valid for signing)
#### `--verbosity quiet`

```
error: NU3018: NotTimeValid: A required certificate is not within its validity period when verifying against the current system clock or the timestamp in the signed file.
error: NU3018: Certificate chain validation failed.
```

#### `--verbosity mimimal` | Default verbosity

```
error: NU3018: NotTimeValid: A required certificate is not within its validity period when verifying against the current system clock or the timestamp in the signed file.
error: NU3018: Certificate chain validation failed.
```

#### `--verbosity normal`
```
Signing package(s) with certificate:
  Subject Name: CN=Test certificate for testing NuGet package signing
  SHA1 hash: 213DE41592E1DB76549096C7EE3A23D932697E4C
  SHA256 hash: 1CAA0FA97F22B3D04483DA858B25C8215AEF7F52EB51E895F1CCE8146ACAABDD
  Issued by: CN=Test certificate for testing NuGet package signing
  Valid from: 10/25/2021 4:53:00 PM to 10/26/2021 4:53:00 PM
Timestamping package(s) with:
http://timestamper/test
Signed package(s) output path:
.\package\Signed\
error: NU3018: NotTimeValid: A required certificate is not within its validity period when verifying against the current system clock or the timestamp in the signed file.
error: NU3018: Certificate chain validation failed.
```