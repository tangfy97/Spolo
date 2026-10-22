import AVFoundation
import CoreGraphics
import Foundation

// Renders an illustrated fjord timelapse (sky, sun, ridges, water, stars, aurora) to an H.264 file,
// so App Store screenshots and the website use footage the studio owns outright.
//
//   swift scripts/sample-video.swift <out.mp4> <seconds> <time of day from> <to> <seed>
//
// Time of day runs from 0 (midday) to 1 (deep night with aurora).
let args = CommandLine.arguments
let outURL = URL(fileURLWithPath: args[1])
let seconds = Double(args[2])!
let todFrom = CGFloat(Double(args[3])!), todTo = CGFloat(Double(args[4])!)
var seed = UInt64(args[5])!

let W = 1920, H = 1080, fps = 25
let frames = Int(seconds * Double(fps))

func random() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat(seed >> 33) / CGFloat(1 << 31)
}

struct RGB { var r, g, b: CGFloat }
func rgb(_ v: UInt32) -> RGB { RGB(r: CGFloat(v >> 16 & 0xff) / 255, g: CGFloat(v >> 8 & 0xff) / 255, b: CGFloat(v & 0xff) / 255) }
func mix(_ a: RGB, _ b: RGB, _ t: CGFloat) -> RGB { RGB(r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t) }
func cg(_ c: RGB, _ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: a) }
func smooth(_ e0: CGFloat, _ e1: CGFloat, _ x: CGFloat) -> CGFloat { let t = max(0, min(1, (x - e0) / (e1 - e0))); return t * t * (3 - 2 * t) }

/// Sky colours (top, horizon) through the day, interpolated between keyframes.
let skyKeys: [(CGFloat, RGB, RGB)] = [
    (0.00, rgb(0x3F86C4), rgb(0xBFE3F2)),
    (0.40, rgb(0x3B5B8C), rgb(0xF6C27B)),
    (0.55, rgb(0x2B2D5C), rgb(0xF2765A)),
    (0.70, rgb(0x141B3D), rgb(0x7A4C8C)),
    (0.85, rgb(0x070B1D), rgb(0x1B2A55)),
    (1.00, rgb(0x04060F), rgb(0x0F1C3A)),
]
func sky(_ tod: CGFloat) -> (RGB, RGB) {
    for i in 1..<skyKeys.count where tod <= skyKeys[i].0 {
        let (a, b) = (skyKeys[i - 1], skyKeys[i])
        let t = (tod - a.0) / (b.0 - a.0)
        return (mix(a.1, b.1, t), mix(a.2, b.2, t))
    }
    return (skyKeys.last!.1, skyKeys.last!.2)
}

// Fixed scenery for this seed
let stars = (0..<260).map { _ in (random() * CGFloat(W), CGFloat(H) * (0.45 + random() * 0.55), 0.6 + random() * 1.8, random()) }
let ridges: [[(CGFloat, CGFloat, CGFloat)]] = (0..<3).map { _ in (0..<5).map { _ in (0.5 + random() * 3, random() * 6.28, 0.3 + random()) } }
let auroraPhase = random() * 6.28

func ridgeHeight(_ layer: Int, _ x: CGFloat) -> CGFloat {
    var h: CGFloat = 0
    for (f, p, a) in ridges[layer] { h += sin(x * f * 0.0016 * CGFloat(layer + 1) + p) * a }
    let base: [CGFloat] = [0.50, 0.42, 0.33]
    let amp: [CGFloat] = [0.07, 0.09, 0.10]
    return CGFloat(H) * (base[layer] + amp[layer] * h / 3)
}

