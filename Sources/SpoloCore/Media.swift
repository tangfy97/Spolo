import AVFoundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// What a file turned out to be once it was read.
public enum MediaKind: String, Codable, Sendable {
    case video, photo
    /// A movie or image macOS can't read, such as MKV or WebM. It stays visible but is left out of the merge.
    case unsupported
    /// The file is gone or Spolo may no longer read it.
    case missing
}

/// What Spolo needs to know about a file to place it in the merged video.
public struct MediaInfo: Codable, Equatable, Sendable {
    public var kind: MediaKind
    /// Upright size in pixels, after the file's own rotation (EXIF orientation or the track transform).
    public var size: CGSize = .zero
    /// Length of the video track, in seconds. Zero for photos.
    public var duration: Double = 0
    public var dateTaken: Date?
    public var frameRate: Float = 0
    public var hasAudio = false
    public var isHDR = false
    /// Video codec (such as "avc1" or "hvc1") and audio format, used to decide whether clips can be joined without re-encoding.
    public var codec = ""
    public var audioFormat = ""
    /// The video track's stored size and transform, also for joining without re-encoding.
    public var naturalSize: CGSize = .zero
    public var transform: CGAffineTransform = .identity

    public init(kind: MediaKind) { self.kind = kind }

    public var isUsable: Bool { kind == .video || kind == .photo }
}

/// How the user has changed one clip.
public struct ClipEdits: Codable, Equatable, Sendable {
    /// Seconds cut from the start and the end of a video.
    public var trimStart: Double = 0
    public var trimEnd: Double = 0
    public var speed: Double = 1
    public var muted = false
    /// Quarter turns clockwise, 0...3.
    public var quarterTurns = 0
    /// How long a photo stays on screen, in seconds.
    public var photoDuration: Double = 3

    public init() {}

    public static let speeds: [Double] = [0.25, 0.5, 1, 1.5, 2, 4]
    public static let shortestClip = 0.1
}

/// One clip in the merge: a file, what it is, and how it is edited.
public struct Segment: Equatable, Sendable {
    public var url: URL
    public var info: MediaInfo
    public var edits: ClipEdits

    public init(url: URL, info: MediaInfo, edits: ClipEdits) {
        self.url = url
        self.info = info
        self.edits = edits
    }

    /// The part of the source video that is kept, in seconds from its start.
    public var trimmedRange: ClosedRange<Double> {
        let length = info.duration
        let start = min(max(0, edits.trimStart), max(0, length - ClipEdits.shortestClip))
        let end = min(length, max(start + ClipEdits.shortestClip, length - max(0, edits.trimEnd)))
        return start...max(start, end)
    }

    /// Seconds this clip lasts in the merged video.
    public var duration: Double {
        switch info.kind {
        case .video: (trimmedRange.upperBound - trimmedRange.lowerBound) / edits.speed
        case .photo: max(ClipEdits.shortestClip, edits.photoDuration)
        case .unsupported, .missing: 0
        }
    }

    /// Upright size after the user's rotation.
    public var displaySize: CGSize {
        edits.quarterTurns % 2 == 0 ? info.size : CGSize(width: info.size.height, height: info.size.width)
    }
}

public enum MediaProbe {
    /// Formats people try to merge that AVFoundation can't read. They are shown, greyed out, rather than dropped.
    static let knownUnsupported: Set<String> = ["mkv", "webm", "avi", "wmv", "flv", "ogv", "rm", "rmvb", "vob", "3gp", "mts", "m2ts", "ts", "mpg", "mpeg", "divx", "asf"]

