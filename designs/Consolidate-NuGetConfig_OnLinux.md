
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
On Linux/Mac, user wide NuGet.Config file is created when trying to get the user wide NuGet.Config file at the beginning phase of running `dotnet restore` command(and many other dotnet commands with implicit restore if not specifying `--no-restore` option, like `dotnet new`, `dotnet build`, `dotnet run`, `dotnet test`, `dotnet publish`, and `dotnet pack`), or `dotnet msbuild -t:restore` command, and found the user wide NuGet.Config file does not exist. Then the user wide NuGet.Config will be created with package source of nuget.org, as the only default package source. 

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

**2. Legacy path exist, but consolidated path does not exist.**

NuGet will copy the NuGet.Config file from legacy path to consolidated path, then delete the one in legacy path. 
NuGet will get user wide NuGet.Config file from consolidated path.

**3. Both legacy path and consolidated path exist.**

**3.1 If NuGet could determine how to consolidate the contents of the two**
  
  e.g. if the two files have the same contents, or one of them has the default content, NuGet could consolidate the two into consolidated path. After consolidation, NuGet will get config file from consolidated path.

**3.2 If NuGet could not determine how to consolidate the contents of the two**
  
  e.g. the two files are of different contents so there might be conflicting configurations, NuGet will show a warning, encouraging customers to consolidate the contents of the two and only keep the one in consolidated path. In this case, NuGet will get user wide NuGet.Config file from **legacy path**.


#### Pros: 
For scenario 1, 2, 3.1, only consolidated path exists, and new tooling will pick NuGet.Config file from consolidated path.
For scenario 3.2, if customer react to the warning, only consolidated path exists, and new tooling will pick NuGet.Config file from consolidated path.

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

**2. Legacy path exist, but consolidated path does not exist.**

NuGet will copy the NuGet.Config file from legacy path to consolidated path, and set up the legacy path to be a symbolic link to the consolidated path.

NuGet will get user wide NuGet.Config file from consolidated path. 

**3. Both legacy path and consolidated path exist, but legacy path is not a symbolic link.**

If NuGet could determine how to consolidate the contents of the two, NuGet will consolidate the two into consolidated path, and set up the legacy path to be a symbolic link to the consolidated path. After consolidation, NuGet will get config file from consolidated path.

If NuGet could not determine how to consolidate the contents of the two, NuGet will show a warning, encouraging customers to consolidate the contents of the two and only keep the one in consolidated path, and set up the legacy path to be a symbolic link to the consolidated path. In this case, NuGet will get user wide NuGet.Config file from **legacy path**.

#### Pros: 
If customer uses gloabal.json to pin different versions of dotnet dynamically, the old version of dotnet will pick config file from legacy path, which is actually the same file with the one in consolidated path. So all versions of dotnet could maintain a single copy of NuGet.Config files. 

#### Cons: 
Legacy path still exists for all scenarios, even if the NuGet.Config file is only in consolidated path, legacy path will be created as  a symbolic link.

If customer sets legacy path wrongly, e.g. a symbolic link pointing to a wrong path, NuGet could not detect if it's on purpose or it's a wrong setting. So NuGet won't break customers in this situation.

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

If the two config files are the same, NuGet will keep the one in consolidated path. If one of them is the default NuGet.Config file, NuGet will ignore the default one and chose the other one. Will any scenarios break if we ignore the default NuGet.Config file?

This should have covered most of the situations. Customers use both dotnet CLI and mono, but have different contents of user wide NuGet.Config file seems not reasonable.

Shall we do the generalized comparison on the two xml files? That is, if the two functionally work the same, then they're same. So  comments, space, key name differences will be ignored. It may need extra work compared with using string compare. Is this worth doing? 


**There is no symbolic link related .NET APIs for non-Windows platform for now.**

There is a [Proposed API for symbolic links](https://github.com/dotnet/runtime/issues/24271)
Shall we implement with P/Invokes first, and change them into .NET API later, when the APIs get implemented?


## Future Work
Get rid of the legacy path completely. 

## Open Questions

**Which dotnet version are we going to bring in this change? Is .NET 6 good?**

The version of .NET with this change will show warning to users who still have NuGet.Config in legacy path, encouraging them to move it to consolidated path.
So it's good if more people could get this warning and get prepared.


**Shall we insert this change into dotnet 2.x, 3.x as servicing patch?**

The bar for servicing patch should be high and for fixing security issues. So it won't be insert into dotnet 2.x, 3.x as servicing patch.  

**When can we get rid of the legacy path completely?**

The version of .NET with this change will show warning to users who still have NuGet.Config in legacy path, encouraging them to move it to consolidated path. If customers react to the warning, then they migrate to the consolidated path.
The next major version should be able to remove legacy path completely. Only customers who receive the warning (with two different NuGet.Config files), but don't act to the warning for the whole lifetime of the previous version of .NET. For other scenarios, NuGet will help customers consolidate the two automatically.


## Considerations
**Is there a way to know how many users are using global.json to pin different versions of dotnet dynamically?**

So that we can determine which solution 2 should be chosen. 


**If customers only have config file in legacy path, and have no idea of the consolidated path**

If taking solution 1, NuGet help customers automatically copy the config file from legacy path to consolidated path, and remove the  one from legacy path. Then customers might be confused that the config file under legacy path disappears, and they would probabaly create a new one in legacy path. 

If taking solution 2, NuGet help customers automatically copy the config file from legacy path to consolidated path, and set up the legacy path to be a symbolic link to the consolidated path. It might be easy for customers to find the change on legacy path.

**If we want to let customers to migrate on their own**
We can consider to show a warning with instructions if the conditions are not satisfied, and let customers to migrate on their own, but not helping customers migrate automatically. If customers follow the instructions and migrate, they must be aware of the change on the locations. If they don't react to the warning, NuGet will keep show the warning.

The main instructions in the warning will be:

Solution1: put the wanted config file in consolidated path, delete the one from legacy path/

Solution2: put the wanted config file in consolidated path, delete the on from legacy path is there is any. Set up the legacy path to be a symbolic link to the consolidated path by running one command `ln -s <legacy path> <consolidated path>`.

### References

* [Implicit restore](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-pack#implicit-restore)
