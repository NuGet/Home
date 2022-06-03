
# Spec Name

* Status: In Review
* Author(s): [Heng Liu](https://github.com/heng-liu)
* Issue: [4413](https://github.com/NuGet/Home/issues/4413) [MacOS, Linux] NuGet writes the NuGet.Config in ~/.config folder, but dotnet restore reads from ~/.nuget 

## Problem Background

On Linux/Mac, NuGet has inconsistent paths of user wide NuGet.Config file for different NuGet tools. Dotnet CLI uses hard coded `~/.nuget` folder, so the user wide NuGet.Config path is `~/.nuget/NuGet/NuGet.Config`). While Mono uses the folder name from environment variable `APPDATA`, so by default, the user wide NuGet.Config file path is `~/.config/NuGet/NuGet.Config`). This is confusing and we should consolidate the two into one location. 

After discussing in NuGet team and checking with Visual Studio Mac/Mono team, we believe we should change the dotnet CLI path to match that of Mono’s, for the following reason:
 * On Linux/Mac, users usually get application data from environment variable XDG_DATA_HOME, which has the default value of ~/.config. Getting application data from ~/.nuget will cause inconsistency user experience between NuGet and other applications.

For the sake of simplicity, we will refer to `~/.nuget/NuGet/NuGet.Config` as legacy path, and refer to `~/.config/NuGet/NuGet.Config` as consolidated path in the following.

## Who are the customers
Dotnet CLI users who work on Linux and Mac.

## Goals
Make dotnet CLI user-wide config file path consistent with Mono on Linux/Mac and break as less dotnet CLI users as possible.

## Non-Goals
Completely get rid of the legacy path.

## Background knowledge
On Linux/Mac, user wide NuGet.Config file is created when trying to get the user wide NuGet.Config file at the beginning phase of running `dotnet restore` command(and many other dotnet commands with implicit restore if not specifying `--no-restore` option, like `dotnet new`, `dotnet build`, `dotnet run`, `dotnet test`, `dotnet publish`, and `dotnet pack`), or `dotnet msbuild -t:restore` command, but the user wide NuGet.Config file does not exist. Then the user wide NuGet.Config will be created with package source of nuget.org, as the only default package source. 

## Potential Solutions overview 
### Solution 1: Use only consolidated path
Change NuGet to use the consolidated config path for dotnet cli. Customers using only new tooling have no reason to keep the legacy path.

#### Implementation
Add following steps when trying to get user-wide config file path by running dotnet CLI on Linux/Mac:
Check if the following two conditions are satisfied.
* The legacy path does not exist.
*	The consolidated path exists.

If the two conditions are satisfied, NuGet will get user wide NuGet.Config path from consolidated path.

If not, it should be one of the following cases:

**1. Neither legacy path nor consolidated exists.**

NuGet will create a default NuGet.Config file in consolidated path.
NuGet will get user wide NuGet.Config file from consolidated path. 
No warning will be shown.

**2. Legacy path exist, but consolidated path does not exist.**

NuGet will copy the NuGet.Config file from legacy path to consolidated path, then delete the one in legacy path. 
NuGet will get user wide NuGet.Config file from consolidated path.
No warning will be shown.

**3. Both legacy path and consolidated path exist.**

**3.1 If NuGet could determine how to consolidate the contents of the two**
  
  If the two files have the same contents, or one of them has the default content, NuGet could consolidate the two into consolidated path. After consolidation, NuGet will get config file from consolidated path.
  No warning will be shown.

**3.2 If NuGet could not determine how to consolidate the contents of the two**
  
  If the two files are of different contents, there might be conflicting configurations. NuGet will get user wide NuGet.Config file from **legacy path**.
  NuGet will show a warning, encouraging customers to consolidate the contents of the two and only keep the one in consolidated path.  

  Warning: there are two user-wide NuGet.Config files. Put the wanted config file in consolidated path, delete the one from legacy path. For more details, please refer to: a link of document.

#### Pros: 
For scenario 1, 2, 3.1, only consolidated path exists, and new tooling will pick NuGet.Config file from consolidated path.
For scenario 3.2, if customer follows the instructions in the warning, then only consolidated path exists, and new tooling will pick NuGet.Config file from consolidated path.

