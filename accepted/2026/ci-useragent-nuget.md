# User-Agent Telemetry Enrichment for NuGet Commands

- Author: [@mruizmares](https://github.com/mruizmares)
- GitHub Issue: https://github.com/NuGet/Client.Engineering/issues/3467

## Summary

This proposal adds telemetry enrichment to the NuGet User-Agent header for push and restore commands. The enriched User-Agent header includes contextual information about the client environment (GitHub Actions, Azure DevOps) and the current operation (push, restore), enabling better analytics and diagnostics for NuGet server operators.

## Motivation

Currently, NuGet HTTP requests include a basic User-Agent header that identifies the NuGet client version and OS.

By enriching the User-Agent header with CI context information we can a better understanding of CI/CD environment usage and issues.

## Explanation

### Functional explanation

When you run NuGet commands, the HTTP requests now include enriched User-Agent information:

**Before:**
```
NuGet Command Line/6.10.0 (Microsoft Windows NT 10.0.22631.0)
```

**After (running in GitHub Actions, push command):**
```
NuGet Command Line/6.10.0 (Microsoft Windows NT 10.0.22631.0) CI/GitHubActions
```

The enrichment happens automatically:
1. **Detection**: NuGet detects if it's running in a known CI/CD environment (GitHub Actions or Azure DevOps) by checking environment variables.
3. **User-Agent Enrichment**: HTTP requests include this context in the User-Agent header.

### Technical explanation

**CI Detection**: 

Detects CI/CD environments from environment variables:

| Environment | Variable | Value | ClientId | Info |
|-------------|----------|-------|----------|------|
| GitHub Actions | `GITHUB_ACTIONS` | "true" | "GitHub" | https://docs.github.com/en/actions/reference/workflows-and-actions/variables?versionId=free-pro-team%40latest&productId=actions |
| Azure DevOps | `TF_BUILD` | "True" | "AzureDevOps" | https://learn.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops&tabs=yaml#system-variables |


#### User-Agent Format

The enriched User-Agent follows the format:
```
{base-user-agent} NuGet/{ClientId} CI/{CiClient}
```

Examples:
- `NuGet xplat/6.10.0 (Microsoft Windows NT) CI/GitHubActions`
- `NuGet xplat/6.10.0 (Linux) CI/AzureDevOps`

## Drawbacks

1. **Limited CI/CD Coverage**: Only GitHub Actions and Azure DevOps are detected initially. Other CI systems are not detected.

### Why this design?

1. **User-Agent vs Custom Headers**: Enriching the existing User-Agent header is preferred over custom headers because:
   - It works with all HTTP infrastructure without configuration
   - It's logged by most web servers by default
   - It follows established conventions for client identification

### Alternatives considered

## Unresolved Questions

1. **User Opt-out**: Should there be a way for users to disable the enriched User-Agent? What would the mechanism be (environment variable, config setting)?

## Future Possibilities