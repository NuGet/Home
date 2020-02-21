# Define an API for the NuGet Package Manager Window

* Status: **DRAFT**
* Author(s): [Donnie Goodson](https://github.com/donnie-msft)
* Issue: [9155](https://github.com/NuGet/Home/issues/9155) Allow Package Manager Window to be controlled via an API
* Type: Feature

# Background
A PM-spec for this feature is available here: https://github.com/NuGet/Home/wiki/%22Update...%22-Command-in-Context-Menu

# API
# Nexus (Internal only)
	What do we expect to happen if someone says Update… on a menu in a LiveShare environment?
	
# Extensibility
	Custom Project Systems could use this API to launch PMUI.

# Telemetry
 - Where do we measure invocations? At the API-level, or in the plumbing?
   - Are there two metrics worth tracking? One, the API usage. And Two, the invocations of PMUI in general.
   - Should existing telemetry be relocated or annotated differently?
   - Theoretically changing what Telemetry means from this point forward.
 - Context Menu (New 'Update' option)
   - Measure the Context Menu usage (already part of VS Telemetry)

