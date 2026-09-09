#!/usr/bin/env bash
# Local release pipeline — no CI minutes needed. Builds on this Mac, tags,
# and publishes a GitHub Release with the zipped app.
#
#   scripts/release.sh 0.3.0
#
# Requires: xcodegen, xcodebuild, gh (authenticated).
set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version, e.g. 0.3.0>}"
cd "$(dirname "$0")/.."

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is dirty — commit or stash first" >&2
  exit 1
fi

echo "==> Setting version $VERSION"
sed -i '' "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"$VERSION\"/" project.yml

echo "==> Generating project"
xcodegen generate >/dev/null

echo "==> Building Release"
xcodebuild -project SayIt.xcodeproj -scheme SayIt -configuration Release \
  -derivedDataPath build build 2>&1 | grep -E "error:|BUILD" || true

APP="build/Build/Products/Release/SayIt.app"
[[ -d "$APP" ]] || { echo "error: build failed, $APP missing" >&2; exit 1; }

echo "==> Signing"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application"; then
  IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')
  echo "    using Developer ID: $IDENTITY"
  codesign --force --deep --options runtime -s "$IDENTITY" "$APP"
  # With a Developer ID you should also notarize:
  #   ditto -c -k --keepParent "$APP" notarize.zip
  #   xcrun notarytool submit notarize.zip --keychain-profile sayit --wait
  #   xcrun stapler staple "$APP"
else
  echo "    no Developer ID found — ad-hoc signing (users will need to approve the app once)"
  codesign --force --deep -s - "$APP"
fi

ZIP="SayIt-$VERSION.zip"
echo "==> Zipping $ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Committing, tagging v$VERSION"
git add project.yml
git commit -m "Release $VERSION" >/dev/null || true
git tag "v$VERSION"
git push
git push origin "v$VERSION"

echo "==> Creating GitHub release"
NOTES='## Install

1. Download `SayIt-*.zip` below, unzip, and drag **SayIt.app** to `/Applications`.
2. First launch: macOS will warn that the app is from an unidentified developer.
   Go to **System Settings → Privacy & Security** and click **Open Anyway**
   (or run `xattr -dr com.apple.quarantine /Applications/SayIt.app` once).
3. Open SayIt and follow its setup — mic, Accessibility, and the fn key.

Requires macOS 26+ on Apple Silicon. Everything runs on-device.'
gh release create "v$VERSION" "$ZIP" \
  --title "SayIt $VERSION" \
  --notes "$NOTES"

rm -f "$ZIP"
echo "==> Done: $(gh release view "v$VERSION" --json url --jq .url)"
