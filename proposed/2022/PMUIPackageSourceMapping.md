# PMUI 
* Start Date: 6/25/22
* Authors: Ella McNally
* Issue: https://github.com/NuGet/Home/issues/11797

## Summary

Currently there is no support for package source mapping in the PMUI. I will add a feature that allows the user to choose if they want to map the package to the source chosen when they install. I will also add error messages that tells the user if restore has problems with the mapping. This feature is a portion of what was discussed in a previous spec. https://github.com/NuGet/Home/blob/dev/implemented/2021/PackageSourceMapping.md

## Motivation

Adding support for package source mapping in PMUI will allow user to make/view package source mappings with more ease. It will also help the user be more aware of where their packages are coming from and what mappings they have already configured

## Explanation

### Functional Explanation

The user will be able to choose whether or not they want to make a mapping to the source in the package source combobox in the details pane. There will be a new checkbox below the package version dropdown which the user can check if they want to map the package they are installing to the source they've selected above. The checkbox will be grayed out and will not allow the user to make a mapping if `All` sources are selected from the dropdown. It would not make sense for a user to make a mapping from one package to all sources. The added checkbox will make the details pane look like:

<!--![image 1](PMUI_Mockup_1.jpg)-->
 
The existing preview dialog that shows when the user hits `Install` or `Update` will be modified to list the mapping they just made under the version. The user already has the option to disable this preview dialog, so if they choose to disable it, there will be nothing telling them what mappings they made. The changes to the preview window will look like:

<!--![image 2](PMUI_Mockup_2.jpg)-->

When the user installs a package with the new checkbox, one of 6 scenarios will happen. These 6 scenarios are in the table below:

| |Package Source Mapping is not enabled | Package Source Mapping is enabled and the package has previous mappings | Package Source Mapping is enabled and the package does not have previous mappings |
|---|---|---|---|
|Checked | Package source mapping is enabled. New mapping is created. Package is now mapped to only the new source| New mapping is created. Package is now mapped to the new source in addition to previous mappings | New mapping is created. Package is now mapped to only the new source.|
|Not Checked | Package source mapping is not enabled. Restore works as normal| No new mappings are made. Package only has previous mappings| |

#### Error Messages

There are a few errors the user could make while trying to install or update a package with a mapping that would make restore fail. I will address those errors with a popup telling the user what did not work. First, there could be issues with the transitive packages. Maybe there are transitive packages that are already mapped to a different source or the source that the user is trying to map a package to does not support some of the transitive packages. In either case, a popup would appear telling the user that the package source mapping could not be made. The popup would have a grid with a column showing the top level package and all of the transitive packages, a column showing if each package already has a mapping (if so what source it is mapped to previously), and whether the source supports the package. This error message will look like:

<!--![image 3](PMUI_Mockup_3.jpg)-->

Two more scenarios could arise when a user tries to update a package if that package has an exisiting mapping. First, the mapping could be to a different source than the one chose from the package source dropdown when `Update` is clicked. In this case, the user would get a popup error message telling them that it cannot update because the package already has a mapping to a different source and ask if the user would like to update using the other source instead. The user could click `OK` to update using the other source or `Cancel`. 

<!--![image 4](PMUI_Mockup_4.jpg)-->

The second scenario would be if the user tries to update a package that is already mapped to a different source (like the first scenario), but the source it is mapped to does not support the version they are trying to update to. In this case, the same popup error message would tell the user that the package is mapped to a different source, and that source does not support the version they are trying to install. The user would not be able to click `OK` in this case because restore would not be able to make this update.

<!--![image 5](PMUI_Mockup_5.jpg)-->

### Technical Explanation

The mapping will not be written to the config until the user selects `OK` on the preview dialog popup. A mapping will only be written to the config if the user selects the checkbox in the details pane. <!--if not checked then key=* ? Does the user have to make a mapping? Maybe if user does not check the box and package source mapping is already enabled then they will get a message saying they should make a mapping--> 

**Example 1** 

```xml
<PackageReference Include="Serilog" Version="11.0.0"/>
```

```xml
<packageSourceMapping>
    <packagesource key="nuget.org">
        <package pattern="Serilog" />
    </packageSource>
</packageSourceMapping>
```

**Result:**

In this example, the user had `nuget.org` selected from the source dropdown. They clicked on the `Serilog` package on the installed tab, chose version `11.0.0`, and selected the checkbox to make a mapping from `Serilog` to `nuget.org`.

## Drawbacks

## Rationale and Alternatives

On the previous spec, there was a pin icon next to the sources dropdown to pin a source instead of a checkbox in the details pane. I thought the pin was confusing since there was nothing to explain what it did. Also the same pin icon is used to different actions already in VS like to pin a file at the top of the screen. It would be confusing to have the same button do different tasks in different parts of VS.

Here is the the mockup for the pin icon:

![Options 3](../../meta/resources/PackageSourceMapping/VS.png)

## Prior Art

## Unresolved Questions

## Future Possibilities 

<!--would it be an error if the user unchecks the box? What if it disables psm?-->
<!--can the mappings be overwritten?-->
<!--When a user selects a package they have already installed, they will see mappings they have previously made in the details pane under version.-->
<!--Will the preview be able to be turned off or will it always show if there is a conflict? or preview is permanent if package source mapping is enabled? -->

