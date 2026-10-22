#!/bin/zsh
# Checks that both builds are ready to ship before anything is signed or uploaded:
# builds the Release (website) and AppStore configurations ad hoc and inspects them.
#
#   scripts/preflight.sh
set -uo pipefail
cd "$(dirname "$0")/.."

failures=0
pass() { print -P "  %F{green}✓%f $1"; }
fail() { print -P "  %F{red}✗ $1%f"; failures=$((failures + 1)); }
check() { local label=$1; shift; if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi; }

echo "==> Source"
/usr/bin/python3 - <<'PY' && pass "every string translated into zh-Hans and zh-Hant" || fail "untranslated strings (listed above)"
import re, sys
keys = lambda p: set(re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', open(p).read(), re.M))
hans, hant = keys("Resources/zh-Hans.lproj/Localizable.strings"), keys("Resources/zh-Hant.lproj/Localizable.strings")
for k in sorted(hans ^ hant):
    print(f"    only in one Chinese file: {k}")
sys.exit(1 if hans ^ hant else 0)
PY
check "privacy manifest is a valid plist" plutil -lint App/PrivacyInfo.xcprivacy
check "string files are valid" plutil -lint Resources/*.lproj/*.strings
check "icon has every size" sh -c 'for s in 16 32 64 128 256 512 1024; do test -f App/Assets.xcassets/AppIcon.appiconset/icon_$s.png || exit 1; done'
check "no networking code" sh -c '! grep -rqE "URLSession|NWConnection|NWBrowser|CFSocket" Sources'
check "no in-app purchase code in 1.0" sh -c '! grep -rqE "import StoreKit|Product\\.products" Sources'

xcodegen generate --quiet
for config in Release AppStore; do
  echo "==> $config build"
  mkdir -p build/preflight.noindex
  if ! xcodebuild -project Spolo.xcodeproj -scheme Spolo -configuration $config \
      -derivedDataPath build/preflight.noindex -destination 'generic/platform=macOS' \
      CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build -quiet >build/preflight.noindex/$config.log 2>&1; then
    fail "build failed (see build/preflight.noindex/$config.log)"
    continue
  fi
  pass "builds without errors"
  app=build/preflight.noindex/Build/Products/$config/Spolo.app
  plist=$app/Contents/Info.plist
  value() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist" 2>/dev/null; }

  [[ $(value CFBundleIdentifier) == com.feiyangtang.Spolo ]] && pass "bundle ID com.feiyangtang.Spolo" || fail "bundle ID is $(value CFBundleIdentifier)"
  [[ $(value CFBundleShortVersionString) =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] && pass "version $(value CFBundleShortVersionString) ($(value CFBundleVersion))" || fail "version $(value CFBundleShortVersionString)"
  [[ $(value LSMinimumSystemVersion) == 14.0 ]] && pass "runs on macOS 14 and later" || fail "minimum system $(value LSMinimumSystemVersion)"
  [[ $(value ITSAppUsesNonExemptEncryption) == false ]] && pass "export compliance: no encryption" || fail "ITSAppUsesNonExemptEncryption missing"
  [[ $(value NSHumanReadableCopyright) == *TangSpark* ]] && pass "copyright $(value NSHumanReadableCopyright)" || fail "copyright missing"
  [[ $(value LSApplicationCategoryType) == public.app-category.video ]] && pass "category Video" || fail "category missing"
  [[ $(value CFBundleIconName) == AppIcon ]] && pass "app icon in the asset catalog" || fail "CFBundleIconName missing"
  [[ $(lipo -archs $app/Contents/MacOS/Spolo) == *arm64* && $(lipo -archs $app/Contents/MacOS/Spolo) == *x86_64* ]] \
    && pass "universal binary (Apple silicon and Intel)" || fail "not universal: $(lipo -archs $app/Contents/MacOS/Spolo)"
  for lang in en en-GB zh-Hans zh-Hant; do
    [[ -d $app/Contents/Resources/$lang.lproj ]] || fail "no $lang localization"
  done && pass "localized in en, en-GB, zh-Hans, zh-Hant"
  check "privacy manifest bundled" test -f $app/Contents/Resources/PrivacyInfo.xcprivacy

  entitlements=$(codesign -d --entitlements - --xml $app 2>/dev/null)
  [[ $entitlements == *com.apple.security.app-sandbox* ]] && pass "App Sandbox on" || fail "App Sandbox off"
  [[ $entitlements != *com.apple.security.network* ]] && pass "no network entitlement" || fail "has a network entitlement"
  [[ $entitlements != *com.apple.security.temporary-exception* ]] && pass "no temporary exceptions" || fail "has temporary exceptions"
  hardened=$(codesign -d --verbose=2 $app 2>&1 | grep -c "runtime")
  [[ $hardened -gt 0 ]] && pass "hardened runtime" || fail "hardened runtime off"

  if [[ $config == AppStore ]]; then
    links=$(strings $app/Contents/MacOS/Spolo)
    [[ $links != *"?installed="* ]] && pass "no website update link" || fail "website update link compiled in"
  else
    links=$(strings $app/Contents/MacOS/Spolo)
    [[ $links == *"?installed="* ]] && pass "Help menu links to the download page" || fail "download page link missing"
  fi
  # Leave no checked copy behind for Spotlight, Launchpad and Open With to find.
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$PWD/$app" 2>/dev/null
  rm -rf $app
done

echo
if [[ $failures -eq 0 ]]; then
  print -P "%F{green}All checks passed.%f"
else
  print -P "%F{red}$failures check(s) failed.%f"
  exit 1
fi
