#!/bin/zsh
# Archives the iOS app and uploads it to App Store Connect (TestFlight) in one go.
#
#   scripts/testflight.sh <TEAM_ID>
#
# Needs: a paid Apple Developer account signed in to Xcode (Settings > Accounts), the app record
# `co.munyati.app` created in App Store Connect, and `brew install xcodegen`.
# The build number is the current time (yyMMddHHmm), so every upload is unique; the version stays
# MARKETING_VERSION from project.yml.
set -euo pipefail

TEAM_ID="${1:-}"
if [[ -z "$TEAM_ID" ]]; then
  echo "usage: scripts/testflight.sh <TEAM_ID>   (Apple Developer > Membership shows it)" >&2
  exit 1
fi

ROOT="${0:A:h:h}"
OUT="$ROOT/build/testflight"
BUILD_NUMBER="$(date +%y%m%d%H%M)"
rm -rf "$OUT" && mkdir -p "$OUT"
cd "$ROOT"

xcodegen generate --quiet

echo "Archiving build $BUILD_NUMBER…"
xcodebuild archive \
  -project Munyati.xcodeproj -scheme Munyati -configuration Release \
  -destination generic/platform=iOS \
  -archivePath "$OUT/Munyati.xcarchive" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  -quiet

cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF

echo "Uploading to App Store Connect…"
xcodebuild -exportArchive \
  -archivePath "$OUT/Munyati.xcarchive" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$OUT/export" \
  -allowProvisioningUpdates

echo "Done: build $BUILD_NUMBER is processing in App Store Connect > TestFlight (about 10–30 min)."
