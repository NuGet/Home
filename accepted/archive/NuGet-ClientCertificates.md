## Client certificates in NuGet

Implements: https://github.com/NuGet/Home/issues/5773
* Status: **Approved, pending implementation**
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

Developers using NuGet packages, with a private source that needs HTTPS client certificates for either or both of:
* mutual connection security
* certificate based authentication.

## Requirements

* Ability to specify client certificates from common [certificate stores](https://docs.microsoft.com/en-us/dotnet/framework/wcf/feature-details/working-with-certificates#certificate-stores)
* Ability to specify client certificates from external files in standard [formats](https://en.wikipedia.org/wiki/X.509#Certificate_filename_extensions)
* Ability to configure settings with command line
* Each source can have at most one client certificate configuration
* If client certificate configuration returns several valid x509 certificates (storeCert for example) first instance will be used
* Client certificate configurations can be overwritten in common way

## Solution

1) Find specified in NuGet configuration file certificates (common implementation for [all products](https://github.com/NuGet/NuGet.Client/tree/dev/src/NuGet.Core/NuGet.Configuration) )
2) Apply them prior any web request to appropriate http handler (product specific)

## NuGet configuration changes

Provide new configuration section `clientCerts` which may have children of 2 types:

1. `storeCert` - certificate import from [certificate store](https://docs.microsoft.com/en-us/dotnet/framework/wcf/feature-details/working-with-certificates#certificate-stores). Internally uses [X509Certificate2Collection.Find](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509certificate2collection.find?view=netframework-4.8#System_Security_Cryptography_X509Certificates_X509Certificate2Collection_Find_System_Security_Cryptography_X509Certificates_X509FindType_System_Object_System_Boolean_) method.
Can be configured with:
    - Attribute `packageSource`. Required. `packageSources` source name reference.
    - Attribute `storeLocation`. [Possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storelocation?view=netframework-4.8#fields). Optional. Equals `CurrentUser` by default.
    - Attribute `storeName`. [Possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storename?view=netframework-4.8#fields). Optional. Equals `My` by default.
    - Attribute `findBy`. [Possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509findtype?view=netframework-4.8#fields) with out FindBy prefix. Optional. Equals `thumbprint` by default.
    - Attribute `findValue`. `value` - the search criteria as an object. Required.

2. `fileCert` - certificate import from file (DER encoded x.509, Base-64 encoded x.509, PKCS)
Can be configured with:
    - Attribute `packageSource`. Required. `packageSources` source name reference.
    - Attribute `path`. Absolute or relative path to certificate file. Required.
    - Attribute `password`. Encrypted password string. Optional. Encrypted in same manner as [PackageSourceCredential](https://docs.microsoft.com/en-us/nuget/reference/nuget-config-file#packagesourcecredentials) password.
    - Attribute `clearTextPassword`. The unencrypted password string. Optional.

It is denied to use `password` and `clearTextPassword` attributes at the same time.

## Configuration example

```xml
<configuration>
    ...
    <packageSources>
        <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
        <add key="Contoso" value="https://contoso.com/packages/" />
        <add key="Foo" value="https://foo.com/bar/packages/" />
    </packageSources>
    ...
    <clientCertificates>	
        <storeCert packageSource="Contoso"
                   storeLocation="currentUser"
                   storeName="my"
                   findBy="thumbprint" 
                   findValue="4894671ae5aa84840cc1079e89e82d426bc24ec6" />
        <fileCert packageSource="Foo"
                  path=".\certificate.pfx" 
                  password="..." />
        <fileCert packageSource="Bar"
                  path=".\certificate.pfx" 
                  clearTextPassword="..." />
    </clientCertificates>
...
</configuration>
```
# NuGet.exe

## client-certs command

Gets, updates, sets or lists client certificates to the NuGet configuration.

Usage
```
nuget client-certs <list|add|remove|update> [options]
```

if none of `list|add|remove|update` is specified, the command will default to `list`.

### nuget client-certs list [options]

Lists all the client certificates in the configuration. This option will include all configured client certificates.

Below is an example output from this command:

```
Registered client certificates:

 1.   Contoso [fileCert]
      Path: d:\Temp\nuget\foo.pfx
      Password: ****
      Certificate: 4894671AE5AA84840C31079E89E82D426BC24EC6

 2.   Foo [storeCert]
      Store location: CurrentUser
      Store name: My
      Find by: Thumbprint
      Find value: ba4d3cc1f011388626a23af5627bb4721d44db6e
      Certificate: BA4D3CC1F011388626A23AF5627BB4721D44DB6E
      
 3.   Fabrikam inc [storeCert]
      Store location: LocalMachine
      Store name: Root
      Find by: IssuerName
      Find value: Fabrikam
      Certificate: Not found
```

### nuget client-certs add [options]

- `-PackageSource` `string` - Required option. Determines to which package source client certificate will be applied to. If there are any existing client certificate configuration which points to specified source command will fail.

- `-Path` `string` - Path to certificate file added to a file client certificate source.

- `-Password` `string` - Password for the certificate, if needed. This option can be used to specify the password for the certificate. Available only for from file source types.

- `-StorePasswordInClearText` `boolean` - Enables storing password for the certificate by disabling password encryption. Default value: false

- `-StoreLocation` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storelocation?view=netframework-4.8) - StoreLocation added to a storage client certificate source. Default value: CurrentUser

- `-StoreName` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storename?view=netframework-4.8) - StoreName added to a storage client certificate source. Default value: My

- `-FindBy` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509findtype?view=netframework-4.8) with out FindBy prefix - FindBy added to a storage client certificate source. Default value: Thumbprint

- `-FindValue` `string` - FindValue added to a storage client certificate source.

- `-Force` - Bypass certificate validatation.

`-Path` and `-Password` options determine final certificate source type as `fileCert`

`-StoreLocation`, `-StoreName`, `-FindBy` and `-FindValue` options determine final certificate source type as `storeCert`

It is denied to use options from different certificate source type at the same time.

Configuration change will not be applied if certificate is not valid.

### nuget client-certs update [options]

- `-PackageSource` `string` - Required option. Determines to which existing package source client certificate will be applied to.

- `-Path` `string` - Path to certificate file added to a file client certificate source.

- `-Password` `string` - Password for the certificate, if needed. This option can be used to specify the password for the certificate. Available only for from file source types.

- `-StorePasswordInClearText` `string` - Enables storing password for the certificate by disabling password encryption. Default value: false

- `-StoreLocation` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storelocation?view=netframework-4.8) - StoreLocation added to a storage client certificate source. Default value: CurrentUser

- `-StoreName` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storename?view=netframework-4.8) - StoreName added to a storage client certificate source. Default value: My

- `-FindBy` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509findtype?view=netframework-4.8) with out FindBy prefix - FindBy added to a storage client certificate source. Default value: Thumbprint

- `-FindValue` `string` - FindValue added to a storage client certificate source.

- `-Force` - Bypass certificate validatation.

`-Path` and `-Password` options determine final certificate source type as `fileCert`

`-StoreLocation`, `-StoreName`, `-FindBy` and `-FindValue` options determine final certificate source type as `storeCert`

It is denied to use options from different certificate source type at the same time.

Command will fail if user tries to change initial certificate source type.

Configuration change will not be applied if certificate is not valid.

### nuget client-certs remove -PackageSource <name>

Removes any client certificate configuration that match the given package source name.

### Examples

```
nuget client-certs Add -PackageSource Foo -Path .\MyCertificate.pfx

nuget client-certs Add -PackageSource Contoso -Path c:\MyCertificate.pfx -Password 42

nuget client-certs Add -PackageSource Foo -FindValue ca4e7b265780fc87f3cb90b6b89c54bf4341e755

nuget client-certs Add -PackageSource Contoso -StoreLocation LocalMachine -StoreName My -FindBy Thumbprint -FindValue ca4e7b265780fc87f3cb90b6b89c54bf4341e755

nuget client-certs Update -PackageSource Foo -FindValue ca4e7b265780fc87f3cb90b6b89c54bf4341e755

nuget client-certs Remove -PackageSource certificateName

nuget client-certs

nuget client-certs List
```

# dotnet tool

## dotnet nuget <command> client-cert

Bunch of commands similar to NuGet.exe client-certs. 

Gets, updates, sets or lists client certificates to the NuGet configuration.

Usage
```
dotnet nuget <list|add|remove|update> client-cert [options]
```
### dotnet nuget list client-cert [options]

Lists all the client certificates in the configuration. This option will include all configured client certificates.

### dotnet nuget add client-cert [options]

- `-s|--package-source` `string` - Required option. Determines to which package source client certificate will be applied to. If there are any existing client certificate configuration which points to specified source command will fail.

- `--path` `string` - Path to certificate file added to a file client certificate source.

- `--password` `string` - Password for the certificate, if needed. This option can be used to specify the password for the certificate. Available only for from file source types.

- `--store-password-in-clear-text` `string` - Enables storing password for the certificate by disabling password encryption. Default value: false

- `--store-location` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storelocation?view=netframework-4.8) - StoreLocation added to a storage client certificate source. Default value: CurrentUser

