# PM UI: Action Selection for Installed Packages

- Author(s): [Jeff Handley](https://github.com/jeffhandley)
- Issue: [1](https://github.com/NuGet/Home/issues/1) UI: Action changes to updating previous version after installing
- Type: Feature
- Status: Implemented

## Problem Background

After installing the latest version of a NuGet package in the Visual Studio Package Manager UI (PM UI), the user experiences unexpected behavior:

1. The **Action** dropdown changes to "Update"
2. The **Version** dropdown changes to the previously installed version
3. The action **button** changes to "Update"

This behavior is confusing because the user just finished installing a package and is now being presented with an action that suggests they should update — to a version they already had before the install. The intent after an installation should be either to keep the current version (and offer Uninstall) or to upgrade to a newer version if one is available.

## Who Are the Customers

- All developers using the Visual Studio NuGet Package Manager UI to install or manage NuGet packages in their projects or solutions.

## Requirements

When a user selects a package that is already installed in the Package Manager UI:

1. **If a newer version is available** (respecting the prerelease checkbox setting): The latest available version should be selected and the action should be set to **Update** (or **Upgrade** for project-level management).
2. **If the installed version is already the latest** (respecting the prerelease checkbox setting): The action should be set to **Uninstall**.

These requirements apply after an installation completes and when selecting an already-installed package from the **Installed** tab.

## Goals

- Fix the post-install state so the PM UI reflects an accurate action after installing the latest version of a package.
- For **project-level** package management: provide clear separation between **Upgrade** and **Downgrade** actions.
  - If upgrades are available, prefer **Upgrade** and select the latest available version.
  - If no upgrades are available (i.e., the latest version is already installed), select **Uninstall** rather than **Downgrade**.
  - The action ordering encourages upgrading over downgrading.
- For **solution-level** package management: retain the single **Update** action.
  - A given version may be an upgrade for one project but a downgrade for another in the same solution, so a simple Upgrade/Downgrade split is not meaningful at the solution level.

## Non-Goals

- Change the behavior of the **Browse** tab or the **Updates** tab.
- Modify how version lists are constructed or queried.
- Change the semantics of the Uninstall action itself.
- Handle solution-level Upgrade/Downgrade separation (deferred to a future iteration if needed).

## Solution

### Project-Level Package Management

The project-level Package Manager UI is updated to separate the **Upgrade** and **Downgrade** actions, replacing the generic **Update** action. This provides clearer intent for the user:

- **Upgrade**: Install a version that is newer than the currently installed version.
- **Downgrade**: Install a version that is older than the currently installed version.
- **Uninstall**: Remove the currently installed package from the project.

**Action selection logic when a package is selected in the Installed tab (project level):**

1. Check whether there are versions newer than the installed version available (respecting the prerelease checkbox).
2. If newer versions exist:
   - Set the action to **Upgrade**.
   - Select the latest available version in the version dropdown.
3. If no newer versions exist (the installed version is the latest):
   - Set the action to **Uninstall**.
   - Do not default to **Downgrade**; only show Downgrade if the user explicitly chooses it.

This ordering — Upgrade first, then Uninstall, then Downgrade — ensures users are guided toward upgrading their packages before considering removal or downgrading.

### Solution-Level Package Management

At the solution level, the **Update** action is retained without splitting it into Upgrade/Downgrade. This is because:

- A solution may contain multiple projects with different versions of the same package installed.
- A version that is newer for one project may be older for another project.
- Splitting into Upgrade/Downgrade at the solution level would require per-project logic that would be ambiguous and confusing.

**Action selection logic when a package is selected in the Installed tab (solution level):**

1. Check whether there are versions newer than the currently installed version (for any affected projects).
2. If newer versions exist:
   - Set the action to **Update**.
   - Select the latest available version in the version dropdown.
3. If no newer versions exist:
   - Set the action to **Uninstall**.

## Considerations

- The prerelease checkbox setting must be respected when determining whether a newer version is available. If prerelease is unchecked, only stable versions are considered when checking for available upgrades.
- The version dropdown is updated to reflect the pre-selected version based on the action chosen, so the user sees the recommended target version immediately.
- These changes apply specifically to the **Installed** tab behavior and post-installation state; the **Browse** and **Updates** tabs continue to behave as before.
