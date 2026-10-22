#!/bin/zsh
# Copies the Spolo pages (and, once there is one, the notarized disk image) into a checkout of the
# tang-spark.no site, ready to review and push (Netlify deploys the site from its main branch).
#
#   scripts/release.sh                                   # optional: build/release/Spolo-<version>.dmg
#   scripts/publish-website.sh ~/Documents/tang-spark.no
#
# It writes spolo*.html, img/spolo-*, and with a disk image downloads/Spolo-<version>.dmg plus a
# /spolo/download redirect in netlify.toml. It never commits or pushes.
set -euo pipefail
cd "$(dirname "$0")/.."

site=${1:?usage: scripts/publish-website.sh <tang-spark.no checkout>}
[[ -f $site/netlify.toml && -f $site/styles.css ]] || { echo "error: $site is not the tang-spark.no site" >&2; exit 1; }
version=$(sed -nE 's/^ *MARKETING_VERSION: "?([^"]*)"?$/\1/p' project.yml)
dmg=build/release/Spolo-$version.dmg

download=""
if [[ -f $dmg ]]; then
  if ! xcrun stapler validate -q "$dmg" 2>/dev/null; then
    echo "error: $dmg is not notarized; publish only what scripts/release.sh built with notarization" >&2
    exit 1
  fi
  download=./spolo/download
fi

SPOLO_DOWNLOAD_URL=$download /usr/bin/python3 website/generate.py
cp website/dist/*.html "$site/"
cp website/static/* "$site/img/"

if [[ -n $download ]]; then
  mkdir -p "$site/downloads"
  cp "$dmg" "$site/downloads/"
  # One redirect, so links to /spolo/download always give the latest disk image
  /usr/bin/python3 - "$site/netlify.toml" "$version" <<'PY'
import re, sys
path, version = sys.argv[1], sys.argv[2]
toml = open(path).read()
block = f'''# spolo-download (managed by Spolo's scripts/publish-website.sh)
[[redirects]]
  from = "/spolo/download"
  to = "/downloads/Spolo-{version}.dmg"
  status = 302
  force = true
# end spolo-download
'''
pattern = re.compile(r"# spolo-download.*?# end spolo-download\n", re.S)
toml = pattern.sub(block, toml) if pattern.search(toml) else toml.rstrip("\n") + "\n\n" + block
open(path, "w").write(toml)
PY
fi

echo "Copied Spolo $version pages${download:+ and disk image} into $site. Review with 'git -C $site status', then commit and push."
