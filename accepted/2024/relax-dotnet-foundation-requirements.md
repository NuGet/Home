# Relax signing certificate requirements for the dotnetfoundation user
<!-- Replace `Title` with an appropriate title for your design -->

- Author Name @glennawatson
- Issue https://github.com/NuGet/NuGetGallery/issues/10187

## Summary

At the moment the .NET foundation user (dotnetfoundation) on nuget.org has control over packages signing permissions. Users can't be the author signing owner of the package and therefore maintainers can't bring their own certificates for author singing.

## Motivation 

The foundation is having complaints from maintainers that they can't control the signing permissions. Also we want the ability for projects to use other signing tech if they want.

We do want to have the project to have some sort of signing since we offer projects free signing certificates to mitigate any costs to the project.

We have had discussions and approval by the .NET Foundation board, and also discussed with our Project Committe and they have agreed to these requirements.

The project committee met on the 12th September 2024 with the meeting minute notes here: https://github.com/dotnet-foundation/projects/issues/398 and agreed upon relaxing the requirements to requiring signing that matches the current NuGet.org trusted signing as per below.

The .NET Foundation board met on the 18th September 2024 00:00 UTC time and agreed to go with the project committe recommendation. Board members will attest to that in the PR.

## Explanation

### Functional explanation

We want the project to have a valid trusted root authority trusted certificate that follows the current NuGet.org requirements for signing.

### Technical explanation
We'd like to have the following standard requirements for nuget.org signing certificates as required. If you make adjustment for these requirements we'd be happy to follow them as long as the nuget package is required to have a trusted root authority certificate.

#### Certificate requirements

Package signing requires a code signing certificate, which is a special type of certificate that is valid for the `id-kp-codeSigning` purpose [[RFC 5280 section 4.2.1.12](https://tools.ietf.org/html/rfc5280#section-4.2.1.12)]. Additionally, the certificate must have an RSA public key length of 2048 bits or higher.

#### Timestamp requirements

Signed packages should include an RFC 3161 timestamp to ensure signature validity beyond the package signing certificate's validity period. The certificate used to sign the timestamp must be valid for the `id-kp-timeStamping` purpose [[RFC 5280 section 4.2.1.12](https://tools.ietf.org/html/rfc5280#section-4.2.1.12)]. Additionally, the certificate must have an RSA public key length of 2048 bits or higher.

Additional technical details can be found in the [package signature technical specs](https://github.com/NuGet/Home/wiki/Package-Signatures-Technical-Details) (GitHub).

#### Signature requirements on NuGet.org

nuget.org has additional requirements for accepting a signed package:

- The primary signature must be an author signature.
- The primary signature must have a single valid timestamp.
- The X.509 certificates for both the author signature and its timestamp signature:
  - Must have an RSA public key 2048 bits or greater.
  - Must be within its validity period per current UTC time at time of package validation on nuget.org.
  - Must chain to a trusted root authority that is trusted by default on Windows. Packages signed with self-issued certificates are rejected.
  - Must be valid for its purpose: 
    - The author signing certificate must be valid for code signing.
    - The timestamp certificate must be valid for timestamping.
  - Must not be revoked at signing time. (This may not be knowable at submission time, so nuget.org periodically rechecks revocation status).

## Drawbacks

If the maintainer and the project leaves the foundation they will be forced to provide signing certificates going forward. We already make the user aware of this requirement when leaving the foundation and have it as part of our exit check list.

## Rationale and alternatives

1. Users are removing the .NET foundation owner (dotnetfoundation), due to the signing restriction. This is reducing our ability to provide services to the user.
2. We feel its the right thing to allow users to bring their own valid certificates
3. This would be the right balance between giving the .NET Foundation and the users some trust that its coming from a valid authority but still giving more flexibilty to our maintainers.

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
