# Releasing Spolo

Spolo ships two ways from the same code: the **Mac App Store** (the `AppStore` build configuration) and a **download on tang-spark.no** (the `Release` configuration, signed with Developer ID and notarized). Both run in the App Sandbox with no network entitlement; they differ only in signing and in the Help menu, where the website build links to its download page to check for a new version.

## Every release

1. Bump `MARKETING_VERSION` (and for the App Store, `CURRENT_PROJECT_VERSION`) in `project.yml`, and add the release to `CHANGELOG.md`.
2. Check everything:
   ```bash
   scripts/preflight.sh
   scripts/test-merge.sh
   ```
3. App Store: build, then upload.
   ```bash
   scripts/appstore.sh upload
   ```
4. Website: build, sign, notarize and staple, then publish (see [WEBSITE.md](WEBSITE.md)).
   ```bash
   scripts/release.sh
   scripts/publish-website.sh ~/Documents/tang-spark.no
   ```

## One-time setup

| What | Status |
|---|---|
| Developer ID Application certificate (Feiyang Tang, X933P26489) | In the login keychain |
| Notarization profile `kvikkshot` | In the keychain, shared with Kvikkshot |
| App Store distribution signing | Cloud-managed by Xcode |
| Bundle ID `com.feiyangtang.Spolo` | Registered by Xcode on the first archive |
| App record | Created 22 October 2026: Apple ID 6825929542; build 1.0.0 (1) attached; listing, price, availability, privacy and review notes filled in; not yet submitted for review |

## App Store Connect

| Field | Value |
|---|---|
| Platform | macOS |
| Bundle ID | `com.feiyangtang.Spolo` |
| Apple ID | 6825929542 |
| SKU | `spolo-macos` |
| Primary language | English (U.S.) |
| Version | 1.0.0 |
| Primary category | Photo & Video |
| Secondary category | Utilities |
| Price | Free (Pro comes in 1.1 as a one-time in-app purchase) |
| Availability | 174 countries or regions: everywhere except China mainland, which needs an ICP filing number |
| Age rating | 4+ (no objectionable content) |
| App Privacy | Data Not Collected |
| Export compliance | No encryption (`ITSAppUsesNonExemptEncryption` is false) |
| Copyright | 2026 TangSpark |
| Support URL | https://tang-spark.no/spolo-support.html |
| Marketing URL | https://tang-spark.no/spolo.html |
| Privacy Policy URL | https://tang-spark.no/spolo-support.html#privacy |
| Localizations | English (U.S.), English (U.K.). The listing is English only; the app itself also speaks Simplified and Traditional Chinese. |

The three tang-spark.no pages are live (see [WEBSITE.md](WEBSITE.md)).

### Screenshots

2880 × 1800, in [screenshots/](appstore/screenshots/en), uploaded to English (U.S.); English (U.K.) uses the same ones. Upload 1, 2, 3 in order. The footage is drawn by `scripts/sample-video.swift`, so the studio owns it outright. To redo them after a UI change, see [Remaking the screenshots](#remaking-the-screenshots).

### English (U.S.)

**Name** (30): Spolo: Merge Videos & Photos

**Subtitle** (30): Combine clips into one video

**Promotional text** (170):
Drop in photos and videos, put them in order and export one video. No upload, no watermark, no limits, and when the clips match, no re-encoding either.

**Keywords** (100):
combine,join,joiner,merger,stitch,slideshow,montage,clips,compilation,concat,mp4,mov,reel,offline

**Description**:

Spolo merges photos and videos into one video, right on your Mac.

Drop in clips from your phone, camera or screen recordings, in any mix of shapes and formats. Put them in order, trim the ends, and export one MP4 or MOV. Nothing is uploaded, nothing is watermarked, and there is no limit on how many clips or how long.

When the clips match, Spolo joins them without re-encoding, which takes seconds instead of minutes.

PUT TOGETHER
• Drag photos and videos in, or add them from Photos without giving Spolo access to your library
• Drag to reorder, or sort by date taken, file name or the order you added them
• Formats macOS can't read, such as MKV or WebM, stay visible instead of silently disappearing

CHANGE EACH CLIP
• Trim the start and end of a video
• Speed from 0.25× to 4×, keeping the pitch
• Mute, rotate, and set how long each photo stays on screen
• Select several clips to change them at once; every change can be undone

ONE SHAPE
• Auto, 16:9, 9:16, 1:1 or 4:5
• Fit with black bars, or fill and crop
• Upright phone videos, HDR and standard clips, and clips without sound all come out right

EXPORT
• MP4 or MOV, in original quality, high, or a smaller file
• Progress with a Cancel button, then Show in Finder or Share
• Videos are read a frame at a time, never loaded whole, so long projects don't slow your Mac down

PRIVATE BY DESIGN
• Everything happens on your Mac. Spolo has no network access at all: no accounts, no analytics, no tracking
• Your clips are there when you come back; Spolo remembers where the files are, without copying them

Spolo speaks English, Simplified Chinese and Traditional Chinese, and it is free.

Made by TangSpark, a small software studio in Norway. Spole is Norwegian for a reel of film.

### English (U.K.)

The same as English (U.S.): the copy uses no spellings that differ between US and UK English.

## Notes for App Review

> Spolo merges photos and videos into one video. It needs no account, has no in-app purchases, and has no network access.
>
> To try it: drag a few photos and MP4 or MOV files onto the window, or choose File > Add…. Click a clip to edit it in the inspector on the right (trim, speed, mute, rotate, or a photo's duration). The toolbar sets the shape (Auto, 16:9, 9:16, 1:1, 4:5) and Fit or Fill. File > Export… saves the merged video.
>
> It runs in the App Sandbox with user-selected read-write access and app-scoped bookmarks, which bring back the last session's clips. Add from Photos uses the system photo picker, so no library permission is requested; picked items are copied into the app's container. The Help menu links (website, support, contact) open in the browser.

## Remaking the screenshots

1. Render the sample footage into `build/sample`:
   ```bash
   swift scripts/sample-video.swift "Fjord Morning.mp4" 14 0 0.25 7
   swift scripts/sample-video.swift "Golden Hour.mp4" 12 0.3 0.6 11
   swift scripts/sample-video.swift "Aurora Night.mp4" 12 0.8 1 3
   ```
   and cut stills and a vertical clip from them with ffmpeg: `IMG_2041.jpg` (Fjord Morning at 3 s, 4:3), `IMG_2047.jpg` (Golden Hour at 6 s, 4:5), `IMG_2052.jpg` (Aurora Night at 5 s, square) and `IMG_2049.mov` (Golden Hour, 9:16).
2. Open them in Spolo in that order (Fjord Morning, 2041, 2047, Golden Hour, 2049, 2052, Aurora Night) with `--args -AppleLanguages "(en)" -AppleLocale en_US`, trim Golden Hour to 0:02.8–0:10.0, and capture the window with `screencapture -o -l <window id>`: Auto and Fit with Golden Hour selected (1), 9:16 and Fill with IMG_2047 selected (2), then the same with File > Export… open (3).
3. Compose each capture:
   ```bash
   swift scripts/storeshot.swift capture.png docs/appstore/screenshots/en/1.jpg "Headline" "Subline"
   ```
   The headlines are in the screenshots themselves; keep them in step with the listing copy.
