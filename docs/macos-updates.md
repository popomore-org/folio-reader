# macOS releases and updates

Folio checks the signed Sparkle appcast in [GitHub Releases](https://github.com/popomore-org/folio-reader/releases). Stable builds can check automatically at startup and every 24 hours while running. Use **Settings → Updates** or **Check for Updates…** in the Folio menu to check manually.

Folio verifies the download before handing it to Sparkle. Workspaces and preferences live outside the app bundle. Open documents and native media playback can delay a restart.

## Verify locally

Run `scripts/prepare-update-qa` and use the directory printed on the last line. Serve its `server` subdirectory on loopback with `python3 -m http.server 18736 --bind 127.0.0.1 --directory "$qa/server"`. Open `"$qa/installed/Folio Update QA.app"` and its `Fixture.md`. Check for, download, and install the update from Settings. The local builds use a separate bundle identity and a temporary Sparkle key.

## Publish a stable release

1. Use a clean checkout of `origin/main` with passing Folio CI. Update `.release/notes.txt` for the release.
2. Create a new `vX.Y.Z` tag on that commit and push it when publication is authorized. The workflow uses the tag as the release version.
3. Verify the GitHub release, Apple Silicon DMG, Sparkle ZIP, and signed public appcast. The stable release becomes Latest.

A manual workflow run checks a tag and builds a local update fixture. A tag push to the public repository publishes. The distribution job uses the repository's workflow token, and the repository must have immutable releases enabled.

Configure the following in the `folio-macos-release` environment:

| Setting | Purpose |
| --- | --- |
| `FOLIO_UPDATE_PUBLIC_KEY` variable | Stable Sparkle Ed25519 public key |
| `FOLIO_UPDATE_PRIVATE_KEY` secret | Corresponding signing seed |
| `FOLIO_APPLE_CERTIFICATE`, `FOLIO_APPLE_CERTIFICATE_PASSWORD` | Base64 Developer ID Application PKCS#12 certificate and password |
| `FOLIO_APPLE_NOTARY_KEY`, `FOLIO_APPLE_NOTARY_KEY_ID`, `FOLIO_APPLE_NOTARY_ISSUER` | Apple notarization credentials |

The job signs and notarizes the app and DMG, stages the packages in a release draft, verifies the stored bytes, and checks the public download URLs. Re-run the original workflow if publication stops partway so the job can reuse the retained signed packages. If those artifacts have expired, recover the exact packages before proceeding.
