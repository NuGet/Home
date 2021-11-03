# PMUI Navigation Responsiveness & Architecture enhancements 
- Author Name [Donnie Goodson](https://github.com/donnie-msft)
- Start Date (YYYY-MM-DD)
- GitHub Issue [10082](https://github.com/NuGet/Home/issues/10082) 
- GitHub PR (GitHub PR link)

## Summary

<!-- One-paragraph description of the proposal. -->
The NuGet Package Manager (PMUI) in Visual Studio (VS) has a design where navigating to a new tab will trigger a heavy reload of NuGet packages. At best, this is a perceivable flickering as the packages clear and repopulate. At worst, it can take 10's of seconds or even minutes. Reloading will reach out to the selected sources to retrieve an updated packages list. Nuget.org is generally quick, but some remote sources can be slow. 

## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
* Much of our XAML, code-behind, ViewModels (VMs), and other UI logic were based on the assumption of a single list. Therefore, I'm currently working on refactoring to resolve bugs this solution introduced. 
  * I feel this refactoring will pay off in the long-term as it's decoupling UI layers and working toward a more maintable and expandable design.
  * **Example bug**: Updates Tab shows checkboxes for each package item. It does this by checking the currently selected tab to see if it's "Updates". That worked for a one-tab-loaded-at-a-time paradigm, but now with async loading of 2 lists, it can result in random checkboxes appearing on the Browse tab if you switch to Browse while Updates tab is loading. 

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
* Eliminate the feeling of heavyweight navigation actions within the PMUI.
* Refactor some XAML and backing code to improve performance and maintainability.

I believe we unnecessarily refresh the package lists on every tab-switch. Users can refresh their package data by using the Refresh button or performing any package action (ie, Install, Update, change Sources). 

Therefore, showing and hiding lists that are maintained in memory results in a much better experience.

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

From a user's point-of-view, there has traditionally been only one list of packages. 

* Protocol performance tuning (eg, HTTP caching) is not part of this effort.

## Drawbacks

<!-- Why should we not do this? -->
* If the PM UI is to be replaced by another UI, technology stack, etc, then this work may not be an efficient use of time.

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
* 
* I attempted to dynamically add/remove child controls from the DockPanel. The result was nearly no improvement, as the time to repopulate the visual tree made it feel much less snappy.

    See: "**(Reverted) Dynamically Create ListBoxes and swap them with DockPanel Children**" https://github.com/NuGet/NuGet.Client/commit/6e5fe62a78b924d12f3ab18ee7ef1dfff7b351ea

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->
1. **Visual Studio Extensions Manager** window has some similarities in UX with the PMUI. I found that they use a `ListView` and swap out "Views", which I believe is a similar paradigm to this spec's solution. https://devdiv.visualstudio.com/DevDiv/_git/VS?path=%2Fsrc%2Fenv%2FMicrosoft.VisualStudio.ExtensionsExplorer.UI%2FUI%2FVsExtensionsExplorerCtl.xaml.cs&version=GBmain&line=990&lineEnd=991&lineStartColumn=1&lineEndColumn=1&lineStyle=plain

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

* [Should Refresh button apply to all tabs? #10155](https://github.com/NuGet/Home/issues/10155)

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
* A client filtering mechanism can be introduced more easily with this refactoring.
    * Example: [Browse Tab search terms can be filtered in UI prior to querying sources #10149](https://github.com/NuGet/Home/issues/10149)