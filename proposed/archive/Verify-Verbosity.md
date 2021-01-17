# `dotnet nuget verify --verbosity`

* Status: **Draft**
* Author: [Kartheek Penagamuri](https://github.com/kartheekp-ms)
* Issue: [#10316](https://github.com/NuGet/Home/issues/10316) - dotnet nuget verify is too quiet

## Problem background

`--verbosity` option available on the `dotnet nuget verify` command doesn't provide any output by default due to logical error in the code. Customers need information about packages’ signatures to [manage package trust boundaries](https://docs.microsoft.com/en-us/nuget/consume-packages/installing-signed-packages).

## Who are the customers

Package consumers that use the `dotnet nuget verify` command to verify package signature and configure NuGet security policy.

## Goals

* Change the output of `dotnet nuget verify` command for various `--verbosity` options.

## Non-goals

* Add `--verbosity` option to `dotnet nuget verify` command.

## Solution

### Situation before this design

Currently, the default verbosity for `dotnet` commands is [`LogLevel.Information`](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.CommandLine.XPlat/Program.cs#L31). If the user didn't pass value for `--verbosity` option, then the log level is set to [`LogLevel.Minimal`](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.CommandLine.XPlat/Commands/Signing/VerifyCommand.cs#L58) due to logical error in the `dotnet nuget verify` command implementation. Hence by default this command does not display any log messages.

### Changes required

The details that should be displayed on each verbosity level are described below. Each level should display the same as the level below plus whatever is specified in that level. In that sense, `quiet` will be give the less amount of information, while `diagnostic` the most.

​                                  | `q[uiet]` | `m[inimal]` | `n[ormal]` | `d[etails]` | `diag[nostic]`
----------------------------------| --------- | ----------- | ---------- | -----------| --------------
`Certificate chain Information`   | ❌       | ❌          | ❌         | ✔️         | ✔️   
`Path to package being verified`  | ❌       | ❌          | ✔️         | ✔️         | ✔️   
`Hashing algorithm used for signature`        | ❌       | ❌          | ✔️         | ✔️         | ✔️   
`Certificate -> SHA1 hash`| ❌       | ❌          | ✔️         | ✔️         | ✔️   
`Certificate -> Issued By`| ❌       | ❌          | ✔️         | ✔️         | ✔️   
`Certificate -> Subject`| ❌       | ❌          | ✔️         | ✔️         | ✔️   
`Package name being verified`                    | ❌       | ✔️          | ✔️         | ✔️         | ✔️   
`Type of signature (author or repository)`| ❌       | ✔️          | ✔️         | ✔️         | ✔️   
`Certificate -> SHA-256 hash`| ❌       | ✔️          | ✔️         | ✔️         | ✔️   
`Certificate -> Validity period`| ❌       | ✔️          | ✔️         | ✔️         | ✔️   
`Certificate -> Service index URL (If applicable)`| ❌       | ✔️          | ✔️         | ✔️         | ✔️   

### Log level mapping - The following details are copied from [here](https://github.com/NuGet/Home/blob/dev/designs/Package-List-Verbosity.md#log-level-mapping). Thanks to [Joel Verhagen](https://github.com/joelverhagen) for the detailed information

The provided `--verbosity` value will include to NuGet log messages with the following levels:

​             | `q[uiet]` | `m[inimal]` | `n[ormal]` | `d[etails]` | `diag[nostic]`
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

### Example output

This is output of the invocation of `dotnet nuget verify nuget.common.5.9.0-preview.2.nupkg`

#### Default verbosity | `--verbosity mimimal`

```
Verifying NuGet.Common.5.9.0-preview.2
Signature type: Author
Verifying the author primary signature with certificate:
  SHA256 hash: 3F9001EA83C560D712C24CF213C3D312CB3BFF51EE89435D3430BD06B5D0EECE
  Valid from: 2/25/2018 4:00:00 PM to 1/27/2021 4:00:00 AM
Timestamp: 11/17/2020 7:23:10 AM
Verifying author primary signature's timestamp with timestamping service certificate:
  SHA256 hash: C474CE76007D02394E0DA5E4DE7C14C680F9E282013CFEF653EF5DB71FDF61F8
  Valid from: 12/22/2017 4:00:00 PM to 3/22/2029 4:59:59 PM
Signature type: Repository
nuget-v3-service-index-url: https://api.nuget.org/v3/index.json
nuget-package-owners: Microsoft, nuget
Verifying the repository countersignature with certificate:
  SHA256 hash: 0E5F38F57DC1BCC806D8494F4F90FBCEDD988B46760709CBEEC6F4219AA6157D
  Valid from: 4/9/2018 5:00:00 PM to 4/14/2021 5:00:00 AM
Timestamp: 12/9/2020 2:32:12 PM
Verifying repository countersignature's timestamp with timestamping service certificate:
  SHA256 hash: C474CE76007D02394E0DA5E4DE7C14C680F9E282013CFEF653EF5DB71FDF61F8
  Valid from: 12/22/2017 4:00:00 PM to 3/22/2029 4:59:59 PM
```

#### `--verbosity quiet`

- No output unless if there are any `errors` or `warnings`.

#### `--verbosity normal`

```
Verifying NuGet.Common.5.9.0-preview.2
<PATH>\nuget.common.5.9.0-preview.2.nupkg
Signature Hash Algorithm: SHA256
Signature type: Author
Verifying the author primary signature with certificate: 
  Subject Name: CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
  SHA1 hash: F404000FB11E61F446529981C7059A76C061631E
  SHA256 hash: 3F9001EA83C560D712C24CF213C3D312CB3BFF51EE89435D3430BD06B5D0EECE
  Issued by: CN=DigiCert SHA2 Assured ID Code Signing CA, OU=www.digicert.com, O=DigiCert Inc, C=US
  Valid from: 2/25/2018 4:00:00 PM to 1/27/2021 4:00:00 AM
Timestamp: 11/17/2020 7:23:10 AM
Verifying author primary signature's timestamp with timestamping service certificate: 
  Subject Name: CN=Symantec SHA256 TimeStamping Signer - G3, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  SHA1 hash: A9A4121063D71D48E8529A4681DE803E3E7954B0
  SHA256 hash: C474CE76007D02394E0DA5E4DE7C14C680F9E282013CFEF653EF5DB71FDF61F8
  Issued by: CN=Symantec SHA256 TimeStamping CA, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  Valid from: 12/22/2017 4:00:00 PM to 3/22/2029 4:59:59 PM
Signature type: Repository
nuget-v3-service-index-url: https://api.nuget.org/v3/index.json
nuget-package-owners: Microsoft, nuget
Verifying the repository countersignature with certificate: 
  Subject Name: CN=NuGet.org Repository by Microsoft, O=NuGet.org Repository by Microsoft, L=Redmond, S=Washington, C=US
  SHA1 hash: 8FB6D7FCF7AD49EB774446EFE778B33365BB7BFB
  SHA256 hash: 0E5F38F57DC1BCC806D8494F4F90FBCEDD988B46760709CBEEC6F4219AA6157D
  Issued by: CN=DigiCert SHA2 Assured ID Code Signing CA, OU=www.digicert.com, O=DigiCert Inc, C=US
  Valid from: 4/9/2018 5:00:00 PM to 4/14/2021 5:00:00 AM
Timestamp: 12/9/2020 2:32:12 PM
Verifying repository countersignature's timestamp with timestamping service certificate: 
  Subject Name: CN=Symantec SHA256 TimeStamping Signer - G3, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  SHA1 hash: A9A4121063D71D48E8529A4681DE803E3E7954B0
  SHA256 hash: C474CE76007D02394E0DA5E4DE7C14C680F9E282013CFEF653EF5DB71FDF61F8
  Issued by: CN=Symantec SHA256 TimeStamping CA, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  Valid from: 12/22/2017 4:00:00 PM to 3/22/2029 4:59:59 PM
Successfully verified package 'NuGet.Common.5.9.0-preview.2'.
```

#### `--verbosity detailed`

```
Verifying NuGet.Common.5.9.0-preview.2
<PATH>\nuget.common.5.9.0-preview.2.nupkg
Signature Hash Algorithm: SHA256
Signature type: Author
Verifying the author primary signature with certificate: 
  Subject Name: CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
  SHA1 hash: F404000FB11E61F446529981C7059A76C061631E
  SHA256 hash: 3F9001EA83C560D712C24CF213C3D312CB3BFF51EE89435D3430BD06B5D0EECE
  Issued by: CN=DigiCert SHA2 Assured ID Code Signing CA, OU=www.digicert.com, O=DigiCert Inc, C=US
  Valid from: 2/25/2018 4:00:00 PM to 1/27/2021 4:00:00 AM
trace:       Subject Name: CN=DigiCert SHA2 Assured ID Code Signing CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:       SHA1 hash: 92C1588E85AF2201CE7915E8538B492F605B80C6
trace:       SHA256 hash: 51044706BD237B91B89B781337E6D62656C69F0FCFFBE8E43741367948127862
trace:       Issued by: CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:       Valid from: 10/22/2013 5:00:00 AM to 10/22/2028 5:00:00 AM
trace: 
trace:             Subject Name: CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:             SHA1 hash: 0563B8630D62D75ABBC8AB1E4BDFB5A899B24D43
trace:             SHA256 hash: 3E9099B5015E8F486C00BCEA9D111EE721FABA355A89BCF1DF69561E3DC6325C
trace:             Issued by: CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:             Valid from: 11/9/2006 4:00:00 PM to 11/9/2031 4:00:00 PM
trace: 
Timestamp: 11/17/2020 7:23:10 AM
Verifying author primary signature's timestamp with timestamping service certificate: 
  Subject Name: CN=Symantec SHA256 TimeStamping Signer - G3, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  SHA1 hash: A9A4121063D71D48E8529A4681DE803E3E7954B0
  SHA256 hash: C474CE76007D02394E0DA5E4DE7C14C680F9E282013CFEF653EF5DB71FDF61F8
  Issued by: CN=Symantec SHA256 TimeStamping CA, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  Valid from: 12/22/2017 4:00:00 PM to 3/22/2029 4:59:59 PM
trace:       Subject Name: CN=Symantec SHA256 TimeStamping CA, OU=Symantec Trust Network, O=Symantec Corporation, C=US
trace:       SHA1 hash: 6FC9EDB5E00AB64151C1CDFCAC74AD2C7B7E3BE4
trace:       SHA256 hash: F3516DDCC8AFC808788BD8B0E840BDA2B5E23C6244252CA3000BB6C87170402A
trace:       Issued by: CN=VeriSign Universal Root Certification Authority, OU="(c) 2008 VeriSign, Inc. - For authorized use only", OU=VeriSign Trust Network, O="VeriSign, Inc.", C=US
trace:       Valid from: 1/11/2016 4:00:00 PM to 1/11/2031 3:59:59 PM
trace: 
trace:             Subject Name: CN=VeriSign Universal Root Certification Authority, OU="(c) 2008 VeriSign, Inc. - For authorized use only", OU=VeriSign Trust Network, O="VeriSign, Inc.", C=US
trace:             SHA1 hash: 3679CA35668772304D30A5FB873B0FA77BB70D54
trace:             SHA256 hash: 2399561127A57125DE8CEFEA610DDF2FA078B5C8067F4E828290BFB860E84B3C
trace:             Issued by: CN=VeriSign Universal Root Certification Authority, OU="(c) 2008 VeriSign, Inc. - For authorized use only", OU=VeriSign Trust Network, O="VeriSign, Inc.", C=US
trace:             Valid from: 4/1/2008 5:00:00 PM to 12/1/2037 3:59:59 PM
trace: 
Signature type: Repository
nuget-v3-service-index-url: https://api.nuget.org/v3/index.json
nuget-package-owners: Microsoft, nuget
Verifying the repository countersignature with certificate: 
  Subject Name: CN=NuGet.org Repository by Microsoft, O=NuGet.org Repository by Microsoft, L=Redmond, S=Washington, C=US
  SHA1 hash: 8FB6D7FCF7AD49EB774446EFE778B33365BB7BFB
  SHA256 hash: 0E5F38F57DC1BCC806D8494F4F90FBCEDD988B46760709CBEEC6F4219AA6157D
  Issued by: CN=DigiCert SHA2 Assured ID Code Signing CA, OU=www.digicert.com, O=DigiCert Inc, C=US
  Valid from: 4/9/2018 5:00:00 PM to 4/14/2021 5:00:00 AM
trace:       Subject Name: CN=DigiCert SHA2 Assured ID Code Signing CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:       SHA1 hash: 92C1588E85AF2201CE7915E8538B492F605B80C6
trace:       SHA256 hash: 51044706BD237B91B89B781337E6D62656C69F0FCFFBE8E43741367948127862
trace:       Issued by: CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:       Valid from: 10/22/2013 5:00:00 AM to 10/22/2028 5:00:00 AM
trace: 
trace:             Subject Name: CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:             SHA1 hash: 0563B8630D62D75ABBC8AB1E4BDFB5A899B24D43
trace:             SHA256 hash: 3E9099B5015E8F486C00BCEA9D111EE721FABA355A89BCF1DF69561E3DC6325C
trace:             Issued by: CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US
trace:             Valid from: 11/9/2006 4:00:00 PM to 11/9/2031 4:00:00 PM
trace: 
Timestamp: 12/9/2020 2:32:12 PM
Verifying repository countersignature's timestamp with timestamping service certificate: 
  Subject Name: CN=Symantec SHA256 TimeStamping Signer - G3, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  SHA1 hash: A9A4121063D71D48E8529A4681DE803E3E7954B0
  SHA256 hash: C474CE76007D02394E0DA5E4DE7C14C680F9E282013CFEF653EF5DB71FDF61F8
  Issued by: CN=Symantec SHA256 TimeStamping CA, OU=Symantec Trust Network, O=Symantec Corporation, C=US
  Valid from: 12/22/2017 4:00:00 PM to 3/22/2029 4:59:59 PM
trace:       Subject Name: CN=Symantec SHA256 TimeStamping CA, OU=Symantec Trust Network, O=Symantec Corporation, C=US
trace:       SHA1 hash: 6FC9EDB5E00AB64151C1CDFCAC74AD2C7B7E3BE4
trace:       SHA256 hash: F3516DDCC8AFC808788BD8B0E840BDA2B5E23C6244252CA3000BB6C87170402A
trace:       Issued by: CN=VeriSign Universal Root Certification Authority, OU="(c) 2008 VeriSign, Inc. - For authorized use only", OU=VeriSign Trust Network, O="VeriSign, Inc.", C=US
trace:       Valid from: 1/11/2016 4:00:00 PM to 1/11/2031 3:59:59 PM
trace: 
trace:             Subject Name: CN=VeriSign Universal Root Certification Authority, OU="(c) 2008 VeriSign, Inc. - For authorized use only", OU=VeriSign Trust Network, O="VeriSign, Inc.", C=US
trace:             SHA1 hash: 3679CA35668772304D30A5FB873B0FA77BB70D54
trace:             SHA256 hash: 2399561127A57125DE8CEFEA610DDF2FA078B5C8067F4E828290BFB860E84B3C
trace:             Issued by: CN=VeriSign Universal Root Certification Authority, OU="(c) 2008 VeriSign, Inc. - For authorized use only", OU=VeriSign Trust Network, O="VeriSign, Inc.", C=US
trace:             Valid from: 4/1/2008 5:00:00 PM to 12/1/2037 3:59:59 PM
trace: 
Successfully verified package 'NuGet.Common.5.9.0-preview.2'.
```

#### `--verbosity diagnostic`

- Same output as `--verbosity detailed`
