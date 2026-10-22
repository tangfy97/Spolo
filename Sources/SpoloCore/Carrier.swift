import AVFoundation

/// A one-second movie of black frames and silence, stretched over every photo and every silent stretch.
/// An empty stretch at the end of a composition doesn't count towards its length, so a photo needs
/// something to occupy its place in the timeline; the compositor draws the photo over it.
enum Carrier {
    static let duration = CMTime(value: 1, timescale: 1)

    // The asset is kept for good: a track stops working once its asset is gone.
    private static let task = Task { AVURLAsset(url: try await write()) }

    static func tracks() async throws -> (video: AVAssetTrack, audio: AVAssetTrack) {
        let asset = try await task.value
        guard let video = try await asset.loadTracks(withMediaType: .video).first,
              let audio = try await asset.loadTracks(withMediaType: .audio).first
        else { throw SpoloError.exportFailed(String(localized: "Couldn’t prepare photos.")) }
        return (video, audio)
    }

    private static func write() async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Spolo-carrier-\(ProcessInfo.processInfo.processIdentifier).mov")
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64,
        ])
        let sampleRate = 48000
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        writer.add(video)
        writer.add(audio)
        guard writer.startWriting() else { throw writer.error ?? SpoloError.exportFailed(String(localized: "Couldn’t prepare photos.")) }
        writer.startSession(atSourceTime: .zero)

        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &buffer)
        guard let buffer else { throw SpoloError.exportFailed(String(localized: "Couldn’t prepare photos.")) }
        CVPixelBufferLockBaseAddress(buffer, [])
        memset(CVPixelBufferGetBaseAddress(buffer), 0, CVPixelBufferGetDataSize(buffer))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        for frame in 0..<4 {
            while !video.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 4))
        }
        video.markAsFinished()

        var format: CMAudioFormatDescription?
        var description = AudioStreamBasicDescription(
            mSampleRate: Double(sampleRate), mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        CMAudioFormatDescriptionCreate(allocator: nil, asbd: &description, layoutSize: 0, layout: nil,
                                       magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format)
        var block: CMBlockBuffer?
        CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: sampleRate * 2, blockAllocator: nil,
                                           customBlockSource: nil, offsetToData: 0, dataLength: sampleRate * 2,
                                           flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block)
        guard let format, let block else { throw SpoloError.exportFailed(String(localized: "Couldn’t prepare photos.")) }
        CMBlockBufferFillDataBytes(with: 0, blockBuffer: block, offsetIntoDestination: 0, dataLength: sampleRate * 2)
        var sample: CMSampleBuffer?
        CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block, formatDescription: format,
                                                             sampleCount: sampleRate, presentationTimeStamp: .zero,
                                                             packetDescriptions: nil, sampleBufferOut: &sample)
        guard let sample else { throw SpoloError.exportFailed(String(localized: "Couldn’t prepare photos.")) }
        while !audio.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
        audio.append(sample)
        audio.markAsFinished()

        writer.endSession(atSourceTime: duration)
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? SpoloError.exportFailed(String(localized: "Couldn’t prepare photos.")) }
        return url
    }
}
