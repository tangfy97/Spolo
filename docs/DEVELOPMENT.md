# How Spolo works

The code is in two parts. `Sources/SpoloCore` is the engine and knows nothing about the window; the Swift package builds it with the `spolo` command-line tool. `Sources/SpoloApp` is the SwiftUI app. The Xcode project (`project.yml`) compiles both into one sandboxed app.

## Reading files (`Media.swift`)

`MediaProbe.probe` turns a file into a `MediaInfo`: photo, video, unsupported or missing, with its upright size, length, frame rate, codecs, HDR flag and the date it was taken (EXIF `DateTimeOriginal`, the QuickTime creation date, or the file's creation date). Photos are read with ImageIO, videos with AVFoundation. Files AVFoundation can't decode (MKV, WebM, AVI…) become `unsupported` and stay in the filmstrip, greyed out. A `Segment` is a file, its `MediaInfo` and the user's `ClipEdits`.

## The timeline (`Timeline.swift`)

`Timeline.build` lays the segments end to end in one `AVMutableComposition` with one video track and one sound track:

- **Videos**: the trimmed range of the video track is inserted, and `scaleTimeRange` changes its speed. Sound is inserted for the same stretch; export and preview use the spectral time-pitch algorithm, so sped-up clips keep their pitch.
- **Photos**: an empty stretch at the end of a composition doesn't count towards its length, so each photo occupies a stretch of a one-second black "carrier" movie (`Carrier.swift`, written once per launch into the sandbox's temporary folder), stretched to the photo's duration. The compositor paints the photo over it.
- **Silence**: muted clips, clips without sound and photos get the carrier's silent sound track, so the merged sound runs the full length.
- The export is cut to the length of the picture, since time-stretched sound can run a few frames over.

Every segment gets a `CompositorInstruction`, and the video composition uses the custom `Compositor` at the chosen frame rate (the fastest clip's, as a standard rate up to 60 fps) and in Rec. 709.

The frame size is the chosen shape (or, for Auto, the first clip's), as large as the largest clip but within 4K; photos alone don't push it past 1080p.

## The compositor (`Compositor.swift`)

An `AVVideoCompositing` that draws each frame with Core Image: the source frame turned upright by the track transform, turned by the user's quarter turns, scaled to fit (with black bars) or fill (cropped), and centred on black. Large reductions use Lanczos scaling.

- AVFoundation hands over video frames one at a time; nothing is loaded whole.
- Photos are decoded with ImageIO at the size they are shown, never larger, and the finished frame is reused for as long as the photo is on screen.
- The compositor declares that it doesn't support HDR or wide-colour sources, so AVFoundation tone-maps HDR (HLG and PQ) to standard range before frames arrive. Mixed HDR and SDR clips therefore come out consistently in SDR Rec. 709.
- Variable frame rate sources are sampled at the output frame rate.

## Export (`Exporter.swift`)

`AVAssetExportSession` reads, composes and encodes as it goes.

| Quality | Size | Encoding |
|---|---|---|
| Original | as computed above | joined without re-encoding when possible; otherwise H.264, or HEVC when a source is HEVC or HDR |
| High | up to 1080p | H.264 |
| Smaller File | up to 1080p | HEVC at a lower bit rate |

Clips are joined without re-encoding (`AVAssetExportPresetPassthrough`) when all of them are videos with the same codec, stored size, transform, frame rate and HDR-ness, none is sped up or turned, the sound formats match, and the frame is their own shape. MOV takes any codec; MP4 is checked with `AVAssetExportSession.compatibility`.

## The app

- `Project` holds the clips, their edits and the frame shape. Every change goes through `change(_:)`, which registers an undo step with the window's undo manager; slider drags and filmstrip drags register one step when they end. What each file turned out to be (`info`) and the thumbnails are kept outside the undo history.
- The session is saved to `Session.json` in the app's container half a second after each change, with an app-scope security-scoped bookmark for each file, and restored on launch.
- Items from Photos come from the system picker (no library permission) and are copied into `Imports/` in the container; imports no clip uses are deleted at the next launch.
- The preview is an `AVPlayerView` playing the same composition at up to 1280 pixels, rebuilt 0.2 s after the last change.
- The toolbar (`Toolbar.swift`) uses flat icon buttons; on macOS 26 each item's shared glass background is hidden with `sharedBackgroundVisibility(.hidden)`, so there are no capsules.
- Settings (`SettingsView.swift`) are plain `UserDefaults` keys in `Preference`, shared with the export sheet.
- Xcode registers every app it builds with Launch Services, so the scripts build into `*.noindex` folders and leave only `build/Spolo.app` behind.

## Testing

`scripts/test-merge.sh` makes test media with ffmpeg and `scripts/test-photos.swift`: H.264 and HEVC video, a portrait video stored sideways with a rotation transform, HLG HDR in 10-bit HEVC, variable frame rate, sound at 48, 44.1 and 22.05 kHz and none at all, a JPEG, a HEIC with EXIF rotation, a PNG, and an MKV. Each picture is a solid colour with a white block in its top-left corner. The script merges them with `spolo` in four ways (mixed Auto/fit, 9:16 fill with edits, photos only, and a join without re-encoding) and checks the frame size, length and sound track, and, in the middle of every clip, its colour, that the white block is top-left (so it is upright), and the black bars. It also checks that a clip at 2× keeps its pitch.
