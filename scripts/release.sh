#!/bin/sh
# Build a Developer ID signed, notarized, stapled Hermes.dmg in dist/.
#   ./scripts/release.sh            # archive, sign, dmg, notarize, staple
#   ./scripts/release.sh --no-notarize
set -e
cd "$(dirname "$0")/.."
IDENTITY="Developer ID Application: Joshua Trommel (QMM486NPYC)"
TEAM=QMM486NPYC
VERSION=$(grep MARKETING_VERSION project.yml | awk '{print $2}')
export ASC_BYPASS_KEYCHAIN=1

rm -rf dist && mkdir -p dist
xcodegen generate >/dev/null
xcodebuild archive -scheme Hermes -configuration Release -archivePath dist/Hermes.xcarchive \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" DEVELOPMENT_TEAM=$TEAM OTHER_CODE_SIGN_FLAGS=--timestamp | tail -1

cp -R dist/Hermes.xcarchive/Products/Applications/Hermes.app dist/
codesign --verify --deep --strict dist/Hermes.app
codesign -dv dist/Hermes.app 2>&1 | grep -E "Authority=Developer ID|flags=.*runtime" >/dev/null || { echo "not Developer ID signed with hardened runtime"; exit 1; }

# drag-to-Applications disk image
mkdir -p dist/dmg && cp -R dist/Hermes.app dist/dmg/ && ln -s /Applications dist/dmg/Applications
hdiutil create -volname "Hermes $VERSION" -srcfolder dist/dmg -ov -format UDZO dist/Hermes.dmg >/dev/null
rm -rf dist/dmg
codesign --sign "$IDENTITY" --timestamp dist/Hermes.dmg

[ "$1" = "--no-notarize" ] && { echo "dist/Hermes.dmg (not notarized)"; exit 0; }
asc notarization submit --file dist/Hermes.dmg --wait --output table
asc notarization staple --file dist/Hermes.dmg --confirm --output table
spctl -a -t open --context context:primary-signature -v dist/Hermes.dmg
echo "dist/Hermes.dmg $VERSION ready"
