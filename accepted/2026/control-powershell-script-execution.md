# Control PowerShell script execution in Visual Studio

- Author: [zivkan](https://github.com/zivkan/)
- GitHub Issue: TBD

## Summary

Disable PowerShell script execution in Visual Studio and add new gestures to run them when needed.

## Motivation

In 2026, supply chain attacks across different package manager ecosystems are continuing to be more common.
A common theme in many of these attacks are malicious scripts that run automatically on install.
Therefore, to improve supply chain security, these PowerShell scripts should no longer run automatically.

NuGet packages can include PowerShell scripts that Visual Studio executes in two different scenarios.
When Visual Studio's Package Manager Console is open, the `tools/init.ps1` script is run in any installed package that contains the file.
When the project uses packages.config (as opposed to PackageReference), `tools/install.ps1` is run on package install and `tools/uninstall.ps1` is run on uninstall (an upgrade is an uninstall of the previous version and an install of the new version).

NuGet has never run PowerShell scripts outside of Visual Studio, so all CLI experiences are out of scope.
This feature spec is specific to PowerShell scripts in packages, so MSBuild props and targets are out of scope.

### Existing packages

Although archived now, [NuGet Insights](https://github.com/NuGet/Insights) was a tool to collect information about all packages on nuget.org.
Using this data, we can estimate the impact of disabling automatic PowerShell script execution.

|File|Any version|Latest stable|Any version published in last 12 months|latest stable published in last 12 months|
|--|--|--|--|--|
|tools/init.ps1|0.3%|0.1%|0.3%|0.2%|
|tools/install.ps1|3.7%|0.9%|2.5%|0.5%|
|tools/uninstall.ps1|3.3%|0.6%|2.5%|0.4%|
|both tools/init.ps1 and tools/install.ps1|0.2%|0.2%|0.0% (1)|0.0% (1)|

1. The package counts were non-zero, but they were so small that they round off to 0.0% when using a single decimal place.

When filtering to packages that have at least one million downloads (across all versions), the percentages are similar.
3.5% of the latest SemVer stable packages have install.ps1 and 0.3% contain init.ps1.

Customer impact depends on popular package usage, not the percentage of packages that use this NuGet feature.
But package contents and download counts are publicly available information.
Also, if a large percentage of packages used this feature, then it would be a signal that it must naturally also have high usage from package consumption.
Since few packages use PowerShell scripts, this suggests that disabling automatic execution will affect a relatively small portion of package consumption.

## Explanation

### Functional explanation

#### Package Manager Console (PMC)

The `Install-Package`, `Remove-Package` and `Update-Package` cmdlets will have an `-AllowPackageScripts` switch.
Without it, package `tools/install.ps1` and `tools/uninstall.ps1` scripts will not be run.
When the scripts are not run, the cmdlets will output a message notifying the user that package scripts were not run, and provide the list of files that were not run, so they can copy and paste the filenames to open the files and inspect what the scripts will do if run.
The output should also have some aka.ms link that redirects to a dedicated docs page on this feature, with clear instructions on how to run the scripts if desired.
This allows us to modify the wording without the customer needing to install updates to Visual Studio.

In general, `Update-Package <id> -Reinstall -AllowPackageScripts` will be sufficient.
However, if a package was uninstalled, that's not going to work.
Similarly, an upgrade is implemented as an uninstall of the old version followed by an install of the new version.
If the old version has a `tools/uninstall.ps1`, then re-installing the new version isn't going to run the previous version's uninstall script.
If the new version has a `tools/uninstall.ps1`, then re-installing will run it and might have unintended consequences.
Therefore, in several scenarios it's preferred to use source control to revert any package uninstalls and then run the command again with `-AllowPackageScripts`.
It's difficult to explain all of this concisely in a hardcoded message in the product, which is why a link to a docs page is preferred.

Additionally, PMC will no longer run `tools/init.ps1` automatically.
A new `Import-NuGetPackageInitScripts` cmdlet will be added to explicitly run selected `tools/init.ps1` scripts.
It will accept script paths as positional or pipeline input.
It will also have an optional `-Packages` parameter that looks up the `init.ps1` scripts belonging to the listed packages.
There will also be a `Get-NuGetPackageInitScripts` cmdlet that lists matching scripts without running them.

#### Package Manager UI

NuGet's PM UI will no longer run any package's PowerShell scripts.
When PM UI detects that a script would previously have been run, it will output a message to the "Package Manager" output window, and bring this output window to focus.
The message will provide the same script details and recovery guidance described for PMC commands above.

#### Command line tooling

As NuGet only runs PowerShell scripts in Visual Studio, no command line tooling is in scope.

### Technical explanation

#### Install, Update, and Remove cmdlets

The `Install-Package`, `Update-Package` and `Remove-Package` cmdlets will choose packages and versions to upgrade the same way as before, when `-ProjectName` or `-Id` are omitted.
The only difference is that `install.ps1` and `uninstall.ps1` are no longer run without the `-AllowPackageScripts` switch.

#### Init script cmdlets

`Get-NuGetPackageInitScripts` will list scripts without running them, returning package ID, version and absolute path as `FullName`.

`Import-NuGetPackageInitScripts` will run all discovered init scripts by default, or accept either:

- Positional or pipeline script paths. Objects are supported by reading their `FullName` property.
- `-Packages` with one or more package IDs. Ambiguous versions can use `id@version`.

These "overloads" of the cmdlet are mutually exclusive, so positional arguments and `-Packages` switch cannot be used at the same time.

```powershell
Import-NuGetPackageInitScripts
Import-NuGetPackageInitScripts (Get-NuGetPackageInitScripts)
Get-ChildItem -Recurse -Filter init.ps1 | Import-NuGetPackageInitScripts
Import-NuGetPackageInitScripts -Packages Package1,Package2@2.0.0
```

Inputs will be validated as installed `tools/init.ps1` files; invalid inputs will produce errors.
Discovery, ordering and deduplication will retain existing solution-level PMC behavior.
The cmdlet will never execute `install.ps1` or `uninstall.ps1`.
Importing `$null` or an empty collection is no-op.

When installing multiple versions of a package, each of which have their own `tools/init.ps1`, NuGet has never attempted to "uninit" or undo any changes that `init.ps1` has made.
`Import-NuGetPackagesInitScripts` will also treat this as an unsupported scenario and customers will need to restart Visual Studio to unload any changes that were made by previous invocations.

## Drawbacks

Packages that are using `install.ps1`, `uninstall.ps1` or `init.ps1` for legitimate purposes will be more difficult to use.
Unfortunately, this is the nature of security hardening.

## Rationale and alternatives

### Persisted settings

Rather than requiring developers to type (or tab-complete) `-AllowPackageScripts` or `Import-NuGetPackageInitScripts` every time they want to run the scripts, it's possible to have a setting saved somewhere.
For example, a list of packages (or package versions) that are trusted, allowing any of the scripts from just these trusted packages to be run automatically.

However, most projects now are using PackageReference, not packages.config.
This means that `install.ps1` and `uninstall.ps1` aren't relevant to most projects anyway.

Similarly, the top 2 packages by download count with an `init.ps1` are Entity Frameworks' two packages (EF6 and EF Core).
They have a combined download count of over 50 times the 3rd most downloaded package with an `init.ps1`, which appears to use it just for a license check.
As a license check `init.ps1` is not fully effective, because if PMC is not open, then the `init.ps1` won't be run anyway.
EF6 doesn't support .NET (Core) projects, and EF Core doesn't support .NET Framework projects.
The [Microsoft.EntityFrameworkCore.Tools package](https://www.nuget.org/packages/Microsoft.EntityFrameworkCore.Tools) has more downloads than the [EntityFramework (EF6) package](https://www.nuget.org/packages/EntityFramework), despite the EF package being available for 4-5 years longer.
At the time this is being written, the "per day average" for EF Core's package is 20 times higher than EF6.
This is relevant because EF Core also has a .NET (global) tool package, allowing `dotnet ef` commands from any terminal, not just PMC.
Hopefully this means that migrating from the PMC tooling to the .NET tool will just be a minor inconvenience.
While developers using EF6 won't have alternatives to running `Import-NuGetPackageInitScripts` every time they restart Visual Studio, the evidence above suggests it's a smaller percentage of customers that will be affected.

Another angle to consider is that once a configuration value is set, it's rarely reconsidered.
If the configuration is forgotten about, the value can persist for years.
While temporary exemptions to security features are useful, a forgotten security setting isn't temporary and therefore could pose a risk.

Additionally, by keeping the first version of the feature smaller, it can be delivered more quickly.

So when considering all these points together, the decision is to not add any settings to persist choices at this time.
After the change ships, we can get customer feedback.

## Prior Art

Projects using `PackageReference` can avoid importing package MSBuild files by using `ExcludeAssets="build;buildTransitive"`.
However, package MSBuild file import is per-project, unlike `init.ps1` in the Package Manager Console.

npm has an `--ignore-scripts` option on the command line, or a `ignore-scripts=true` setting in the config file, to ignore post-install scripts in packages.
It also has `allowScripts` in the config file, which can be managed by `npm approve-scripts` and `npm deny-scripts`

## Unresolved Questions
