---
description: "README"
---

# Release & distribution helpers (macOS)

This folder contains helper scripts and documentation for macOS distribution hygiene:

- `sign_and_notarize.sh` — helper to codesign a macOS `.app` and submit it to Apple's notarization service (supports notarytool with API key or legacy altool flow). Requires Xcode command line tools and a signing identity in your keychain. Do NOT store credentials in the repo; use environment variables as described in the script header.

- `create_github_release.sh` — simple wrapper that creates a GitHub Release and uploads a build artifact using the `gh` CLI. This is helpful when using Tauri's updater configured to check GitHub Releases.

- `bootstrap_first_run.sh` — a developer convenience script that checks and creates a Python venv under `ForgeTM/apps/backend/.venv`, installs `requirements.txt` (if present), checks ports (8000/8001), and writes a starter `.env` file if missing.

High-level notes

- Code signing & notarization
  - Recommended: create an App Store Connect API key (Issuer ID + Key ID + .p8 file) and set `APPLE_API_KEY_PATH`, `APPLE_API_KEY_ID`, and `APPLE_ISSUER_ID` in your environment before running `sign_and_notarize.sh`.
  - The script attempts to auto-detect a `Developer ID Application` identity. If you use a custom identity name, sign manually or update the script.
  - Stapling the notarization ticket is performed with `xcrun stapler staple` after successful notarization.

- Tauri auto-updates (GitHub Releases)
  - Ensure your `tauri.conf.json` is configured with the GitHub updater and correct repository information.
  - Use `create_github_release.sh` to publish artifacts. The Tauri updater will fetch releases from GitHub and download the artifact that matches the platform/channel.

- First-run bootstrap
  - Intended for developer convenience, not production provisioning.
  - The `bootstrap_first_run.sh` script writes a minimal `.env`. Replace secrets and production configurations before deploying.

Security & CI

- Do not commit Apple API keys, passwords, or app-specific passwords to the repo. Use CI/CD secrets (GitHub Actions secrets) when automating notarization.
- For automated CI notarization, consider using `xcrun notarytool` with an API key stored in CI secrets and call the `sign_and_notarize.sh` script or replicate its steps in your workflow.

Usage examples

Make scripts executable:

```bash
chmod +x tools/release/*.sh
```

Run bootstrap locally:

```bash
./tools/release/bootstrap_first_run.sh
```

Create a release (example):

```bash
./tools/release/create_github_release.sh v1.0.0 ./dist/MyApp-macos.zip "Release notes for v1.0.0"
```

Run signing & notarization (example — using API key):

```bash
export APPLE_API_KEY_PATH="$HOME/keys/AuthKey_ABC123.p8"
export APPLE_API_KEY_ID="ABC123"
export APPLE_ISSUER_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
./tools/release/sign_and_notarize.sh ./dist/MyApp.app com.example.myapp
```
