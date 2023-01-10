# Title

- Andy Zivkovic ([zivkan](https://github.com/zivkan))
- Start Date (2022-12-15)
- GitHub Issue (https://github.com/NuGet/Home/issues/6437)
- GitHub PR (not yet implemented)

## Summary

<!-- One-paragraph description of the proposal. -->

Enable unencrypted API keys in `nuget.config` files, so that they can be used on platforms other than Windows.

## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->

Currently `nuget.config` `<apikeys>` section only supports encrypted values, via .NET's [`System.Security.Cryptography.ProtectedData` APIs](https://learn.microsoft.com/dotnet/api/system.security.cryptography.protecteddata).
As the important message says on the docs page, on Windows it uses Windows' Data Protection API (DPAPI), which isn't supported on Linux or Mac, and [the .NET libraries team have no plans to support it since it will have different security promises than on Windows](https://github.com/dotnet/runtime/issues/22886).
There is [an issue to consider another way of having less secure "encrypted" passwords](https://github.com/NuGet/Home/issues/1851) on Linux and Mac (like what Mono does for the `ProtectedData` API), but it hasn't been implemented yet.
Therefore, in order for this feature not to be blocked, `<apikeys>` needs to support unencrypted (plain text) secrets, just as source credentials do.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

Add an XML attribute `encrypted`, which will be a boolean `true`/`false`, to specify if the value is encrypted or not.
If omitted from the element, the default value is true, to maintain backwards compatibility with prior versions of NuGet.
For example:

```xml
<apikeys>
    <add key="https://api.nuget.org/v3/index.json" value="api_key" encrypted="false" />
</apikeys>
```

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

We have got [feedback from customers](https://github.com/NuGet/Home/issues/3245) who manually entered clear text package credentials where NuGet expects encrypted credentials, and NuGet will crash with an obscure error message ("The parameter is incorrect") that is not actionable by customers.
While we are working on API keys, I propose that we should additionally catch the decryption of encrypted API keys, and if DPAPI throws an exception, report a meaningful error message back to the customer.

The `<packageSources>` section also uses the `<add key="string" value="string">` syntax that most other parts of `nuget.config` use, but it also supports the `protocolVersion="int"` attribute.
The approach it takes to add `protocolVersion` can be copied to make the `encrypted` attribute work.

## Drawbacks

<!-- Why should we not do this? -->

### Backwards compatibility

There are risks in changing the `nuget.config` schema, particularly around compatibility with older versions of NuGet.
This includes NuGet.exe, the `dotnet` CLI, Visual Studio, Visual Studio for Mac, and possibly 3rd party IDEs such as JetBrains Rider.
This is compounded by the fact that the `dotnet` CLI supports `global.json` to pin to older versions of the `dotnet` CLI (and therefore SDK) within a directory.

Problems with the above proposal that extends the existing schema with an additional `encrypted="true/false"` property.

1. Reading nuget.config from older versions of NuGet.

It needs to be verified if older versions of NuGet will fail to load the file if it contains this unexpected attribute on the `<add>` element.
However, even if it doesn't, since older versions of NuGet expect the value to be always encrypted, it will try to decrypt with DPAPI, and there's a very low chance that the value will decrypt, so it's likely that it will throw an exception saying that the value isn't valid.
Customers in the past have given us feedback that NuGet does not gracefully handle this scenario and will crash with a very obscure error message that customers don't understand.

This could be mitigated by persisting clear test API keys in a completely different section of the `nuget.config` file, such as `<clearApiKeys>`, which older versions of NuGet should ignore.

2. Writing nuget.config from older versions of NuGet.

If a customer runs any command that requires `nuget.config` to be modified, for example `dotnet nuget add source`, NuGet will deserialize the existing config, modify the value as per the command, and then serialize back to disk.
Since older versions of NuGet don't know about the `encrypted="true/false"` attribute, this attribute will be lost, and then if a newer version of NuGet is run, it will assume that the value is encrypted, and then cause errors.

If NuGet doesn't already handle maintaining sections of the config file that it doesn't know about, then there is no mitigation for this.
Using a different section name, like `<clearApiKeys>` will still get lost, but at least it won't cause DPAPI to try to decrypt an unencrypted string, and therefore improving the error message will not be as important.

### Unencrypted secrets

Since the API key is a secret, providing a way to reduce security might not be desirable.
However, at the time that this design spec is being written, there is no alternative on Linux and Mac, making API keys in the `nuget.config` file a Windows-only feature, which is also not desirable.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

### Prefer cross platform encrypted secrets

If [NuGet supported encrypted secrets on Linux and Mac](https://github.com/NuGet/Home/issues/1851), then this feature wouldn't be needed.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

[`<packageSources>` already uses the `<add key="string" value="string">` syntax](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#packagesources), but it also adds a `protocolVersion` attribute.

[`<packageSourceCredentials>` has a different schema](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#packagesourcecredentials).
It still uses the `<add key="string" value="string">` syntax, allowing it to use `<add key="cleartextpassword" value="secret" />` and `<add> key="password" value="encrypted" />`.
But that's because these elements are nested within an element whose name is the package source.
To try to do the same with `<apikeys>` would require a breaking schema change, since currently it uses `key` as the package source and `value` as the API key.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
