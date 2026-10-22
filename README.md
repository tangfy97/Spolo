<p align="center"><img src="docs/images/icon.png" width="128" height="128" alt="Spolo icon"></p>

# Spolo

A native macOS app that merges photos and videos into one video, entirely on your Mac. Nothing is uploaded, and when the clips allow it they are joined without re-encoding. *Spole* is Norwegian for a reel; *spole fram* means fast-forward.

- Drop in photos and videos, or add them from Photos without giving Spolo access to your library
- Drag to reorder, or sort by date taken, file name or the order they were added
- Trim, speed up or slow down (0.25× to 4×, keeping the pitch), mute and rotate videos; set how long each photo stays on screen; change several clips at once
- Auto, 16:9, 9:16, 1:1 or 4:5, with black bars or cropped to fill
- Export MP4 or MOV in original quality, high or a smaller file; matching clips are joined instantly without re-encoding
- No watermark, and no limit on clip count or length; videos are read frame by frame, never loaded into memory
- Mixed HDR and SDR, clips without sound, variable frame rates and phone videos shot upright all come out right
- MKV, WebM and other formats macOS can't read stay visible, greyed out, instead of silently disappearing
- The last session comes back when you reopen Spolo, and every change can be undone; Settings (⌘,) hold the defaults for new photos and exports
- English, English (UK), Simplified Chinese and Traditional Chinese, following the system language
- Runs in the App Sandbox with no network access; no accounts, no analytics ([privacy policy](PRIVACY.md))

**Download:** Spolo 1.0 is free. Get the signed, notarized disk image from [Releases](https://github.com/tangfy97/Spolo/releases/latest) or [tang-spark.no/spolo](https://tang-spark.no/spolo.html); it is coming to the Mac App Store. It needs macOS 14 Sonoma or later, on Apple silicon or Intel.

## Build

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
scripts/build.sh          # sandboxed build in build/Spolo.app, signed to run locally
scripts/preflight.sh      # builds both release configurations and checks them before shipping
scripts/test-merge.sh     # merges generated test media and checks every frame (needs ffmpeg)
```

`project.yml` is the source of truth for the Xcode project; edit it rather than the `.xcodeproj`, then run `xcodegen generate`. The `Release` configuration is the website build and `AppStore` the Mac App Store build; both run in the App Sandbox with no network entitlement. The Swift package builds the engine, `SpoloCore` (reading media, the composition, the Core Image compositor and export), and `spolo`, a command-line tool that merges files the same way the app does.

| Script | What it does |
|---|---|
| `scripts/release.sh` | Website build: Developer ID, notarized, as a DMG and zip in `build/release` |
| `scripts/appstore.sh` | App Store build: signed installer package, and `upload` sends it to App Store Connect |
| `scripts/publish-website.sh` | Copies the pages from `website/` (and the notarized disk image) into the tang-spark.no site |
| `scripts/icon.swift` | Renders the app icon into the asset catalog |
| `scripts/sample-video.swift`, `scripts/storeshot.swift` | Sample footage and App Store screenshot composition |
| `scripts/test-merge.sh`, `scripts/test-photos.swift` | Test media and end-to-end checks of the merge engine |

Releasing and App Store Connect values: [docs/APP_STORE.md](docs/APP_STORE.md). How the engine works: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). The website pages: [docs/WEBSITE.md](docs/WEBSITE.md). The product plan, including what comes in Pro: [docs/PLAN.md](docs/PLAN.md).

## License

Copyright © 2026 TangSpark. Released under the [Apache License 2.0](LICENSE). Contributions: [CONTRIBUTING.md](CONTRIBUTING.md). Security: [SECURITY.md](SECURITY.md).
