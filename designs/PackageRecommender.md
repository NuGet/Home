# PackageRecommender - spec to explore business/technical options.

Contacts: [rrelyea](https://github.com/rrelyea) [karann-msft](https://github.com/karann-msft)

## Repos/Builds/Artifacts/Install

### Part of NuGet.Client repo

- Build as part of NuGet.Client builds
- Would require NuGet insertion in VS/CLI/SDK/Mono every last minute build of NuGet. As such, the bar for taking a change late in the game for releases is very high.

### Part of VS repo

- builds and update cycle independent of NuGet.Client builds
- Install as own VSIX - NuGet.PackageRecommender.vsix*
- interop with NuGet Client via interop apis

## Client side and/or Server side?

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