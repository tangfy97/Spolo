#!/bin/zsh
# Development build: regenerates the Xcode project from project.yml and builds a locally signed
# (sandboxed) copy into build/Spolo.app. For releases see scripts/release.sh (website) and
# scripts/appstore.sh (Mac App Store).
set -e
cd "$(dirname "$0")/.."

xcodegen generate --quiet
xcodebuild -project Spolo.xcodeproj -scheme Spolo -configuration Release \
    -derivedDataPath build/DerivedData.noindex \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
    -quiet build

# Xcode registers every app it builds with Launch Services. Move the product out rather than copying it,
# so build/Spolo.app is the only development copy that Spotlight, Launchpad and Open With can find.
product=build/DerivedData.noindex/Build/Products/Release/Spolo.app
rm -rf build/Spolo.app
mv $product build/
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$PWD/$product" 2>/dev/null || true
echo "Built build/Spolo.app"
