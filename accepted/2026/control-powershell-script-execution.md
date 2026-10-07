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

The `Install-Package`, `Remove-Package` and `Update-Package` cmdlets will have a `-PackageScripts` parameter with `Run`, `Skip` and `Fail` values.
The default will be `Fail`.
Packages without `tools/install.ps1` and `tools/uninstall.ps1` scripts will work the same as before.
When scripts are present and the value is `Fail`, the cmdlet will fail and instruct the customer to use `-PackageScripts Run` or `-PackageScripts Skip`, along with the filenames of the scripts so the customer can inspect them.

Additionally, PMC will no longer run `tools/init.ps1` automatically.
A new `Import-PackageInitScript` cmdlet will be added to explicitly run selected `tools/init.ps1` scripts.
It will accept script paths as positional or pipeline input.
It will also have an optional `-Packages` parameter that looks up the `init.ps1` scripts belonging to the listed packages.
There will also be a `Get-PackageInitScript` cmdlet that lists matching scripts without running them.

`Import-PackageInitScript` runs package init scripts only when the cmdlet is invoked.
If a package containing `init.ps1` is installed or upgraded afterward, the cmdlet must be run again to import that script.
Package upgrades and uninstallations may also encounter issues when a previous invocation loaded files from the package, such as a PowerShell module that has the same name in multiple package versions.
This behavior already existed when NuGet ran init scripts automatically; `Import-PackageInitScript` does not attempt to unload or undo their changes.

#### Package Manager UI

NuGet's PM UI will no longer run any package's PowerShell scripts.
Before any project files are modified, when PM UI detects that a script would previously have been run, the operation fails, with an error message instructing the customer to use the Package Manager Console (PMC) to perform the operation.
See the [rationale and alternatives section](#rationale-and-alternatives) for justification.
This does not prevent a future change from improving the scenario, but for the first version this is the design and then we'll gather customer feedback.

If feasible, output the script paths; each path identifies the package ID and version.
However, as long as the message instructs the customer to run the appropriate PMC cmdlet, that command's default `-PackageScripts Fail` behavior will also output the script path(s).

#### Command line tooling

As NuGet only runs PowerShell scripts in Visual Studio, no command line tooling is in scope.

### Technical explanation

#### Install, Update, and Remove cmdlets

The `Install-Package`, `Update-Package` and `Remove-Package` cmdlets will choose packages and versions to upgrade the same way as before, when `-ProjectName` or `-Id` are omitted.
Before modifying any project files, NuGet will inspect every package action in the resolved operation, including dependency actions, for `install.ps1` and `uninstall.ps1`.
When `-PackageScripts Run` is used, all discovered scripts will run.
When `-PackageScripts Skip` is used, all discovered scripts will be skipped and the operation will continue.
When `-PackageScripts Fail` is used, the operation will fail before modifying any project files if scripts are discovered.
`Fail` is the default when `-PackageScripts` is omitted.

#### Init script cmdlets

`Get-PackageInitScript` will list scripts without running them, returning package ID, version and absolute path as `FullName`.

`Import-PackageInitScript` will run all discovered init scripts by default, or accept either:

- Positional or pipeline script paths. Objects are supported by reading their `FullName` property.
- `-Packages` with one or more package IDs. Ambiguous versions can use `id@version`.

These "overloads" of the cmdlet are mutually exclusive, so positional arguments and `-Packages` switch cannot be used at the same time.

```powershell
Import-PackageInitScript
Import-PackageInitScript (Get-PackageInitScript)
Get-ChildItem -Recurse -Filter init.ps1 | Import-PackageInitScript
Import-PackageInitScript -Packages Package1,Package2@2.0.0
```

Inputs will be validated as installed `tools/init.ps1` files; invalid inputs will produce errors.
Discovery, ordering and deduplication will retain existing solution-level PMC behavior.
The cmdlet will never execute `install.ps1` or `uninstall.ps1`.
Importing `$null` or an empty collection is no-op.

When installing multiple versions of a package, each of which have their own `tools/init.ps1`, NuGet has never attempted to "uninit" or undo any changes that `init.ps1` has made.
`Import-PackageInitScript` will also treat this as an unsupported scenario and customers will need to restart Visual Studio to unload any changes that were made by previous invocations.

## Drawbacks

Packages that are using `install.ps1`, `uninstall.ps1` or `init.ps1` for legitimate purposes will be more difficult to use.
Unfortunately, this is the nature of security hardening.

## Rationale and alternatives

### Package Manager UI blocked gestures

The Visual Studio data we have on Package Manager UI actions and PowerShell script execution shows that a very small percentage of actions runs `install.ps1` or `uninstall.ps1`.
Therefore, the customer impact in blocking PM UI for projects using packages.config when the package contains either a `tools/install.ps1` or `tools/uninstall.ps1` is estimated to be low.

An alternative is to provide a UI to allow customers to choose which scripts to run and which to skip is possible.
But the PMC commands will mean that this is not a blocking issue, just a convenience issue.
The low usage makes the work low priority until more data can be gathered to justify it over other features.

### Fail commands or skip scripts by default

This proposal is that both PMC and PM UI will fail on install, uninstall, or upgrade, when any package contains an install.ps1 or uninstall.ps1.
An alternate design is to use `-PackageScripts Skip` by default, warn customers that scripts were skipped, and have them re-install in PMC with `-PackageScripts Run` when they want.

This would be ok for packages with an install.ps1, as customers could run `Update-Package PackageName -Reinstall -PackageScripts Run`.
Although there's a risk that customers don't notice the warning, and would therefore be unaware that a package script that used to run is no longer running.

However, packages with uninstall.ps1 are much more difficult.
Customers would need to revert to the previous state, perhaps through source control, or otherwise by reinstalling or downgrading a package, before they could run the uninstall or upgrade again, this time allowing the scripts to run.
Failing the original command to avoid this complexity may be the simpler option.

Similar to the PM UI gestures above, given the low usage data we have, we value speed in delivering this feature and then focusing on other high priority work, over polishing this feature at this time.
Once this ships we can gather customer feedback for potential improvements.

### Persisted settings

Rather than requiring developers to type (or tab-complete) `-PackageScripts Run` or `Import-PackageInitScript` every time they want to run the scripts, it's possible to have a setting saved somewhere.
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
While developers using EF6 won't have alternatives to running `Import-PackageInitScript` every time they restart Visual Studio, the evidence above suggests it's a smaller percentage of customers that will be affected.

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