#### Cons: 
If customer uses gloabal.json to pin different versions of dotnet dynamically, the old version of dotnet will create the default config file in legacy path if it doesn't exist. The invoking on old version dotnet might break (if the default config file doesn't work). The next new version of dotnet invoking will be in scenario 3.1 or 3.2.

### Solution 2: Use symbolic link during transition period so that both paths use the same file contents
Set up the legacy path to be a symbolic link to the consolidated path, so that customers using a mix of old and new tooling don't accidentally get the config settings out-of-sync.

#### Implementation
Add following steps when trying to get user-wide config file path by running dotnet CLI on Linux/Mac:
Check if the following conditions are satisfied.
* The legacy path exists and it's a symbolic link.
*	The consolidated path exists.

If they're satisfied, NuGet will get user wide NuGet.Config path from consolidated path.

If not, it should be in one of the following cases:

**1. Neither legacy path nor consolidated exists.**

NuGet will create a default NuGet.Config file in consolidated path, and set up the legacy path to be a symbolic link to the consolidated path.
NuGet will get user wide NuGet.Config file from consolidated path. 
No warning will be shown.

**2. Legacy path exist, but consolidated path does not exist.**

NuGet will copy the NuGet.Config file from legacy path to consolidated path, and set up the legacy path to be a symbolic link to the consolidated path.
NuGet will get user wide NuGet.Config file from consolidated path. 
No warning will be shown.

**3. Legacy path does not exist, but consolidated path exists.**
NuGet will set up the legacy path to be a symbolic link to the consolidated path.

**4. Both legacy path and consolidated path exist, but legacy path is not a symbolic link.**

**4.1 If NuGet could determine how to consolidate the contents of the two**
If NuGet could determine how to consolidate the contents of the two, NuGet will consolidate the two into consolidated path, and set up the legacy path to be a symbolic link to the consolidated path. After consolidation, NuGet will get config file from consolidated path.
No warning will be shown.

**4.2 If NuGet could not determine how to consolidate the contents of the two**
If NuGet could not determine how to consolidate the contents of the two, NuGet will get user wide NuGet.Config file from **legacy path**.
NuGet will show a warning, encouraging customers to consolidate the contents of the two and only keep the one in consolidated path. If customers finish that, the next time, it will jump to scenario 3. legacy path does not exist, but consolidated path exists, so NuGet will help them set up the legacy path to be a symbolic link to the consolidated path. 

Warning: there are two user-wide NuGet.Config files. Put the wanted config file in consolidated path, delete the one from legacy path. Next time, NuGet will set up the legacy path to be a symbolic link to the consolidated path. For more details, please refer to: a link of document.

#### Pros: 
If customer uses gloabal.json to pin different versions of dotnet dynamically, the old version of dotnet will pick config file from legacy path, which is actually the same file with the one in consolidated path. So all versions of dotnet could maintain a single copy of NuGet.Config files. 

#### Cons: 
Legacy path still exists for all scenarios, even if the NuGet.Config file is only in consolidated path, legacy path will be created as a symbolic link.

If customer sets legacy path wrongly by themselves(not following instructions in warning of scenario 4.2 and let NuGet to do that for them), e.g. a symbolic link pointing to a wrong path, NuGet is able to detect that, but NuGet won't know if it's on purpose or it's a wrong setting. So NuGet won't break customers in this situation.

### Scenarios from the developer side
**1. Visual Studio for Mac** 

  It's in .NET Framework code path so it will not be affected by this change.

**2. Mono CLI (NuGet)**

  It's in .NET Framework code path so it will not be affected by this change.

**3. dotnet CLI (NuGet)**

  On windows, it will not be affected by this change.
  On Linux/Mac, this change will be applied.

**4. CI/CD (Headless CLI)**

  On windows, it will not be affected by this change.
  On Linux/Mac, this change will be applied. But considering most users will put the URLs in a NuGet.Config file in the repository, so the user wide NuGet.Config in both legacy path and consolidated path should be the default content in most cases. Not sure if there is any data we could use to prove this assumption.


