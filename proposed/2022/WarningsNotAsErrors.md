# Honor WarningsNotAsErrors

- Author Name (GitHub username link)
- Start Date (YYYY-MM-DD)
- GitHub Issue (GitHub Issue link)
- GitHub PR (GitHub PR link)

## Summary

<!-- One-paragraph description of the proposal. -->

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->

### Technical explanation

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net6.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <EnforceCodestyleInBuild>true</EnforceCodestyleInBuild>
  </PropertyGroup>

  <!-- Fails. Treat all warnings as errors-->
  <!-- <PropertyGroup>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup> -->

  <!-- Fails. Treat only certain warnings as errors-->
  <!-- <PropertyGroup>
    <WarningsAsErrors>CS1998</WarningsAsErrors>
  </PropertyGroup> -->

  <!-- Succeeds with a warning. Treat everything except. -->
  <!-- <PropertyGroup>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <WarningsNotAsErrors>CS1998</WarningsNotAsErrors>
  </PropertyGroup> -->

  <!-- Succeeds. Everything, but no warn.-->
  <!-- <PropertyGroup>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <NoWarn>CS1998</NoWarn>
  </PropertyGroup> -->


  <!-- Succeeds.. No warn takes precedence -->
  <!-- <PropertyGroup>
    <WarningsNotAsErrors>CS1998</WarningsNotAsErrors>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <NoWarn>CS1998</NoWarn>
  </PropertyGroup> -->

  <!-- Error. Warnings as errors takes precedence -->
  <!-- <PropertyGroup>
    <WarningsNotAsErrors>CS1998</WarningsNotAsErrors>
    <WarningsAsErrors>CS1998</WarningsAsErrors>
  </PropertyGroup> -->

  <!-- Error. WarningsNotAsErrors takes precedence over TreatWarningsAsErrors, but WarningsAsErrors takes precedence over WarningsNotAsErrors-->
  <PropertyGroup>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <WarningsNotAsErrors>CS1998</WarningsNotAsErrors>
    <WarningsAsErrors>CS1998</WarningsAsErrors>
  </PropertyGroup>

</Project>
```

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

<!-- What future possibilities can you think of that this proposal would help with? -->
