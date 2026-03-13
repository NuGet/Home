# Add --allow-untrusted-root flag to NuGet sign commands

- [@elantiguamsft](https://github.com/elantiguamsft)
- [NuGet/NuGet.Client#7201](https://github.com/NuGet/NuGet.Client/pull/7201)

## Summary

Add a new `--allow-untrusted-root` flag to `nuget sign` and `dotnet nuget sign` that allows signing NuGet packages with certificates whose root CA is not installed in a trusted root certificate store. When this flag is set, the `UntrustedRoot` X509 chain status is treated as a warning instead of a fatal error. The certificate chain is still fully built and validated for structural correctness.

## Motivation

In enterprise and CI/CD environments, signing certificates are often provisioned from Azure Key Vault or similar systems where the root CA certificate is not (and should not be) installed into the machine's trusted root certificate store. Installing root CA certificates into `LocalMachine\Root` requires **administrator elevation**, which:

- **Triggers UAC prompts** on developer machines — an unexpected and disruptive experience during build setup.
- **Fails in non-elevated CI containers** — many container-based CI systems (Docker, WinCrush, containment environments) run without admin privileges and cannot install certificates into the machine-level trusted root store.
- **Creates security friction** — granting admin elevation solely to install a signing root CA broadens the attack surface unnecessarily.

Today, `nuget sign` and `dotnet nuget sign` perform internal X509 chain validation via `CertificateChainUtility.GetCertificateChain()`. If the signing certificate's root CA is not in a trusted store, chain building produces an `UntrustedRoot` status which is treated as a **fatal error** — blocking the signing operation entirely. There is no existing flag or workaround to bypass this behavior.

Other signing tools in the ecosystem already handle this scenario:
- **signtool.exe** — uses the `/r` flag to resolve the root independently; does not require a trusted root store.
- **VsixSigntool.exe** — uses file-based signing (`/f` + `/p`), no store chain needed.
- **CoseSign** — uses thumbprint directly, bypasses store-based chain validation.

NuGet's `sign` command is the only commonly used signing tool that cannot sign when the root CA is not in a trusted store.

## Explanation

### Functional explanation

When you need to sign a NuGet package with a certificate whose root CA is not installed in your machine's trusted root certificate store, you can now use the `--allow-untrusted-root` flag:

**dotnet CLI:**
```bash
dotnet nuget sign MyPackage.nupkg \
  --certificate-fingerprint <SHA256-fingerprint> \
  --certificate-store-name My \
  --timestamper http://timestamp.example.com \
  --allow-untrusted-root
```

**nuget.exe (classic):**
```bash
nuget sign MyPackage.nupkg \
  -CertificateFingerprint <SHA256-fingerprint> \
  -CertificateStoreName My \
  -Timestamper http://timestamp.example.com \
  -AllowUntrustedRoot
```

When this flag is provided:
1. The certificate chain is still fully built from the signing certificate up to the root.
2. All structural chain validations still apply (expiration, key usage, revocation checks, etc.).
3. The only difference is that `UntrustedRoot` is treated as a **warning** (logged) rather than a **fatal error** (exception).

If the flag is **not** provided, behavior is unchanged — `UntrustedRoot` remains a fatal error, preserving full backward compatibility.

**Example scenario:**

A build system downloads a code signing certificate from Azure Key Vault. The certificate chains up to an internal corporate root CA. The root CA certificate is available in the certificate chain but is not installed in `LocalMachine\Root` or `CurrentUser\Root`. Previously, `nuget sign` would fail with error NU3018. With `--allow-untrusted-root`, the signing succeeds and a warning is logged indicating the root is untrusted.

### Technical explanation

The implementation adds an `AllowUntrustedRoot` boolean property at three levels:

1. **`SignArgs.AllowUntrustedRoot`** (`NuGet.Commands`) — CLI argument model. Populated by CLI option parsing in both `nuget.exe SignCommand` and `dotnet nuget sign` XPlat command.

2. **`CertificateSourceOptions.AllowUntrustedRoot`** (`NuGet.Commands`) — passed to `CertificateProvider` during certificate discovery. When true, `CertificateProvider.GetValidCertificates()` and `IsValid()` call `GetCertificateChain` with `allowUntrustedRoot=true`, so certificates with untrusted roots are not filtered out during store lookup.

3. **`SignPackageRequest.AllowUntrustedRoot`** (`NuGet.Packaging`) — used during the actual signing chain build in `BuildSigningCertificateChainOnce()`. Passed through to `CertificateChainUtility.GetCertificateChain()`.

The core mechanism is a new public overload of `CertificateChainUtility.GetCertificateChain`:

```csharp
public static IX509CertificateChain GetCertificateChain(
    X509Certificate2 certificate,
    X509Certificate2Collection extraStore,
    ILogger logger,
    CertificateType certificateType,
    bool allowUntrustedRoot)
```

Internally, `GetChainStatusFlags()` is updated to accept `allowUntrustedRoot`. When true, `X509ChainStatusFlags.UntrustedRoot` is added to the **warning** flags instead of the **error** flags:

```csharp
private static void GetChainStatusFlags(
    X509Certificate2 certificate,
    CertificateType certificateType,
    bool allowUntrustedRoot,
    out X509ChainStatusFlags errorStatusFlags,
    out X509ChainStatusFlags warningStatusFlags)
{
    // ... existing logic ...
    warningStatusFlags = X509ChainStatusFlags.RevocationStatusUnknown
                       | X509ChainStatusFlags.OfflineRevocation;

    if (certificateType == CertificateType.Signature
        && (CertificateUtility.IsSelfIssued(certificate) || allowUntrustedRoot))
    {
        warningStatusFlags |= X509ChainStatusFlags.UntrustedRoot;
    }
}
```

This reuses the same mechanism that already exists for self-issued (self-signed) certificates, extending it to the `allowUntrustedRoot` case. Chain statuses classified as warnings are logged via `ILogger` but do not cause `GetCertificateChain` to throw.

**Public API additions** (both net472 and net8.0):
```
NuGet.Packaging.Signing.CertificateChainUtility.GetCertificateChain(
    X509Certificate2, X509Certificate2Collection, ILogger, CertificateType, bool) → IX509CertificateChain
NuGet.Packaging.Signing.SignPackageRequest.AllowUntrustedRoot.get → bool
NuGet.Packaging.Signing.SignPackageRequest.AllowUntrustedRoot.set → void
NuGet.Commands.SignArgs.AllowUntrustedRoot.get → bool
NuGet.Commands.SignArgs.AllowUntrustedRoot.set → void
```

**Certificate discovery flow with `AllowUntrustedRoot=true`:**
1. `SignCommandRunner.GetCertificateAsync()` creates `CertificateSourceOptions` with `AllowUntrustedRoot = signArgs.AllowUntrustedRoot`
2. `CertificateProvider.GetCertificateAsync()` calls `LoadCertificateFromStore()` → `GetValidCertificates(collection, options.AllowUntrustedRoot)`
3. `GetValidCertificates()` calls `IsValid(cert, extraStore, allowUntrustedRoot)` for each candidate
4. `IsValid()` calls `CertificateChainUtility.GetCertificateChain(cert, extraStore, logger, CertificateType.Signature, allowUntrustedRoot)`
5. With `allowUntrustedRoot=true`, `UntrustedRoot` is a warning → chain builds successfully → cert is not filtered out

**Signing flow with `AllowUntrustedRoot=true`:**
1. `SignCommandRunner.ExecuteCommandAsync()` sets `signRequest.AllowUntrustedRoot = signArgs.AllowUntrustedRoot`
2. `SignPackageRequest.BuildSigningCertificateChainOnce()` calls `GetCertificateChain(Certificate, AdditionalCertificates, logger, CertificateType.Signature, AllowUntrustedRoot)`
3. `UntrustedRoot` is treated as warning → chain is returned → package is signed

## Drawbacks

- **Reduced trust verification at sign time**: By allowing untrusted roots, the signer no longer guarantees that the signing certificate chains to a known, trusted root CA. However, this is a **sign-time** concern only — NuGet package **verification** (`nuget verify`) independently validates the certificate chain against the consumer's trusted root store. The signed package still contains the full certificate chain, so verification is unaffected.
- **Opt-in flag could be misused**: Users might use `--allow-untrusted-root` without understanding the implications. This is mitigated by:
  - The flag name clearly communicates the security trade-off ("untrusted")
  - The default remains `false` — existing behavior is fully preserved
  - A warning is logged when UntrustedRoot status is encountered

## Rationale and alternatives

### Why this design

This approach was chosen for its **simplicity and broad compatibility**:

- **Works on net472**: Unlike `X509ChainTrustMode.CustomRootTrust` (which requires .NET 5+), this approach works with the existing `X509Chain` API on .NET Framework 4.7.2. This is critical because `nuget.exe` targets net472 and is widely used in Windows build environments.
- **Minimal surface area**: A single boolean flag at three levels (args → options → request) is the smallest possible API change.
- **Consistent with existing patterns**: The implementation reuses the same warning-vs-error classification mechanism already used for self-signed certificates.
- **No new dependencies**: No new certificate files, fingerprints, or trust store configurations needed.

### Alternatives considered

| Alternative | Why not chosen |
|---|---|
| **`AdditionalTrustAnchors` with `CustomRootTrust`** | Requires .NET 5+; does not work with `nuget.exe` (net472). More complex API surface (trust anchor files, fingerprint verification). Was prototyped in [PR #7194](https://github.com/NuGet/NuGet.Client/pull/7194) but superseded by the simpler approach. |
| **Install root CA to `CurrentUser\Root`** | Still triggers an interactive trust dialog on Windows — defeats the purpose. |
| **Programmatic `X509Store.Add()` to `CurrentUser\Root`** | Also triggers the trust dialog. |
| **Use `dotnet/sign` CLI tool** | Uses the same NuGet libraries internally; fails with the same chain validation. |
| **Reflection to inject custom chain** | Fragile; breaks on NuGet package updates. |

### Impact of not doing this

Without this change, any environment that cannot install root CA certificates into a trusted root store (containers, non-elevated CI, locked-down developer machines) cannot use `nuget sign` or `dotnet nuget sign`. Users must either:
- Run with admin elevation (security concern)
- Skip NuGet signing entirely (compliance concern)
- Use alternative signing tools and workflows (complexity concern)

## Prior Art

- **signtool.exe `/r` flag**: Microsoft's Authenticode signing tool has long supported signing without requiring the root CA in a trusted store, via the `/r` (root subject name) parameter.
- **NuGet's existing self-signed certificate handling**: `CertificateChainUtility.GetChainStatusFlags` already treats `UntrustedRoot` as a warning for self-issued certificates. This proposal extends that same mechanism.
- **NuGet `allowUntrustedRoot` in `nuget.config`**: NuGet's [`trustedSigners` configuration](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#trustedsigners-section) already supports an `allowUntrustedRoot` attribute on `<certificate>` elements. When set to `true`, it allows a trusted signer's certificate to chain to an untrusted root during signature verification. This proposal brings the same concept to the `sign` side as a CLI flag.
- **CoseSignTool `X509ChainTrustValidator`**: Microsoft's [CoseSignTool](https://github.com/microsoft/CoseSignTool) uses `CustomRootTrust` with `CustomTrustStore` for similar scenarios, but requires .NET 5+.

## Unresolved Questions

- **Warning message verbosity**: Should the warning logged when `UntrustedRoot` is encountered include remediation guidance (e.g., "consider installing the root CA certificate to suppress this warning")?
- **Interaction with `nuget verify`**: The existing `allowUntrustedRoot` attribute on `<certificate>` elements in the [`trustedSigners` section of `nuget.config`](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file#trustedsigners-section) serves a similar purpose for the verification side. Should the new `--allow-untrusted-root` flag and the existing config-level `allowUntrustedRoot` be documented together as complementary features?

## Future Possibilities

- **Default behavior change**: If enterprise adoption shows that `--allow-untrusted-root` is used in the vast majority of signing scenarios, a future proposal could consider changing the default behavior or adding a NuGet.config-level setting.
- **NuGet.config integration**: A `<config><add key="allowUntrustedRoot" value="true" /></config>` setting could make this persistent across commands without requiring the flag every time.
- **Certificate chain logging improvements**: With the untrusted root warning in place, NuGet could provide richer chain diagnostics (e.g., logging the full chain, identifying which root was found but untrusted).