### Challenges

**About merging NuGet.Config files in legacy path and consolidated path when they both exist**

1.If the two config files are the same, NuGet will keep the one in consolidated path. 
Shall we do the generalized comparison on the two xml files? That is, if the two functionally work the same, then they're same. So comments, space, key name differences will be ignored. It may need extra work compared with using string compare. Is this worth doing? 

2.If one of them is the default NuGet.Config file, NuGet will ignore the default one and choose the other one. Will any scenarios break if we ignore the default NuGet.Config file?
If one of them is the default NuGet.Config file(has nuget.org as the only source), the other one is not and it doesn't have nuget.org as one of it's sources.

The above two should have covered most of the situations when the two config files both exist. 
The 3rd situation is, customers use both dotnet CLI and mono, but have different contents of user wide NuGet.Config file other than default NuGet.Config file. That seems not reasonable. Is there any data we could use to prove this assumption? 

**The symbolic link related .NET APIs for non-Windows platform are available in net6.0 for now, but we need to retarget some of our projects to net6.0.**

There is a [Proposed API for symbolic links](https://github.com/dotnet/runtime/issues/24271)
And the following APIs are available in net6.0:
* [File.ResolveLinkTarget(String, Boolean) Method](https://docs.microsoft.com/en-us/dotnet/api/system.io.file.resolvelinktarget?view=net-6.0)
* [File.CreateSymbolicLink(String, String) Method](https://docs.microsoft.com/en-us/dotnet/api/system.io.file.createsymboliclink?view=net-6.0)

When retargeting some of our projects to net6.0, are we going to add net6.0 into the current list of TFMs, or replace some of the old TFMs?

## Future Work
Get rid of the legacy path completely. 

## Open Questions

**Which dotnet version are we going to bring in this change?**

The version of .NET with this change will show warning to users who still have NuGet.Config in legacy path, encouraging them to move it to consolidated path.
So it's good if more people could get this warning and get prepared to get rid of legacy path compleletly for future versions.
For now, .NET 7 is the earlest possible version we could have this change.

**Shall we insert this change into dotnet 6.x as servicing patch?**

6.x is a LTS version. If 6.x doesn't have this change, it will still use the legacy path, we could not get rid of the legacy path completely if there are still people using 6.x.
But at the same time, the bar for servicing patch should be high and for fixing security issues. 

**When can we get rid of the legacy path completely?**

This version: the .NET version with this change. It will show warning to users who still have NuGet.Config in legacy path, encouraging them to move it to consolidated path. If customers react to the warning, then they migrate to the consolidated path.
Prior version: the .NET version uses only the legacy path. 
Later version: the .NET version uses only the consolidated path. (NuGet will not delete the legacy path)

Who will be affected if we get rid of the legacy path completely in later .NET versions?
1.Customers who receive the warning (with two different NuGet.Config files) in this version, but don't take any action for the whole lifetime of this version. 
  When they shift to later version, the config file will be changed.

Who will NOT be affected if we get rid of the legacy path completely in later .NET versions?
1.Customers who uses only later version. 
2.Customers who uses both this version and later version and:
  * The two paths have been consolidated by NuGet automatically (solution 1, scenario 1, 2, 3.1, or solution 2, scenario 1, 2, 3, 4.1)  
  * The customers who receive the warning (with two different NuGet.Config files) in this version, and follow the instruction and consolidate the two paths(solution 1, scenario 3.2, or solution 2, scenario 4.2). 

So it might be good if we give customers more time to shift from legacy path to consolidated path.


## Considerations
**Is there a way to know how many users are using global.json to pin different versions of dotnet dynamically?**

So that we can determine which solution should be chosen. Solution 2 if better if there are many users using global.json.

**We need to update existing documents/add new documents along with this change, so we could add the link in the warning to increase the clarity**
For customers who need to consolidate the two config files, we'd better to let them know more about this change along with detailed instructions.
For customers who need to change the user-wide config files after this change, they might get confused if the path changes.

Documents need to be changed:
https://docs.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior


### References

* [Implicit restore](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-pack#implicit-restore)
