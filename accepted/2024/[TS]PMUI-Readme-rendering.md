# Markdown Readme Rendering in PM UI

- Jonatan Gonzalez ([jgonz120](https://github.com/jgonz120)) 
- Issue [#12583](https://github.com/NuGet/Home/issues/12583) <!-- GitHub Issue link -->
- [Feature Spec](https://github.com/NuGet/Home/blob/7943122dffa435f4daeee600efcc5b744cd2e97e/accepted/2023/PMUI-Readme-rendering.md)

## Summary

We want to update the PM UI to render the ReadMe.md file while browsing packages. 

## Motivation 

We want help our customers understand what a package does and if it will be helpful to them. This could also increase ReadMe adoption if developers know their users will see the ReadMe. 

## Explanation

### Functional explanation
When a package is selected we will determine if a ReadMe file exists and if it does we'll render it in the PM UI. 

The PM UI will be updated to have tabs for the Package Details and the the ReadMe. This UX will be displayed for both the Browse and installed tabs.
![Alt text](https://github.com/NuGet/Home/assets/89422562/81b24877-f12f-4783-905c-4a155d3c7693)
<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

### Technical explanation
We want to leverage the [IMarkdownPreview](https://devdiv.visualstudio.com/DevDiv/_git/VS-Platform?path=/src/Productivity/MarkdownLanguageService/Impl/Markdown.Platform/Preview/IMarkdownPreview.cs) class to render the ReadMe in the IDE. A new instance can be created using [PreviewBuilder](https://devdiv.visualstudio.com/DevDiv/_git/VS-Platform?path=/src/Productivity/MarkdownLanguageService/Impl/Markdown.Platform/Preview/PreviewBuilder.cs). 

We can use the Preview builder as follows:
```C#
//This creates a new instance of the preview builder
var markdownPreview = new PreviewBuilder().Build();

//We update the current markdown being rendered by calling "UpdateContentAsync"
markdownPreview.UpdateContentAsync(markDown ?? string.Empty, ScrollHint.None)

//IMarkdownPreview.VisualElement contains the FrameworkElement to be passed to the view
MarkdownPreviewControl = markdownPreview.VisualElement
```
The ReadMe file will be selected from disk if available otherwise pulled from package source. 

The ReadMe will be displayed for both solution level and project level package manager.
<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

This control is not currently using Daytona. There are plans to upgrade it, [Experience 1870733](https://devdiv.visualstudio.com/DevDiv/_workitems/edit/1870733), but they have been delayed. 

It's also currently marked as obsolete since the interface has not been finalized. So when an upgrade is made we may have to change how we use the control.

## Rationale and alternatives
By using an existing control we maintain consistency throughout the IDE and can rely on the owner to fix any bugs with the control.
<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

## Unresolved Questions
1. Will we show readme in the updates tab?
1. What do we show if the package has a ReadMe.txt instead of md?
    * Current suggestion is to focus on ReadMe.md. Once that's complete see how ReadMe.txt would appear when rendered. 
    * How many packages have a ReadMe.txt vs ReadMe.md?
1. What do we show if there is no ReadMe defined?
    - [ ] Hide the tab from the the details pane
    - [ ] Display the tab with a message saying there is no ReadMe defined.
<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
