# Honor WarningsNotAsErrors

- Author Name <https://github.com/nkolev92>
- Start Date 2022-10-01
- GitHub Issue <https://github.com/NuGet/Home/issues/5375>
- GitHub PR <https://github.com/NuGet/NuGet.Client/pull/4846>

## Summary

<!-- One-paragraph description of the proposal. -->
`WarningsNotAsErrors` is an existing [compiler option](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-options/errors-warnings) that allows users with treat warnings as errors, to not get errors for every warning raised by their build.
NuGet supports `TreatWarningsAsErrors`, `WarningsAsErrors` and `NoWarn`. In this proposal we want to add support for `WarningsNotAsErrors`.

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->

`TreatWarningsAsErrors` is very commonly used feature in the .NET world. NoWarn allows you to suppress certain warning, but that is often too strong. `WarningsNotAsErrors` provides a middle ground, where the users are aware of the warning, but it doesn't fail their build.
This feature is supported by the compiler, and we want to provide parity for both pack and restore.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
The proposed behavior here matches the compiler behavior. All the scenarios are best represented in a table.

The precedence order for the 3 properties by NuGet can summarized as:
`NoWarn > WarningsAsErrors > WarningsNotAsErrors`.

For the following table assume `NU1603` is being raised during restore.

| TreatWarningsAsErrors | NoWarn | WarningsAsErrors | WarningsNotAsErrors | Behavior | Explanation |
|-----------------------|--------|------------------|---------------------|----------|-------------|
| true | | | | All warnings are treated as errors | |
| true | NU1603 | |  | Succeeds with no warning. | NoWarn prevents NU1603 from being raised. |
| false | | NU1603 | | NU1603 is upgraded to an error. | Only a certain list of warnings are being treated as errors |
| true | | | NU1603 | Succeeds with a warning. | Only NU1603 is a warning. If any other warning is raised, it'll be upgraded to an error |
| true | NU1603 | | NU1603 | Succeeds. No warning. | NoWarn takes precedence over both WarningAsErrors and WarningNotAsErrors. |
| false | NU1603 | NU1603 |  | Succeeds. No warning. | NoWarn takes precedence over both WarningAsErrors and WarningNotAsErrors. |
| false | | NU1603 | NU1603 | NU1603 is upgraded to an error | WarningsAsErrors takes precedence over WarningsNotAsErrors. This is likely not an intentional user scenario. |
| true | | NU1603 | NU1603 | NU1603 is upgraded to an error | WarningsNotAsErrors takes precedence over TreatWarningsAsErrors, but WarningsAsErrors takes precedence over WarningsNotAsErrors |

### Technical explanation

We already have a concept for [holding warning properties](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.ProjectModel/WarningProperties.cs), and [logic](https://github.com/NuGet/NuGet.Client/blob/f4e0ae1ca207f9f4a388b73c2f7edf18b2078f2a/src/NuGet.Core/NuGet.Commands/RestoreCommand/Logging/WarningPropertiesCollection.cs#L75) that handles the no warn and upgrade warnings.
We will just extend that.

## Drawbacks

<!-- Why should we not do this? -->
- N/A

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
- N/A

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

- The compiler has already implemented the feature.

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

- Should this feature be enabled in 6.5, 7.0.200 of the .NET SDK.
  - This is a behavior change where if someone was using `WarningsNotAsErrors` for NuGet, updating their tooling with change behavior. 
  - However, given that it currently doesn't work, it is not very likely that users would have that in their project.
  - WarningsNotAsErrors is the lowest precedence setting supported by NuGet.
  - Any behavior change can be consider a breaking change by people, but given the low likelihood this has as a new feature, I think it should be safe to merge in 6.5.

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
