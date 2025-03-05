# Reducing support costs related to Mono runtime
<!-- Replace `Title` with an appropriate title for your design -->

- Author Name jeffkl

## Summary
<!-- One-paragraph description of the proposal. -->
NuGet is already available across platforms since it ships as part of the .NET SDK.
However, `NuGet.exe` is a .NET Framework application that works on the Mono runtime, making it possible to run on other platforms like Mac and Linux.
`NuGet.exe` is not officially supported on the Mono runtime, but does require some maintenance overhead since we still run tests against this environment.
In order to reduce complexity of our build pipelines, we would like to stop running our tests on the Mono runtime.


## Motivation
<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
The Mono runtime was the original cross-platform implementation of the .NET Framework.
With the development of .NET Core, which is also cross-platform, it is now highly recommended that users port their applications to .NET Core rather than build .NET Framework applications that require Mono.

The last major release of the Mono Project was in July 2019, with minor patch releases since that time. The last patch release was February 2024.
The WineHQ organization has taken over stewardship of the project and will potentially still work on security or bug fixes.

Since the implementation is considered finalized, we do not anticipate anything to change in Mono that would break a standard .NET Framework application like `NuGet.exe`.
If nothing is changing in .NET Framework or in Mono, there is very little reason to be running our tests against Mono.


## Explanation

### Functional explanation
<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

We do not officially support Mono which is specified at https://learn.microsoft.com/en-us/nuget/resources/nuget-faq#does-nuget-support-mono- .
However, we've continued to run our tests on Mono to ensure that we do not unintentionally break functionality.

We would not take any intentional actions to make `NuGet.exe` stop working on Mono, we would just not guarantee that it continues to work.
We would also continue to test `NuGet.exe` on Windows .NET Framework, so it is unlikely that functionality would break.

We will take the following actions:

1. Stop running tests on any Mono runtime, regardless of operating system.
1. Add a note to the GitHub action [setup-nuget](https://github.com/NuGet/setup-nuget) that running `NuGet.exe` on Mono is not officially supported.
1. Update documentation to indicate that installing the Mono runtime on hosted build agents may be required depending on the users' environment since some companies are leaving Mono out of agent images.
1. Add XML documentation comments to our code in areas where there is Mono specific logic to indicate that Mono is not officially supported but to not remove any existing code.
1. Consider closing all [existing issues related to Mono](https://github.com/NuGet/Home/issues?q=is%3Aissue%20state%3Aopen%20label%3APlatform%3AMono)


### Technical explanation
<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

There are a few places in our code with [Mono-specific logic](https://github.com/search?q=repo%3ANuGet%2FNuGet.Client%20mono&type=code) and we would not be removing any of this.
However, we should add XML doc comments to indicate that Mono isn't supported but we should not remove the code either.

To stop running tests on Mono we could simply disable [the parameter](https://github.com/NuGet/NuGet.Client/blob/dev/eng/pipelines/pull_request.yml#L40) by default which would be simpler.
Alternatively, we could completely remove it from the pipeline YAML.
Since the functionality could get broken over time, there's no guarantee that leaving the option in place would work going forward.

## Drawbacks/Risks
<!-- Why should we not do this? -->

NuGet does not want to break Mono functionality or remove anyone's ability to run `NuGet.exe` on Mono.
However, by no longer running the tests on the Mono runtime, we will not be aware if we unintentionally broke something or if something changed in the platform that broke `NuGet.exe`.

At this time, we consider the risk to be low because:
1. `NuGet.exe` continues to be tested on .NET Framework and Mono should have the same APIs available.
1. Older versions of `NuGet.exe` will continue to be available in the unlikely event that a newer version breaks.
1. Mono specific code will remain in NuGet so fixing any unintentional breakage would still be possible in any supported version of `NuGet.exe`.
1. It is unlikely that Mono will be changing any implementation details that would break applications.
1. Any platform changes in Linux or Mac would handled by the Mono runtime, which allows existing applications to continue to work.

MicroBuild, an internal-only tool for build infrastructure in the Developer Division uses `NuGet.exe` to acquire plug-ins.
On Windows, it downloads the latest version of `NuGet.exe` from https://dist.nuget.org/win-x86-commandline/latest/nuget.exe.
On Linux, it downloads the latest version of `NuGet.exe` via `apt -y install nuget`.
There is a chance we could break Mono compatibility, leading to widespread infrastructure issues.
Since we won't be removing any Mono code from NuGet, it is unlikely that this would happen.
Also, MicroBuild could pin to an older version of `NuGet.exe` if needed.

Another potential risk is that not all functionality of `NuGet.exe` is available in the .NET SDK.
The [feature availability](https://learn.microsoft.com/nuget/install-nuget-client-tools?tabs=macos#feature-availability) table indicates which features users might need before they move to the .NET SDK.
Since we won't be intentionally breaking Mono compatibility, they would still be able to run `NuGet.exe` on if needed.

## Rationale and alternatives
<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

We could potentially install the Mono runtime on a Windows hosted agent and run Mono tests there which would reduce complexity a little.
We would still want to update all documentation to indicate that its not supported.
These tests fail occasionally which also causes friction.

## Prior Art
<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

We have already updated our support policy stating that Mono is not supported https://learn.microsoft.com/en-us/nuget/resources/nuget-faq#does-nuget-support-mono-.


## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities
<!-- What future possibilities can you think of that this proposal would help with? -->
We could look at telemetry in the future to determine if users are still running `NuGet.exe` on Mono to determine if we could ever remove the code in the application and block execution in an unsupported scenario.
I don't believe we would ever want to do this any time soon, but it is a possibility.