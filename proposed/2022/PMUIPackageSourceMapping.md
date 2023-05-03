# Package Source Mapping in PMUI 
* Start Date: 6/25/22
* Authors: Ella McNally, Donnie Goodson ([donnie-msft](https://github.com/donnie-msft))
* Issue: https://github.com/NuGet/Home/issues/11797

## Summary

Currently, there is no support for package source mapping in the NuGet Package Manager in VS (PM UI). We want to introduce mapping status for the package selected in the Details Pane of PM UI, as well as allow customers to choose whether to map the package to the selected source when they install or update. 

Package Source Mapping in Restore was introduced in: https://github.com/NuGet/Home/blob/dev/implemented/2021/PackageSourceMapping.md

## Motivation

Adding support for package source mapping in PM UI will allow customers to onboard and manage package source mappings more easily. It also increases awareness of where their packages will be coming from before initiating a package management action.

## Explanation

### Functional Explanation

On the details pane there will be two new rows below the Install/Update buttons. 

#### Row 1: Mapping Status and Settings link

A label will appear under the `Install/Update` button indicating the Package Source Mapping status.

A button to launch VS Settings to the NuGet Package Source Mapping settings page will be beside the label. The behavior is similar to the settings button beside the sources dropdown in the top right of the PM UI. The details pane will look like:

![PMUI 1](../../meta/resources/PackageSourceMapping/PMUI_details_pane.png)

#### Row 2: Consent to a New Mapping
 A `CheckBox` that allows the customer to choose if they want to add a mapping to the package from the selected source when they `Install`/`Update`. This `CheckBox` will always be shown even if package source mapping is not enabled. Package source mapping can be enabled by the customer checking the `CheckBox` to create the first mapping for the solution's settings. Once package source mapping is enabled, the customer must either have a mapping previously configured, or consent to a new mapping by checking the `CheckBox` to install. Otherwise, Restore will fail as it does today.

 PSM Enabled|Package Mapped|Current Behavior|Proposed Behavior
---|---|------|------|
No|No|regular install|regular install
Yes|No|Error in Error List|Preview Window appears showing mappings being created to selected source
Yes|Yes|regular install|Allow creating new mapping to selected source for each newly installed package (including transitives)
 
 The existing Preview Window dialog that shows when the customer hits `Install` or `Update` will be modified to list the mappings that will be made by their action. The customer already has the option to disable this preview dialog, so if they choose to disable it, there will be nothing telling them what mappings they made. The changes to the preview window will look like:

![PMUI 2](../../meta/resources/PackageSourceMapping/PMUI_preview.png)

#### Restore Errors

There are a few errors the customer could make while trying to install or update a package with a mapping that would make `Restore` fail. First, there could be issues with the transitive packages. Maybe there are transitive packages that are already mapped to a different source or the source that the customer is trying to map a package to does not support some of the transitive packages. 

The customer could also try to update a package that is already mapped to a different source, but the source it is mapped to does not support the version they are trying to update to. In these scenarios, `Restore` will fail in the same way it does today. The customer can see why `Restore` failed in the output window. 

### Technical Explanation

Package Source Mappings will be loaded from Settings when the PM UI is initialized and stored in a cache. Status for each selected package will be checked against this cache. Any changes to the Settings by external edits to the `nuget.config(s)` will invalidate this cache.

Package Management action logic will pass down a new mapping package ID and source name to Restore. Preview Restore Utilities will look for this new mapping and use it in the preview restore: By appending 2 package patterns, a "*" and the new package ID, along with the new mapping source name to Settings in memory.

Once preview restore determines the newly installed package IDs (top-level and transitive), those IDs will be checked against existing mappings. If an existing mapping is found, no new mapping is written for that package.

If a package is found in the Global Packages Folder (GPF), that package will be mapped to the selected source.

If the customer consents to the preview result, the new package source mappings (top-level and transitive) will be written to the applicable `nuget.config`.

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

In this example, the customer had `nuget.org` selected from the source dropdown. They clicked on the `Serilog` package on the installed tab, chose version `11.0.0`, and selected the checkbox to make a mapping from `Serilog` to `nuget.org`.

## Drawbacks

## Rationale and Alternatives

On the previous spec, there was a pin icon next to the sources dropdown to pin a source instead of a checkbox in the details pane. Reviewing with the UX Board, the pin concept may be confusing since there was nothing to explain what it did and it's not near the action buttons. The pin icon is used for different actions already in VS, like to pin a file at the top of the screen. It would be confusing to have the same button do different tasks in different parts of VS.

Here is the mockup for the pin icon:

![Options 3](../../meta/resources/PackageSourceMapping/VS.png)

## Prior Art

## Unresolved Questions

None

## Future Possibilities 

1. Currently, if an `Install`/`Update` cannot find transitive packages on the mapped source being mapped, the restore will fail. Reaching out to other configured sources and allowing the customer to select a different source for these packages may resolve this issue. However, care must be taken to avoid unintentionally leaking requested package IDs to these secondary sources when the customer hasn't agreed to such a query.

1. If a package is found in the Global Packages Folder (GPF), the PM UI could look at the source in the `nupkg.metadata` file. A new mapping could either be created for this source auotmatically, or it could be presented to the customer in the Preview Window or another affordance.