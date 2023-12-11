# NuGet Package Management - Command Palette & Quick Picks in Visual Studio Code


- Jon Douglas, Allie Barry, Jean-Pierre
- GitHub Issue <!-- GitHub Issue link -->

## Summary

<!-- One-paragraph description of the proposal. -->
This proposal introduces a command palette experience including quickpick flows for NuGet package management. It covers browsing for a package and installing it, managing packages(removing, updating, etc) in existing projects & solutions, clearing caches/package folders, packaging a library, pushing it to a source, managing package sources, and opening the package manager.

Elaborate on the summary -- quick run down of each of the features and flow to help people understand what they are about to read 

table of contents with links to specific parts of the doc?

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Visual Studio Code now supports "C# Dev Kit" which is an extension that allows a .NET/C# developer to use familiar Visual Studio tooling for their purposes. This proposal brings integrated Visual Studio Code-like experiences directly into the extension to make it easier for .NET/C# developers to manage their packages and package-related tasks.

Requests for NuGet functionality are at an all time high since the general availability of C# Dev Kit. NuGet feature requests remain in the top 3 of GitHub issues on the C# Dev Kit repository. It was a popular ask at MVP Summit, Microsoft Build, and dotnetConf.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or pseudocode to show how this proposal would look. -->

#### Browse and Install a Package

##### Option 1: Navigating to add package directly in command palette

A new command is listed named `NuGet: Add a package...``.

![Screenshot showing the Visual Studio Code command palette with 'NuGet: Add package...' command at the top of the list and highlighted](../../meta/resources/vscode-commands/addpackage-commandpalette1.png)

When a developer selects this command, it will prompt them in a search box to provide a search term for a respective package to be found on their package sources. If the user wants to search specifically by a package attribute, they can do so by following the convention 'owner:Microsoft'. Otherwise, the search will search across all package attributes. (This search convention will work for the following attributes: owner, tag, and packageid.)

![Screenshot showing the quick picks search box prompting the user to enter a search term to search for a NuGet package.](../../meta/resources/vscode-commands/addpackage-searchbox.png)

The developer can then enter a search term to search for a NuGet package, and press enter. At this point, if they would like to cancel the operation, they can press the 'Escape' key on the keyboard. There will be a line of text underneath the searchbox that alerts the user of the functions of both the 'Enter' and 'Escape' keys here.

When the developer presses enter, the results box will appear and provide them a selectable list of packages that match their search term. For the first iteration of this experience, only the package ID will be shown in the search results. There are a few other possible options for what the search results could look like in the "Future Possibilities" section later in this document.

![Screenshot showing the list of search results of NuGet packages when a user searched for the term "Microsoft". The results are a list of package ids on nuget.org that match the search term "Microsoft".](../../meta/resources/vscode-commands/addpackage-searchresults.png)

Once a package is selected from the list, the user will then be prompted to select the version number that they would like to install.

![Screenshot showing a selectable list of version numbers for 'Microsoft.CSharp' package.](../../meta/resources/vscode-commands/addpackage-searchresults.png)

Once the user selects their desired version number, the package will be installed. Once installation has either succeeded or failed, the developer will recieve a toast notification notifying them of the status of the installation operation. If the installation has succeeded, the notification will read " Package X was successfully installed". If the installation has failed then the notification will read "Package X failed to install due to an error.". This toast will also include a blue button that says "More Information", which when clicked, will direct the developer to the output window where they can see why the installation failed.

![Screenshot showing failed package install notification](../../meta/resources/vscode-commands/addpackage-failurenotification.png)

![Screenshot showing successful package install notification](../../meta/resources/vscode-commands/addpackage-successnotification.png)

##### Option 2: Navigating to 'NuGet: Add Package' command through C# DevKit Solution Explorer

A developer will also be able to access the same add package command through a right click experience built directly into the solution explorer offered through C# DevKit. We want to provide an experience that aligns closely with the experience that is currently offered in, and future plans for, C# Dev Kit. When interacting with the solution explorer for C# projects that is offered through DevKit, many of the elements that exist today can be interacted with through a similar right-click experience, as well as icons that appear on hover of these elements that allow for quick selection of common functions. We want to incorporate this functionality into the NuGet VS Code experience to allow for a seamless and well-rounded experience for C# Developers.

In the solution explorer, there is a "Dependencies" node, and within that node, there is a "Packages" node, which contains a list of all of the NuGet packages directly installed into the solution in question. When a user hovers over this "Packages" folder, they will see a small plus sign icon appear in line on the far right.

![A screenshot showing the plus sign icon that will appear next to the "packages" folder when a user hovers over it](../../meta/resources/vscode-commands/addpackage-plussign.png)

Additionally, when the user right clicks on this Packages folder, they will see a menu show up, providing them with options to manage their NuGet packages. Specifically, they will see an option to "Add package...".

![Screenshot showing the menu that will appear when a user right clicks on the "packages folder" in C# DevKit. The menu contains an option to add a nuget package](../../meta/resources/vscode-commands/addpackage-rightclickmenu.png)

When the user selects the "Add package" menu list item, or when they select the 'plus sign' icon that appears on hover next to the
'Packages' folder, the command palette will open and they will be guided through the same package install process described in option 1, starting with the empty search box to search for a specific package. 

![Screenshot showing the quick picks search box prompting the user to enter a search term to search for a NuGet package.](../../meta/resources/vscode-commands/addpackage-searchbox.png)

#### Removing a Package

##### Option 1: Navigating to remove package directly in command palette

A new command is listed named `NuGet: Remove a package...``.

TODO: Add a screenshot of the command palette option for remove package

When a developer selects this command, it will prompt them in a search box to provide a search term for a respective package to be found within the packages they have installed in their current solution. Beneath the search bar, a list of all of these packages installed in the solution will appear, and the developer will have the option to enter a search term to narrow down the list, or just select directly from the list provided.

TODO: show screenshot of what the experience described above will look like (search bar with list of all installed packages below it)
Question: do we want to provide check boxes and allow multiple packages to be selected at once? or could this be a possible addition for a future iteration

##### Option 2: Navigating to 'NuGet: Remove package' command through C# DevKit solution explorer

A developer will also be able to access the same remove package command through a right click experience built directly into the solution explorer offered through C# DevKit. In the dependency node, if the developer right clicks on a specific package in the folder, they will see a menu of options for operations to perform on this specific package. One of these options will be: "Remove package".

Option to use the existing delete command & key binding?

TODO: Define the remove package experience ... I assume we want to prompt the user to confirm this action and not just delete right away.

#### Updating a Package

##### Option 1: Navigating to update package directly in command palette

A new command is listed named `NuGet: Update a package...``.

TODO: add a screenshot of the command palette option for updating a package

##### Option 2: Navigating to 'NuGet: Update Package' command through C# DevKit soltion explorer

A developer will also be able to access the same update package command through a right click experience built directly into the soltion explorer offered through C# DevKit. In the dependency node, if the developer right clicks on a specific package in the folder, they will see a menu of options for operations to perform on this specific package. One of these options will be: "Update package".

TODO: Define update package experience

#### Clearing package caches/folders

TBD

#### Packaging a Library

TBD

#### Pushing a package to a source

TBD

#### Managing package sources

TBD

#### Opening a Package Manager

TBD

#### Navigating back in operation flow

At any point during a specific package operation using the command palette, the user will have the option to navigate back, and undo their most resent previous selection. They can do this by...

TODO: define how the navigating back experience will look
Ask Wendy about if this is something they do/enable currently

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->

expand on possibilities for future iterations ( more package details in the quick picks list, etc.)
