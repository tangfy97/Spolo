#!/bin/zsh
# Copies the Spolo pages and the notarized disk image into a checkout of the tang-spark.no site,
# ready to review and push (Netlify deploys the site from its main branch).
#
#   scripts/release.sh                                   # first: build/release/Spolo-<version>.dmg
#   scripts/publish-website.sh ~/Documents/tang-spark.no
#
# It writes spolo*.html, spolo.css, spolo/ (images), downloads/Spolo-<version>.dmg,
# and points /spolo/download at that disk image in netlify.toml. It never commits or pushes.
set -euo pipefail
cd "$(dirname "$0")/.."

site=${1:?usage: scripts/publish-website.sh <tang-spark.no checkout>}
[[ -f $site/netlify.toml && -f $site/styles.css ]] || { echo "error: $site is not the tang-spark.no site" >&2; exit 1; }
version=$(sed -nE 's/^ *MARKETING_VERSION: "?([^"]*)"?$/\1/p' project.yml)
dmg=build/release/Spolo-$version.dmg

[[ -f $dmg ]] || { echo "error: $dmg not found; run scripts/release.sh first" >&2; exit 1; }
if ! xcrun stapler validate -q "$dmg" 2>/dev/null; then
  echo "error: $dmg is not notarized; publish only what scripts/release.sh built with notarization" >&2
  exit 1
fi

[[ -f website/generate.py ]] || { echo "error: the Spolo web pages (website/) don't exist yet" >&2; exit 1; }
/usr/bin/python3 website/generate.py
cp website/dist/*.html "$site/"
cp website/static/spolo.css "$site/"
mkdir -p "$site/spolo" "$site/downloads"
cp website/static/spolo/* "$site/spolo/"
cp "$dmg" "$site/downloads/"

# One redirect, so links to /spolo/download always give the latest disk image
/usr/bin/python3 - "$site/netlify.toml" "$version" <<'EOF'
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
EOF

echo "Copied Spolo $version into $site. Review with 'git -C $site status', then commit and push."
