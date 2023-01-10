# dotnet nuget setapikey

- Andy Zivkovic ([zivkan](https://github.com/zivkan))
- Start Date (2022-12-15)
- GitHub Issue (https://github.com/NuGet/Home/issues/6437)
- GitHub PR (not yet implemented)

## Summary

<!-- One-paragraph description of the proposal. -->

Add the `dotnet nuget apikey set` command, to allow customers to set a NuGet server API key in their `nuget.config` file.
Also add `dotnet nuget apikey unset`, so customers can clean up secrets easily.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->

Some NuGet servers, most notably nuget.org, use authentication via [API keys](https://learn.microsoft.com/nuget/reference/nuget-config-file#apikeys) ([custom `X-NuGet-ApiKey` HTTP header](https://learn.microsoft.com/nuget/api/package-publish-resource#request-parameters)), rather than [package source credentials](https://learn.microsoft.com/nuget/reference/nuget-config-file#packagesourcecredentials) ([HTTP standard `Authorization` header)](https://developer.mozilla.org/docs/Web/HTTP/Headers/Authorization), when pushing packages.
Package source credentials can either be persisted in the `nuget.config` file, or obtained via [an authentication provider](https://learn.microsoft.com/en-us/nuget/reference/extensibility/nuget-cross-platform-authentication-plugin), avoiding the need for the secret to be persisted in the `nuget.config` file.
While package source credentials were primarily designed to allow for private feeds, where authentication is needed to search, restore and install packages, several NuGet server implementations that support private feeds use the same package source credentials to authorize push, without the need to use NuGet's custom HTTP header.
In any case, there are servers which require API keys to push packages.

Customers who need to use API keys have two options.
Either persist the secret in `nuget.config`, so that the `push` command line does not need to specify the secret, or to pass the API key on the `push` command line.
Passing the API on the command line risks leaking secrets, for example a CI system might not mask the secret in logs, or the secret being persisted in a shell's history file.
Therefore, risk can be reduced by providing customers commands to add and remove the API to the `nuget.config` file, especially if it can be done in a way where the secret is not entered into, or output from, the console.

In `nuget.config`, the API keys are in a different section to source credentials.
There is a command `nuget.exe setapikey` to set the API key in a config file, however, `nuget.exe` does not ship in Visual Studio or the .NET SDK.
Also, `nuget.exe` requires mono on Linux and Mac, since `nuget.exe` is built for the .NET Framework.
Therefore, a command in the .NET SDK will significantly reduce the barrier for customers to set values in the `nuget.config` file.

Customers may want to remove secrets from their `nuget.config` files, so an `unset` command should be added.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

- `dotnet nuget apikey set`

```text
Description:
  Set the API key in a nuget.config file.

Usage:
  dotnet nuget apikey set <VALUE> [options]

Arguments:
  <VALUE> The value of the API key. If neither --from-file or --environment-variable is specified, the value is treated as a string literal.

Options:
  -e, --environment-variable Treat the <VALUE> argument as the environment variable name to read, whose value will be used as the API key.
  -f, --from-file            Treat the <VALUE> argument as a filename, whose contents contain the API key.
  -s, --source <SOURCE>      The package source which this API should be used with. [Required]
  --configfile               The nuget.config file to write the API key to. [Default: c:\users\zivkan\AppData\Roaming\NuGet\NuGet.Config]
  -?, -h, --help             Show command line help.
```

Note on `--configfile`:

NuGet has been using `--configfile`, rather than `--config-file` for multiple years, so this "incorrect" name is used to remain consistent with other commands.

Additionally, since API keys are always secrets, `--configfile` will always default to the user-profile `nuget.config`
See ["which nuget.config file" in the rationale and drawbacks section](#which-nugetconfig-file).

This allows the API to securely be added to `nuget.config`.
An example for Azure Pipelines:

```yaml
steps:
- script: dotnet nuget apikey set -e APIKEY
  name: Set nuget.org API key
  variables:
    APIKEY: $(SECRET_API_KEY_FOR_NUGET_ORG)
```

Note on `--source`:

The technical feasibility needs to be checked, but `nuget.config` has a key `defaultPushSource`.
When this is defined, `--source` should be optional and if `dotnet nuget apikey set` is run without specifying a value for `--source`, the default push source should be used.
When none of the `nuget.config` files specify a `defaultPushSource`, then `--source` should be a required option.

- `dotnet nuget apikey unset`

```text
Description:
  Unset an API key from a nuget.config file.

Usage:
  dotnet nuget apikey unset [options]

Options:
  -s, --source <SOURCE>      The package source which this API should be used with. [Required]
  --configfile               The nuget.config file to write the API key to. [Default: c:\users\zivkan\AppData\Roaming\NuGet\NuGet.Config]
  -?, -h, --help             Show command line help.
```

The note for `--source` applies from the above `dotnet nuget apikey set`.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

Some care needs to be taken when implementing the default values for options.

For `--configfile`, Linux is case-sensitive, and a customer might be using `nuget.config` (or `NuGet.config`), rather than NuGet's default `NuGet.Config`.
The default value factory will need to check the filesystem for which casing actually exists, and only fall back to the default casing if none are found.

Similarly, if the default value factory for `--source` should handle when `nuget.config` files have errors that throw exceptions when loaded.
In this case, treat the scenario like `defaultPushSource` doesn't exist, so that `--source` is a required option.

Finally, NuGet has always been inconsistent in supporting URLs or source names in `--source` commands.
I think it makes sense for NuGet to first assume that the value provided is a name, and try to look up a source with that name.
If no source matches the name, then assume it's a URL.
Therefore, customers should be able to use either name or URL.

## Drawbacks

<!-- Why should we not do this? -->

I don't believe there are any drawbacks to implementing the `dotnet nuget apikey` commands.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

### Which nuget.config file

At the time this spec is written, all NuGet commands that can write values in `nuget.config` files have the following unintuitive behavior.
The docs on [common NuGet configurations](https://learn.microsoft.com/nuget/consume-packages/configuring-nuget-behavior) explains that there's a hierarchy of directories and files checked.
When making a change, NuGet will look for the first file in that ordered list that contains the relevant section (first child of the XML root element).
For example, `nuget.exe config` will look for the first file that contains `<config>`, and `dotnet nuget add source` will look for the first file that contains `<packageSources>`.
While package sources, and certainly other config settings are valuable to be in a solution `nuget.config` file, and therefore commit into source control, accidentally committing a secret into source control is a security risk.
Therefore, `dotnet nuget apikey set` will always default to the user scope `nuget.config` file.

On stateful CI agents, this poses a security risk.
If the pipeline does not remove the API key from the user nuget.config, then other pipelines running on the same agent will be able to read the API key from the config file.
However, a pipeline that fails to clean up after itself on a stateful CI agent (for example times out, or the agent crashes or restarts without waiting for the pipeline to finish) will similarly leave secrets that other pipelines can read.
Although, if the secret is in a repo-specific directory, it will be less discoverable by other pipelines.
But a balance needs to be made between defaults for devboxes or CI agents, since the preferred default for each scenario is different.
If it were possible to easily detect when NuGet is running on a CI agent, it might be good to detect and change the defaults.
However, [there is no standardization across CI platforms](https://adamj.eu/tech/2020/03/09/detect-if-your-tests-are-running-on-ci/).

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

- `dotnet nuget apikey` commands `set` and `unset`

The [`dotnet nuget config` spec](https://github.com/NuGet/Home/pull/12172) proposed `set` and `unset`, to mimic `git config` commands, rather than `add` and `remove` or `delete`, which commands like `dotnet add package` and `dotnet nuget add source` use.

Some apps have a pre-defined environment variable name, rather than allowing customers to specify the environment variable name.
For example, apps running on GitHub Actions expect to the a GitHub access token in the `GITHUB_TOKEN` environment variable.

Some apps allow contents to be read from files by having the first character of the value be a `@`.
NuGet does this with package source credentials, however, it has caused a significant amount of customer confusion because this `@filename` convention is not well known, and NuGet doesn't provide a clear error message.
The GitHub CLI avoids this with its `gh api` commands by forcing customers to choose between `-f` which passes raw values, or `-F` which gets parsed, either as numbers or read from a file if it starts with a `@`.

Several UNIX commands allow you to pass `-` which tells the command to read from STDIN.
However, I don't believe this is compelling for `dotnet nuget apikey set`.
This could be interesting to allow piped commands like `get-from-keyvault nuget_api_key | dotnet nuget apikey set -`.
However, I believe that reading from environment variables and files are sufficient and customers will be able to work with it.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

- Need to validate old nuget behavior when `apikeys` contains unexpected `encryption` element. Validate both read and write.
- Have a quick play with System.CommandLine and validate that it's reasonable for default value factories to do non-trivial calculations, like find the correct case for `nuget.config` and load config files to check the value of `defaultPushSource`.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

If [the spec to allow unencrypted API keys in `nuget.config` files](https://github.com/NuGet/Home/pull/12354) is accepted, then `dotnet nuget apikey set` should have a `--store-in-clear-text` argument to allow the API to be saved without encryption.