    /// Whether a file belongs in the filmstrip at all: images and movies, including ones Spolo can't read.
    public static func isMedia(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if knownUnsupported.contains(ext) { return true }
        guard let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .image) || type.conforms(to: .movie)
    }

    public static func probe(_ url: URL) async -> MediaInfo {
        guard FileManager.default.isReadableFile(atPath: url.path) else { return MediaInfo(kind: .missing) }
        let type = UTType(filenameExtension: url.pathExtension.lowercased())
        if type?.conforms(to: .image) == true {
            return probePhoto(url) ?? MediaInfo(kind: .unsupported)
        }
        if knownUnsupported.contains(url.pathExtension.lowercased()) { return MediaInfo(kind: .unsupported) }
        return await probeVideo(url) ?? MediaInfo(kind: .unsupported)
    }

    static func probePhoto(_ url: URL) -> MediaInfo? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Double,
              let height = props[kCGImagePropertyPixelHeight] as? Double, width > 0, height > 0
        else { return nil }
        var info = MediaInfo(kind: .photo)
        let orientation = props[kCGImagePropertyOrientation] as? UInt32 ?? 1
        info.size = orientation >= 5 ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        if let text = exif?[kCGImagePropertyExifDateTimeOriginal] as? String ?? tiff?[kCGImagePropertyTIFFDateTime] as? String {
            info.dateTaken = exifDate(text, offset: exif?[kCGImagePropertyExifOffsetTimeOriginal] as? String)
        }
        info.dateTaken = info.dateTaken ?? fileDate(url)
        return info
    }

    static func probeVideo(_ url: URL) async -> MediaInfo? {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let (natural, transform, fps, range, formats, characteristics) = try? await track.load(
                .naturalSize, .preferredTransform, .nominalFrameRate, .timeRange, .formatDescriptions, .mediaCharacteristics),
              let decodable = try? await track.load(.isDecodable), decodable,
              natural.width > 0, natural.height > 0, range.duration.seconds > 0
        else { return nil }
        var info = MediaInfo(kind: .video)
        let upright = CGRect(origin: .zero, size: natural).applying(transform)
        info.size = CGSize(width: abs(upright.width).rounded(), height: abs(upright.height).rounded())
        info.duration = range.duration.seconds
        info.frameRate = fps
        info.naturalSize = natural
        info.transform = transform
        info.isHDR = characteristics.contains(.containsHDRVideo)
        if let format = formats.first { info.codec = fourCC(CMFormatDescriptionGetMediaSubType(format)) }
        if let audio = try? await asset.loadTracks(withMediaType: .audio).first,
           let audioFormats = try? await audio.load(.formatDescriptions), let format = audioFormats.first {
            info.hasAudio = true
            if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee {
                info.audioFormat = "\(fourCC(asbd.mFormatID)) \(Int(asbd.mSampleRate)) \(asbd.mChannelsPerFrame)"
            }
        }
        if let item = try? await asset.load(.creationDate), let date = try? await item.load(.dateValue) {
            info.dateTaken = date
        }
        info.dateTaken = info.dateTaken ?? fileDate(url)
        return info
    }

    static func exifDate(_ text: String, offset: String?) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let offset {
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"
            if let date = formatter.date(from: text + offset) { return date }
        }
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: text)
    }

    static func fileDate(_ url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return values?.creationDate ?? values?.contentModificationDate
    }

    static func fourCC(_ code: FourCharCode) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> $0) & 0xff) }
        return String(bytes: bytes, encoding: .macOSRoman)?.trimmingCharacters(in: .whitespaces) ?? "\(code)"
    }
}

public enum Thumbnail {
    /// A small upright picture of the clip: a photo, or the first frame of a video.
    public static func make(_ url: URL, kind: MediaKind, maxPixels: Int = 320) async -> CGImage? {
        switch kind {
        case .photo:
            return Photo.load(url, maxPixels: maxPixels)
        case .video:
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxPixels, height: maxPixels)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)
            return try? await generator.image(at: CMTime(seconds: 0.1, preferredTimescale: 600)).image
        case .unsupported, .missing:
            return nil
        }
    }

    /// Turns an image by quarter turns clockwise.
    public static func rotate(_ image: CGImage, quarterTurns: Int) -> CGImage {
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns != 0 else { return image }
        let swap = turns % 2 == 1
        let width = swap ? image.height : image.width, height = swap ? image.width : image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        context.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        context.rotate(by: -CGFloat(turns) * .pi / 2)
        context.draw(image, in: CGRect(x: -CGFloat(image.width) / 2, y: -CGFloat(image.height) / 2,
                                       width: CGFloat(image.width), height: CGFloat(image.height)))
        return context.makeImage() ?? image
    }
}

enum Photo {
    /// Decodes a photo upright, no larger than `maxPixels` on its long side, without reading more than that into memory.
    static func load(_ url: URL, maxPixels: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixels),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
