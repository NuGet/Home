
# Additional user wide configuration options

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

We will start detecting additional configs from the user specific directory similar to the extensibility from machine wide configs.

Given that these are additional configs, they will be merged with lower priority than the default user specific config. The rest are merged deterministically in lexicographical order because they are not expected to conflict.
The determinism allows an out in case something really goes wrong.

### A new folder for additional user-wide configuration

Use %APPDATA%\NuGet\config\` on Windows and `~/.config/NuGet/config/` or `~/.nuget/NuGet/config/` on Mac/Linux

Pros:

* Satisfies all the requirements.

Cons:

* Arguably not as intuitive as some other proposals, but it doesn't suffer from the same potential issues with unexpected configuration files. Given the difficulty one could have identifying which config brings in what source or fallback folder. The trade off might be good enough.

Worth to mention that while there have been instances of additional configs in the current user wide directory, it's impossible for us to determine the exact indicidence. We are likely talking about very few customers.

### Reading and writing priority

Say we have 1 solution configuration file and 2 user-wide configuration files.

* Local - solution file.
* User - The default user wide file from %APPDATA%\NuGet
* AdditionalUser - The additional user file from whichever the new location is.

The contents of the files are as follows respectively:

Local

```xml
<configuration>
    <SectionName>
        <add key="key1" value="local" />
        <add key="key2" value="local" />
    </SectionName>
</configuration>
```

User

```xml
<configuration>
    <SectionName>
        <add key="key2" value="user" />
        <add key="key3" value="user" />
    </SectionName>
</configuration>
```

AdditionalUser

```xml
<configuration>
    <SectionName>
        <add key="key3" value="additional" />
        <add key="key4" value="additional" />
    </SectionName>
</configuration>
```

### Reading priority

Given that the local file is the closest and the additional user configuration is considered the furthest, when reading `key2` for example will have the value `local`.

### Writing priority

Conversely, when writing we write to the furthest available config file.
In order to preserve backwards compatibility on the writing side, we will consider this additional user config as `read only`. The configuration commands will not write to the additional configuration files.
Specifically if we were to write `key5`, it would be written to the `User` config file.

## Future Work

None

## Open Questions

## Considerations

The considered but ultimately not accepted proposal is detailed below. 

### Re-use the existing %APPDATA%\NuGet directory

Pros:

* Simple & intuitive. Windows: %appdata%\NuGet\*.Config
Mac/Linux: ~/.config/NuGet/*.[C|c]onfig or ~/.nuget/NuGet/*.[C|c]onfig.

Cons:

* This is an existing folder. There are some known instances of unexpected NuGet.config files there. Examples include: NuGet_backup.config found by the OP of the linked issue. It's also likely there are some additional copies of NuGet.config in there.

### References

* [9394](https://github.com/NuGet/Home/issues/9394) NuGet should support multiple config files in %APPDATA%\NuGet directory
* [Configuring NuGet behavior](https://docs.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior#config-file-locations-and-uses)
* [Pull request](https://github.com/NuGet/NuGet.Client/pull/3421) implementing the first approach.
