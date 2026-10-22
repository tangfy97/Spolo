import AVKit
import SwiftUI

/// Plays the merged video as it will be exported, at preview size.
@MainActor @Observable
final class Preview {
    let player = AVPlayer()
    private var starts: [UUID: Double] = [:]

    struct Key: Equatable {
        var ids: [UUID]
        var segments: [Segment]
        var layout: Layout
    }

    /// Rebuilds the composition and keeps the playhead where it was.
    func update(_ key: Key) async {
        guard !key.segments.isEmpty else {
            player.replaceCurrentItem(with: nil)
            starts = [:]
            return
        }
        guard let timeline = try? await Timeline.build(key.segments, layout: key.layout, maxLongEdge: 1280),
              !Task.isCancelled else { return }
        let item = AVPlayerItem(asset: timeline.composition)
        item.videoComposition = timeline.videoComposition
        item.audioTimePitchAlgorithm = .spectral
        item.forwardPlaybackEndTime = timeline.duration
        let time = player.currentTime(), playing = player.rate != 0
        player.replaceCurrentItem(with: item)
        if time.isValid, time > .zero {
            await player.seek(to: min(time, timeline.duration), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        if playing { player.play() }
        starts = Dictionary(uniqueKeysWithValues: zip(key.ids, timeline.starts))
    }

    /// Moves the playhead to the start of a clip.
    func show(_ id: UUID) {
        guard let start = starts[id] else { return }
        player.seek(to: CMTime(seconds: start + 0.01, preferredTimescale: 6000), toleranceBefore: .zero, toleranceAfter: .zero)
    }
}

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = true
        view.allowsPictureInPicturePlayback = false
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
    }
}

enum TimeText {
    /// 0:04, 12:30, 1:02:03
    static func short(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600, m = total / 60 % 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// 0:04.5, for trimming.
    static func precise(_ seconds: Double) -> String {
        let tenths = Int((max(0, seconds) * 10).rounded())
        return String(format: "%d:%02d.%d", tenths / 600, tenths / 10 % 60, tenths % 10)
    }

    static func seconds(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
