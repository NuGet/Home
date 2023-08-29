
# Spec Name

* Status: Implemented
* Author(s): [Heng Liu](https://github.com/heng-liu)
* Issue: [4413](https://github.com/NuGet/Home/issues/4413) [MacOS, Linux] NuGet writes the NuGet.Config in ~/.config folder, but dotnet restore reads from ~/.nuget 

## Problem Background

On Linux/Mac, NuGet has inconsistent paths of user wide NuGet.Config file for different NuGet tools. Dotnet CLI uses hard coded `~/.nuget` folder, so the user wide NuGet.Config path is `~/.nuget/NuGet/NuGet.Config`. While Mono uses the folder name from environment variable `APPDATA`, so by default, the user wide NuGet.Config file path is `~/.config/NuGet/NuGet.Config`. This is confusing.

Previously, we considered consolidating the two into one location in NuGet code. 
But since VS Mac (version 17.0 and later) runs on .NET rather than Mono, we revisit the previous discussions with VS Mac/Mono team. We both believe we should not change the dotnet CLI path, nor that of Mono’s, for the following reasons:
 * Majority users use the path `~/.nuget/NuGet/NuGet.Config`. Changing this path will be of high risk as it affects too many users.

   Dotnet CLI, VSCode, Riders use this path. 
   VS Mac (version 17.0 and later) runs on .NET rather than Mono. 
   On VS Mac (version 17.0 and later), only classic Mono project will use `~/.config/NuGet/NuGet.Config` to restore.
 * Mono is in maintenance mode. So even if NuGet changes the path `~/.config/NuGet/NuGet.Config` for Mono, the change won't flow to Mono.

For the sake of simplicity, we will refer to `~/.nuget/NuGet/NuGet.Config` as .nuget path and refer to `~/.config/NuGet/NuGet.Config` as .config path in the following.

## Who are the customers

Various NuGet tools users who work on Linux and Mac.

## Goals
Make users who have to maintain two user-wide config files in both .nuget and .config paths less confused and provide a workaround for them to maintain only one user-wide config file.

## Non-Goals
Completely get rid of any paths.

## Background knowledge
On Linux/Mac, user wide NuGet.Config file is created when trying to get the user wide NuGet.Config file at the beginning phase of running `dotnet restore` command(and many other dotnet commands with implicit restore if not specifying `--no-restore` option, like `dotnet new`, `dotnet build`, `dotnet run`, `dotnet test`, `dotnet publish`, and `dotnet pack`), or `dotnet msbuild -t:restore` command, but the user wide NuGet.Config file does not exist. Then the user wide NuGet.Config will be created with package source of nuget.org, as the only default package source. 

## Solution overview 
### Solution: No code change but update the document
Update the document of [Common NuGet configurations](https://docs.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior), explaining the inconsistency and providing the workaround of manually consolidating the two paths into one by setting up symbolic link.

#### Implementation
No code change and only the document gets updated.

#### Pros: 
Majority users who use .nuget path will not be affected. Users who have to handle two paths will be able to consolidate the two paths by following the instructions in the document in just a few minutes. It's also of low cost.

#### Cons: 
Users who encounter the "inconsistent user settings" issue might not be aware of the document.

## Considerations
### 1. In addition to the proposed solution, 2 of other solutions were considered.
#### **Solution 1:** 
If NuGet detects two paths both exist, warn/inform users and link the updated document in the warning/log.

**Implementation:**
Add following steps when trying to get user-wide config file path from .NET Core code path on Linux/Mac:

Check if the config files exist in both .nuget and .config path.
If yes, NuGet will show a warning/information links to the updated document.
If no, nothing will be changed.

**Pros:** 
The updated document will have a higher visibility when it's link is in warnings. Not sure about if it's just an info in the log. 

**Cons:** 
Users who have already consolidated the two paths by following the instructions in the updated document will still see the warning/information. It might be annoying.

We can only warn/inform users when they use NuGet tools based on .NET Core code path.

#### **Solution 2:**
If NuGet detects two paths both exists, and neither of them is the symbolic link path, warn users and link the updated document in the warning.

**Implementation:**
Add following checks when trying to get user-wide config file path from .NET Core code path on Linux/Mac:

1.If the config files exist in both .nuget and .config path. 

2.If any of them is a symbolic link path.

If 1 is yes, and 2 is no, NuGet will show a warning, linking to the updated document.
Otherwise, nothing will be changed.

**Pros:** 
The updated document will have a higher visibility when it's link is in warnings. 

Users who have already consolidated the two paths by following the instructions in the updated document will not receive this warning.

**Cons:** 
To identify if a path is a symbolic link or not, we need to use the [File.ResolveLinkTarget(String, Boolean) Method](https://docs.microsoft.com/en-us/dotnet/api/system.io.file.resolvelinktarget?view=net-6.0). It's only available in .NET 6 or later. To be able to use this API, we will have to retarget the projects related to this change to .NET 6. The cost of this work is high considering we only want to show a warning to the right users.

We can only warn/inform users when they use NuGet tools based on .NET Core code path.

### 2. How to raise the awareness of the updated document about the user-wide NuGet.Config file if using the proposed solution?
* The following NuGet.exe commands will change user-wide NuGet.Config file. The document of those commands should clarify that on Linux/MacOS, the default updated  config file the commands is in .config file.
  * [`NuGet.exe config`](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-config) command 
  * [`NuGet.exe sources`](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-sources) command 
  * [`NuGet.exe setapikey`](https://docs.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-setapikey) command

* Add the link of updated document into the related issues/feedback tickets.
https://github.com/NuGet/Home/issues/4413
https://github.com/NuGet/Home/issues/4095
https://github.com/NuGet/Home/issues/7839
https://github.com/NuGet/Home/issues/7980
https://developercommunity.visualstudio.com/search?space=41&q=NuGet.Config

* Ask VS Mac team if they could raise the awareness of the updated document from their side.

## Future Work
N/A

### References

* [Implicit restore](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-pack#implicit-restore)
