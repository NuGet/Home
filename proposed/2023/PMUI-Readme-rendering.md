# Markdown Readme Rendering
* Start Date: 6/27/23
* Authors: Allie Barry ([albarry4](https://github.com/albarry4))
* Issue: https://github.com/NuGet/Home/issues/12583

## Summary

Support rendering markdown (MD) Readmes in the package details page for NuGet in Visual Studio to make package affordances more accessible for customers browsing packages within the PMUI, and to increase motivation for high quality Readme inclusion for package authors. This will be part of a larger effort to enhance the experience around Readmes and increase their inclusion rate across packages in the NuGet ecosystem.

## Motivation

In the latest NuGet in Visual Studio 17.5 customer survey, our team found that one of the largest problems that our customers face while using NuGet in the Visual Studio ecosystem is around understanding package affordances – specifically calling out the usage of package metadata such as Readmes. Only 35.35% of survey respondents feel that they can adequately understand the affordances of a package (does it do what I need to to do when I need it?) while browsing and installing packages. Including a detailed Readme file and implementing features to facilitate Readme viewing and inclusion would positively impact this number.   

## Explanation

### Functional Explanation

The goal of this new experience would be to integrate the experience of viewing a rendered Readme directly into NuGet in Visual Studio. Additionally, we want to draw more attention to the Readme in general, and make it feel like an important and crucial element of a package.  

The desired experience would be similar to the current design of the package details page in NuGet in Visual Studio, but we would add a tab at the top of the view where the user could toggle back and forth to view the regular package details that exist currently, and a rendered Readme file (if a Readme exists in the package contents). The only change in the current package details page would be the removal of the "Readme: View Readme" list item. Below shows a mock of the desired view of both the Readme and the Package Details tabs: 

![package details](https://github.com/NuGet/Home/assets/89422562/c106ca79-e26e-4b1d-b5ea-273651f79857)

![Readme](https://github.com/NuGet/Home/assets/89422562/81b24877-f12f-4783-905c-4a155d3c7693)


### Technical Explanation

To render markdown in Visual Studio, we can use Markdig to convert the MD to HTML, and then use either Webview2 or Daytona to render the HTML and stylize. 


Currently, the Markdown editor team within Visual studio uses webview 2 to render their HTML for general MD rendering within Visual Studio. Using WebView2 would require us to use CSS to create our own styling for the rendered HTML. A drawback to their solution is that the markdown editor team mentioned that they are currently receiving a lot of accessibility bugs caused by their CSS, so this solution is not ideal. Daytona offers inbuilt styling, so using Daytona over WebView2 would avoid accessibility bugs, and cut out the effort required to write our own CSS styling. The markdown editor team is currently in the process of transitioning from using WebView2 to Daytona, and recommended that, if possible, our team should use Daytona from the beginning.

## Drawbacks
 Some potential drawbacks of adding this experience include: 
 
* We would be changing a core experience in VS and that could potentially be disruptive for users who have been interacting with our UI for a long time, and are very familiar with the current functionality.
* There is limited space to render a README in VS today compared to say NuGet.org or other package registry websites.
* There might be a small performance hit to render the README or fetch it.

## Rationale and Alternatives

An alternative here would be to include a link within the package detail page which would open up the rendered readme externally. Should we find complications with directly embedding the rendered readme into the package detail page, this would be a proposed alternative.

An alternate design would be to show the Package details tab first and most prominently by default when a user selects a package. 

Additionally, since we do not know the users preference to seeing the Readme information first, or the package details tab first and most prominently, there are a few alternatives here that we can consider instead of choosing one to be the default. OPtions include: allowing the user to set their default tab in settings, or allowing the user to "pin" one tab or the other to be displayed as default. 


## Unresolved Questions

We do not know the current preference of people wanting to see a README or package information. Alternatives to address this question are presented in the section above. 

Below is a list of functional questions that must be addressed during the implementation of this feature: 
1. Will README files only be rendered for packages in the Browse tab?
2. Will we show a README for installed packages in the Installed tab? If so, it would be worth calling out where we will be getting this README from. I would imagine we'd be pulling it in from disk rather than from the remote package source.
3. Will we show README for packages in the Updates tab?
4. Will we show README markdown for the Solution-level package manager or just Project-level package manager?
5. What will we do in cases where there's a README.txt file for an installed package? Will we display that as well in the details pane or is this experience only for README if it's in markdown format?
6. What will we show in the details pane if there is no README for the selected package?

Additionally, we must determine a way to measure success for this feature. How will we determine if this experience of showing the README in the details pane has had the desired effect and meets the goal outlined in the section above?


## Future Possibilities 

As a future possibility, we might want to continue to make the NuGet UI in Visual Studio more closely mirror and provide the affordances of the UI in NuGet.org -- i.e. the additon of seperate tabs for "Frameworks", "dependencies", etc.
