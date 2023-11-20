# Allow insecure connections and disable certificate validation

- [Jon Douglas](https://github.com/jondouglas)
- Start Date (2023-04-13)
- [#4387](https://github.com/NuGet/Home/issues/4387), [#12015](https://github.com/NuGet/Home/issues/12015)

## Summary

<!-- One-paragraph description of the proposal. -->
NuGet does not provide much functionality for controlling the decisions of trust against http and https sources. In recent surveys, we have even seen a general sentiment towards using 2 or more sources for their projects. Many of these sources have different security requirements that should be up to the developer to decide on. 

There are two functionalities that need to be added to NuGet tooling to help companies move over to a "HTTPS Everywhere" ideal world.

1. I have a HTTP server and don't want the HTTPS warning/error.
2. I have a HTTPS server and I want to ignore SSL/TLS certification validation.

In both of these cases, developers would like more fine-grain control to opt-out of these security best practices such in cases where they have their own local http source or are self-signing with a certificate.

## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
When we blogged about an initial plan about ["HTTPS Everywhere" for NuGet](https://devblogs.microsoft.com/nuget/https-everywhere/), we were met with widespread feedback on scenarios we aren't always aware of. The primary scenario is that a company may have a HTTP source on a local network that they would like to remain using based on their other company security practices. There's also still a challenge of obtaining a SSL/TLS certificate which may take longer than the timeline we initially proposed (~3 years).

With this feedback in mind, we would like to ensure that we have a generally agreed upon plan that provides these mechanism for flexibility based on where you are personally on your journey to "HTTPS Everywhere" in the [.NET 8 timeframe given it is a LTS](https://dotnet.microsoft.com/en-us/platform/support/policy). While these mechanisms are not recommended to use long-term and generally are seen as not an ideal security practice, we believe that it is not our place to push specific security ideology and rather make our tools flexible to meet everyone where they are.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

There will be multiple ways to opt-out of these two functionalities described above.

#### Package Source NuGet Config

A developer may have anywhere from 2+ sources defined in their projects based on recent survey data. Each package source has its own unique security requirements and a developer should have control on a per package source basis where they can apply the `disableTLSCertificateValidation` property to a HTTPS source. If applied to a HTTP source, nothing will happen. A developer should also be able to apply the `allowInsecureConnections` property to a HTTP source. If applied to a HTTPS source, nothing will happen.

```
<!-- Disables certification validation on a specific https source and allows insecure connections on a specific http source -->
<packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" disableTLSCertificateValidation="true" />
    <add key="Contoso" value="http://contoso.com/packages/" allowInsecureConnections="true" />
    <add key="Test Source" value="c:\packages" />
</packageSources>
```

### Redacted Functional Experiences (based on community feedback)

#### Global NuGet.config

A developer may choose to want a global setting applied to all sources in which they may allow insecure connections on any defined HTTP source and disable certificate validation on any defined HTTPS source.

```
<!-- Disables certification validation for all HTTPS sources and allows insecure connections from all  HTTP sources -->
<config>
    <add key="allowInsecureConnections" value="true" />
    <add key="disableCertificateValidation" value="true" />
</config>
```

#### Package Source NuGet Config (Alternate) - Not ideal for UX or discoverability.

In the case that additional metadata cannot be added to the `<packageSources>` children, we can invent a new section similar to previously designed features where one can specify if a package source is deemed insecure or not. This will opt-out completely out of both scenarios.

```
<!-- Allows insecure http source and ignores certificate validation for https source -->
<insecurePackageSources>
    <add key="Contoso" value="true" />
</insecurePackageSources>
```

#### NuGet Environment Variables

A developer may not want to check in an insecure configuration file and may want to have a local machine or CI/CD override for these scenarios. The following environment variables would behave similarly to the global NuGet config concept above.

- `NUGET_ALLOW_INSECURE_CONNECTIONS` - Allows insecure/HTTP sources.
- `NUGET_DISABLE_CERTIFICATE_VALIDATION` - Disables certificate validation for HTTPS sources.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->
This section will be filled out by the respective person picking up this work in more detail if more needs to be explained. 

`HttpClient` and `HttpClientHandler` should be able to support this functionality easily such as a custom `ServerCertificateCustomValidationCallback` which always returns `true` meaning that any certificate presented by the server will be considered valid for the `disableTLSCertificateValidation` functionality.

As for `allowInsecureConnections`, this functionality should be fairly easy to revert the initial warning/error messages to take into account this new flag. Simply put, if there's no code flow to this property, a user will continue to see HTTPS warnings/errors encouraging best practice. 

## Drawbacks

<!-- Why should we not do this? -->
- Bypassing HTTP and certificate validation can be dangerous and should only be done if you are absolutely sure the server you are connecting to is trustworthy.
- While the intention is a stopgap meeting where developers are today, it could promote bad security practices.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
There are a number of ideas and proposals on the GitHub issues listed above. I have tried to combine them into simple and practical explanations with comparison to other tools adjacent to ours and their similar behaviors. I'm not diving into the specific scenarios for each of these behaviors, but rather just providing a high-level ability to turn off the checks that align with other tools.

By default, every secure connection NuGet makes is verified to be secure before the transfer takes place. Using these options makes the transfer insecure.

Here are two other alternatives that could be considered although they add a bit of a barrier to use.

1. Make this feature user-specific for the nuget.config & properties. It is suggested there are a couple existing nuget.config features(proxy for example) that are only enabled if they are found in the scope of the `user` settings. See https://learn.microsoft.com/nuget/consume-packages/configuring-nuget-behavior#how-settings-are-applied for more details.
2. Add detection for common local network sources. This would require a known list of these sources and ensuring it covers the common scenarios. We currently do not know what these are and would have to extend more customer development to learn. To my knowledge at the time of writing this, no other ecosystem does this.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->
- curl has `--insecure` - https://curl.se/docs/manpage.html#-k
- npm has `strict-ssl` - https://docs.npmjs.com/cli/v6/using-npm/config#strict-ssl
- composer has `disable-tls` and `secure-http` - https://getcomposer.org/doc/06-config.md#disable-tls
- maven wagon has a number of settings - https://maven.apache.org/wagon/wagon-providers/wagon-http/

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->
- Are these the best descriptive names for these behaviors?
    - Could they be simplified more?
        - Other suggestions are: `DisableHttpsCertificateValidation`, `DisableTLSCertificateValidation`, and `DisableSSLCertificateValidation` (SSL is deprecated).
            - These suggestions are to not confuse the current [package signing verification](https://learn.microsoft.com/dotnet/core/tools/nuget-signed-package-verification) feautres.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
- This can help many companies and developers on their path to get to "HTTPS Everywhere". There are no known other possibilities at this time.
- These flags can provide warnings in the far future when HTTPS adoption is significant.
- Finer grain control of SSL checks can be added in the future if desired such as matching certificates to IP/DNS, ignoring validity dates, and overriding CA entries.
