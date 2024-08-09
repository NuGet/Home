# Trusted Publishers, using OpenID Connect for NuGet push (technical)

- Author: Joel Verhagen ([@joelverhagen](https://github.com/joelverhagen) on GitHub)
- Issue: [NuGet/NuGetGallery#9332](https://github.com/NuGet/NuGetGallery/issues/9332)

This is the technical description of the experience described in [Trusted Publishers, using OpenID Connect for NuGet
push](trusted-publishers-oidc-for-nuget-push.md). The content is split to clearly separate the functional/UX description
(the other doc) from the technical description (this doc). This document acts as a supporting document to the other so
that other one should be read first.

Much of the technical explanation is described in [Trusted Publishers for All Package
Repositories](https://repos.openssf.org/trusted-publishers-for-all-package-repositories). I will expand on certain
technical details which are particularly interesting or specific to NuGet.

## Validation of the GitHub OIDC token

The most critical step in this design is understanding how NuGet.org will validate that an incoming OIDC token is
acceptable to trade for a short-lived NuGet API key.

The following checks are made:

- The token is issued by a known Trusted Publisher (only GitHub Actions at this time)
- The token is validated per all JWT rules, such as but not limited to:
  - valid signature via JWKS
  - validate duration (`nbf` and `exp` claims)
  - only used once, via `jti`
  - valid `aud` claim, being `nuget`

The
[Microsoft.IdentityModel.Protocols.OpenIdConnect](https://www.nuget.org/packages/Microsoft.IdentityModel.Protocols.OpenIdConnect)
package can help us properly validate JWTs in our NuGet/NuGetGallery ASP.NET application.

In addition to the general JWT checks, specific checks are made for each Trusted Publisher. For GitHub Actions, the
following checks will be made:

- `sub` claim matches `{repo owner}/{repo name}:.*` (case insensitive)
  - The suffix of the `sub` is implied by the other checks
- `repository_owner` claim matches the `{repo owner}` name (case insensitive)
- `repository_owner_id` claim matches the numeric owner ID recorded at the time of the trust policy creation
  - This is to avoid resurrection attacks.
- `repository` claim matches the `{repo name}` name (case insensitive)
- `repository_id` claim matches the numeric repository ID recorded at the time of the trust policy creation
  - This is to avoid resurrection attacks.
- If a branch filter is provided in the trust policy:
  - `ref_type` claim must be `branch`
  - `ref` claim must be `refs/head/{branch}` (case insensitive)
- If an environment filter is provided in the trust policy:
  - `environment` claim must be `{environment}` (case insensitive)
- If a workflow path filter is provided in the trust policy:
   - `job_workflow_ref` claim must be `{repo owner}/{repo name}/{workflow path}@.*` (case insensitive)
   - The workflow path should be normalized to `/` path separators at the time of trust policy creation

A list of possible claims to verify against is available in GitHub's [Understanding the OIDC
token](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#understanding-the-oidc-token)
document.

Other Trusted Publishers like Azure DevOps or Bitbucket should have sufficient token claims so both the registry
(NuGet.org) and the package author are certain that only proper workload identity tokens are traded for privileged
short-lived API keys.

## Data relationships (persisting trust policies, schema changes)

A new SQL table will be added to the NuGetGallery database to store trust policies. The table should be generic enough
to allow us to add additional Trusted Publishers without a DB schema change (ideally). The trust policy DB record with
have a foreign key to the `Users` table (containing both user and organization records) but will be restricted from
associating with organization records by the application. Many of the columns will be shared with the `Credentials`
table in order to express the scoping rules to be copied into the short-lived API key.

A nullable column will be added to the `Credentials` table to refer to the trust policy used to create the short-lived
API key. This will allow package publish operations to audit their related trust policy information.

Deleting a trust policy should have the effect of deleting all related short-lived API keys.

## Trading an OIDC token for an API key

A new endpoint will be needed for trading an bearer token (OIDC token, a JWT) for an API key. The endpoint URL will be
discoverable via the [V3 service index](https://learn.microsoft.com/en-us/nuget/api/overview#service-index) and a new
resource type which is `ApiKeyService/1.0.0`. For NuGet.org, the service index is available at
`https://api.nuget.org/v3/index.json`. The new resource URL be something like `https://www.nuget.org/api/v2/api-key`.

```
POST /api/v2/api-key HTTP/1.1
Host: www.nuget.org
Authorization: Bearer {OIDC token}
Content-Type: application/json

{
   "username": "{username of user with trust policy}"
}
```

The response will look like this:

```
HTTP/1.1 200 OK
Content-Type: application/json

{
   "api_key": "{short lived API key in clear text}",
   "expires": "{ISO 8601 timestamp of expiration}"
}
```

Authorization failures on this endpoint must return HTTP 401 Unauthorized with an `WWW-Authenticate: Bearer` response
header.

The package source MUST NOT opt to return the an existing compatible API key (i.e. it must not cache the API key for
subsequent calls). To do so would require the original API key to be stored in plain text. NuGet.org API keys are hashed
prior to storage (much like standard recommendations around storing passwords). The package source has concerns on
scalability it must opt to rate limit the endpoint instead of caching. NuGet.org will rate limit the endpoint to 1 API
key created per 30 seconds, per user.

Unlike normal API keys, no warning message will be returned from the push endpoint (or any other authenticated endpoint)
as the API key nears its expiration. Additionally, no reminder email will be sent when these short-lived API keys are
nearing expiration (i.e. immediately!). Short-lived API keys will be cleaned up soon after their expiration to avoid
unnecessary bloat in the database.

The clear text (secret) of the short-lived API keys will be hashed in the database, much like existing long-lived API
keys.

The `jti` claim will be recorded with the created API key so that subsequent calls to the endpoint can rejected, per the
`jti` uniqueness constraint.

These short-lived API keys will not be visible in the NuGet.org UI.

NuGet.org MAY record the JWT and related details (e.g. JWKS) for auditing and feature adoption purposes.

## Other package sources

Other NuGet package sources aside from NuGet.org could also implement this protocol. They would need to implement the
token trade endpoint.

The `nuget/login` action could be implemented so that it supports and V3 package source, as long as it has a
`ApiKeyService/1.0.0` resource in the service index. This level of flexibility should be implemented anyways so that it
can be tested against NuGet DEV and INT pre-production environments.

It would be the responsibility of the package source to implement OIDC token validation as well as expressing trust
policies.

## Auditing usage on NuGet.org

To help us understand the success of this feature and record priviledged actions for security auditing, we will at least
record minimal information about the OIDC token trade, such as the repository owner, repository name, workflow path,
etc. Existing auditing for API key usage will be used anywhere the short-lived API key is used.

The metadata available in a GitHub Actions OIDC token is mentioned in GitHub's [Understanding the OIDC
token](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#understanding-the-oidc-token).

These claims could offer useful indicators to package consumers about the package. In order to support a future effort
for [SLSA Build L1](https://slsa.dev/spec/v1.0/levels#build-l1), NuGet.org may record additional properties provided in
the OIDC token so that they could adorn the package details page. This would be in addition to minimal records kept for
security auditing purposes but would not extent beyond what is provided by GitHub Actions in their token or their public
OIDC endpoints (e.g. JWKS). This is not as strong as signed provenance artifacts but can augment the freeform metadata
we have today such as repository URL, project URL, or SourceLink information.

Imagine showing "this package version was published from GitHub repository X, at commit Y", with some linked docs and
caveats, on the package details page. I think it can be useful without being authoritative, much like project URL or
repository URL today. If we begin gathering this information at day 1 of Trusted Publishers auth, we can backfill the
information visible on the package details sometime in the future.

Note that this metadata provided in the token is not enough for a build provenance experience like npm's (see the [blog
announcement](https://github.blog/security/supply-chain-security/introducing-npm-package-provenance/)). This is because
a proper build provenance story has signed attestation occurring inside the Trusted Publisher. See [SLSA Build
L2](https://slsa.dev/spec/v1.0/levels#build-l2) for more information.

## The `nuget/login` GitHub Action step

In order to fetch a GitHub OIDC from the GitHub Actions runtime environment, we need a custom GitHub action step. This
will be a new `NuGet/login` GitHub repository to host the source code for the step. This mimics the pattern of the
[`azure/login`](https://github.com/Azure/login).

The step will require the ambient `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN` environment
variables to trade the request token for a GitHub Actions OIDC token with the `nuget` value for the `aud` claim. An
custom `aud` claim can be fetched by appending `audience={desired aud}` query string to the
`ACTIONS_ID_TOKEN_REQUEST_URL` or by using the `@actions/core` JavaScript library.

This latter GitHub Actions OIDC token will be send to the `ApiKeyService/1.0.0` resource, found via the `source`
parameter provided to the action. The `source` parameter must point to a V3 service index (JSON document). The service
index and the `ApiKeyService/1.0.0` resource URL must both be HTTPS.

The `NuGet/login` GitHub Action can use the NuGet.Protocol .NET package to determine the URL for the "create API key"
endpoint, via the `ApiKeyService/1.0.0` resource in the V3 service index. For cross-platform reason, the GitHub Action
will either be a [JavaScript action or a composite
action](https://docs.github.com/en/actions/creating-actions/about-custom-actions#types-of-actions) (to be determined
during implementation). At this times, it seems it would be easiest to implement a JavaScript action and not use
`NuGet.Protocol` at all.

Once this `nuget/login` GitHub Action is complete, it will be published to the GitHub Action Marketplace, much like
Ruby's [`rubygems/release-gem` step](https://github.com/marketplace/actions/release-gem).
