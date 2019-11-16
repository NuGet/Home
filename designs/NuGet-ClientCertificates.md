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
* Ability to specify inline client Base64 encoded DER certificate in [PEM](https://en.wikipedia.org/wiki/Privacy-Enhanced_Mail) format

## Solution

1) Find specified in NuGet configuration file certificates (common implementation for [all products](https://github.com/NuGet/NuGet.Client/tree/dev/src/NuGet.Core/NuGet.Configuration) )
2) Apply them prior any web request to appropriate http handler (product specific)

## NuGet configuration changes

Added new configuration section **clientCertificates** which may have children of 2 types:

**fromStorage** - item for certificate import from [certificate store](https://docs.microsoft.com/en-us/dotnet/framework/wcf/feature-details/working-with-certificates#certificate-stores). Internally uses [X509Certificate2Collection.Find](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509certificate2collection.find?view=netframework-4.8#System_Security_Cryptography_X509Certificates_X509Certificate2Collection_Find_System_Security_Cryptography_X509Certificates_X509FindType_System_Object_System_Boolean_) method.
Can be configured with 4 Add item's

- Optional Key="**StoreLocation**" Value="[possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storelocation?view=netframework-4.8#fields)".  
Equals '**CurrentUser**' by default
- Optional Key="**StoreName**" Value="[possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storename?view=netframework-4.8#fields)". 
Equals '**My**' by default
- Optional Key="**FindType**" Value="[possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509findtype?view=netframework-4.8#fields)". 
Equals '**FindByThumbprint**' by default
- Optional Key="**FindValue**" Value="The search criteria as an object"

- **fromFile** - item for certificate import directly from file (DER encoded x.509, Base-64 encoded x.509, PKCS)
Can be configured with 2 Add item's

- Key="**Path**" Value="Absolute or relative path to certificate file". Relative path resolve have 2 stages: first relative to configuration file origin, second relative to current application directory.
- Optional Key="**Password**" Value="Encrypted password". Password for certificate file. Encrypted in same manner as PackageSourceCredential password.

- **fromPEM** - item for certificate import directly from configuration body (Base-64 encoded x.509 in PEM format)
Can be configured with 1 optional Add item

- Items body must  be filled with [PEM](https://en.wikipedia.org/wiki/Privacy-Enhanced_Mail) (Base-64 encoded x.509 certificate). Start and end of text are trimmed from spaces and new line chars.

- Optional Key="**Password**" Value="Encrypted password". Password for certificate file. Encrypted in same manner as PackageSourceCredential password.


## Configuration example

```xml
<configuration>
...
    <clientCertificates>	
        <fromStorage>
            <!-- Optional. CurrentUser by default -->
            <add key="StoreLocation" value="CurrentUser" />
            <!-- Optional. My by default -->
            <add key="StoreName" value="My" />
            <!-- Optional. FindByThumbprint by default -->
            <add key="FindType" value="FindByThumbprint" />
            <!-- Required. -->
            <add key="FindValue" value="4894671ae5aa84840cc1079e89e82d426bc24ec6" />
        </fromStorage>
        <fromFile>
            <!-- Absolute or relative path to certificate file. -->
            <add key="Path" value=".\certificate.pfx" />
            <!-- Encrypted password -->
            <add key="Password" value="..." />
        </fromFile>
        <fromPEM>
-----BEGIN CERTIFICATE-----
MIIEjjCCA3agAwIBAgIJIBkBGf8AAAAPMA0GCSqGSIb3DQEBCwUAMIGzMQswCQYD
...
tJl1UvF7GWJd0yNyPVqCCnBY
-----END CERTIFICATE-----
        </fromPEM>
    </clientCertificates>
...
</configuration>
```

## Configuration components implementation

Added several new SettingItem's to parse configuration above. Certificates search logic encapsulated inside.

For high level usage were introduced:

`ClientCertificateProvider` class
* `Provide(settings:ISettings) : IEnumerable<X509Certificate>` - extracts certificates from settings

`ClientCertificates` static singleton certificate storage.
* `Store(certificates: IEnumerable<X509Certificate>)` - stores certificate instances
* `SetupClientHandler(httpClientHandler:HttpClientHandler)` - adds stored certificates to HttpClientHandler instance. 

## NuGet Cli implementation as example

1) Internally certificates extracted from configuration items on base [Command.Execute](https://github.com/NuGet/NuGet.Client/blob/d4f53c3e523493fcbe35c537cb004e9a3e228abd/src/NuGet.Clients/NuGet.CommandLine/Commands/Command.cs) with `ClientCertificateProvider.Provide` method
2) Extracted certificates stored as singleton inside static `ClientCertificates` class with `ClientCertificates.Store` method.
2) On any [HttpHandlerResourceV3 creation](https://github.com/NuGet/NuGet.Client/blob/d4f53c3e523493fcbe35c537cb004e9a3e228abd/src/NuGet.Core/NuGet.Protocol/HttpSource/HttpHandlerResourceV3Provider.cs) internal `HttpClientHandler` filled with configured certificates with `ClientCertificates.SetupClientHandler` method.

## Implementation pull request

[3098](https://github.com/NuGet/NuGet.Client/pull/3098) Implemented fromStorage and fromCert client certificates
