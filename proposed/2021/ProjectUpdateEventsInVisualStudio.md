# Title

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

```cs
namespace NuGet.SolutionRestoreManager
{
    /// <summary>
    /// NuGet project update events.
    /// Architecturally, packages.config and PackageReference projects differ in the way package updates are processed.
    /// This interface is meant to provide a single API of interest for components wanting to listen to *all* project updates by NuGet.
    /// </summary>
    [ComImport]
    [Guid("30CDDD0A-6901-482D-8CEF-6D798F1A99FC")]
    public interface IVsNuGetProjectUpdateEvents
    {
        /// <summary>
        /// Raised when solution restore starts with the list of projects that will be restored.
        /// The list will not include all projects. Some projects may have been skipped in earlier up to date check, and other projects may no-op.
        /// </summary>
        /// <remarks>
        /// Just because a project is being restored that doesn't necessarily mean any actual updates will happen.
        /// Only PackageReference projects are includede in this list.
        /// </remarks>
        event SolutionRestoreEventHandler SolutionRestoreStarted;

        /// <summary>
        /// Raised when solution restore finishes with the list of projects that were restored.
        /// The list will not include all projects. Some projects may have been skipped in earlier up to date check, and other projects may no-op.
        /// </summary>
        /// <remarks>
        /// Just because a project is being restored that doesn't necessarily mean any actual updates will happen.
        /// Only PackageReference projects are includede in this list.
        /// </remarks>
        event SolutionRestoreEventHandler SolutionRestoreFinished;

        /// <summary>
        /// Raised when particular project is about to be updated.
        /// For PackageReference projects, this means an assets file or a nuget temp msbuild file write (nuget.g.props or nuget.g.targets). The list of updated files will include the aforementioned.
        /// For packages.config projects, this means a single package is installed/unistall/unistalled. The list of updated files may include the path of the package that was changed.
        /// </summary>
        event ProjectUpdateEventHandler ProjectUpdateStarted;

        /// <summary>
        /// Raised when particular project update has been completed.
        /// For PackageReference projects, this means an assets file or a nuget temp msbuild file write (nuget.g.props or nuget.g.targets). The list of updated files will include the aforementioned.
        /// For packages.config projects, this means a single package is installed/unistall/unistalled. The list of updated files may include the path of the package that was changed.
        /// </summary>
        event ProjectUpdateEventHandler ProjectUpdateFinished;
    }

    /// <summary>
    /// Defines an event handler delegate for PackageReference solution restore start and end.
    /// </summary>
    /// <param name="projects">List of projects that will run restore. Never <see langword="null"/>.</param>
    public delegate void SolutionRestoreEventHandler(IReadOnlyList<string> projects);

    /// <summary>
    /// Defines an event handler delegate for project updates.
    /// </summary>
    /// <param name="projectUniqueName">Project full path. Never <see langword="null"/>. </param>
    /// <param name="updatedFiles">NuGet output files that may be updated. Never <see langword="null"/>.</param>
    public delegate void ProjectUpdateEventHandler(string projectUniqueName, IReadOnlyList<string> updatedFiles);
}
```

### Technical explanation

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
