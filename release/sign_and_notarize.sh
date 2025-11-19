#!/usr/bin/env bash
set -euo pipefail

# sign_and_notarize.sh
# Helper to sign (codesign) a macOS .app bundle and submit to Apple Notary service.
# This script does not store secrets; set the required environment variables prior to running.
#
# Required env vars (choose one notarization flow):
# - For notarytool with API key (recommended):
#     APPLE_API_KEY_PATH=/path/to/AuthKey_ABC123XYZ.p8
#     APPLE_API_KEY_ID=ABC123XYZ
#     APPLE_ISSUER_ID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
# - Or using app-specific password (legacy):
#     APPLE_ID=you@domain.com
#     APPLE_APP_SPECIFIC_PASSWORD=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#
# Usage:
# ./sign_and_notarize.sh /path/to/MyApp.app "com.example.myapp"

if [[ "$#" -lt 2 ]]; then
  echo "Usage: $0 /path/to/App.app com.example.bundleid" >&2
  exit 2
fi

APP_PATH="$1"
BUNDLE_ID="$2"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at $APP_PATH" >&2
  exit 3
fi

echo "Signing $APP_PATH (bundle id: $BUNDLE_ID)"

# Codesign the app (use the Developer ID Application identity)
if ! command -v codesign >/dev/null 2>&1; then
  echo "codesign is required but not found" >&2
  exit 4
fi

# The signing identity should be provided by the user. We will attempt to auto-detect a Developer ID Application identity.
SIGN_IDENTITY="$(security find-identity -v -p codesigning | grep 'Developer ID Application' | awk -F '"' '{print $2; exit}')" || true

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "No 'Developer ID Application' identity found in keychain. Please unlock and add your signing key or pass a specific identity." >&2
  echo "To use a specific identity: codesign -s '3rd Party Mac Developer Application: Your Name (TEAMID)' ..." >&2
else
  echo "Using signing identity: $SIGN_IDENTITY"
  echo "Running codesign..."
  codesign --deep --force --verbose --options runtime -s "$SIGN_IDENTITY" "$APP_PATH"
fi

ZIP_PATH="${APP_PATH%/}.zip"
echo "Creating zip: $ZIP_PATH"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Submitting to Apple Notary service..."

if [[ -n "${APPLE_API_KEY_PATH:-}" && -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_ISSUER_ID:-}" ]]; then
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun not found; please install Xcode command line tools" >&2
    exit 5
  fi
  echo "Using notarytool with API key..."
  xcrun notarytool submit --key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_ISSUER_ID" --wait "$ZIP_PATH"
  echo "Stapling notarization ticket..."
  xcrun stapler staple "$APP_PATH"
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  echo "Using legacy altool (app-specific password)..."
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun not found; please install Xcode command line tools" >&2
    exit 5
  fi
  xcrun altool --notarize-app -f "$ZIP_PATH" --primary-bundle-id "$BUNDLE_ID" -u "$APPLE_ID" -p "$APPLE_APP_SPECIFIC_PASSWORD"
  echo "Note: legacy altool flow may require polling for status via altool --notarization-info <uuid>"
  echo "After notarization completes, staple with: xcrun stapler staple \"$APP_PATH\""
else
  echo "No notarization credentials provided. Set APPLE_API_KEY_PATH/APPLE_API_KEY_ID/APPLE_ISSUER_ID or APPLE_ID/APPLE_APP_SPECIFIC_PASSWORD" >&2
  exit 6
fi

echo "Signed and notarization requested/completed for $APP_PATH"
