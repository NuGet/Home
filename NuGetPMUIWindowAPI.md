# Define an API for the NuGet Package Manager Window

* Status: **DRAFT**
* Author(s): [Donnie Goodson](https://github.com/donnie-msft)
* Issue: [9155](https://github.com/NuGet/Home/issues/9155) Allow Package Manager Window to be controlled via an API
* Type: Feature

# Background
A PM-spec for this feature is available here: https://github.com/NuGet/Home/wiki/%22Update...%22-Command-in-Context-Menu

# API Goals
#### Window & Tabs
   - Create a **new** PMUI Window when one isn't open
     - Param (optional): Set the Initial Tab (or default as it does, today) 

   - Switch to an **open** PMUI Window when one is already open 
     - Param (optional): Switch the selected Tab (or unchanged)
    
 #### Package Selection
 Modes:
   - All - _Checkmark all packages (Selection unchanged)_
   - PackageID - _Checkmark & Select the specific Package ID_
   - PackageList - _Checkmark all packages specified (Selection unchanged)_

Not Found: 
   - Select nothing and do not error
   - Perhaps record a NoOp Telemetry event?

#### Filters
_Not modifiable in this API_

# VS Service
Expose our PM UI object through a VS Service?

e.g., The `Object Browser` Window is accessed from Project System like this:

`var objectBrowser = this.ProjectNode.ServiceProvider.GetService(typeof(SVsObjBrowser)) as IVsNavigationTool;` (see [ViewReferenceInObjectBrowserAsync](http://ddindex/?leftProject=Microsoft.VisualStudio.ProjectSystem.VS.Implementation&leftSymbol=wpbjeyqrr6xl&file=Package%5cCommands%5cDefaultVsUIHierarchyWindowCmdsHandler.cs))


# Nexus (Internal only)
What do we expect to happen if someone says Update… on a menu in a LiveShare environment?
   - Design considerations for the API?
   - Use the `IServiceBroker`?
	
# Extensibility
Custom Project Systems could use this API to launch PMUI.

Do we want to support other Project Systems?
   - Could start internal, then expose later.

# Telemetry
#### Where should we measure invocations ? 
   - At the API-level
     -  Track API as an entry-point.
   - At the Plumbing-level
      - Track launches of PMUI in general (from existing entry points or this new API).
   - Both?

#### Context Menu interaction (New 'Update' option)
   - Measure the Context Menu usage (already part of VS Telemetry)

#### Should existing telemetry be relocated or annotated differently?
   - Theoretically changing what our Telemetry means from this point forward.
