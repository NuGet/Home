# Package Manager UI Tab-Switch Refactoring

* Status: In-process
* Author(s): [Donnie Goodson](https://github.com/donnie-msft)
* Issue: [10082](https://github.com/NuGet/Home/issues/10082) PMUI Package List Refactoring

## Problem Background

The NuGet Package Manager (PMUI) in Visual Studio (VS) has a design where navigating to a new tab will trigger a heavy reload of NuGet packages. At best, this is a perceivable flickering as the packages clear and repopulate. At worst, it can take 10's of seconds or even minutes. Reloading will reach out to the selected sources to retrieve an updated packages list. Nuget.org is generally quick, but some remote sources can be slow. 


## Who are the customers

Visual Studio users who may utilize the PMUI.

## Goals

* Eliminate the feeling of heavyweight navigation actions within the PMUI.
* Refactor some XAML and backing code to improve performance and maintainability.

## Non-Goals

* Protocol performance tuning (eg, HTTP caching) is not part of this effort.

## Solution
I believe we unnecessarily refresh the package lists on every tab-switch. Users can refresh their package data by using the Refresh button or performing any package action (ie, Install, Update, change Sources). 

Therefore, showing and hiding lists that are maintained in memory results in a much better experience.

### My branch
* My current branch (still actively working on it): https://github.com/NuGet/NuGet.Client/tree/dev-donnie-msft-prototypeTwoItemsLists
* Current commit on branch as of this writing: https://github.com/NuGet/NuGet.Client/commit/420e1d12fa418089f1f299b981d1ed409ee59cc4
* _(I've included links throughout this spec to specific lines)_

#### Active work
* [Loading Status Indicator refactoring for new tab lists paradigm #10150](https://github.com/NuGet/Home/issues/10150)
* [Updating in PMUI causes Object reference not set to an instance of an object #9882](https://github.com/NuGet/Home/issues/9882)
* [Refresh button should work in new tabbing paradigm #10147](https://github.com/NuGet/Home/issues/10147)
* [Store the search terms on each tab independently & Installed data is searched in UI #10148](https://github.com/NuGet/Home/issues/10148)
* [Details Pane needs to reselect appropriate package #10145](https://github.com/NuGet/Home/issues/10145)
* [Details Pane Versions Dropdown default selection should be Installed/LatestStable on Installed/Updates tabs #9887](https://github.com/NuGet/Home/issues/9887)

### Core Concepts
* From a user's point-of-view, there has traditionally been only one list of packages. My solution adds a **second Listbox** that I show and hide depending on selected tab. 

* Additionally, a WPF [CollectionViewSource.Filter](https://docs.microsoft.com/en-us/dotnet/api/system.windows.data.collectionviewsource?view=netcore-3.1#events) ("UI Filtering") is applied to only show packages with Updates Available on the Updates tab.

### High-level Logic
`_listBrowse` - Represents packages on the Browse tab only

`_listInstalled` - Represents packages on the Installed, Updates, and Consolidate tabs

**Browse tab**
* `_listBrowse` is Visibile https://github.com/NuGet/NuGet.Client/blob/420e1d12fa418089f1f299b981d1ed409ee59cc4/src/NuGet.Clients/NuGet.PackageManagement.UI/Xamls/InfiniteScrollList.xaml#L379
* `_listInstalled` is Collapsed https://github.com/NuGet/NuGet.Client/blob/420e1d12fa418089f1f299b981d1ed409ee59cc4/src/NuGet.Clients/NuGet.PackageManagement.UI/Xamls/InfiniteScrollList.xaml#L388

**Installed tab**
* `_listBrowse` is Collapsed
* `_listInstalled` is Visibile
* UI Filter set to null 

**Updates tab**
* `_listBrowse` is Collapsed
* `_listInstalled` is Visibile
* UI Filter set to only packages with an Update Available https://github.com/NuGet/NuGet.Client/blob/420e1d12fa418089f1f299b981d1ed409ee59cc4/src/NuGet.Clients/NuGet.PackageManagement.UI/Xamls/InfiniteScrollList.xaml.cs#L390

**Consolidate tab**
* `_listBrowse` is Collapsed
* `_listInstalled` is Visibile
* UI Filter: (TODO)


### Demo of improvement
The screen capture shows how snappy it is to change this visibility and apply UI filtering as opposed to clearing the list and refreshing data.
![GIF 10-14-2020 12-13-41 PM](https://user-images.githubusercontent.com/49205731/96022393-cad9a100-0e1e-11eb-80ef-8bb2b2974339.gif)


### Challenges
* Much of our XAML, code-behind, ViewModels (VMs), and other UI logic were based on the assumption of a single list. Therefore, I'm currently working on refactoring to resolve bugs this solution introduced. 
  * I feel this refactoring will pay off in the long-term as it's decoupling UI layers and working toward a more maintable and expandable design.
  * **Example bug (partially resolved as of 10/14/20)**: Updates Tab shows checkboxes for each package item. It does this by checking the currently selected tab to see if it's "Updates". That worked for a one-tab-loaded-at-a-time paradigm, but now with async loading of 2 lists, it can result in random checkboxes appearing on the Browse tab if you switch to Browse while Updates tab is loading. 

* For now, I'm allowing the code-behind to continue to serve as a "VM", though ideally I'll move toward a more generic structure. 

  **For example**:
  In the constructor, I'm having to hook up 2 list synchronization mechanisms. Not a big deal, but it's a code-smell:
  https://github.com/NuGet/NuGet.Client/blob/420e1d12fa418089f1f299b981d1ed409ee59cc4/src/NuGet.Clients/NuGet.PackageManagement.UI/Xamls/InfiniteScrollList.xaml.cs#L84-L95

  That smell reappears in new properties like `CurrentlyShownListBox` where I determine which tab is selected, then return the corresponding `ListBox` or `ObservableCollection`: 
  https://github.com/NuGet/NuGet.Client/blob/420e1d12fa418089f1f299b981d1ed409ee59cc4/src/NuGet.Clients/NuGet.PackageManagement.UI/Xamls/InfiniteScrollList.xaml.cs#L256

### XAML Memory impact
* Using the XAML debugger tools, I can see that an initially hidden ListBox does not load any XAML elements (it shows 0 or blank). 
* Once both ListBoxes have been shown once, the number of elements is proportional on both lists.
* I have not yet measured overall VS memory usage differences on the heap, etc. The expectation is this is capped since we use a VirtualizingStackPanel on our ListBoxes:
	    
    >VirtualizingPanel.IsVirtualizing="true"  
    VirtualizingPanel.VirtualizationMode="Recycling"  
    VirtualizingPanel.CacheLength="1,2"  
    VirtualizingPanel.CacheLengthUnit="Page"  

## Future Work

* [Browse Tab search terms can be filtered in UI prior to querying sources #10149](https://github.com/NuGet/Home/issues/10149)
* [Should Refresh button apply to all tabs? #10155](https://github.com/NuGet/Home/issues/10155)

## Open Questions

None

## Considerations

1. I attempted to dynamically add/remove child controls from the DockPanel. The result was nearly no improvement, as the time to repopulate the visual tree made it feel much less snappy.

    See: "**(Reverted) Dynamically Create ListBoxes and swap them with DockPanel Children**" https://github.com/NuGet/NuGet.Client/commit/6e5fe62a78b924d12f3ab18ee7ef1dfff7b351ea

## References
1. **Visual Studio Extensions Manager** window has some similarities in UX with the PMUI. I found that they use a `ListView` and swap out "Views", which I believe is a similar paradigm to this spec's solution. https://devdiv.visualstudio.com/DevDiv/_git/VS?path=%2Fsrc%2Fenv%2FMicrosoft.VisualStudio.ExtensionsExplorer.UI%2FUI%2FVsExtensionsExplorerCtl.xaml.cs&version=GBmain&line=990&lineEnd=991&lineStartColumn=1&lineEndColumn=1&lineStyle=plain
