# Spolo on tang-spark.no

The product and support pages live in the [tang-spark.no](https://github.com/tangfy97/tang-spark.no) repo, which Netlify deploys from `main`. Their source is here, so the copy, the version and the download stay in step with the app.

| Page | URL |
|---|---|
| Product (EN, 简体, 繁體) | `/spolo.html`, `/spolo-zh-cn.html`, `/spolo-zh-tw.html` |
| Support, privacy, terms | `/spolo-support.html` (+ `-zh-cn`, `-zh-tw`); privacy is `#privacy` |
| Latest disk image | `/spolo/download`, a redirect to `/downloads/Spolo-<version>.dmg` |

The app's Help menu links to these pages in the language it runs in ([Links.swift](../Sources/SpoloApp/Links.swift)). In the downloaded version, Help › Check for a New Version opens the product page with `?installed=<version>`.

## Files here

- `website/generate.py`: the copy in all three languages and the page templates, in the site's Plakat layout (shared with Rydd). It reads the version from `project.yml`.
- `website/static/`: the icon and the app screenshots, copied to the site's `img/`.

The homepage lists Spolo as app 05 in `index.html` of the site repo; that entry was added by hand.

## Publishing a release

```bash
scripts/release.sh                                  # notarized build/release/Spolo-<version>.dmg
scripts/publish-website.sh ~/Documents/tang-spark.no
git -C ~/Documents/tang-spark.no add -A && git -C ~/Documents/tang-spark.no commit -m "Spolo <version>"
git -C ~/Documents/tang-spark.no push
```

`publish-website.sh` refuses a disk image that isn't notarized, regenerates the pages, copies them with the images and the disk image, and points `/spolo/download` at the new version in `netlify.toml`. It never commits or pushes.

Once the app is live on the App Store, set `APP_STORE_URL` in `website/generate.py` to show the Mac App Store button, and publish again.
