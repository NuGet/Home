# NuGet Proposal Process

## How do I create a proposal?

- Fork or clone https://github.com/NuGet/Home
- Copy `meta/template.md` into `proposed/<year>/your-proposal-name.md`
- Fill in the template with your proposal.
- Submit a PR to the `NuGet/Home` repo
- (Optional) Create a new discussion to talk about it https://github.com/NuGet/Home/discussions/new

## How does a proposal review work?

The official place for discussion for a proposal is its pull request or a [GitHub Discussion](https://github.com/NuGet/Home/discussions). Anyone, both NuGet contributors and non-contributors, can participate in the discussion and ask questions and provide constructive feedback to the proposal. Please keep in mind that only NuGet contributors are able to act upon the proposal even if other users can comment.

All discussions surrounding a proposal are covered by the [.NET Foundation code of conduct](https://dotnetfoundation.org/code-of-conduct). Please keep discussions constructive, respectful, and focused on what's best for the .NET ecosystem. If discussions get heated, the NuGet team may at its own discretion moderate the discussion to enforce the code of conduct.

## What happens to a proposal?

When there is consensus among the NuGet contributors and .NET community of the direction of the proposal, it will go into one of three states.

- `accepted` - The proposal has been accepted and work will be scheduled to implement it.
- `withdrawn` - The proposal has been rejected or withdrawn by the author.
- `implemented` - The proposal has already been accepted and implemented into the product.

Once a proposal has been reviewed on GitHub with all interested parties having an opportunity to review it, and at least one NuGet contributor has signed off on the proposal, the PR will be accepted and merged.

## What happens when a proposal is accepted?

When a proposal is reviewed and accepted, it will be moved from `proposed` to `accepted`. Once accepted, it will be scheduled by the NuGet contributors to be implemented or put up for grabs for anyone to implement by making a PR in the appropriate repository.

## What happens when a proposal is withdrawn?

When a proposal is reviewed for its accuracy and relevance and no longer fits the goals of the project or is no longer a candidate for implementation, a proposal will be moved from `accepted` to `withdrawn` with a clear reason as to why it was moved. 

## What happens when a proposal is implemented?

When the changes described in the proposal have been implemented and merged into the relevant repository and due for release the corresponding proposal will be moved from `accepted` to `implemented`. If you'd like to implement an `accepted` proposal, please make a PR in the appropriate repository and mention the proposal in the PR. 
