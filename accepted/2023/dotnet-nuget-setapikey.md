# dotnet nuget setapikey

- Andy Zivkovic ([zivkan](https://github.com/zivkan))
- Start Date (2022-12-15)
- GitHub Issue (https://github.com/NuGet/Home/issues/6437)
- GitHub PR (not yet implemented)

## Summary

<!-- One-paragraph description of the proposal. -->

Add the `dotnet nuget apikey set` command, to allow customers to set a nuget.org api key in their `nuget.config` file. Also add `dotnet nuget apikey unset`, so customers can clean up secrets easily. Additionally, `nuget.config` will be changed to allow unencrypted (plain text) API keys.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->

- `dotnet nuget apikey set`

nuget.org is one of the only package sources that uses API keys (`X-NuGet-ApiKey` HTTP header), rather than source credentials (`Authorization` HTTP header).
However, it is also one of the most important package sources, since it's the only default package source.
Hence most package authors who want wide adoption of their packages publish to nuget.org.

In `nuget.config`, the API keys are in a different section to source credentials.
There is a command `nuget.exe setapikey` to set the API key in a config file, however, `nuget.exe` does not ship in Visual Studio or the .NET SDK.
Also, `nuget.exe` requires mono on Linux and Mac, since `nuget.exe` is built for the .NET Framework.
Therefore, a command in the .NET SDK will significantly reduce the barrier for customers to set values in the `nuget.config` file.
While `dotnet nuget push` provides a `--apikey` option, this increases the risk that the secret value is exposed in the CI log, whereas customers can more easily secure a separate command that modifies the `nuget.config` file.
Especially if that command is capable of reading values from environment variables.

- `dotnet nuget apikey unset`

Customers may want to remove secrets from their `NuGet.config` files, so an `unset` command should be added.

- `nuget.config` support for unencrypted `<apikeys>`

Currently `nuget.config` `<apikeys>` section only supports encrypted values, via .NET's [`System.Security.Cryptography.ProtectedData` APIs](https://learn.microsoft.com/dotnet/api/system.security.cryptography.protecteddata).
As the important message says on the docs page, on Windows it uses Windows' Data Protection API (DPAPI), which isn't supported on Linux or Mac, and [the .NET libraries team have no plans to support it since it will have different security promises than on Windows](https://github.com/dotnet/runtime/issues/22886).
There is [an issue to consider another way of having less secure "encrypted" passwords](https://github.com/NuGet/Home/issues/1851) on Linux and Mac (like what Mono does for the `ProtectedData` API), but it hasn't been implemented yet.
Therefore, in order to enable this feature, `<apikeys>` needs to support unencrypted (plain text) secrets (just as source credentials do).

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

- `dotnet nuget apikey set`

```text
Description:
  Set the API key in a NuGet.config file.

Usage:
  dotnet nuget apikey set <VALUE> [options]

Arguments:
  <VALUE> The value of the API key. If neither --from-file or --environment-variable is specified, the value is treated as a string literal.

Options:
  -e, --environment-variable Treat the <VALUE> argument as the environment variable name to read, whose value will be used as the API key.
  -f, --from-file            Treat the <VALUE> argument as a filename, whose contents contain the API key.
  -s, --source <SOURCE>      The package source which this API should be used with. [Required]
  --configfile               The NuGet.config file to write the API key to. [Default: c:\users\zivkan\AppData\Roaming\NuGet\NuGet.config]
  --store-in-clear-text      Don't use .NET's ProtectedData APIs to encrypt API key. Required on platforms that don't support the API.
  -?, -h, --help             Show command line help.
```

Note on `--configfile`:

NuGet has been using `--configfile`, rather than `--config-file` for multiple years, so this "incorrect" name is used to remain consistent with other commands.

Additionally, since API keys are always secrets, `--configfile` will always default to the user-profile `NuGet.config`. See ["which nuget.config file" in the rationale and drawbacks section](#which-nugetconfig-file).

This allows the API to securely be added to `nuget.config`. An example for Azure Pipelines:

```yaml
steps:
- script: dotnet nuget apikey set -e APIKEY
  name: Set nuget.org API key
  variables:
    APIKEY: $(SECRET_API_KEY_FOR_NUGET_ORG)
```

Note on `--source`:

The technical feasibility needs to be checked, but `NuGet.config` has a key `defaultPushSource`.
When this is defined, `--source` should be optional and if `dotnet nuget apikey set` is run without specifying a value for `--source`, the default push source should be used.
When none of the `NuGet.config` files specify a `defaultPushSource`, then `--source` should be a required option.

- `dotnet nuget apikey unset`

```text
Description:
  Unset an API key from a NuGet.config file.

Usage:
  dotnet nuget apikey unset [options]

Options:
  -s, --source <SOURCE>      The package source which this API should be used with. [Required]
  --configfile               The NuGet.config file to write the API key to. [Default: c:\users\zivkan\AppData\Roaming\NuGet\NuGet.config]
  -?, -h, --help             Show command line help.
```

The note for `--source` applies from the above `dotnet nuget apikey set`.

- `nuget.config` support for unencrypted `<apikeys>`

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

- `dotnet nuget apikey`

Some care needs to be taken when implementing the default values for options.

For `--configfile`, Linux is case-sensitive, and a customer might be using `nuget.config`, rather than `NuGet.config`.
The default value factory will need to check the filesystem for which casing actually exists, and only fall back to the default casing if none are found.

Similarly, if the default value factory for `--source` should handle when `nuget.config` files have errors that throw exceptions when loaded.
In this case, treat the scenario like `defaultPushSource` doesn't exist, so that `--source` is a required option.

- `nuget.config` support for unencrypted `<apikeys>`

We have got feedback in the past from customers who manually entered clear text package credentials where NuGet expects encrypted credentials, and NuGet will crash with an obscure error message that is not actionable by customers.
While we are working on API keys, I propose that we should additionally catch the decryption of encrypted API keys, and if DPAPI throws an exception, report a meaningful error message back to the customer.

The `<packageSources>` section also uses the `<add key="string" value="string">` syntax that most other parts of `NuGet.config` use, but it also supports the `protocolVersion="int"` attribute.
The approach it takes to add `protocolVersion` can be copied to make the `encrypted` attribute work.

## Drawbacks

<!-- Why should we not do this? -->

I don't believe there are any drawbacks to implementing the `dotnet nuget apikey` commands.

However, there are risks in changing the `NuGet.config` schema, particularly around compatibility with older versions of NuGet. This includes NuGet.exe, the `dotnet` CLI, Visual Studio, Visual Studio for Mac, and possibly 3rd party IDEs such as JetBrains Rider. This is compounded by the fact that the `dotnet` CLI supports `global.json` to pin to older versions of the `dotnet` CLI (and therefore SDK) within a directory.

Problems with the above proposal that extends the existing schema with an additional `encrypted="true/false"` property.

1. Reading NuGet.config from older versions of NuGet.

It needs to be verified if older versions of NuGet will fail to load the file if it contains this unexpected attribute on the `<add>` element. However, even if it doesn't, since older versions of NuGet expect the value to be always encrypted, it will try to decrypt with DPAPI, and there's a very low chance that the value will decrypt, so it's likely that it will throw an exception saying that the value isn't valid.
Customers in the past have given us feedback that NuGet does not gracefully handle this scenario and will crash with a very obscure error message that customers don't understand.

This could be mitigated by persisting clear test API keys in a completely different section of the `NuGet.config` file, such as `<clearApiKeys>`, which older versions of NuGet should ignore.

2. Writing NuGet.config from older versions of NuGet.

If a customer runs any command that requires `NuGet.config` to be modified, for example `dotnet nuget add source`, NuGet will deserialize the existing config, modify the value as per the command, and then serialize back to disk.
Since older versions of NuGet don't know about the `encrypted="true/false"` attribute, this attribute will be lost, and then if a newer version of NuGet is run, it will assume that the value is encrypted, and then cause errors.

If NuGet doesn't already handle maintaining sections of the config file that it doesn't know about, then there is no mitigation for this.
Using a different section name, like `<clearApiKeys>` will still get lost, but at least it won't cause DPAPI to try to decrypt an unencrypted string, and therefore improving the error message will not be as important.

## Rationale and alternatives

### Which NuGet.config file

At the time this spec is written, all NuGet commands that can write values in `NuGet.config` files have the following unintuitive behavior.
The docs on [common NuGet configurations](https://learn.microsoft.com/nuget/consume-packages/configuring-nuget-behavior) explains that there's a hierarchy of directories and files checked.
When making a change, NuGet will look for the first file in that ordered list that contains the relevant section (first child of the XML root element).
For example, `nuget.exe config` will look for the first file that contains `<config>`, and `dotnet nuget add source` will look for the first file that contains `<packageSources>`.
While package sources, and certainly other config settings are valuable to be in a solution `NuGet.config` file, and therefore commit into source control, accidentally committing a secret into source control is a security risk.
Therefore, `dotnet nuget apikey set` will always default to the user scope `NuGet.config` file.

On stateful CI agents, this poses a security risk.
If the pipeline does not remove the API key from the user nuget.config, then other pipelines running on the same agent will be able to read the API key from the config file.
However, a pipeline that fails to clean up after itself on a stateful CI agent (for example times out, or the agent crashes or restarts without waiting for the pipeline to finish) will similarly leave secrets that other pipelines can read.
Although, if the secret is in a repo-specific directory, it will be less discoverable by other pipelines.
But a balance needs to be made between defaults for devboxes or CI agents, since the preferred default for each scenario is different.
If it were possible to easily detect when NuGet is running on a CI agent, it might be good to detect and change the defaults.
However, [there is no standardization across CI platforms](https://adamj.eu/tech/2020/03/09/detect-if-your-tests-are-running-on-ci/).

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

- `dotnet nuget apikey` commands `set` and `unset`

The [`dotnet nuget config` spec](https://github.com/NuGet/Home/pull/12172) proposed `set` and `unset`, to mimic `git config` commands, rather than `add` and `remove` or `delete`, which commands like `dotnet add package` and `dotnet nuget add source` use.

Some apps have a pre-defined environment variable name, rather than allowing customers to specify the environment variable name.
For example, apps running on GitHub Actions expect to the a GitHub access token in the `GITHUB_TOKEN` environment variable.

Some apps allow contents to be read from files by having the first character of the value be a `@`. NuGet does this with package source credentials, however, it has caused a significant amount of customer confusion because this `@filename` convention is not well known, and NuGet doesn't provide a clear error message. The GitHub CLI avoids this with its `gh api` commands by forcing customers to choose between `-f` which passes raw values, or `-F` which gets parsed, either as numbers or read from a file if it starts with a `@`.

Several UNIX commands allow you to pass `-` which tells the command to read from STDIN. However, I don't believe this is compelling for `dotnet nuget apikey set`.
This could be interesting to allow piped commands like `get-from-keyvault nuget_api_key | dotnet nuget apikey set -`.
However, I believe that reading from environment variables and files are sufficient and customers will be able to work with it.

- `nuget.config` support for unencrypted `<apikeys>`

[`<packageSources>` already uses the `<add key="string" value="string">` syntax](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#packagesources), but it also adds a `protocolVersion` attribute.

[`<packageSourceCredentials>` has a different schema](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#packagesourcecredentials).
It still uses the `<add key="string" value="string">` syntax, allowing it to use `<add key="cleartextpassword" value="secret" />` and `<add> key="password" value="encrypted" />`.
But that's because these elements are nested within an element whose name is the package source. To try to do the same with `<apikeys>` would require a breaking schema change, since currently it uses `key` as the package source and `value` as the API key.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

- Need to validate old nuget behavior when `apikeys` contains unexpected `encryption` element. Validate both read and write.
- Have a quick play with System.CommandLine and validate that it's reasonable for default value factories to do non-trivial calculations, like find the correct case for `nuget.config` and load config files to check the value of `defaultPushSource`.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
