
# Spec Name

* Status: In Review
* Author(s): [Heng Liu](https://github.com/heng-liu)
* Issue: [4413](https://github.com/NuGet/Home/issues/4413) [MacOS, Linux] NuGet writes the NuGet.Config in ~/.config folder, but dotnet restore reads from ~/.nuget 

## Problem Background

On Linux/Mac, NuGet has inconsistent paths of user wide NuGet.Config file for different NuGet tools. Dotnet CLI uses hard coded `~/.nuget` folder (`~/.nuget/NuGet/NuGet.Config`), while Mono uses the folder from environment variable `APPDATA`, (by default, it's `~/.config/NuGet/NuGet.Config`). This is confusing and we should consolidate the two into one location. 
After discussing in NuGet team and checking with Visual Studio Mac/Mono team, we believe we should change the dotnet CLI path to match that of Mono’s, for the following reasons:
 * On Linux/Mac, users usually get application data from environment variable APPDATA, which has the default value of ~/.config. Getting application data from ~/.nuget will cause inconsistency user experience between NuGet and other applications.
 * Getting application data from environment variable APPDATA on Linux/Mac will make it consistent with the behavior on Windows.

For the sake of simplicity, we will refer to `~/.nuget/NuGet/NuGet.Config` as legacy path, and refer to `~/.config/NuGet/NuGet.Config` as consolidated path in the following.

## Who are the customers
Dotnet CLI users who work on Linux and Mac.

## Goals
Make dotnet CLI user-wide config file path consistent with Mono on Linux/Mac and break as less dotnet CLI users as possible.

## Non-Goals
Completely get rid of the legacy path.

## Background knowledge
On Linux/Mac, user wide NuGet.Config file is created when trying to get the user wide NuGet.Config file at the beginning phase of running `dotnet restore` command(and many other dotnet commands with implicit restore if not specifying `--no-restore` option, like `dotnet new`, `dotnet build`, `dotnet run`, `dotnet test`, `dotnet publish`, and `dotnet pack`), or `dotnet msbuild -t:restore` command, and found the user wide NuGet.Config file does not exist. Then the user wide NuGet.Config will be created with package source of nuget.org, as the only default package source. 

## Solution overview 
Add following steps when trying to get user-wide config file path by running dotnet CLI on Linux/Mac:
(If it's not on Linux/Mac, or it's not in .NET core code path, we will not add those steps. So that the mono and dotnet CLI on Windows will not be affected.)
Check if the following conditions are satisfied.
•	The legacy path does not exist.
•	The consolidated path exists.
If yes, NuGet will get user wide NuGet.Config path from consolidated path.
If above condition is not satisfied, it should be in one of the following conditions:

** 1.Neither legacy path nor consolidated exists.**
In this scenario, user has never called NuGet in dotnet CLI or Mono before.
NuGet will create a default NuGet.Config file in consolidated path.
NuGet will get user wide NuGet.Config file from consolidated path. 

** 2.Legacy path exist, but consolidated path does not exist.**
In this scenario, user has called NuGet in dotnet CLI before, but has never called NuGet in Mono.
NuGet will copy the NuGet.Config file from legacy path to consolidated path, then delete the one in legacy path. 
NuGet will get user wide NuGet.Config file from consolidated path.

** 3.Both legacy path and consolidated path exist.**
In this scenario, user has called NuGet in both dotnet CLI and Mono before.
NuGet could not determine for users to consolidate the contents of the two NuGet.Config files, as there might be conflicting config.
NuGet will get user wide NuGet.Config file from legacy path, as dotnet CLI users do not expect the location of NuGet.Config file changes when dotnet version changes.
NuGet will also show a warning about the existence of NuGet.Config file in legacy path, encouraging users to consolidate the contents of the two and only keep the one in consolidated path.

### Scenarios from the developer side
** 1.Visual Studio for Mac** 
  It's in .NET Framework code path so it will not be affected by this change.

** 2.Mono CLI (NuGet)**
  It's in .NET Framework code path so it will not be affected by this change.

** 3.dotnet CLI (NuGet)**
  On windows, it will not be affected by this change.
  On Linux/Mac, this change will be applied.

** 4.CI/CD (Headless CLI)**
  On windows, it will not be affected by this change.
  On Linux/Mac, this change will be applied. But considering most users will put the URLs in a NuGet.config file in the repository, so the user wide NuGet.Conifg in both legacy path and consolidated path should be the default content in most cases. Not sure if there is any data we could use to prove this assumption.


### Challenges

* For users working with multiple versions of .NET SDK, and use global.json to pin different versions of dotnet dynamically, will they be affected?
Old versions of .NET SDK will generate the default user wide NuGet.Config file in legacy path, if it does not exist.
For dotnet CLI users who just follows the instructions to consolidate the two NuGet.Config files and only keep the one in consolidated path, they'll be confused. As they might not aware calling old dotnet CLI will create the NuGet.Config in legacy path again, which triggers the warning again (warn about the existence of NuGet.Config file in legacy path, encouraging users to consolidate the contents of the two and only keep the one in consolidated path). 
What's more, the lower version of dotnet CLI might break if the default user wide NuGet.Config doesn't work.
And, they still need to maintain user wide NuGet.Config in two different locations. 

We can help those users avoid maintaining user wide NuGet.Config in two different locations by ecouraging them to set the user wide NuGet.Config as following:
1. Put the real NuGet.Config file in consolidated path.
2. Create a symbolic link in legacy path, and point it to the consolidated path.
If the two above are set, users will only maintain the user wide NuGet.Config file in consolidated path.
But they will still receive the warning about the existence of legacy path.

We can help those users who follow the above two steps suppress the warning if we could detect if the following 4 conditions are satisfied:
1. The legacy path exists.
2. The consolidated path exists.
3. The legacy path is a symbolic link.
4. The symbolic link is pointing to the consolidated path.

We need the following APIs to implement the checking on the 4 conditions above:
1. Check if a path is a symbolic link or not
2. Check the target path of a symbolic path
But we don't have .NET APIs for non-Windows platform for now, so we need to implement the two functions by using P/Invokes.

We'd better know how many users are in this situation(use global.json to pin different versions of dotnet dynamically). 
Then we can determine if the extra work is worth doing, just to make their experience better, that is, do not receive warning every time about legacy path still exists because lower version of dotnet CLI) needs it.

* Users having both the legacy path and the consolidated path, users have to consolidate manually. Can we help them better?
e.g. If one of the user wide NuGet.Config file is a default NuGet.Config file, can we override it with the other one to consolidate?
     If NuGet.Config files in legacy path and consolidated path are the same, can we just delete the one in legacy path?
  The comparison between two xml files might be tricky. We need to consider the space, and the comments could be ignored, and the lines with same values but with different key names will be treated as the same.
  We need to consider if it's worth doing to help users consolidate the two NuGet.Config in these two conditions. Or just let users to manually merge the two.

## Future Work
Get rid of the legacy path completely. 

## Open Questions

* Which dotnet version are we going to bring in this change? 
Is .NET 5 good?
The version of .NET with this change will show warning to users who still have NuGet.Config in legacy path, encouraging them to move it to consolidated path.
So it's good if more people could get this warning and get prepared.

* Shall we insert this change into dotnet 2.x, 3.x as servicing patch? 
The bar for servicing patch should be high and for fixing security issues. So it won't be insert into dotnet 2.x, 3.x as servicing patch.  

* When can we get rid of the legacy path completely? 
The version of .NET with this change will show warning to users who still have NuGet.Config in legacy path, encouraging them to move it to consolidated path.
Since all old versions of dotnet still need the legacy path, we could not get rid of the legacy path if old versions are still in service.
The next major version should be able to remove legacy path completely if all the previous .NET versions are out of support.


## Considerations
* Is there a way to know how many users are using global.json to pin different versions of dotnet dynamically? 
Then we can determine if the extra work is worth doing, to make their experience better, that is, do not receive warning every time about the existence of legacy path, because lower version of dotnet CLI) needs it.

* Are we going to help users to consolidate the two NuGet.Config files in the following cases? How complex is it?
Any of the NuGet.Config file of the legacy path and consolidated path is a default config file.
The two NuGet.Config files are the same. 


### References

* [Implicit restore](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-pack#implicit-restore)
