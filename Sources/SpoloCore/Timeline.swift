import AVFoundation

/// The shape of the merged video.
public enum FrameShape: String, Codable, CaseIterable, Sendable {
    /// The shape of the first clip.
    case auto
    case wide, tall, square, portrait

    var ratio: CGSize? {
        switch self {
        case .auto: nil
        case .wide: CGSize(width: 16, height: 9)
        case .tall: CGSize(width: 9, height: 16)
        case .square: CGSize(width: 1, height: 1)
        case .portrait: CGSize(width: 4, height: 5)
        }
    }

    /// "16:9" and so on; Auto is named by the app, in the user's language.
    public var ratioName: String? {
        ratio.map { "\(Int($0.width)):\(Int($0.height))" }
    }
}

/// Whether a clip that doesn't match the frame's shape gets black bars or is cropped.
public enum FillMode: String, Codable, CaseIterable, Sendable {
    case fit, fill
}

public struct Layout: Codable, Equatable, Sendable {
    public var shape: FrameShape = .auto
    public var fill: FillMode = .fit
    public init(shape: FrameShape = .auto, fill: FillMode = .fit) {
        self.shape = shape
        self.fill = fill
    }
}

public enum SpoloError: LocalizedError {
    case nothingToMerge
    case unreadable(URL)
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .nothingToMerge: String(localized: "There is nothing to merge.")
        case .unreadable(let url): String(localized: "“\(url.lastPathComponent)” can’t be read.")
        case .exportFailed(let reason): reason
        }
    }
}

/// The clips laid end to end: an `AVComposition` with the Core Image compositor that draws every frame,
/// or, when the clips allow it, a plain composition that is joined without re-encoding.
public struct Timeline: @unchecked Sendable {
    public let composition: AVComposition
    /// Nil when the clips are joined as they are.
    public let videoComposition: AVVideoComposition?
    public let renderSize: CGSize
    /// The length of the picture; sound that runs past it after time-stretching is cut off.
    public let duration: CMTime
    /// Where each usable segment starts in the merged video, in seconds.
    public let starts: [Double]
    public var isPassthrough: Bool { videoComposition == nil }

    static let maxLongEdge: CGFloat = 3840
    static let maxShortEdge: CGFloat = 2160
    /// Photos alone don't make the video larger than 1080p.
    static let photoLongEdge: CGFloat = 1920

    /// The size of the merged video: the frame's shape, as large as the largest clip, within 4K.
    public static func renderSize(_ segments: [Segment], layout: Layout, maxLongEdge limit: CGFloat? = nil) -> CGSize {
        let usable = segments.filter(\.info.isUsable)
        guard let first = usable.first else { return CGSize(width: 1920, height: 1080) }
        let aspect = layout.shape.ratio ?? first.displaySize
        let longest = usable.map { segment in
            let long = max(segment.displaySize.width, segment.displaySize.height)
            return segment.info.kind == .photo ? min(long, photoLongEdge) : long
        }.max() ?? 1920
        let long = max(320, min(longest, maxLongEdge, limit ?? .infinity))
        var size = aspect.width >= aspect.height
            ? CGSize(width: long, height: long * aspect.height / aspect.width)
            : CGSize(width: long * aspect.width / aspect.height, height: long)
        let short = min(size.width, size.height)
        if short > maxShortEdge {
            size = CGSize(width: size.width * maxShortEdge / short, height: size.height * maxShortEdge / short)
        }
        return CGSize(width: max(2, (size.width / 2).rounded() * 2), height: max(2, (size.height / 2).rounded() * 2))
    }

    /// Whether the clips can be joined as they are: all videos with the same encoding, size and frame rate,
    /// none sped up or turned, in a frame of their own shape.
    public static func canJoinWithoutReencoding(_ segments: [Segment], layout: Layout) -> Bool {
        let usable = segments.filter(\.info.isUsable)
        guard let first = usable.first?.info else { return false }
        let audio = usable.filter { $0.info.hasAudio && !$0.edits.muted }.map(\.info.audioFormat)
        return usable.allSatisfy { segment in
            let info = segment.info
            return info.kind == .video && segment.edits.speed == 1 && segment.edits.quarterTurns % 4 == 0
                && info.codec == first.codec && info.naturalSize == first.naturalSize && info.transform == first.transform
                && info.isHDR == first.isHDR && abs(info.frameRate - first.frameRate) < 0.5
        } && Set(audio).count <= 1 && renderSize(usable, layout: layout) == first.size
    }

    /// The output frame rate: the fastest clip's, as a standard rate up to 60 fps.
    static func frameDuration(_ segments: [Segment]) -> CMTime {
        let fastest = segments.filter { $0.info.kind == .video }.map(\.info.frameRate).max() ?? 30
        let rates: [(Float, CMTime)] = [
            (23.976, CMTime(value: 1001, timescale: 24000)), (24, CMTime(value: 1, timescale: 24)),
            (25, CMTime(value: 1, timescale: 25)), (29.97, CMTime(value: 1001, timescale: 30000)),
            (30, CMTime(value: 1, timescale: 30)), (50, CMTime(value: 1, timescale: 50)),
            (59.94, CMTime(value: 1001, timescale: 60000)), (60, CMTime(value: 1, timescale: 60)),
        ]
        let target = min(max(fastest, 24), 60)
        return rates.min { abs($0.0 - target) < abs($1.0 - target) }!.1
    }

