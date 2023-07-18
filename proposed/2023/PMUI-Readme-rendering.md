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

None


## Rationale and Alternatives

An alternative here would be to include a link within the package detail page which would open up the rendered readme externally. Should we find complications with directly embedding the rendered readme into the packag detail page, this would be a proposed alternative.


## Unresolved Questions

None


## Future Possibilities 

TBD
