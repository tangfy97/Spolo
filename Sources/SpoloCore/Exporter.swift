import AVFoundation

public enum ExportFormat: String, Codable, CaseIterable, Sendable {
    case mp4, mov

    public var fileType: AVFileType { self == .mp4 ? .mp4 : .mov }
    public var fileExtension: String { rawValue }
}

public enum ExportQuality: String, Codable, CaseIterable, Sendable {
    /// Full size at the highest quality, and joined without re-encoding when the clips allow it.
    case original
    /// Up to 1080p, H.264, for sharing anywhere.
    case high
    /// Up to 1080p, HEVC at a lower bit rate.
    case smaller

    var maxLongEdge: CGFloat? { self == .original ? nil : 1920 }
}

/// Writes the merged video with `AVAssetExportSession`, which reads, composes and encodes frame by frame.
public final class Exporter: @unchecked Sendable {
    public let segments: [Segment]
    public let layout: Layout
    public let format: ExportFormat
    public let quality: ExportQuality
    private var session: AVAssetExportSession?
    private var cancelled = false
    private let lock = NSLock()

    public init(segments: [Segment], layout: Layout, format: ExportFormat, quality: ExportQuality) {
        self.segments = segments.filter(\.info.isUsable)
        self.layout = layout
        self.format = format
        self.quality = quality
    }

    /// Whether this export will join the clips without re-encoding.
    public var isPassthrough: Bool {
        quality == .original && Timeline.canJoinWithoutReencoding(segments, layout: layout)
    }

    public var duration: Double { segments.reduce(0) { $0 + $1.duration } }

    /// Exports to `url`, replacing any file there. `progress` is called on an arbitrary thread with 0...1.
    public func export(to url: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        // Joining as-is also needs the container to take the codecs (ProRes, for one, can't go into MP4).
        var joined: Timeline?
        if isPassthrough {
            let timeline = try await Timeline.build(segments, layout: layout, passthrough: true)
            if await AVAssetExportSession.compatibility(ofExportPreset: AVAssetExportPresetPassthrough,
                                                       with: timeline.composition, outputFileType: format.fileType) {
                joined = timeline
            }
        }
        let timeline: Timeline
        if let joined {
            timeline = joined
        } else {
            timeline = try await Timeline.build(segments, layout: layout, maxLongEdge: quality.maxLongEdge)
        }
        let preset = joined != nil ? AVAssetExportPresetPassthrough : preset(for: timeline)
        guard let session = AVAssetExportSession(asset: timeline.composition, presetName: preset) else {
            throw SpoloError.exportFailed(String(localized: "This combination of clips can’t be exported."))
        }
        session.outputURL = url
        session.outputFileType = format.fileType
        session.videoComposition = timeline.videoComposition
        session.timeRange = CMTimeRange(start: .zero, duration: timeline.duration)
        session.audioTimePitchAlgorithm = .spectral
        session.shouldOptimizeForNetworkUse = true
        try? FileManager.default.removeItem(at: url)

        let stop = lock.withLock { () -> Bool in
            self.session = session
            return cancelled
        }
        if stop { throw CancellationError() }

        let timer = Task {
            while !Task.isCancelled {
                progress(Double(session.progress))
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { done.resume() }
        }
        timer.cancel()
        switch session.status {
        case .completed:
            progress(1)
        case .cancelled:
            try? FileManager.default.removeItem(at: url)
            throw CancellationError()
        default:
            try? FileManager.default.removeItem(at: url)
            throw SpoloError.exportFailed(session.error?.localizedDescription ?? String(localized: "The export failed."))
        }
    }

    public func cancel() {
        let session = lock.withLock { () -> AVAssetExportSession? in
            cancelled = true
            return self.session
        }
        session?.cancelExport()
    }

    private func preset(for timeline: Timeline) -> String {
        switch quality {
        case .original:
            // Keep HEVC sources in HEVC; everything else in H.264, which also plays everywhere.
            let hevc = segments.contains { $0.info.codec.hasPrefix("hvc") || $0.info.codec.hasPrefix("hev") || $0.info.isHDR }
            return hevc ? AVAssetExportPresetHEVCHighestQuality : AVAssetExportPresetHighestQuality
        case .high:
            return AVAssetExportPresetHighestQuality
        case .smaller:
            return AVAssetExportPresetHEVC1920x1080
        }
    }
}
