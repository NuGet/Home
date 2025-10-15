# **NuGet Audit Sources in Visual Studio Options**

- Author: Donnie Goodson (<https://github.com/donnie-msft>)
- GitHub Issue: <https://github.com/nuget/home/issues/14583>

## **Summary**

Visual Studio currently supports NuGet Audit to help developers identify vulnerable packages. As adoption grows, customers need a convenient way to manage **Audit Sources** directly from the Visual Studio Options UI, rather than editing `nuget.config` manually. This proposal introduces first-class support for adding, removing, and updating Audit Sources in Visual Studio.

## **Motivation**

Pain-points today:

- Customers must manually edit `NuGet.Config` to configure `<auditSources>`.
  There can be multiple files containing this configuration.
- Lack of discoverability for audit-related settings in Visual Studio.

## **Explanation**

### **Functional Explanation**

Add an **"Audit Sources"** table to the "Package Sources" page in NuGet's Visual Studio Options.

- **Discoverability**: Enable Quick Search (Ctrl+Q) so that searching for "Audit Source" navigates to the Package Sources page in Unified Settings.
- Up to **Three Tables** can be shown in this order:
  - Package Sources (always shown)
  - Audit Sources (shown when explicitly configured),
  - Machine-wide Package Sources (shown when explicitly configured)
- New dropdown: **Choose how NuGet Audit retrieves vulnerability data**
  - Introduce a dropdown control to switch from **"Read vulnerabilities from my package sources"** to **"Configure sources to read vulnerabilities"**
  - When an audit source is configured, the Audit Sources table appears.
  - To configure the first audit source, select **"Configure sources to read vulnerabilities"**; this reveals the Audit Sources table.

#### Read vulnerabilities from my package sources

- Default option - if no audit sources exist, this will be the selection.
- Audit Sources table will be **hidden**.

![Existing package sources Visual Studio Options page shown with a new "Choose how NuGet Audit retrieves vulnerability data" dropdown](../../meta/resources/AuditSources-VS/audit-choose-package-source-page.png)

#### Configure sources to read vulnerabilities

- Audit Sources table will be **shown**.
- **Pre-selected**  when one or more audit sources are already configured.
  - The dropdown will be disabled as well since the presence of audit sources takes away the behavior of reading vulnerability data from package sources.
- **User-selectable** only when no audit sources exist, enabling  a customer to explicitly configure their first `<auditSource>` using the `Add` button.

![New dropdown expanded with both options shown"](../../meta/resources/AuditSources-VS/choose-nuget-audit-dropdown.png)

![Table of Audit Sources shown below Package Sources because Combobox option "Configure sources to read vulnerabilities" is selected](../../meta/resources/AuditSources-VS/audit-sources-visible-table.png)

- Switching the dropdown back to "**Read vulnerabilities from my package sources**" would not be supported in this iteration.
  - If customers want the ability to switch back from their audit sources to only package sources for Vulnerability data, a future iteration could support this and automatically clear `<auditSources>` after showing a warning messagebox that can be cancelled.

#### Describe Package versus Audit sources

Before each table, introduce descriptive text to reinforce with customers how Package Sources and Audit Sources work together.

- **Package sources**:

  > Configure the sources NuGet will use to for displaying and downloading packages. NuGet Audit will also reference vulnerability data from sources that support it. Alternatively, dedicated Audit Source(s) can be configured below.

- **Audit sources**:

  > Configure the sources NuGet Audit will use for retrieving Package Vulnerability data. If none are configured, any configured package sources that support Vulnerability data will be used by NuGet Audit.

### **Technical Explanation**

- Add an array setting titled "Audit Sources" to the "Package Sources" NuGet options page in the Unified Settings registration.json file.
- Make the "Audit Sources" array setting hidden unless the "Choose how NuGet Audit retrieves vulnerability data" value is "Configure sources to read vulnerabilities".
- Use existing NuGet.Configuration APIs to read/write `<auditSources>` in `nuget.config` files.

#### Telemetry

- Track management actions (add/remove/enable) of audit sources to better understand customer needs.

## **Drawbacks**

- Potential confusion for package sources that act as audit sources implicitly by having a vulnerability resource.

## **Rationale and Alternatives**

### Alternative 1: Always show Audit Sources table

No ComboBox to select - the Audit Sources table will always be available below package sources, relying on explanatory text to explain the behavior changes if any are configured.

![Table of Audit Sources shown below Package Sources in the existing package sources Visual Studio Options page](../../meta/resources/AuditSources-VS/audit-source-vs-options.png)

### Alternative 2: Create a Separate Options Page

Rather than share the page with Package Sources, create a new section, **Audit Sources**

- Advantages:

  - Less clutter on the Package Sources page.

- Disadvantages:

  - Separate UI for Package & Audit sources is potentially confusing, or at least more cumbersome for customers, as they are conceptually tightly related.
  - More duplication of code to setup a separate page which is nearly identical to the Package Sources page.

### Alternative 3: Audit Source Property on Package Sources

Add a new column to the Package Sources table, which is a property to configure how that package source behaves in regard to NuGet Audit.

Options include:

- "Package Source"
  - Create only a `<packageSource>` entry for this source.
  - This is treated as a package source, which could potentially be an implicit audit source. (*)See footnote

- "Audit Source"
  - Create only an `<auditSource>` entry for this source.

- "Both"
  - Create both a `<packageSource>` and `<auditSource>` entry for this source.

(*) The concern here is regarding confusion, because NuGet restore will sometimes use package sources for vulnerability data.
That scenario is when no `<auditSources>` have been configured, and an existing package source provides the VulnerabilityInfo resource.
Would setting the Audit property here to "Package Source" be clear that it _could_ be an audit source?
How does that differ from selecting "Both"?

## **Prior Art**

- Audit Sources are used by NuGet's CLI tooling and recently supported in Visual Studio.
- NuGet.Config support for audit sources was implemented consistently with other settings, so it follows that UI tooling to manage those audit sources would build upon that work.

## **Unresolved Questions**

None at this time

## **Future Possibilities**

1. Consider UI for Package Sources that are implicitly audit sources
    1. For implicit audit sources, modify the Package Sources table to show a checkbox or similar indicator that the package source provides vulnerability data.
    1. Validate audit source URLs by checking for `VulnerabilityInfo` resource in the service index.
1. Should there be a button to add `nuget.org` as an audit source?
1. Work with Unified Settings team to reduce whitespace due to a fixed-height table.
Today, if only 1 package source is shown, for example, the array is still around 6 rows in height.
Real estate is lost and this requires customers to unnecessarily scroll down to see audit sources.
