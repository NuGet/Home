# User-Agent Telemetry Enrichment for NuGet Commands

- Author: [@mruizmares](https://github.com/martinrrm)
- GitHub Issue: https://github.com/NuGet/Client.Engineering/issues/3467

## Summary

This proposal adds telemetry enrichment to the NuGet User-Agent header for push and restore commands. The enriched User-Agent header includes contextual information about the client environment (GitHub Actions, Azure DevOps).

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
NuGet Command Line/6.10.0 (Microsoft Windows NT 10.0.22631.0; GithubActions)
```

The enrichment happens automatically:
1. **Detection**: NuGet detects if it's running in a known CI/CD environment (GitHub Actions or Azure DevOps) by checking environment variables.
2. **User-Agent Enrichment**: HTTP requests include this context in the User-Agent header.

### Technical explanation

**CI Detection**: 

Detects CI/CD environments from environment variables:

| Environment | Variable | Value | ClientId | Info |
|-------------|----------|-------|----------|------|
| GitHub Actions | `GITHUB_ACTIONS` | "true" | "GitHub" | https://docs.github.com/en/actions/reference/workflows-and-actions/variables?versionId=free-pro-team%40latest&productId=actions |
| Azure DevOps | `TF_BUILD` | "True" | "AzureDevOps" | https://learn.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops&tabs=yaml#system-variables |
| AppVeyor | `APPVEYOR` | "True" | "AppVeyor" | https://www.appveyor.com/docs/environment-variables/ |
| Travis | `TRAVIS` | "True" | "Travis CI" | https://docs.travis-ci.com/user/environment-variables/#default-environment-variables |
| CircleCI | `CIRCLECI` | "True" | "CircleCI" | https://circleci.com/docs/2.0/env-vars/#built-in-environment-variables |
| AWS CodeBuild | `CODEBUILD_BUILD_ID` | != '' | AWS CodeBiuld | https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-env-vars.html |
| Jenkins | `BUILD_ID` AND `BIULD_URL` | != '' AND != '' | Jenkins | https://www.jenkins.io/doc/book/pipeline/jenkinsfile/#using-environment-variable |
| Google Cloud | `BUILD_ID` AND `PROJECT_ID` | != '' AND != '' | Google Cloud | https://cloud.google.com/build/docs/configuring-builds/substitute-variable-values |
| TeamCity | `TEAMCITY_VERSION` | != '' | TeamCity | https://www.jetbrains.com/help/teamcity/predefined-build-parameters.html#Server+Build+Properties |
| JetBrains | `JB_SPACE_API_URL` | != '' | JetBrains | https://www.jetbrains.com/help/space/automation-environment-variables.html#general |
| CI | `CI` | "True" | "CI" | A general-use flag | |

#### User-Agent Format

The enriched User-Agent follows the format:
```
{base-user-agent} NuGet/{ClientId; CIClient}
```

Examples:
- `NuGet xplat/6.10.0 (Microsoft Windows NT; GitHubActions)`
- `NuGet xplat/6.10.0 (Linux; AzureDevOps)`
- `NuGet xplat/6.10.0 (Linux; CI)`

## Drawbacks

1. **Limited CI/CD Coverage**: We have to manually update the table if we want to track a new specific CI environment. We are considering the exising CI environments that dotnet sdk is tracking (https://github.com/dotnet/sdk/blob/1b58d7631b1ed3cd26f7fa7415c075f686ae0f1a/src/Cli/dotnet/Telemetry/CIEnvironmentDetectorForTelemetry.cs#L13). Other CI environment will be considered as "CI".

### Why this design?

1. **User-Agent vs Custom Headers**: Enriching the existing User-Agent header is preferred over custom headers because:
   - It works with all HTTP infrastructure without configuration
   - It's logged by most web servers by default
   - It follows established conventions for client identification

### Alternatives considered

## Unresolved Questions

1. **User Opt-out**: Should there be a way for users to disable the enriched User-Agent? What would the mechanism be (environment variable, config setting)?

## Future Possibilities