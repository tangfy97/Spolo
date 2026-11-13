# Spolo on tang-spark.no

The product and support pages live in the [tang-spark.no](https://github.com/tangfy97/tang-spark.no) repo, which Netlify deploys from `main`. Their source is here, so the copy, the version and the download stay in step with the app.

| Page | URL |
|---|---|
| Product (EN, 简体, 繁體) | `/spolo.html`, `/spolo-zh-cn.html`, `/spolo-zh-tw.html` |
| Support, privacy, terms | `/spolo-support.html` (+ `-zh-cn`, `-zh-tw`); privacy is `#privacy` |
| Download | `https://github.com/tangfy97/Spolo/releases/latest`; the site hosts no installers, and its `netlify.toml` redirects the old `/spolo/download` links there |

The app's Help menu links to these pages in the language it runs in ([Links.swift](../Sources/SpoloApp/Links.swift)). In the downloaded version, Help › Check for a New Version opens the product page with `?installed=<version>`.

## Files here

- `website/generate.py`: the copy in all three languages and the page templates, in the site's Plakat layout (shared with Rydd). It reads the version from `project.yml`.
- `website/static/`: the icon and the app screenshots, copied to the site's `img/`.

The homepage lists Spolo as app 05 in `index.html` of the site repo; that entry was added by hand.

## Publishing a release

```bash
scripts/release.sh                                  # notarized build/release/Spolo-<version>.dmg, .zip and SHA256SUMS
gh release create v<version> build/release/Spolo-<version>.dmg build/release/Spolo-<version>.zip build/release/SHA256SUMS \
  --repo tangfy97/Spolo --title "Spolo <version>" --target main
scripts/publish-website.sh ~/Documents/tang-spark.no
git -C ~/Documents/tang-spark.no add -A && git -C ~/Documents/tang-spark.no commit -m "Spolo <version>"
git -C ~/Documents/tang-spark.no push
```

The download button links to the latest GitHub release, so publish the release before the pages. `publish-website.sh` regenerates the pages and copies them with the images. It never copies a disk image, edits `netlify.toml`, commits or pushes.

Once the app is live on the App Store, set `APP_STORE_URL` in `website/generate.py` to show the Mac App Store button, and publish again.