func draw(_ ctx: CGContext, progress p: CGFloat) {
    let tod = todFrom + (todTo - todFrom) * p
    let (top, horizon) = sky(tod)
    let waterLine = CGFloat(H) * 0.26

    // Sky
    let skyGradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [cg(horizon), cg(top)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(skyGradient, start: CGPoint(x: 0, y: waterLine), end: CGPoint(x: 0, y: CGFloat(H)), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Stars
    let night = smooth(0.62, 0.85, tod)
    for (x, y, r, twinkle) in stars where night > 0 {
        let a = night * (0.55 + 0.45 * sin(p * 40 + twinkle * 20))
        ctx.setFillColor(CGColor(gray: 1, alpha: a))
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
    }

    // Aurora: translucent curtains drifting sideways
    let aurora = smooth(0.74, 0.92, tod)
    if aurora > 0 {
        for band in 0..<3 {
            let path = CGMutablePath()
            let baseY = CGFloat(H) * (0.60 + CGFloat(band) * 0.07)
            path.move(to: CGPoint(x: 0, y: baseY))
            for xi in stride(from: 0, through: W, by: 24) {
                let x = CGFloat(xi)
                let y = baseY + sin(x * 0.004 + p * 6 + auroraPhase + CGFloat(band)) * 60 + sin(x * 0.011 + p * 9) * 25
                path.addLine(to: CGPoint(x: x, y: y))
            }
            for xi in stride(from: W, through: 0, by: -24) {
                let x = CGFloat(xi)
                let y = baseY + 170 + sin(x * 0.003 + p * 5 + auroraPhase + CGFloat(band)) * 80
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.closeSubpath()
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            let colours = [CGColor(srgbRed: 0.35, green: 0.95, blue: 0.62, alpha: 0.55 * aurora),
                           CGColor(srgbRed: 0.45, green: 0.55, blue: 0.95, alpha: 0)]
            let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colours as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: baseY - 40), end: CGPoint(x: 0, y: baseY + 260), options: [])
            ctx.restoreGState()
        }
    }

    // Sun, setting behind the ridges
    let sunY = CGFloat(H) * (0.82 - 0.75 * smooth(0, 0.62, tod))
    let sunX = CGFloat(W) * (0.62 + 0.08 * tod)
    if tod < 0.66 {
        let sunColour = mix(rgb(0xFFF4C2), rgb(0xFF7A3D), smooth(0.25, 0.6, tod))
        let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [cg(sunColour, 0.55), cg(sunColour, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: CGPoint(x: sunX, y: sunY), startRadius: 0, endCenter: CGPoint(x: sunX, y: sunY), endRadius: 420, options: [])
        ctx.setFillColor(cg(sunColour))
        ctx.fillEllipse(in: CGRect(x: sunX - 46, y: sunY - 46, width: 92, height: 92))
    }

    // Ridges, far to near, panning slowly
    let dayRidges = [rgb(0x7FA3B8), rgb(0x4F7A8C), rgb(0x2C4A57)]
    let nightRidges = [rgb(0x1A2440), rgb(0x111830), rgb(0x080C1A)]
    for layer in 0..<3 {
        let shift = p * CGFloat(W) * 0.08 * CGFloat(layer + 1)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: waterLine))
        for xi in stride(from: 0, through: W, by: 8) {
            path.addLine(to: CGPoint(x: CGFloat(xi), y: ridgeHeight(layer, CGFloat(xi) + shift)))
        }
        path.addLine(to: CGPoint(x: CGFloat(W), y: waterLine))
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(cg(mix(mix(dayRidges[layer], horizon, 0.18), nightRidges[layer], smooth(0.35, 0.85, tod))))
        ctx.fillPath()
    }

    // Water: a darker mirror of the sky with a shimmering sun streak
    let water = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [cg(mix(top, rgb(0x000000), 0.35)), cg(mix(horizon, rgb(0x000000), 0.25))] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(water, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: waterLine), options: [])
    if tod < 0.66 {
        for i in 0..<26 {
            let y = waterLine - CGFloat(i) * 11 - 6
            let w = (120 - CGFloat(i) * 3) * (0.7 + 0.3 * sin(p * 50 + CGFloat(i)))
            ctx.setFillColor(cg(mix(rgb(0xFFE3A3), rgb(0xFF8A50), smooth(0.25, 0.6, tod)), 0.35 * (1 - CGFloat(i) / 26)))
            ctx.fill(CGRect(x: sunX - w / 2, y: y, width: w, height: 4))
        }
    }
}

// Encode
try? FileManager.default.removeItem(at: outURL)
let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000, AVVideoMaxKeyFrameIntervalKey: fps * 2],
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
for i in 0..<frames {
    while !input.isReadyForMoreMediaData { usleep(1000) }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
    CVPixelBufferLockBaseAddress(buffer!, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer!), width: W, height: H, bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer!), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    draw(ctx, progress: CGFloat(i) / CGFloat(max(frames - 1, 1)))
    CVPixelBufferUnlockBaseAddress(buffer!, [])
    adaptor.append(buffer!, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps)))
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print("wrote \(outURL.lastPathComponent): \(frames) frames, status \(writer.status.rawValue)")
