# NuGet PMUI Tab Consolidation

- Allie Barry @albarry4
- Start Date 7/27/2023

## Summary

This proposal suggests a solution to reduce the 3 tab format of the NuGet PMUI in Visual Studio as a first step to simplify and modernize the UI, and to address recent customer feedback.  

## Motivation 

We have recently recieved feedback from custmers that the NuGet PMUI design is "clunky" and "requires too much clicking over all the tabs, checkboxes... takes too much clicking and surfing to navigate to varius changelogs". Based on this feedback, I wanted to propose an initial solution to specifcially target and reduce the amount of clicking, and to simplify and consolidate the controls within the PMUI by reducting the number of tabs available. Specifically, this proposal aims to consolidate the "Installed" and "Updates" tabs into a single window titled "My Packages".

Note: I want to include data here about tab click-through rates, but am still working on getting access to that data!

## Explanation

### Functional explanation

Put simply, the end goal of this proposal is to reduce the number of tabs in the NuGet PMUI, and to simplify the format of the User interface. 

In this new experience, instead of seeing three tabs ("Browse", "Installed", "Update"), the user will see two tabs at the top of the screen, "Browse", and "My Packages". Below, I will describe how these two tabs will behave. 

The "Browse" tab will remain unchanged from the current design. 

Within the "My Packages" tab, the user will see a list of the packages that they have installed in the current project. The layout of the tab will remain mostly unchanged from the general layout of the seperate "Installed" and "Updates" Tabs that we see today, but with a few tweaks to consolidate all of this information into one tab. 

If no installed backages have an update available, this is what the user will see:

![image](https://github.com/albarry4/Home/assets/89422562/ce769bc6-ae6d-48b0-b093-730881d7ef2d)


If the user has a package installed with an update available, this is what the user will see: 

![image](https://github.com/albarry4/Home/assets/89422562/f13f6a26-e023-4aca-bb47-826581d61952)



### Technical explanation

All packages with an update available will have a checkbox next to it, with the option at the top of the screen to select all, and bulk update all packages with an available update, or handle them on a one-at-a-time basis. This behaves similarly to the current functionality of the "Updates" tab

## Drawbacks

The current layout with the three tabs provides an inutitive design with a clear, seperate function for each of the tabs (browse packages, view the packages I have installed, update packages). Moving away from this concept might cause a disruption to users who have been using our platform for a long time, and are familiar with this current experience. However, based on feedback as well as a movement towards a more modern UI, designing a simpler and more consolidated UI will keep NuGet relevant and ultimately adress many painpoints of the newer developer demographic.

Additionally, consolidating all of this informaiton onto one tab would create one busier tab as opposed to two tabs with less elements/clutter. However, we want to utilize and make the most of available "real estate" on your UI, and minimize the amount of "clicking around" that customers have to do to accomplish a task. 

## Rationale and alternatives

Alternatives to be considered int his design could be the placement of specific elements on the screen, as well as the way in which bulk update capabilities can be transferred to this new UI concept. The current proposed design bubbles updates up to the top, but we could also consider the concept of putting it over to the side of the screen, or doing "nested tabs" where within the "My Packages tab, the user would see two tabs -- one with all installed packages and one just with packages with available updates. However, this "nested tab" alternate design could be slightly counterintuitive, as it would achieve the goal of condensing the highest level of segmentation within the UI (the top level tabs), but would likely not do much for reducing the amount of clicks required between tabs to accomplish the task of updating a package. 


## Prior Art

The basis of this design comes from other similar and more modern virtual software marketplace designs we see today such as the Microsoft Store app for Windows. The current experience in the Microsoft Store allows for the user to browse apps of different types (Apps, Games, Entertainment), and then there is one single tab view titled "Library" which displays all of the different apps that a user has installed, and when an update is available in one of these apps, it is bubbled up to the top and the user can install the update. Once the update has completed, the app resturns the the list with the rest of the up to date apps. The end-goal experience for NuGet would be similar to this. 

Below shows a screenshot of how this experience looks when an app on the Microsoft Store has an update available.

![image](https://github.com/albarry4/Home/assets/89422562/f7c5502c-fc7c-4f3f-baa7-88349cb5d884)


## Unresolved Questions

Still need to analyze tab clickthrough rate data and include in this proposal 

Should a package with an update available appear in both the "updates" list and the "installed" list? or just the "updates" list?

## Future Possibilities

TBD - continued modernization of the NuGet UI in VS, as well as the creation of a fresh NUget UI for Visual Studio Code 
