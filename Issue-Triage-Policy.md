# Issues Triage Policy
Triaging an issue is a multi-step process that is collaboratively performed by the HotSeat, the triage meeting, area owners, and our issue bot. Triaging an issue usually takes around one week but may take longer, for example, when the feature area owner is not around, or we need more information.

## Our Triaging Flow
![IssueTriagingFlow](/meta/resources/Issue-triaging/IssueTriagingFlow.png)

The chart uses three major states. They are easily identifiable:
| State | What your GitHub issue looks like |
| -------- | --------------------------------------------- |
| Waiting for triaging | has any label starts with `Triage:`|
| Closed | matches the query is:closed |
| Backlog| has label `Priority:1` or `Priority:2` |
| Under Consideration | has label `Priority:3` |


In the rest of this document, we'll go into more detail about each of the activities of triaging and how we make decisions.


### Closing conditions
We close issues for the following reasons:
| Reason | Label |
| --------------------------------------------------------- | ---------------------- |
|We didn't get the information we need within 28 days.      | Resolution:NeedMoreInfo|
|It's a duplicate of another issue.	                        | Resolution:Duplicate   |
|What is described is the designed behavior.                | Resolution:ByDesign    |
|The issue is a user question.	                            | Resolution:Question    |
|Given the information we have we can't reproduce the issue.| Resolution:NotRepro    |
|This issue appears to be External to NuGet.                | Resolution:External    |
|This issue appears to not be a bug.                        | Resolution:NotABug     |
|It has a negative cost-benefit balance.                    | Resolution:WontFix     |

We close issues with the help of a bot that responds to a particular comment or to assigning a label with adding a pre-canned comment to the issue and closing the issue.

### Requesting Information
If an issue misses information that we need to understand the issue, we assign the `WaitingForCustomer` label. We usually manually add the `WaitingForCustomer` label at first, then bot will switch between the `WaitingForCustomer` and `WaitingForClientTeam` labels automatically when there is a new comment.

The bot is monitoring all issues labeled `WaitingForCustomer`. If we don't receive the needed information within 14 days, the bot will add a `no recent activity` label and a comment. After another 14 days without any comment from the author, the bot closes the issue and add `Resolution:NeedMoreInfo` label.

### Important Issues
We assign the `Priority:1` label to issues that are:
- a regression from a previous RTM
- high-impacting to the community
- core scenario blocking

### Asking for Help
We label issues with `help wanted` to encourage the community to take up. If issues are suitable for beginners, we may add the `good first issue` label and we add code pointers that help beginners to get started with a pull request.

Sometimes, we get issues that we can't or don't have the time to reproduce due to the complexity or time requirements of the setup but that we indeed suspect to be issues. We label those issues with `Triage:Investigate`. What we are looking for is help in reproducing and analyzing the issue. In the best of all worlds, we receive a pull request from you. :smiley:

Please note, issues with the `Priority:2` label usually have higher impact than issues with the `Priority:3` label. So, if you'd like to make more impact, please prioritize working on fixing issues with the `Priority:2` label.

### Managing feature requests
We appreciate everyone who takes their time creating issues of feature requests to help us improve our product. In theory, we could keep all issues open no matter if what will happen in the future. But that makes it hard to understand what has realistic chances to ever make it into the repository. 

Here are the questions we consider when triaging:
* Does it match our general philosophy? Does the proposal match with our general product direction? 

* Can our team afford to implement and maintain it? Are the direct and the opportunity costs to implement the functionality and maintain it going forward reasonable compared to the size of our team?

* Does it align with our roadmap?
  Does the functionality described in the feature request have any reasonable chance to be implemented in the next 24 months? 24 months is longer than our roadmap which outlines the next 6-12 months. Thus, there is some crystal ball reading on our part, and we'll most likely keep more feature requests open than what we can accomplish in 24 months.

* Do we think the feature request is bold and forward looking and would we like to see it be tackled at some point even if it's further out than 24 months? (Clearly, this is quite subjective.)

* Has the community at large expressed interest in this functionality? I.e. has it gathered more than 5 up-votes.

After triaging, the issue will fall into one of the following categories:
* The issue is accepted. A `Priority:1` or `Priority:2` label is added.

* The issue is closed. A `Resolution:WontFix` label is added.

* The feature is under consideration. A `Priority:3` label is added. 
A bot monitors the issues having a `Priority:3` label. If an issue receives 5 or more up-votes in 90 days, the bot adds a `Triage:NeedsTriageDiscussion` label. The NuGet team meets weekly to discuss issues labeled `Triage:NeedsTriageDiscussion` and we will do more analysis to determine the cost/benefit. If we decide the issue should be on the backlog, we will change the priority label to `Priority:2`.

> [!Note]
> Currently, the threshold is 5 up-votes. We start with this low threshold as we don't want to miss your voices. Going forward, we might need to adjust the threshold if it doesn't fit well.

### Up-voting a feature request/bug
When we refer to "up-voting" a feature request/bug, we specifically mean adding a GitHub +1/"👍" reaction to the issue description. In the GitHub UI this looks like so:

![IssueTriagingFlow](/meta/resources/Issue-triaging/Upvotes-Example.png)


### Won't fix Bugs
We close bugs as wont-fix if there is a negative cost-benefit balance. It's not that we don't care about users who are affected by an issue but, for example, if the fix is so complex that despite all of our tests we risk regressions for many users, fixing is not a reasonable choice. When we close a bug as wont-fix we'll make our case why we do so.