- `--store-name` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storename?view=netframework-4.8) - StoreName added to a storage client certificate source. Default value: My

- `--find-by` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509findtype?view=netframework-4.8) with out FindBy prefix - FindBy added to a storage client certificate source. Default value: Thumbprint

- `--find-value` `string` - FindValue added to a storage client certificate source.

- `-f|--force` - Bypass certificate validatation.

`--path` and `--password` options determine final certificate source type as `fileCert`

`--store-location`, `--store-name`, `--find-by` and `--find-value` options determine final certificate source type as `storeCert`

It is denied to use options from different certificate source type at the same time.

If certificate does not exist tool will inform user with warning but still option will be added.

Configuration change will not be applied if certificate is not valid.

### dotnet nuget update client-cert [options]

- `-s|--package-source` `string` - Required option. Determines to which existing package source client certificate will be applied to.

- `--path` `string` - Path to certificate file added to a file client certificate source.

- `--password` `string` - Password for the certificate, if needed. This option can be used to specify the password for the certificate. Available only for from file source types.

- `--store-password-in-clear-text` `string` - Enables storing password for the certificate by disabling password encryption. Default value: false

- `--store-location` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storelocation?view=netframework-4.8) - StoreLocation added to a storage client certificate source. Default value: CurrentUser

- `--store-name` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storename?view=netframework-4.8) - StoreName added to a storage client certificate source. Default value: My

