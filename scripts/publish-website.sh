#!/bin/zsh
# Copies the Spolo pages into a checkout of the tang-spark.no site, ready to review and push
# (Netlify deploys the site from its main branch). The site hosts no installers: the download button
# goes to https://github.com/tangfy97/Spolo/releases/latest, and the site's netlify.toml sends the old
# /spolo/download links there too.
#
#   scripts/publish-website.sh ~/Documents/tang-spark.no
#
# It writes spolo*.html and img/spolo-*. It never copies a disk image, edits netlify.toml, commits or pushes.
set -euo pipefail
cd "$(dirname "$0")/.."

site=${1:?usage: scripts/publish-website.sh <tang-spark.no checkout>}
[[ -f $site/netlify.toml && -f $site/styles.css ]] || { echo "error: $site is not the tang-spark.no site" >&2; exit 1; }
version=$(sed -nE 's/^ *MARKETING_VERSION: "?([^"]*)"?$/\1/p' project.yml)

/usr/bin/python3 -I website/generate.py
cp website/dist/*.html "$site/"
cp website/static/* "$site/img/"

echo "Copied the Spolo $version pages into $site. Review with 'git -C $site status', then commit and push."
