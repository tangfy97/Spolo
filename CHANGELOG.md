# Changelog

All notable changes to Spolo are listed here. Versions follow [Semantic Versioning](https://semver.org).

## [1.0.1] - 2026-10-22

A cleaner window, with undo and a way back always in reach.

- A quieter toolbar without capsules: Undo and Redo beside the title, then Add, Sort, the frame (for example “16:9 · Fill”) and Export as labelled buttons, and the inspector toggle.
- Start Over (⌘N, or Remove All in the filmstrip's menu) goes back to the empty window; Undo brings the clips back. Esc clears the selection.
- No Settings window: the export sheet remembers the last format and quality, and everything else is in the window.
- The empty window's Add from Photos… button is no longer cut off.
- Files opened with Spolo while it starts now appear in the window straight away.
- With no clip selected, the inspector shows the merged video: shape, scaling, clip count, length and size.
- A + tile at the end of the filmstrip; Delete removes and ⌘A selects all clips once the filmstrip is clicked.
- Development builds no longer leave extra copies of Spolo for Spotlight, Launchpad and Open With to find.

## [1.0.0] - 2026-10-22

The first release: a free, complete merger, for the Mac App Store and as a download from tang-spark.no.

- Merge photos and videos into one MP4 or MOV, with no watermark and no limit on clips or length.
- Add by dragging, with Add… (⌘O), from the Dock or Open With, or from Photos through the system picker.
- Reorder by dragging, or sort by date taken, file name or the order added.
- Per clip: trim, speed (0.25× to 4×, pitch kept), mute and rotate for videos; duration and rotation for photos. Several clips can be changed at once.
- Frame shape Auto, 16:9, 9:16, 1:1 or 4:5, fitted with black bars or filled and cropped.
- Export in original quality, high (1080p H.264) or a smaller file (1080p HEVC), with progress, Cancel, Show in Finder and Share. Matching clips are joined without re-encoding.
- Mixed HDR and SDR, clips without sound, variable frame rates and portrait phone videos.
- Unsupported formats such as MKV and WebM stay in the filmstrip, greyed out.
- The last session is restored on launch, and every change can be undone.
- English, English (UK), Simplified Chinese and Traditional Chinese.
- Runs in the App Sandbox with no network access.
