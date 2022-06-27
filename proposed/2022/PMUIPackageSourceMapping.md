# PMUI 
* Start Date: 6/25/22
* Authors: Ella McNally
* Issue

## Summary

Currently there is no support for package source mapping in the PMUI. I will add a feature that allows the user to choose a source to map a package to when they install it and a feature that shows all package source mappings in the preview. This feature is a portion of what was discussed in a previous spec. https://github.com/NuGet/Home/blob/dev/implemented/2021/PackageSourceMapping.md

## Motivation

Adding support for package source mapping in PMUI will allow user to make/view package source mappings with more ease. It will also help the user be more aware of where their packages are coming from and what mappings they have already configured

## Explanation

### Functional Explanation

#### Browse

##### Details Pane

The user will be able to choose whether or not they want to make a mapping to the source in the dropdown in the details pane. There will be a checkbox below the package version dropdown which the user can check if they want to map the package they are installing to the source they've selected above. If the user has all sources selected, then the checkbox will be grayed out because it doesn't make sense to let the user make mappings from a package to all configured sources.

##### Preview Dialog

After the user clicks install, they will see the mapping they made listed under the version on the preview dialog.

##### Transitive Packages

If the user trys to make a mapping when installing a package, but one of the transitive packages already has a mapping to a different source, then nothing will be written to the config. The user will get an error message saying that they could not install the package with the mapping because at least one transitive package already had a different mapping. They will also see a grid showing every transitive package and whether or not it already has a mapping (if so what it is mapped to).

#### Install

When a user selects a package they have already installed, they will see mappings they have previously made in the details pane under version.

#### Update



### Technical Explanation

The mapping will not be written to the config until the user selects okay on the preview dialog popup. A mapping will only be written to the config if the user selects the checkbox in the details pane. 

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

