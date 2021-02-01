# NuGet Client Team Dev Process

- Status: **Implemented**
- Author: [Kat Marchan](https://github.com/zkat)

# Issue

[#8994](https://github.com/NuGet/Home/issues/8994)

# Background

For a while now, the NuGet Client team has been using [ZenHub](https://zenhub.com) as part of its development process. At the same time, while ZenHub provides a lot of features, the team isn't taking advantage of some of the nicer ones, such as its charting capabilities and its Roadmap feature. It also has other features, like Blockers and Epics, which the team does use but could be using more often, or differently.

This proposal is aimed at overhauling the Client Team's usage of ZenHub and further streamline its public development process to increase velocity, as well as increase visibility into what's being done, and what needs to be done. It also describes existing processes, so this document may be used as a reference for development flow.

# Prerequisites

Easiest way to use ZenHub in context of an GitHub project is to install [ZenHub browser extension](https://help.zenhub.com/support/solutions/articles/43000507578-installing-the-zenhub-extension). If you are using Chromium-based [Microsoft Edge](https://www.microsoft.com/edge), you have to enable "Allow extensions from other stores" in [edge://extensions](edge://extensions) and install the extension from Chrome Web Store.

After installing the extension, first time navigation to the link to a ZenHub board will log you in with your GitHub credentials.

# Proposal

## OKR Tracking

- Link: https://github.com/NuGet/Home#workspaces/nuget-client-team-55aec9a240305cf007585881/roadmap?repos=29996513

One of the main additions in this proposal is that it adds (indirect) tracking of OKRs into our ZenHub process. The way this works is by using ZenHub's Roadmap feature.

Each quarter, Epics should be created for particular public KRs (internally associated with Objectives, but we don't publish this), with dates adjusted appropriately. Ideally, all work will exist under some quarterly epic and be displayed on the roadmap. While we want to hide the mechanics of OKRs from public view, it is still useful to communicate with each other, and with the larger community, about what work we have scheduled on the roadmap, and how complete that work is. The Roadmap feature is perfect for this!

## Epic Tracking

The Client Team uses Epics to track high-level status of various issues. Epics should be created for tracking large verticals of work, or when there's many disparate subtasks that will be involved and potentially assigned to multiple people, or involve multiple PRs to complete. As described in [OKR Tracking](#okr-tracking), they should also be created to track specific (public) KRs.

Another way to think about Epics is: if there is a customer-facing feature, an Epic should be the parent of all tasks from spec'ing to writing the actual code to test to insertion to shipping and writing docs.

Concretely, these are GitHub issues tagged as Epic, and they navigate the board slightly different from regular issues:

1. When any issue under an Epic is In Progress, the associated Epic should be moved to the In Progress pipeline as well.
2. Epics should remain under "In Review" or "Validating" until the related change is available to customers. That is, they shouldn't be closed until released.

Tracking Epics in this way allows customers and stakeholders to see a more fine-grained view of the status of any KR work by going to the Board and [filtering by Epics and hiding subtasks](https://github.com/NuGet/Home#workspaces/nuget-client-team-55aec9a240305cf007585881/board?epics:settings=epicsOnly&filterLogic=any&repos=29996513).

## Sprint Tracking

Previously, the Client Team used GitHub labels to track its 3-week sprints, using the format `Sprint <number>`, and Milestones to track release versions. Now, the Client Team uses GitHub Milestones to track sprint tasks. This is done for one main reason: enabling the [Velocity Tracking](https://github.com/NuGet/Home#workspaces/nuget-client-team-55aec9a240305cf007585881/reports/velocity) and [Burndown](https://github.com/NuGet/Home#workspaces/nuget-client-team-55aec9a240305cf007585881/reports/burndown?milestoneId=4983201) reports.

Issues start off without an assigned sprint. During Sprint Planning at the beginning of each Sprint, items in the Backlog should be assigned to an appropriate Sprint Milestone, as well as (generally) assigned to someone who will be working on it during that sprint.

Over time, doing things this way will allow the Client Team to get a sense of its overall Velocity, which will help with future planning and resourcing.

At the beginning of every sprint, issues that were partially worked on but not completed should be re-estimated to reflect the amount of work **left to be done**. While this means velocity data may be partially "lost", [it's a better choice for the sake of estimating the new sprint, which is what should matter more](https://www.scrum.org/index.php/forum/scrum-forum/29033/re-estimate-story-points-or-not).

## Quality/Engineering Backlog Handling

By using certain tags, the Client Team maintains ongoing quality and engineering backlogs, which represent things like bugs, engineering improvements, and tech debt.

Every 6 months or so, the Client Team dedicates one sprint just to these backlog issues, with a full-team push in that direction.

## Release Tracking

As mentioned above, the Client Team used GitHub Milestones to track releases. Since those are now being used for Sprints (for the sake of ZenHub tracking reports), release tracking is moved to the [Release feature](https://github.com/NuGet/Home#workspaces/nuget-client-team-55aec9a240305cf007585881/reports/release?release=5e0e5fbd021f7aa0ec95db18) in ZenHub.

When issues are scheduled, they should be assigned an appropriate Release, along with a Sprint.

In order to generate release changelogs, the team should use [the ZenHub API](https://github.com/ZenHubIO/API#get-all-the-issues-for-a-release-report) -- possibly through [ZenHub.NET](https://github.com/AlexGhiondea/ZenHub.NET/blob/21cd562b30570594beb3842b28c372d66f87dcc6/src/ZenHubReleaseClient.cs#L84-L90).

## Tracking Private/Sensitive Issues

This document focuses on **public** issue tracking. Private issues, such as private design specs and security issues are handled through a private repo and tracked separately.

## The Board

- Link: https://github.com/NuGet/Home#workspaces/nuget-client-team-55aec9a240305cf007585881/board?repos=29996513

### Pipelines

These are the columns on the board, and each one has a specific purpose, described below. Note that epics are handled slightly different, as outlined in [Epic Tracking](#epic-tracking):

#### New Issues

This is the default pipeline/column for incoming issues. Whenever a new issue is created in NuGet/Home, a card is added here to represent that story.

As the team works to whittle down the list of issues in the repository, this pipeline will become empty except for un-triaged issues. From here, one of three things will happen to an issue:

1. It will be moved to the Icebox
2. It will be moved to the Backlog
3. It will be closed

#### Icebox

The Icebox is for issues the team thinks are worth doing, doesn't foresee having time to do themselves. Generally, these issues should also be tagged as `help wanted` and, if appropriate, `good first issue`. Issues from the Icebox can progress in two ways:

1. If the Backlog is exhausted
2. The issue is closed because it's no longer relevant

#### Backlog

The Backlog is the overall task list for the Client Team. This is the work the team intends to be doing itself in the current sprint or in the next two sprints. Anything else goes back in the Icebox.

The general intention with the Backlog is that when a team member has completed all their work, they should be able to pull off something near the top of the Backlog and start working on it.

Once something is in the Backlog, it can also be assigned a Sprint. This allows us to filter the Backlog into a Sprint Backlog by filtering by Sprint! Sprint Backlog items take priority over other Backlog items and should generally be assigned to Sprints during Sprint Planning, sized in such a way that it'll be just enough for 2 weeks of work.

As items enter the Backlog, they should be prioritized as well as possible, with more important issues bubbling to the top, and, if high priority, marked as such, which will pin it to the top.

All issues in the Backlog should be estimated, with each Story Point being roughly 1 hour, with a strong preference towards increments of 5. Estimates include review and review fixes time. Epics should not be directly estimated, and should instead rely on their sub-tasks' estimates.

The Backlog can further be filtered into three main buckets, using GitHub Labels:

1. Quality - test improvements, bugfixes, tech debt
2. Engineering - engineering process improvements like CI and other process optimizations
3. Product - Issues associated with OKRs

During a Sprint, the first two weeks should be spent on Product Backlog issues, according to team assignments. Starting week 3, or earlier if someone's Product tasks are done, the Client Team will start pulling things out of the Quality and Engineering Backlogs.

Issues move out of the Backlog one of three ways:

1. Work starts on the issue, so it gets moved to In Progress
2. The issue is considered no longer relevant, and is closed
3. The issue is no longer considered an active priority, and so is moved to the Icebox and tagged accordingly

#### In Progress

When issues are actively being worked on, they should be moved to the In Progress pipeline. This Pipeline represents our active work.

Blocked items should be left in the In Progress Pipeline, and marked as blocked by going into the issue and creating a dependency to an issue tracking the blocker itself.

Issues in the In Progress pipeline move out in the following cases:

1. The issue is no longer being worked on -- move to Backlog
2. The issue is no longer relevant -- move to Icebox or Close
3. The issue is ready for code review -- move to In Review

#### In Review

When a PR is created and ready for review, the associated issue should be moved to the In Review pipeline.

From here, there's three ways to go:

1. The associated PR/task is completed -- move to Closed
2. The issue is no longer relevant -- move to Closed
3. Additional validation is required (for example, by vendors) -- move to Validating once the patch is available for testing. Since merging PRs can automatically close these issues, it may need to be manually reopened and moved back from Closed.

#### Validating

This column is used for tracking additional validation on an issue -- for example, vendor testing or customer validation.

From here:

1. The validation passes, in which case the issue is closed and everything's done!
2. The validation failed, in which case the issue should be moved to its appropriate column: usually In Progress or Backlog, depending on current tasks.

# Further Reading

- [ZenHub Book](https://www.zenhub.com/github-project-management.pdf)
