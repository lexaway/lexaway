#!/usr/bin/env bash
set -euo pipefail

# Usage: ./tools/release.sh
# Builds and uploads the IPA to App Store Connect.
# Bump the version in pubspec.yaml first!

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "==> Building IPA..."
flutter build ipa --release

echo "==> Uploading to App Store Connect..."
xcrun altool --upload-app --type ios \
  -f build/ios/ipa/*.ipa \
  --apiKey RQJSZ643B2 \
  --apiIssuer 7890ec76-7830-4eb8-a6a5-5d4646cff982

echo "==> Done! Check App Store Connect for the new build."
