# `dotnet nuget verify --verbosity`

* Status: **In Review**
* Author: [Kartheek Penagamuri](https://github.com/kartheekp-ms)
* Issue: [#10316](https://github.com/NuGet/Home/issues/10316) - dotnet nuget verify is too quiet

## Problem background

`dotnet nuget verify` command doesn't provide any output by default due to logical error in the implementation. If the user didn't pass value for `--verbosity` option, then the log level is set to [`LogLevel.Minimal`](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.CommandLine.XPlat/Commands/Signing/VerifyCommand.cs#L58). Customers need information about packages’ signatures to [manage package trust boundaries](https://docs.microsoft.com/en-us/nuget/consume-packages/installing-signed-packages).

## Who are the customers

Package consumers that use the `dotnet nuget verify` command to verify package signature and configure NuGet security policy.

## Goals

* Change the output of `dotnet nuget verify` command for various `--verbosity` options.
* Improve log messages & error codes in docs to improve the customer experience based upon the learnings from the recent Debian incident.

## Non-goals

* Add `--verbosity` option to `dotnet nuget verify` command.

## Solution

The details that should be displayed on each verbosity level are described below. Each level should display the same as the level below plus whatever is specified in that level. In that sense, `quiet` will be give the least amount of information, while `diagnostic` the most.

​                                  | `q[uiet]` | `m[inimal]` | `n[ormal]` | `d[etailed]` | `diag[nostic]`
----------------------------------| --------- | ----------- | ---------- | -----------| --------------
`Certificate chain Information`   | ❌       | ❌          | ❌         | ✔️         | ✔️
`Path to package being verified`  | ❌       | ❌          | ✔️         | ✔️         | ✔️
`Hashing algorithm used for signature`        | ❌       | ❌          | ✔️         | ✔️         | ✔️
`Author/Repository Certificate -> SHA1 hash`| ❌       | ❌          | ✔️         | ✔️         | ✔️
`Author/Repository Certificate -> Issued By`| ❌       | ❌          | ✔️         | ✔️         | ✔️
`Timestamp Certificate -> Issued By`| ❌       | ❌          | ✔️         | ✔️         | ✔️
`Timestamp Certificate -> SHA-256 hash`| ❌       | ❌          | ✔️         | ✔️         | ✔️
`Timestamp Certificate -> Validity period`| ❌       | ❌          | ✔️         | ✔️         | ✔️
`Timestamp Certificate -> SHA1 hash`| ❌       | ❌          | ✔️         | ✔️         | ✔️
`Timestamp Certificate -> Subject name`| ❌       | ❌          | ✔️         | ✔️         | ✔️
`Author/Repository Certificate -> Subject name`| ❌       | ✔️          | ✔️         | ✔️         | ✔️
`Author/Repository Certificate -> SHA-256 hash`| ❌       | ✔️          | ✔️         | ✔️         | ✔️
`Author/Repository Certificate -> Validity period`| ❌       | ✔️          | ✔️         | ✔️         | ✔️
`Author/Repository Certificate -> Service index URL (If applicable)`| ❌       | ✔️          | ✔️         | ✔️         | ✔️
`Package name being verified`                    | ❌       | ✔️          | ✔️         | ✔️         | ✔️
`Type of signature (author or repository)`| ❌       | ✔️          | ✔️         | ✔️         | ✔️

```
Once this spec has been implemented the output of `nuget.exe verify` command for various verbosity levels will change and be in sync with `dotnet nuget verify` command.
```

### Log level mapping - The following details are copied from [here](https://github.com/NuGet/Home/blob/dev/designs/Package-List-Verbosity.md#log-level-mapping). Thanks to [Joel Verhagen](https://github.com/joelverhagen) for the detailed information

The provided `--verbosity` value will include to NuGet log messages with the following levels:

​             | `q[uiet]` | `m[inimal]` | `n[ormal]` | `d[etailed]` | `diag[nostic]`
------------- | --------- | ----------- | ---------- | ----------- | --------------
`Error`       | ✔️        | ✔️         | ✔️         | ✔️         | ✔️
`Warning`     | ✔️        | ✔️         | ✔️         | ✔️         | ✔️
`Minimal`     | ❌        | ✔️         | ✔️         | ✔️         | ✔️
`Information` | ❌        | ❌         | ✔️         | ✔️         | ✔️
`Verbose`     | ❌        | ❌         | ❌         | ✔️         | ✔️
`Debug`       | ❌        | ❌         | ❌         | ✔️         | ✔️

Note that MSBuild itself has the following mapping for it's own "log levels"
([source](https://docs.microsoft.com/en-us/visualstudio/msbuild/obtaining-build-logs-with-msbuild?view=vs-2019#verbosity-settings)):

​                                     | `q[uiet]` | `m[inimal]` | `n[ormal]` | `d[etailed]` | `diag[nostic]`
------------------------------------- | --------- | ----------- | ---------- | ----------- | --------------
Errors                                | ✔️        | ✔️         | ✔️         | ✔️         | ✔️
Warnings                              | ✔️        | ✔️         | ✔️         | ✔️         | ✔️
High-importance Messages              | ❌        | ✔️         | ✔️         | ✔️         | ✔️
Normal-importance Messages            | ❌        | ❌         | ✔️         | ✔️         | ✔️
Low-importance Messages               | ❌        | ❌         | ❌         | ✔️         | ✔️
Additional MSBuild-engine information | ❌        | ❌         | ❌         | ❌         | ✔️

In other words, you can think of the following log concepts per row as equivalent.

NuGet log level    | MSBuild verbosity switch | MSBuild message type
------------------ | ------------------------ | --------------------
`Error`, `Warning` | `q[uiet]`                | Errors and Warnings
`Minimal`          | `m[inimal]`              | High-importance Messages
`Information`      | `n[ormal]`               | Normal-importance Messages
`Verbose`, `Debug` | `d[etailed]`             | Low-importance Messages
​                   | `diag[nostic]`           | Additional MSBuild-engine information

### Example output in success scenarios

This is output of the invocation of `dotnet nuget verify nuget.common.5.9.0-preview.2.nupkg`

#### Default verbosity | `--verbosity mimimal`

<details>
<summary>output</summary>

```
Verifying NuGet.Common.5.9.0-preview.2

Signature type: Author
  Subject name: CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
  SHA256 hash: 3F9001EA83C560D712C24CF213C3D312CB3BFF51EE89435D3430BD06B5D0EECE
  Valid from: 2/25/2018 4:00:00 PM to 1/27/2021 4:00:00 AM

Signature type: Repository
Service index: https://api.nuget.org/v3/index.json
Owners: Microsoft, nuget
  Subject name: CN=NuGet.org Repository by Microsoft, O=NuGet.org Repository by Microsoft, L=Redmond, S=Washington, C=US
  SHA256 hash: 0E5F38F57DC1BCC806D8494F4F90FBCEDD988B46760709CBEEC6F4219AA6157D
  Valid from: 4/9/2018 5:00:00 PM to 4/14/2021 5:00:00 AM

Successfully verified package 'NuGet.Common.5.9.0-preview.2'.
```

</details>

#### `--verbosity quiet`

* No output unless there are any `errors` or `warnings`.

#### `--verbosity normal`

<details>
<summary>output</summary>

```
Verifying NuGet.Common.5.9.0-preview.2
<PATH>\nuget.common.5.9.0-preview.2.nupkg
Signature Hash Algorithm: SHA256

Signature type: Author
Verifying the author primary signature with certificate: 
  Subject name: CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
  SHA1 hash: F404000FB11E61F446529981C7059A76C061631E
  SHA256 hash: 3F9001EA83C560D712C24CF213C3D312CB3BFF51EE89435D3430BD06B5D0EECE
  Issued by: CN=DigiCert SHA2 Assured ID Code Signing CA, OU=www.digicert.com, O=DigiCert Inc, C=US
  Valid from: 2/25/2018 4:00:00 PM to 1/27/2021 4:00:00 AM
Timestamp: 11/17/2020 7:23:10 AM
Verifying author primary signature's timestamp with timestamping service certificate: 
  Subject name: CN=Symantec SHA256 TimeStamping Signer - G3, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  SHA1 hash: A9A4121063D71D48E8529A4681DE803E3E7954B0
  SHA256 hash: C474CE76007D02394E0DA5E4DE7C14C680F9E282013CFEF653EF5DB71FDF61F8
  Issued by: CN=Symantec SHA256 TimeStamping CA, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  Valid from: 12/22/2017 4:00:00 PM to 3/22/2029 4:59:59 PM

Signature type: Repository
Service index: https://api.nuget.org/v3/index.json
Owners: Microsoft, nuget
Verifying the repository countersignature with certificate: 
  Subject name: CN=NuGet.org Repository by Microsoft, O=NuGet.org Repository by Microsoft, L=Redmond, S=Washington, C=US
  SHA1 hash: 8FB6D7FCF7AD49EB774446EFE778B33365BB7BFB
  SHA256 hash: 0E5F38F57DC1BCC806D8494F4F90FBCEDD988B46760709CBEEC6F4219AA6157D
  Issued by: CN=DigiCert SHA2 Assured ID Code Signing CA, OU=www.digicert.com, O=DigiCert Inc, C=US
  Valid from: 4/9/2018 5:00:00 PM to 4/14/2021 5:00:00 AM
Timestamp: 12/9/2020 2:32:12 PM
Verifying repository countersignature's timestamp with timestamping service certificate: 
  Subject name: CN=Symantec SHA256 TimeStamping Signer - G3, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  SHA1 hash: A9A4121063D71D48E8529A4681DE803E3E7954B0
  SHA256 hash: C474CE76007D02394E0DA5E4DE7C14C680F9E282013CFEF653EF5DB71FDF61F8
  Issued by: CN=Symantec SHA256 TimeStamping CA, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  Valid from: 12/22/2017 4:00:00 PM to 3/22/2029 4:59:59 PM

Successfully verified package 'NuGet.Common.5.9.0-preview.2'.
```

</details>

#### `--verbosity detailed`

<details>
<summary>output</summary>

```
Verifying NuGet.Common.5.9.0-preview.2
<PATH>\nuget.common.5.9.0-preview.2.nupkg
Signature Hash Algorithm: SHA256

Signature type: Author
Verifying the author primary signature with certificate: 
  Subject name: CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
  SHA1 hash: F404000FB11E61F446529981C7059A76C061631E
  SHA256 hash: 3F9001EA83C560D712C24CF213C3D312CB3BFF51EE89435D3430BD06B5D0EECE
  Issued by: CN=DigiCert SHA2 Assured ID Code Signing CA, OU=www.digicert.com, O=DigiCert Inc, C=US
  Valid from: 2/25/2018 4:00:00 PM to 1/27/2021 4:00:00 AM
trace:       Subject name: CN=DigiCert SHA2 Assured ID Code Signing CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:       SHA1 hash: 92C1588E85AF2201CE7915E8538B492F605B80C6
trace:       SHA256 hash: 51044706BD237B91B89B781337E6D62656C69F0FCFFBE8E43741367948127862
trace:       Issued by: CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:       Valid from: 10/22/2013 5:00:00 AM to 10/22/2028 5:00:00 AM 
trace:             Subject name: CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:             SHA1 hash: 0563B8630D62D75ABBC8AB1E4BDFB5A899B24D43
trace:             SHA256 hash: 3E9099B5015E8F486C00BCEA9D111EE721FABA355A89BCF1DF69561E3DC6325C
trace:             Issued by: CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:             Valid from: 11/9/2006 4:00:00 PM to 11/9/2031 4:00:00 PM
Timestamp: 11/17/2020 7:23:10 AM
Verifying author primary signature's timestamp with timestamping service certificate: 
  Subject name: CN=Symantec SHA256 TimeStamping Signer - G3, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  SHA1 hash: A9A4121063D71D48E8529A4681DE803E3E7954B0
  SHA256 hash: C474CE76007D02394E0DA5E4DE7C14C680F9E282013CFEF653EF5DB71FDF61F8
  Issued by: CN=Symantec SHA256 TimeStamping CA, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  Valid from: 12/22/2017 4:00:00 PM to 3/22/2029 4:59:59 PM
trace:       Subject name: CN=Symantec SHA256 TimeStamping CA, OU=Symantec Trust Network, O=Symantec Corporation, C=US
trace:       SHA1 hash: 6FC9EDB5E00AB64151C1CDFCAC74AD2C7B7E3BE4
trace:       SHA256 hash: F3516DDCC8AFC808788BD8B0E840BDA2B5E23C6244252CA3000BB6C87170402A
trace:       Issued by: CN=VeriSign Universal Root Certification Authority, OU="(c) 2008 VeriSign, Inc. - For authorized use only", OU=VeriSign Trust Network, O="VeriSign, Inc.", C=US
trace:       Valid from: 1/11/2016 4:00:00 PM to 1/11/2031 3:59:59 PM
trace:             Subject name: CN=VeriSign Universal Root Certification Authority, OU="(c) 2008 VeriSign, Inc. - For authorized use only", OU=VeriSign Trust Network, O="VeriSign, Inc.", C=US
trace:             SHA1 hash: 3679CA35668772304D30A5FB873B0FA77BB70D54
trace:             SHA256 hash: 2399561127A57125DE8CEFEA610DDF2FA078B5C8067F4E828290BFB860E84B3C
trace:             Issued by: CN=VeriSign Universal Root Certification Authority, OU="(c) 2008 VeriSign, Inc. - For authorized use only", OU=VeriSign Trust Network, O="VeriSign, Inc.", C=US
trace:             Valid from: 4/1/2008 5:00:00 PM to 12/1/2037 3:59:59 PM

Signature type: Repository
Service index: https://api.nuget.org/v3/index.json
Owners: Microsoft, nuget
Verifying the repository countersignature with certificate: 
  Subject name: CN=NuGet.org Repository by Microsoft, O=NuGet.org Repository by Microsoft, L=Redmond, S=Washington, C=US
  SHA1 hash: 8FB6D7FCF7AD49EB774446EFE778B33365BB7BFB
  SHA256 hash: 0E5F38F57DC1BCC806D8494F4F90FBCEDD988B46760709CBEEC6F4219AA6157D
  Issued by: CN=DigiCert SHA2 Assured ID Code Signing CA, OU=www.digicert.com, O=DigiCert Inc, C=US
  Valid from: 4/9/2018 5:00:00 PM to 4/14/2021 5:00:00 AM
trace:       Subject name: CN=DigiCert SHA2 Assured ID Code Signing CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:       SHA1 hash: 92C1588E85AF2201CE7915E8538B492F605B80C6
trace:       SHA256 hash: 51044706BD237B91B89B781337E6D62656C69F0FCFFBE8E43741367948127862
trace:       Issued by: CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:       Valid from: 10/22/2013 5:00:00 AM to 10/22/2028 5:00:00 AM
trace:             Subject name: CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:             SHA1 hash: 0563B8630D62D75ABBC8AB1E4BDFB5A899B24D43
trace:             SHA256 hash: 3E9099B5015E8F486C00BCEA9D111EE721FABA355A89BCF1DF69561E3DC6325C
trace:             Issued by: CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:             Valid from: 11/9/2006 4:00:00 PM to 11/9/2031 4:00:00 PM 
Timestamp: 12/9/2020 2:32:12 PM
Verifying repository countersignature's timestamp with timestamping service certificate: 
  Subject name: CN=Symantec SHA256 TimeStamping Signer - G3, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  SHA1 hash: A9A4121063D71D48E8529A4681DE803E3E7954B0
  SHA256 hash: C474CE76007D02394E0DA5E4DE7C14C680F9E282013CFEF653EF5DB71FDF61F8
  Issued by: CN=Symantec SHA256 TimeStamping CA, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  Valid from: 12/22/2017 4:00:00 PM to 3/22/2029 4:59:59 PM
trace:       Subject name: CN=Symantec SHA256 TimeStamping CA, OU=Symantec Trust Network, O=Symantec Corporation, C=US
trace:       SHA1 hash: 6FC9EDB5E00AB64151C1CDFCAC74AD2C7B7E3BE4
trace:       SHA256 hash: F3516DDCC8AFC808788BD8B0E840BDA2B5E23C6244252CA3000BB6C87170402A
trace:       Issued by: CN=VeriSign Universal Root Certification Authority, OU="(c) 2008 VeriSign, Inc. - For authorized use only", OU=VeriSign Trust Network, O="VeriSign, Inc.", C=US
trace:       Valid from: 1/11/2016 4:00:00 PM to 1/11/2031 3:59:59
trace:             Subject name: CN=VeriSign Universal Root Certification Authority, OU="(c) 2008 VeriSign, Inc. - For authorized use only", OU=VeriSign Trust Network, O="VeriSign, Inc.", C=US
trace:             SHA1 hash: 3679CA35668772304D30A5FB873B0FA77BB70D54
trace:             SHA256 hash: 2399561127A57125DE8CEFEA610DDF2FA078B5C8067F4E828290BFB860E84B3C
trace:             Issued by: CN=VeriSign Universal Root Certification Authority, OU="(c) 2008 VeriSign, Inc. - For authorized use only", OU=VeriSign Trust Network, O="VeriSign, Inc.", C=US
trace:             Valid from: 4/1/2008 5:00:00 PM to 12/1/2037 3:59:59 PM

Successfully verified package 'NuGet.Common.5.9.0-preview.2'.
```

</details>

#### `--verbosity diagnostic`

* Same output as `--verbosity detailed`

### Example output in failure scenarios

* Errors and Warnings are displayed to the console irrespective of `verbosity` level.

#### `Verifying a tampered package`

<details>
<summary>output</summary>

```
dotnet nuget verify tampered.12.0.1.nupkg -v -n

Verifying Newtonsoft.Json.12.0.3
C:\Users\kapenaga\Downloads\tampered.12.0.1.nupkg
Signature Hash Algorithm: SHA256

Signature type: Author
Verifying the author primary signature with certificate:
  Subject Name: CN=Json.NET (.NET Foundation), O=Json.NET (.NET Foundation), L=Redmond, S=wa, C=US, SERIALNUMBER=603 389 068
  SHA1 hash: 4CFB89FAA49539A58968D81960B3C1258E8F6A34
  SHA256 hash: A3AF7AF11EBB8EF729D2D91548509717E7E0FF55A129ABC3AEAA8A6940267641
  Issued by: CN=.NET Foundation Projects Code Signing CA, O=.NET Foundation, C=US
  Valid from: 10/24/2018 5:00:00 PM to 10/29/2021 5:00:00 AM
Timestamp: 11/8/2019 4:56:46 PM
Verifying author primary signature's timestamp with timestamping service certificate:
  Subject Name: CN=TIMESTAMP-SHA256-2019-10-15, O="DigiCert, Inc.", C=US
  SHA1 hash: 0325BD505EDA96302DC22F4FA01E4C28BE2834C5
  SHA256 hash: 481F4373272D98586C5364B6C115E82425675AEBFD9FACF7ADC464FA2FFFB8F0
  Issued by: CN=DigiCert SHA2 Assured ID Timestamping CA, OU=www.digicert.com, O=DigiCert Inc, C=US
  Valid from: 9/30/2019 5:00:00 PM to 10/16/2030 5:00:00 PM

Signature type: Repository
Service index: https://api.nuget.org/v3/index.json
Owners: jamesnk, newtonsoft
Verifying the repository countersignature with certificate:
  Subject Name: CN=NuGet.org Repository by Microsoft, O=NuGet.org Repository by Microsoft, L=Redmond, S=Washington, C=US
  SHA1 hash: 8FB6D7FCF7AD49EB774446EFE778B33365BB7BFB
  SHA256 hash: 0E5F38F57DC1BCC806D8494F4F90FBCEDD988B46760709CBEEC6F4219AA6157D
  Issued by: CN=DigiCert SHA2 Assured ID Code Signing CA, OU=www.digicert.com, O=DigiCert Inc, C=US
  Valid from: 4/9/2018 5:00:00 PM to 4/14/2021 5:00:00 AM
Timestamp: 11/8/2019 5:28:02 PM
Verifying repository countersignature's timestamp with timestamping service certificate:
  Subject Name: CN=Symantec SHA256 TimeStamping Signer - G3, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  SHA1 hash: A9A4121063D71D48E8529A4681DE803E3E7954B0
  SHA256 hash: C474CE76007D02394E0DA5E4DE7C14C680F9E282013CFEF653EF5DB71FDF61F8
  Issued by: CN=Symantec SHA256 TimeStamping CA, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  Valid from: 12/22/2017 4:00:00 PM to 3/22/2029 4:59:59 PM

Finished with 1 errors and 0 warnings.
error: NU3008: The package integrity check failed. The package has been tampered with since being signed.
Package signature validation failed.
```

</details>

#### `Verifying author signed package with no timestamp and untrusted signing certificate root`

<details>
<summary>output</summary>

```
dotnet nuget verify "package.nupkg" -v n
Verifying packageA.1.0.0
C:\Users\kapenaga\Downloads\package.nupkg
Signature Hash Algorithm: SHA256

Signature type: Author
Verifying the author primary signature with signing certificate:
  Subject name: CN=test
  SHA1 hash: B0A2B3B1695AB8361B1D2B14A9F5D64136E26380
  SHA256 hash: 89A2B6EB529E0AEBF0D11C8A18A846C7B8D1290791B6BF494BAFEC299F2EAAB2
  Issued by: CN=test
  Valid from: 1/29/2021 12:28:11 PM to 1/29/2021 1:28:11 PM

Finished with 2 errors and 1 warnings.
error: NU3018: The author primary signature's signing certificate is not trusted by the trust provider.
error: NU3037: The author primary signature validity period has expired.
warn : NU3027: The signature should be timestamped to enable long-term signature validity after the signing certificate has expired.

Package signature validation failed.
```

</details>

#### `Debian case - Verifying author signed package with untrusted timestamping signing certificate`

<details>
<summary>output</summary>

```
dotnet nuget verify "package.nupkg" -v n
Verifying packageA.1.0.0
C:\Users\kapenaga\Downloads\package.nupkg
Signature Hash Algorithm: SHA256

Signature type: Author
Verifying the author primary signature with signing certificate:
  Subject name: CN=test
  SHA1 hash: B0A2B3B1695AB8361B1D2B14A9F5D64136E26380
  SHA256 hash: 89A2B6EB529E0AEBF0D11C8A18A846C7B8D1290791B6BF494BAFEC299F2EAAB2
  Issued by: CN=test
  Valid from: 1/29/2021 12:28:11 PM to 02/29/2022 1:28:11 PM
Timestamp: 2/3/2021 3:36:12 PM
Verifying author primary signature's timestamp with timestamping service certificate:
  Subject Name: CN=Entrust Timestamp Authority - TSA1, O="Entrust, Inc.", L=Ottawa, S=Ontario, C=CA
  SHA1 hash: 94A59549D6E7CE926ED8D2625E1C2ADEBA04C37F
  SHA256 hash: 950A26FDC7C02018E9F791A95C38F26EEF3DA43267CAB0CD15A555AF631072C9
  Issued by: CN=Entrust Timestamping CA - TS1, OU="(c) 2015 Entrust, Inc. - for authorized use only", OU=See www.entrust.net/legal-terms, O="Entrust, Inc.", C=US
  Valid from: 7/22/2020 3:33:29 PM to 12/29/2030 4:29:23 PM

Finished with 1 errors and 2 warnings.
error: NU3028: The author primary signature's timestamping certificate is not trusted by the trust provider.
warn : NU3028: The author primary signature's timestamp found a chain building issue: The revocation function was unable to check revocation because the revocation server could not be reached. For more information, visit https://aka.ms/certificateRevocationMode.
warn : NU3028: The author primary signature's timestamp found a chain building issue: RevocationStatusUnknown: The revocation function was unable to check revocation for the certificate.

Package signature validation failed.
```

</details>

#### `Debian case - Verifying expired author signed package with untrusted timestamping signing certificate`

<details>
<summary>output</summary>

```
dotnet nuget verify "AuthorExpired.1.0.0.nupkg" -v n
Verifying packageA.1.0.0
C:\Users\kapenaga\Downloads\package.nupkg
Signature Hash Algorithm: SHA256

Signature type: Author
Verifying the author primary signature with signing certificate:
  Subject name: CN=test
  SHA1 hash: B0A2B3B1695AB8361B1D2B14A9F5D64136E26380
  SHA256 hash: 89A2B6EB529E0AEBF0D11C8A18A846C7B8D1290791B6BF494BAFEC299F2EAAB2
  Issued by: CN=test
  Valid from: 1/29/2021 12:28:11 PM to 02/29/2021 1:28:11 PM
Timestamp: 2/3/2021 3:36:12 PM
Verifying author primary signature's timestamp with timestamping service certificate:
  Subject name: CN=NuGet Test Root Certificate Authority (40998d55-3d73-4a3b-a689-55e30c1fac3c), O=NuGet, L=Redmond, S=WA, C=US
  SHA1 hash: 6B2378A3DC9CA185252BB66F24F262D129165B5B
  SHA256 hash: 61B18DE3D814FA7960C6ED62DB20BEA6D0F8D65F678464D7D7C9227E7D5DEFBD
  Issued by: CN=NuGet Test Root Certificate Authority (40998d55-3d73-4a3b-a689-55e30c1fac3c), O=NuGet, L=Redmond, S=WA, C=US
  Valid from: 2/3/2021 3:36:11 PM to 12/31/2099 4:00:00 PM

Finished with 2 errors and 0 warnings.
error: NU3018: The author primary signature's signing certificate is not trusted by the trust provider.
error: NU3028: The author primary signature's timestamping certificate is not trusted by the trust provider.

Package signature validation failed.
```

</details>