- `--find-by` [possible values](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509findtype?view=netframework-4.8) with out FindBy prefix - FindBy added to a storage client certificate source. Default value: Thumbprint

- `--find-value` `string` - FindValue added to a storage client certificate source.

- `-f|--force` - Bypass certificate validatation.

`--path` and `--password` options determine final certificate source type as `fileCert`

`--store-location`, `--store-name`, `--find-by` and `--find-value` options determine final certificate source type as `storeCert`

It is denied to use options from different certificate source type at the same time.

Command will fail if user tries to change initial certificate source type.

Configuration change will not be applied if certificate is not valid.

### dotnet nuget update client-cert [options]

- `-s|--package-source` `string` - Required option. Determines to which existing package source client certificate will be applied to.

Removes any client certificate configuration that match the given package source name.

### Examples

```
dotnet nuget add client-cert --package-source Foo --path .\MyCertificate.pfx

dotnet nuget add client-cert --package-source Contoso --path c:\MyCertificate.pfx --password 42

dotnet nuget add client-cert --package-source Foo --find-value ca4e7b265780fc87f3cb90b6b89c54bf4341e755

dotnet nuget add client-cert -s Contoso --store-location localMachine --store-name my --find-by thumbprint --find-value ca4e7b265780fc87f3cb90b6b89c54bf4341e755

dotnet nuget update client-cert --package-source Foo --find-value ca4e7b265780fc87f3cb90b6b89c54bf4341e755

dotnet nuget remove client-cert -s certificateName

dotnet nuget list client-cert
```
