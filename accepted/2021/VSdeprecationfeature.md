# Title

- Author Name: Meera Haridasa http://github.com/meeraharidasa
- 2021-05-12
- GitHub Issue (GitHub Issue link) N/A
- GitHub PR (GitHub PR link) N/A
- Status: Implemented

## Summary

<!-- One-paragraph description of the proposal. -->

Changes to VS NuGet package manager that will make deprecated packages more obvious improve the rate at which customers move to the latest packages.
- Deprecation message within the search result with a clickable link to the latest package 
- Updated deprecation message within the right hand side details pane where “More info” takes you to the NuGet.org site for that package and has another clickable link for the latest package 
- Warning icon next to the version number in the search result 


## Motivation 

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->

Customers don’t move to the latest libraries because they don’t realize they are using outdated ones. Our current deprecation indicators are too subtle and don’t appear in enough places. This means:
•	Customer may be using libraries that are no longer supported – which is a security risk and means they don’t get the benefits of the latest libraries.
•	Library publishers, such as the Azure SDK team, see slow adoption of their newer libraries.

The expected outcome is for the Azure SDK team to see an increase in adoption rates for Track 2 packages. 


## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
If you are a developer trying to install the latest package in the NuGet package manager, you will be notified when a package has been deprecated. As you open the package manager, if a certain package is deprecated, 
you'll see a warning icon next to the version number, a deprecation message along inside the description of the package linking to the newest package and when you click on the package itself, 
there is an updated message that also links to the newest package. 

<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->


![alt text](https://github.com/meeraharidasa/Home/blob/dev/proposed/2021/Screen%20Shot%202021-05-12%20at%2010.27.10%20AM.png)
![alt text](https://github.com/meeraharidasa/Home/blob/dev/proposed/2021/Screen%20Shot%202021-05-12%20at%2010.27.01%20AM.png)


### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

There is no technical explanation of this feature other than implementing the capability for these items to display the messages while searching for a package. 

## Drawbacks

<!-- Why should we not do this? -->
An increase to track 2 libraries may not be based on user's not seeing deprecated pakcages, but we have gathered enough customer evidence and done Quick Pulses to confidently say 
that we don't have a great end-to-end deprecation story. This will be helping that out. 

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

This is the best design because its simple and gets the point across to our customers. We have iterated on many different designs and worked with UX Board to see 
which one would be the best in the long run. Other designs were not chosen because they invovled other aspects such as the Solution Explorer and Properties pane which
are hard to change. 

The impact of not doing this keeps the unresolved question of how do we explain our deprecated story to customers? In the Quick Pulse that we ran, 100% of customers
say that they would want the deprecation end-to-end to be more clear and visible to them in VS. 

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevent to this proposal? -->

There are no previous proposals on this issue, we are trying to tackle this customer pain point by starting off with this feature and then hopefully adding more
to the deprecated journey for customers. Once this feature is implemented, we can track progress and see if this is successful in navigating customers to the latest packages
and then iterate through a more robust feature then. 

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

The designs have been approved by UX Board and the team is trying to figure out when engineering has time to implement this. Related issues might be addressing a 
deprecation story for customers that already have old libraries installed and navigating them to the latest packages. This feature would involve other parts of VS such as
the Solution Explorer and Properties pane, which if we want to change, this feature should first show success. 

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
Creating a full end-to-end story for deprecation within VS that makes the transition smooth for both customers who are installing a package and those who are trying to upgrade
to the latest package.  
