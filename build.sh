#!/bin/sh
set -eu
cd "$(dirname "$0")"
app="Open in T3 Code.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
xcrun clang -fobjc-arc -Os -Wall -Werror -mmacosx-version-min=13.0 -arch arm64 -arch x86_64 \
  -framework Cocoa src/Launcher.m src/main.m -o "$app/Contents/MacOS/OpenInT3Code"
cp resources/Info.plist "$app/Contents/Info.plist"
cp resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp LICENSE THIRD_PARTY_NOTICES.md "$app/Contents/Resources/"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
echo "Built $app"
