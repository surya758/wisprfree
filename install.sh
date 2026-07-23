#!/bin/zsh
# Build WisprFree and install it into /Applications.
set -e
cd "$(dirname "$0")"

# Use the shared git hooks (Conventional Commits enforcement).
git config core.hooksPath .githooks 2>/dev/null || true

xcodegen
xcodebuild -project WisprFree.xcodeproj -scheme WisprFree -configuration Release build | grep -E "error:|BUILD"

APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/WisprFree-*/Build/Products/Release/WisprFree.app | head -1)
pkill -x WisprFree 2>/dev/null || true
sleep 1
rm -rf /Applications/WisprFree.app
ditto "$APP" /Applications/WisprFree.app
open /Applications/WisprFree.app
echo "Installed and launched /Applications/WisprFree.app"
