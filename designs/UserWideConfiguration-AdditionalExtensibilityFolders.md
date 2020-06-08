
# Spec Name

* Status: In Review
* Author(s): [Nikolche Kolev](https://github.com/nkolev92)
* Issue: [9394](https://github.com/NuGet/Home/issues/9394) NuGet should support multiple config files in %APPDATA%\NuGet directory

## Problem Background

The XAML and WinForms teams want to allow control library installers to add user-specific NuGet fallback folders by having their SDK installers drop config files in %APPDATA%\NuGet. On uninstall this file would be deleted.

We considered two alternatives which I mentioned as workarounds above:

1. Require SDK installers to drop config files in %ProgramFiles(x86)%\NuGet\Config instead. However, we've gotten feedback from control vendors that they would like the option of installing without elevation which prevents the installer from being able to write to this directory.
1. Require SDK installers to modify the one %APPDATA%\NuGet\NuGet.config file. However this seems error prone.

## Who are the customers

All NuGet customers are affected. Primary consumers are the WPF and WinForms customers.

## Goals

* Provide a way for 3rd party vendors to add new user-wide configuration files without elevation.

## Non-Goals

## Solution

The solution to start detecting additional configs from the user specific directory similar to the extensibility from machine wide configs.

Given that these are additional configs, they will be merged with lower priority than the default user specific config. The rest are merged deterministically in alphabetical order because they are not expected to confict.
The determinism allows an out in case something really goes wrong.

There 2 solutions that satisfy the requirement with the least amount of friction.

### Re-use the existing %APPDATA%\NuGet directory

Pros:

* Simple & intuitive. Windows: %appdata%\NuGet\NuGet.Config
Mac/Linux: ~/.config/NuGet/NuGet.Config or ~/.nuget/NuGet/NuGet.Config.

Cons:

* This is an existing folder. There are some known instances of unexpected NuGet.config files there. Examples include: NuGet_backup.config found by the OP of the linked issue. It's also likely there are some additional copies of NuGet.config in there.

### Define a new folder for additiona user-wide configuration

The proposal is to use `%APPDATA%\NuGet\config`.

Pros:

* Satisfies all the requirements.

Cons:

* Arguably not as intuitive as the first proposal, but it doesn't suffer from the same potential issues with unexpected configuration files. Given the difficulty one could have identifying which config brings in what source or fallback folder. The trade off might be good enough.

Worth to mention that while there have been instances of additional configs in the current user wide directory, it's impossible for us to determine the exact indicidence. We are likely talking about very few customers.

## Future Work

None

## Open Questions

* Which of the 2 approaches do we prefer? Personally I was leaning toward re-using the same folder, but if we want to be risk averse, we can just take the new folder approach.

## Considerations

None

### References

* [9394](https://github.com/NuGet/Home/issues/9394) NuGet should support multiple config files in %APPDATA%\NuGet directory
* [Configuring NuGet behavior](https://docs.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior#config-file-locations-and-uses)
* [Pull request](https://github.com/NuGet/NuGet.Client/pull/3421) implementing the first approach.