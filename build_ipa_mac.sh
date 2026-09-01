#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
rm -rf build Payload ChiTieu.ipa

xcodebuild \
  -project ChiTieu.xcodeproj \
  -scheme ChiTieu \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

APP="build/Build/Products/Release-iphoneos/ChiTieu.app"

if [ ! -d "$APP" ]; then
  echo "Không tìm thấy ChiTieu.app sau khi build."
  exit 1
fi

# Ad-hoc sign để tạo bundle phù hợp cho sideload/TrollStore.
/usr/bin/codesign --force --deep --sign - --timestamp=none "$APP" || true

mkdir Payload
cp -R "$APP" Payload/
zip -qry ChiTieu.ipa Payload
rm -rf Payload

echo "Xong: $(pwd)/ChiTieu.ipa"
