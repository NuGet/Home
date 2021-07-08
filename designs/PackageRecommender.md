# PackageRecommender - spec to explore business/technical options.

Contacts: [rrelyea](https://github.com/rrelyea) [karann-msft](https://github.com/karann-msft)

## Repos/Work/Builds/Artifacts/Install

Targetting 16.6p1 to have A/B testable component.

### Part of VS repo

- source code would live in VS repo
- builds as part of your own build and then inserts VSIX or part of VS build?
- builds and update cycle independent of NuGet.Client builds
- Install as own VSIX - NuGet.PackageRecommender.vsix*
- interop with NuGet Client via interop apis - contract defined in recommender project
  - the contract dll needs to be published as a public package that nuget.tools.vsix can consume in our build.

Example repo that builds some DLLs, and has VSIX authoring:
https://github.com/microsoft/artifacts-credprovider#azure-artifacts-credential-provider
(can also look at NuGet.VisualStudio.Client.csproj in NuGet.Client for a different example)
- where should this be installed? inside its own extension directory.

- Setup authoring necessary to integrate into VS as dependency for NuGet:
(below is example of artifacts-credential-provider, which just drops DLLs)
 https://devdiv.visualstudio.com/DevDiv/_search?action=contents&text=Microsoft.CredentialProvider&type=code&lp=code-Project&filters=ProjectFilters%7BDevDiv%7DRepositoryFilters%7BVS%7D&pageSize=25&result=DefaultCollection%2FDevDiv%2FVS%2FGBmaster%2F%2Fsrc%2FSetupPackages%2FInstallerManifests%2FExternal%2FVisualStudio.External.vsmanproj
   (look at history of some of those files...see first change...and see all changes)

[Note, could be installed by default, or have a checkbox to let the user choose (still would have a default one way or another) -- if size gets huge, perhaps we would want to allow the checkbox...]

### Part of NuGet.Client repo

Changes necessary in NuGet.Client code:
in search pane, call recommender. display stuff.
UI changes - add some stars.
(reduce whitespace?)
diagnostics.
a/b testing ability.

[not planning to pursue this for the recommender code or model itself.]
- Build as part of NuGet.Client builds and public repos
- Would require NuGet insertion in VS/CLI/SDK/Mono every last minute build of NuGet. As such, the bar for taking a change late in the game for releases is very high.

## Client side and/or Server side? (answer: client side to start, and likely always)

### Background for Recommenders
    harvest package usage data from github.
    currently filtered to only use package ids from nuget.org

    intellicode is a similar model
        github data.
        but enable people to build custom models.

    
    we wanted to discuss, 
        is only nuget.org interesting.
        are custom models interesting.


After we find that this is successful via client A/B testing, 
we'll move to add search term support.
    on the client, that is likely possible with id filtering and description filtering on the client side (as part of model data)

over time, we may find people want custom models, and as such, we may then decide where the model would live:
    * on a nuget feed
    * in a git repo
    * other?

we should stay in sync with search telemetry advances.
Matt is going to share the telemetry PRs with Joel.

How do KPIs of search and recommender relate?

should we test non-stars??...