    /// Fills a stretch of a track with the carrier, sped up or slowed down to fit.
    private static func stretch(_ source: AVAssetTrack, into track: AVMutableCompositionTrack, _ range: CMTimeRange) throws {
        guard range.duration > .zero else { return }
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: Carrier.duration), of: source, at: range.start)
        track.scaleTimeRange(CMTimeRange(start: range.start, duration: Carrier.duration), toDuration: range.duration)
    }

    /// Lays the clips end to end. Unsupported and missing files are skipped.
    /// - Parameters:
    ///   - maxLongEdge: a smaller frame, for the preview or a smaller export.
    ///   - passthrough: join without re-encoding; only when `canJoinWithoutReencoding` allows it.
    public static func build(_ segments: [Segment], layout: Layout, maxLongEdge: CGFloat? = nil,
                             passthrough: Bool = false) async throws -> Timeline {
        let usable = segments.filter(\.info.isUsable)
        guard !usable.isEmpty else { throw SpoloError.nothingToMerge }
        let renderSize = renderSize(usable, layout: layout, maxLongEdge: maxLongEdge)

        let composition = AVMutableComposition()
        guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw SpoloError.exportFailed(String(localized: "Couldn’t create the composition.")) }

        // Joined without re-encoding there are no photos, and gaps in the sound stay empty rather than mixing formats.
        let carrier = passthrough ? nil : try await Carrier.tracks()
        func silence(_ track: AVMutableCompositionTrack, _ range: CMTimeRange) throws {
            if let carrier { try stretch(carrier.audio, into: track, range) }
        }

        var instructions: [CompositorInstruction] = []
        var starts: [Double] = []
        var cursor = CMTime.zero
        var hasAudio = false
        for segment in usable {
            starts.append(cursor.seconds)
            let length: CMTime
            switch segment.info.kind {
            case .video:
                let asset = AVURLAsset(url: segment.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
                guard let source = try await asset.loadTracks(withMediaType: .video).first else {
                    throw SpoloError.unreadable(segment.url)
                }
                let sourceRange = try await source.load(.timeRange)
                let trimmed = segment.trimmedRange
                let range = CMTimeRange(
                    start: sourceRange.start + CMTime(seconds: trimmed.lowerBound, preferredTimescale: 6000),
                    end: min(sourceRange.end, sourceRange.start + CMTime(seconds: trimmed.upperBound, preferredTimescale: 6000)))
                try video.insertTimeRange(range, of: source, at: cursor)

                // Audio fills exactly the same stretch: the clip's sound where it has some, silence elsewhere.
                var audioEnd = cursor
                if !segment.edits.muted, let sound = try await asset.loadTracks(withMediaType: .audio).first {
                    let soundRange = try await sound.load(.timeRange).intersection(range)
                    if soundRange.duration > .zero {
                        let offset = soundRange.start - range.start
                        try silence(audio, CMTimeRange(start: cursor, duration: offset))
                        try audio.insertTimeRange(soundRange, of: sound, at: cursor + offset)
                        audioEnd = cursor + offset + soundRange.duration
                        hasAudio = true
                    }
                }
                try silence(audio, CMTimeRange(start: audioEnd, end: cursor + range.duration))

                if segment.edits.speed != 1 {
                    let scaled = CMTimeMultiplyByFloat64(range.duration, multiplier: 1 / segment.edits.speed)
                    video.scaleTimeRange(CMTimeRange(start: cursor, duration: range.duration), toDuration: scaled)
                    audio.scaleTimeRange(CMTimeRange(start: cursor, duration: range.duration), toDuration: scaled)
                    length = scaled
                } else {
                    length = range.duration
                }
                let transform = try await source.load(.preferredTransform)
                instructions.append(CompositorInstruction(
                    timeRange: CMTimeRange(start: cursor, duration: length), trackID: video.trackID,
                    source: .video(orientation: Orientation(transform)), segment: segment, layout: layout))
            case .photo:
                // Photos occupy a stretch of black carrier video that the compositor paints the still over.
                guard let carrier else { throw SpoloError.nothingToMerge }
                length = CMTime(seconds: segment.duration, preferredTimescale: 6000)
                try stretch(carrier.video, into: video, CMTimeRange(start: cursor, duration: length))
                try silence(audio, CMTimeRange(start: cursor, duration: length))
                instructions.append(CompositorInstruction(
                    timeRange: CMTimeRange(start: cursor, duration: length), trackID: nil,
                    source: .photo(segment.url, pixelSize: segment.info.size), segment: segment, layout: layout))
            case .unsupported, .missing:
                continue
            }
            cursor = cursor + length
        }
        if !hasAudio { composition.removeTrack(audio) }

        guard !passthrough else {
            return Timeline(composition: composition, videoComposition: nil, renderSize: renderSize, duration: cursor, starts: starts)
        }
        // The last instruction must reach exactly to the end of the composition.
        if let last = instructions.popLast() {
            instructions.append(last.with(end: max(composition.duration, cursor)))
        }
        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = Compositor.self
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = frameDuration(usable)
        videoComposition.instructions = instructions
        // Everything, HDR included, comes out as standard-range Rec. 709.
        videoComposition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
        videoComposition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
        videoComposition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
        return Timeline(composition: composition, videoComposition: videoComposition, renderSize: renderSize, duration: cursor, starts: starts)
    }
}
