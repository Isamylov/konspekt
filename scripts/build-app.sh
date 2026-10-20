#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=.build/Konspekt.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/konspekt "$APP/Contents/MacOS/konspekt"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign -s - --force --timestamp=none "$APP"

echo "$APP"
