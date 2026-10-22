#!/bin/zsh
# Development build: regenerates the Xcode project from project.yml and builds a locally signed
# (sandboxed) copy into build/Spolo.app. For releases see scripts/release.sh (website) and
# scripts/appstore.sh (Mac App Store).
set -e
cd "$(dirname "$0")/.."

xcodegen generate --quiet
xcodebuild -project Spolo.xcodeproj -scheme Spolo -configuration Release \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
    -quiet build

rm -rf build/Spolo.app
cp -R build/DerivedData/Build/Products/Release/Spolo.app build/
echo "Built build/Spolo.app"
