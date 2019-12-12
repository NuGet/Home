## Client certificates in NuGet

Implements: https://github.com/NuGet/Home/issues/5773
* Status: **Purposed**
* Author(s): [Shkolka Volodymyr](https://github.com/BlackGad)

## Issue

[5773](https://github.com/NuGet/Home/issues/5773) - NuGet cannot restore from HTTPS sources that require Client Certificates

## Background

Developer tools that supports [Client Certificate Authentication](https://blogs.msdn.microsoft.com/kaushal/2015/05/27/client-certificate-authentication-part-1/).
* [NPM](https://docs.npmjs.com/misc/config#cert)
* [Maven](https://maven.apache.org/guides/mini/guide-repository-ssl.html)
* [Teamcity](https://www.jetbrains.com/help/teamcity/using-https-to-access-teamcity-server.html#UsingHTTPStoaccessTeamCityserver-ConfiguringJVMforauthenticationwithclientcertificate)

It is necessary to add client certificate authentication feature support to NuGet.

## Who are the customers

All .NET Core customers.

## Requirements

* Ability to specify client certificates from common [certificate stores](https://docs.microsoft.com/en-us/dotnet/framework/wcf/feature-details/working-with-certificates#certificate-stores)
* Ability to specify client certificates from external files in standard [formats](https://en.wikipedia.org/wiki/X.509#Certificate_filename_extensions)
* Ability to configure settings with command line

## Solution

1) Find specified in NuGet configuration file certificates (common implementation for [all products](https://github.com/NuGet/NuGet.Client/tree/dev/src/NuGet.Core/NuGet.Configuration) )
2) Apply them prior any web request to appropriate http handler (product specific)

## NuGet configuration changes

Provide new configuration section `clientCertificates` which may have children of 2 types:

1. `fromStorage` - certificate import from [certificate store](https://docs.microsoft.com/en-us/dotnet/framework/wcf/feature-details/working-with-certificates#certificate-stores). Internally uses [X509Certificate2Collection.Find](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509certificate2collection.find?view=netframework-4.8#System_Security_Cryptography_X509Certificates_X509Certificate2Collection_Find_System_Security_Cryptography_X509Certificates_X509FindType_System_Object_System_Boolean_) method.
Can be configured with:
    - Attribute `name`. Required. Unique setting identifier.
    - Child item `<Add Key="StoreLocation" Value="[values]" />`. [Possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storelocation?view=netframework-4.8#fields). Optional. Equals `CurrentUser` by default.
    - Child item `<Add Key="StoreName" Value="[values]" />`. [Possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storename?view=netframework-4.8#fields). Optional. Equals `My` by default.
    - Child item `<Add Key="FindType" Value="[values]" />`. [Possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509findtype?view=netframework-4.8#fields). Optional. Equals `FindByThumbprint` by default.
    - Child item `<Add Key="FindValue" Value="value" />`. `value` - the search criteria as an object. Required.

2. `fromFile` - certificate import from file (DER encoded x.509, Base-64 encoded x.509, PKCS)
Can be configured with:
    - Attribute `name`. Required. Unique setting identifier.
    - Child item `<Add Key="Path" Value="value" />`. `value` - Absolute or relative path to certificate file. Required.
    - Child item `<Add Key="Password" Value="value" />`. `value` - Plain or encrypted password string. Optional. Encrypted in same manner as PackageSourceCredential password.

## Configuration example

```xml
<configuration>
...
    <clientCertificates>	
        <fromStorage name="unique name 1">
            <!-- Require at least one reference to source -->
            <add key="TargetSource" value="<source name from packageSources section>" />
            <!-- Optional. CurrentUser by default -->
            <add key="StoreLocation" value="CurrentUser" />
            <!-- Optional. My by default -->
            <add key="StoreName" value="My" />
            <!-- Optional. FindByThumbprint by default -->
            <add key="FindType" value="FindByThumbprint" />
            <!-- Required. -->
            <add key="FindValue" value="4894671ae5aa84840cc1079e89e82d426bc24ec6" />
        </fromStorage>
        <fromFile name="unique name 2">
            <!-- Require at least one reference to source -->
            <add key="TargetSource" value="<source name from packageSources section>" />
            <!-- Absolute or relative path to certificate file. -->
            <add key="Path" value=".\certificate.pfx" />
            <!-- Encrypted password -->
            <add key="Password" value="..." />
        </fromFile>
    </clientCertificates>
...
</configuration>
```

## client-certificates command

Gets, sets or lists client certificates to the NuGet configuration.

Usage
```
nuget client-certificates <list|add|remove> [options]
```

if none of `list|add|remove` is specified, the command will default to `list`.

### nuget client-certificates list [options]

Lists all the client certificates in the configuration. This option will include all configured client certificates that match to specified options.

- `-Check` one of `true|false` - Indicates that certificate existence must be checked. If the certificate is found, its fingerprint will be printed.

- `-SourceType` one of `file|storage` - Filter available client certificates by it's source type.

- `-Name` `string` - Filter client certificates **from all sources** by string presence in it's name.

- `-Path` `string` - Filter client certificates **from file source** by string presence in it's Path.

- `-StoreLocation` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storelocation?view=netframework-4.8) - Filter client certificates **from storage source** by it's StoreLocation.

- `-StoreName` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storename?view=netframework-4.8) - Filter client certificates **from storage source** by it's StoreName.

- `-FindType` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509findtype?view=netframework-4.8) - Filter client certificates **from storage source** by it's FindType.

- `-FindValue` `string` - Filter client certificates from storage source by string presence in it's FindValue.

Below is an example output from this command:

```
Registered client certificates:


 1.   file3 [fromFile]
      Path: d:\Temp\nuget\foo.pfx
      Password: ****
      Certificate: 4894671AE5AA84840C31079E89E82D426BC24EC6

 2.   Foo organization certificate in storage [fromStorage]
      Store location: CurrentUser
      Store name: My
      Find type: FindByThumbprint
      Find value: ba4d3cc1f011388626a23af5627bb4721d44db6e
      Certificate: BA4D3CC1F011388626A23AF5627BB4721D44DB6E
```

### nuget client-certificates add [options]

- `-Check` one of `true|false` - Indicates that certificate existence must be checked before add action. If the certificate is not found it will not be added.

- `-Name` `string` - Required option for client certificate identification. If certificate with same name exist it will be updated.

- `-Path` `string` - Path to certificate file added to a file client certificate source.

- `-TargetSource` `string` - Required semicolon separated option to specify NuGet sources on which client certificate will be applied.

- `-Password` `string` - Password for the certificate, if needed. This option can be used to specify the password for the certificate. Available only for from file source types.

- `-StorePasswordInClearText` `string` - Enables storing password for the certificate by disabling password encryption. Default value: false

- `-StoreLocation` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storelocation?view=netframework-4.8) - StoreLocation added to a storage client certificate source. Default value: CurrentUser

- `-StoreName` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storename?view=netframework-4.8) - StoreName added to a storage client certificate source. Default value: My

- `-FindType` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509findtype?view=netframework-4.8) - FindType added to a storage client certificate source. Default value: FindByThumbprint

- `-FindValue` `string` - FindValue added to a storage client certificate source.



Providing `-Path` and one of `-StoreLocation`, `-StoreName`, `-FindType`, `-FindValue` at the same time is not supported.

### nuget client-certificates remove -Name <name>

Removes any client certificate that match the given name.

### Examples

```
nuget client-certificates Add -Name certificateName -Path .\MyCertificate.pfx -TargetSource "Foo"

nuget client-certificates Add -Name certificateName -Path c:\MyCertificate.pfx -TargetSource "Foo;Bar" -Password 42 -Check true

nuget client-certificates Add -Name certificateName -FindValue ca4e7b265780fc87f3cb90b6b89c54bf4341e755 -TargetSource "Foo"

nuget client-certificates Add -Name certificateName -StoreLocation LocalMachine -StoreName My -FindType FindByThumbprint -FindValue ca4e7b265780fc87f3cb90b6b89c54bf4341e755 -TargetSource "Foo"

nuget client-certificates Remove -Name certificateName

nuget client-certificates

nuget client-certificates List -Check true

nuget client-certificates List -Name containsInName

nuget client-certificates List -SourceType storage
```

## Internal components

Provide `IClientCertificateProvider` generic provider for client certificate management from `ISettings`. Also provide `ClientCertificates` processor for `HttpClientHandler` setup.

### IClientCertificateProvider interface

* `AddOrUpdate(item : CertificateSearchItem)` - Adds a new client certificate or updates an existing one in the settings.
* `Remove(item : IReadOnlyList<CertificateSearchItem>)` - Removes client certificates from the settings.
* `GetClientCertificates(sourceName : string) : IReadOnlyList<CertificateSearchItem>` - Get a list of all the trusted signer entries under the computer trusted signers section for specified source name.

## Implementation pull request

[3098](https://github.com/NuGet/NuGet.Client/pull/3098) Implemented fromStorage and fromCert client certificates
