import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Describes one clip's stretch of the timeline to the compositor.
final class CompositorInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    enum Source {
        case video(orientation: CGImagePropertyOrientation)
        case photo(URL, pixelSize: CGSize)
    }

    let timeRange: CMTimeRange
    let enablePostProcessing = false
    /// True for photos, so that a photo is drawn at every frame rather than as one long frame.
    let containsTweening: Bool
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid

    let trackID: CMPersistentTrackID?
    let source: Source
    let quarterTurns: Int
    let fill: FillMode

    init(timeRange: CMTimeRange, trackID: CMPersistentTrackID?, source: Source, quarterTurns: Int, fill: FillMode) {
        self.timeRange = timeRange
        self.trackID = trackID
        self.requiredSourceTrackIDs = trackID.map { [NSNumber(value: $0)] } ?? []
        if case .photo = source { containsTweening = true } else { containsTweening = false }
        self.source = source
        self.quarterTurns = ((quarterTurns % 4) + 4) % 4
        self.fill = fill
    }

    convenience init(timeRange: CMTimeRange, trackID: CMPersistentTrackID?, source: Source, segment: Segment, layout: Layout) {
        self.init(timeRange: timeRange, trackID: trackID, source: source, quarterTurns: segment.edits.quarterTurns, fill: layout.fill)
    }

    func with(end: CMTime) -> CompositorInstruction {
        CompositorInstruction(timeRange: CMTimeRange(start: timeRange.start, end: end), trackID: trackID,
                              source: source, quarterTurns: quarterTurns, fill: fill)
    }
}

/// The rotation a video track's transform describes, as an image orientation.
func Orientation(_ t: CGAffineTransform) -> CGImagePropertyOrientation {
    switch (t.a.rounded(), t.b.rounded(), t.c.rounded(), t.d.rounded()) {
    case (0, 1, -1, 0): .right
    case (-1, 0, 0, -1): .down
    case (0, -1, 1, 0): .left
    case (-1, 0, 0, 1): .upMirrored
    case (1, 0, 0, -1): .downMirrored
    case (0, 1, 1, 0): .leftMirrored
    case (0, -1, -1, 0): .rightMirrored
    default: .up
    }
}

/// Draws every frame of the merged video with Core Image: the clip's frame or photo, upright and turned,
/// scaled to fit or fill the frame, on black. Video frames arrive one at a time; photos are decoded once,
/// at the size they are shown, and the finished frame is reused for as long as the photo is on screen.
final class Compositor: NSObject, AVVideoCompositing {
    private static let pixelFormat: [String: any Sendable] = [
        kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA],
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: String](),
    ]
    let sourcePixelBufferAttributes: [String: any Sendable]? = Compositor.pixelFormat
    let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = Compositor.pixelFormat
    // AVFoundation converts HDR and wide-colour frames to standard range before they get here.
    let supportsWideColorSourceFrames = false
    let supportsHDRSourceFrames = false

    private let queue = DispatchQueue(label: "Spolo.Compositor", qos: .userInitiated)
    private let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
        .cacheIntermediates: false,
    ])
    private let outputColorSpace = CGColorSpace(name: CGColorSpace.itur_709)!
    private let lock = NSLock()
    private var generation = 0
    /// The last photo's finished frame (only touched on `queue`).
    private var still: (instruction: ObjectIdentifier, size: CGSize, frame: CVPixelBuffer)?

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        queue.async { self.still = nil }
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        let started = lock.withLock { generation }
        queue.async {
            guard started == self.lock.withLock({ self.generation }) else {
                request.finishCancelledRequest()
                return
            }
            autoreleasepool { self.render(request) }
        }
    }

    func cancelAllPendingVideoCompositionRequests() {
        lock.withLock { generation += 1 }
    }

    private func render(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? CompositorInstruction else {
            request.finish(with: SpoloError.exportFailed("Unexpected instruction."))
            return
        }
        let size = request.renderContext.size
        if case .photo = instruction.source, let still, still.instruction == ObjectIdentifier(instruction), still.size == size {
            request.finish(withComposedVideoFrame: still.frame)
            return
        }
        guard let output = request.renderContext.newPixelBuffer() else {
            request.finish(with: SpoloError.exportFailed("Out of memory."))
            return
        }
        let bounds = CGRect(origin: .zero, size: size)
        let black = CIImage(color: .black).cropped(to: bounds)
        var image = black
        switch instruction.source {
        case .video(let orientation):
            if let trackID = instruction.trackID, let frame = request.sourceFrame(byTrackID: trackID) {
                image = place(CIImage(cvPixelBuffer: frame).oriented(orientation), instruction, in: size).composited(over: black)
            }
        case .photo(let url, let pixelSize):
            if let photo = loadPhoto(url, pixelSize: pixelSize, instruction, in: size) {
                image = place(photo, instruction, in: size).composited(over: black)
            }
        }
        CVBufferSetAttachment(output, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(output, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(output, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
        context.render(image.cropped(to: bounds), to: output, bounds: bounds, colorSpace: outputColorSpace)
        if case .photo = instruction.source {
            still = (ObjectIdentifier(instruction), size, output)
        }
        request.finish(withComposedVideoFrame: output)
    }

    /// Turns the image, then scales it to fit or fill the frame and centres it.
    private func place(_ source: CIImage, _ instruction: CompositorInstruction, in size: CGSize) -> CIImage {
        var image = source
        for _ in 0..<instruction.quarterTurns { image = image.oriented(.right) }
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        let width = image.extent.width, height = image.extent.height
        guard width > 0, height > 0 else { return image }
        let scale = instruction.fill == .fill
            ? max(size.width / width, size.height / height)
            : min(size.width / width, size.height / height)
        if scale < 0.75 {
            let filter = CIFilter.lanczosScaleTransform()
            filter.inputImage = image.clampedToExtent().cropped(to: image.extent)
            filter.scale = Float(scale)
            filter.aspectRatio = 1
            image = filter.outputImage ?? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        } else if scale != 1 {
            image = image.samplingLinear().transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        let x = ((size.width - image.extent.width) / 2 - image.extent.minX).rounded()
        let y = ((size.height - image.extent.height) / 2 - image.extent.minY).rounded()
        return image.transformed(by: CGAffineTransform(translationX: x, y: y))
    }

    /// Decodes a photo no larger than it will be shown.
    private func loadPhoto(_ url: URL, pixelSize: CGSize, _ instruction: CompositorInstruction, in size: CGSize) -> CIImage? {
        let turned = instruction.quarterTurns % 2 == 1
        let width = turned ? pixelSize.height : pixelSize.width, height = turned ? pixelSize.width : pixelSize.height
        guard width > 0, height > 0 else { return nil }
        let scale = instruction.fill == .fill
            ? max(size.width / width, size.height / height)
            : min(size.width / width, size.height / height)
        let longEdge = Int((max(width, height) * min(1, scale)).rounded(.up))
        return Photo.load(url, maxPixels: longEdge).map { CIImage(cgImage: $0) }
    }
}
