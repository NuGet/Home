- Author: [Loïc Sharma](https://github.com/loic-sharma)
- Status: Withdrawn

## Issue
The work for this feature and the discussion for this spec are tracked here - [NuGetGallery#7896](https://github.com/NuGet/NuGetGallery/issues/7896)

## Problem Background

Package popularity strongly influences search rankings on NuGet.org. When you want to change the name of your package, you need to create a new package. This new package starts with no popularity and has to compete and likely underperforms against the older package. This leads to poor search quality for the new package.

For example, the following popular packages have been renamed:

Package | Replacements
-- | --
[FAKE](https://www.nuget.org/packages/FAKE/) | [fake-cli](https://www.nuget.org/packages/fake-cli/)
[EntityFramework.Extended](https://www.nuget.org/packages/EntityFramework.Extended/) |[ Z.EntityFramework.Plus.EFCore](https://www.nuget.org/packages/Z.EntityFramework.Plus.EFCore/), [Z.EntityFramework.Plus.EF6](https://www.nuget.org/packages/Z.EntityFramework.Plus.EF6/)
[iTextSharp](https://www.nuget.org/packages/iTextSharp/) | [itext7](https://www.nuget.org/packages/itext7/)
[Microsoft.Tpl.Dataflow](https://www.nuget.org/packages/Microsoft.Tpl.Dataflow/) | [System.Threading.Tasks.Dataflow](https://www.nuget.org/packages/System.Threading.Tasks.Dataflow/)
[Microsoft.SourceLink.Vsts.Git](https://www.nuget.org/packages/Microsoft.SourceLink.Vsts.Git) | [Microsoft.SourceLink.AzureRepos.Git](https://www.nuget.org/packages/Microsoft.SourceLink.AzureRepos.Git/)
[ManagedEsent](https://www.nuget.org/packages/ManagedEsent/) | [Microsoft.Database.ManagedEsent](https://www.nuget.org/packages/Microsoft.Database.ManagedEsent/)
[NuGet.Packaging.Core](https://www.nuget.org/packages/NuGet.Packaging.Core/5.3.0) | [NuGet.Packaging](https://www.nuget.org/packages/NuGet.Packaging )
[WindowsAzure.Storage](https://www.nuget.org/packages/WindowsAzure.Storage) | [Azure.Storage.Blobs](https://www.nuget.org/packages/Azure.Storage.Blobs)

### What about package deprecation?

Today, package authors can "rename" a package by deprecating it and adding a suggested alternative. In fact, packages like [`Fake`](https://www.nuget.org/packages/FAKE/) and [`NuGet.Packaging.Core`](https://www.nuget.org/packages/NuGet.Packaging.Core/5.3.0) have done exactly just that. This approach has a few flaws:

1. **Package deprecations does not affect search results**. For example, the package [`FAKE`](https://www.nuget.org/packages/FAKE/) is deprecated and suggests [`fake-cli`](https://www.nuget.org/packages/fake-cli) as an alternative, however, [searching for "FAKE"](https://www.nuget.org/packages?q=FAKE) yields [`FAKE`](https://www.nuget.org/packages/FAKE/) as the first result and [`fake-cli`](https://www.nuget.org/packages/fake-cli) as the thirteenth result.
1. **Package deprecations are version specific**. In other words, the author must deprecate each version of their package to effectively "rename" it. Furthermore, keeping deprecation messages consistent across many versions can be tricky. For example, notice how `NuGet.Packaging.Core` has inconsistent deprecations across versions [`5.3.0`](https://www.nuget.org/packages/NuGet.Packaging.Core/5.3.0) and [`5.4.0`](https://www.nuget.org/packages/NuGet.Packaging.Core/5.4.0).

## Solution

* [Add a "Rename" section to the "Manage Package" page](https://github.com/NuGet/Home/wiki/Support-package-renames#add-a-rename-section-to-the-manage-package-page)
  * [Saving renames](https://github.com/NuGet/Home/wiki/Support-package-renames#saving-renames)
  * [Pending renames](https://github.com/NuGet/Home/wiki/Support-package-renames#pending-renames)
* [Update the "Deprecation" section on the "Manage Package" page](https://github.com/NuGet/Home/wiki/Support-package-renames#update-the-deprecation-section-on-the-manage-package-page)
* [Show package renames on the "Display Package" page](https://github.com/NuGet/Home/wiki/Support-package-renames#show-package-renames-on-the-display-package-page)
* [Popularity Transfers](https://github.com/NuGet/Home/wiki/Support-package-renames#popularity-transfers)
* [Visual Studio (Preview)](https://github.com/NuGet/Home/wiki/Support-package-renames#visual-studio-preview)
  * [Show package renames on the "Browse" tab](https://github.com/NuGet/Home/wiki/Support-package-renames#show-package-renames-on-the-browse-tab)
  * [Show package renames on the "Installed" tab](https://github.com/NuGet/Home/wiki/Support-package-renames#show-package-renames-on-the-installed-tab)
  * [Show package renames on the "Updates" tab](https://github.com/NuGet/Home/wiki/Support-package-renames#show-package-renames-on-the-updates-tab)
* [.NET Core CLI (Preview)](https://github.com/NuGet/Home/wiki/Support-package-renames#net-core-cli-preview)

### Add a "Rename" section to the "Manage Package" page

We will add a new section to the "Manage Package" page that lets the package's owners link the current package to its replacements:

![image](https://user-images.githubusercontent.com/737941/77343450-ea787300-6cee-11ea-95f1-935ffc452fd1.png)

Clicking on the `Learn more` link will lead you to a documentation page detailing explaining how to "rename" a package. The documentation will also explain the transfer popularity feature.

You can select any package as the `New package` that is different from the current package as long as it has at least one listed and non-deleted version. Furthermore, the `New package` may be a package owned by a different account.

The `Provide custom message` field is a free-form field to give consumers more context on the package rename. This field is not required.

Selecting `Transfer popularity` will split the popularity of the current package and transfer it equally to the new packages (more on that in the next section). As a result, the new packages will now be favored in search rankings over the replaced package. Given transferring the popularity "hurts" the current package's search rankings, a warning message is displayed if a `Transfer popularity` checkbox is selected.

We will only allow up to 5 new packages. Once you reach the limit, the `+ Add more` link will disappear:

![image](https://user-images.githubusercontent.com/737941/79151860-146a0600-7d80-11ea-9449-bae28e6f527e.png)

#### Saving renames

Saving will notify the user that it may take several hours for this change to propagate through our system:

![image](https://user-images.githubusercontent.com/737941/79152031-5c892880-7d80-11ea-9bf3-82f09bcd4835.png)

#### Pending renames

Opening the "Rename" section will show a message if popularity transfers are pending:

![image](https://user-images.githubusercontent.com/737941/79151940-3794b580-7d80-11ea-82d8-09d4347dd235.png)

### Update the "Deprecation" section on the "Manage Package" page
We will add a `rename a package` link to the "Deprecation" section:

![image](https://user-images.githubusercontent.com/737941/79291677-1c12d300-7e84-11ea-8ea5-355996eb6404.png)

Clicking on this link will scroll down to the "Rename" section and expand it.

### Show package renames on the "Display Package" page

Once you've marked your package as renamed, the "Display Package" page will notify consumers:

![image](https://user-images.githubusercontent.com/737941/79152134-83dff580-7d80-11ea-9948-8b94802fe84f.png)

If you chose a single `New package`, the message on the "Display Package" page will read: `This package has been renamed`.

If you choose multiple `New package`s, the message on the "Display Package" page will read: `This package has been renamed or split into new packages`.

> **NOTE**: This message only appears on the old package that was renamed. The new packages' "Display Package" page won't say anything!

Below the `Additional Details` section is the free-form text provided by the package author. If no text was provided, the `Additional Details` section will be hidden.

### Popularity Transfers
Today, packages receive a popularity score based off their total downloads. These popularity scores influence search rankings: a package with a higher popularity score is more likely to be a top result.

Renamed packages will transfer a percentage of their downloads equally between the replacements that have `Transfer Popularity` checked. In other words, the replacement packages will have increased popularity scores. On the other hand, the renamed package will have a decreased popularity score. This transfer only affects popularity scoring, NuGet.org and Visual Studio will display packages' original downloads.

> **NOTE**: A package with both outgoing and incoming transfers will "ignore" the incoming downloads. The transferred incoming downloads are effectively lost.

### Visual Studio (Preview)

Visual Studio's search rankings will reflect popularity transfers due to package renames. For now, package renames information will NOT appear in Visual Studio. This will be added in the future.

> **NOTE**: The mock-ups below capture our vision for the experience on Visual Studio. These are early previews and may change!

#### Show package renames on the "Browse" tab

Customers should be notified that the package they are browsing has been renamed:

![image](https://user-images.githubusercontent.com/737941/79392503-559d1a00-7f28-11ea-82a4-0e5a09dcf341.png)

#### Show package renames on the "Installed" tab

Customers should be notified that a package they have installed has been renamed:

![image](https://user-images.githubusercontent.com/737941/79393361-0952d980-7f2a-11ea-9e4f-9f01a4eb773b.png)

The "Installed" tab will have an "Info" icon if an installed package has been renamed. This will be replaced by a "Warning" icon if an installed package is deprecated.

An "Info" icon will be added to the renamed package in the list of installed packages. This will be replaced by a "Warning" icon if the renamed package is also deprecated.

The details pane on the right side displays the rename information. A package that is both renamed and deprecated will show the deprecated message first, followed by the renamed message.

#### Show package renames on the "Updates" tab

Customers should be notified that a package with updates has been renamed:

![image](https://user-images.githubusercontent.com/737941/79393958-3653bc00-7f2b-11ea-8965-1873624b5885.png)

An "Info" icon will be added to the renamed package in the list of package updates. This will be replaced by a "Warning" icon if the renamed package is also deprecated.

The details pane on the right side displays the rename information. A package that is both renamed and deprecated will show the deprecated message first, followed by the renamed message.

### .NET Core CLI (Preview)

For now, package renames information will NOT appear in the .NET Core CLI. We will consider adding a `--renamed` option to the `dotnet list package` command.

## Feedback
If you have feedback, feel free to reach out in the following ways:

* GitHub on [NuGetGallery#7896](https://github.com/NuGet/NuGetGallery/issues/7896)
* Twitter at [@sharmaloic](https://twitter.com/sharmaloic)