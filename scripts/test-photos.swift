import AppKit
import ImageIO
import UniformTypeIdentifiers

// Writes the test photos for scripts/test-merge.sh: a solid colour with a white block in the top-left
// corner as it should be seen, so the merged frames show whether each photo came out upright.
// usage: swift scripts/test-photos.swift <folder>
let folder = URL(fileURLWithPath: CommandLine.arguments[1])

/// Draws the upright picture, then stores it turned so that the EXIF orientation turns it back.
func photo(_ name: String, type: UTType, width: Int, height: Int, rgb: (CGFloat, CGFloat, CGFloat),
           orientation: Int = 1, taken: String? = nil) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let upright = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    upright.setFillColor(CGColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1))
    upright.fill(CGRect(x: 0, y: 0, width: width, height: height))
    upright.setFillColor(.white)
    // Core Graphics counts from the bottom, so the top-left block starts at height * 0.8.
    upright.fill(CGRect(x: 0, y: Double(height) * 0.8, width: Double(width) * 0.2, height: Double(height) * 0.2))
    var image = upright.makeImage()!
    if orientation == 6 {
        // Orientation 6 means "turn 90° clockwise to view", so store it turned 90° anticlockwise.
        let stored = CGContext(data: nil, width: height, height: width, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                               bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        stored.translateBy(x: CGFloat(height) / 2, y: CGFloat(width) / 2)
        stored.rotate(by: .pi / 2)
        stored.draw(image, in: CGRect(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2, width: CGFloat(width), height: CGFloat(height)))
        image = stored.makeImage()!
    }
    var properties: [CFString: Any] = [kCGImagePropertyOrientation: orientation]
    if let taken {
        properties[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifDateTimeOriginal: taken]
    }
    let url = folder.appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    precondition(CGImageDestinationFinalize(destination), "couldn't write \(name)")
}

photo("e_photo.jpg", type: .jpeg, width: 4032, height: 3024, rgb: (1, 0, 1), taken: "2025:06:01 09:00:00")
photo("f_photo_turned.heic", type: .heic, width: 1200, height: 1600, rgb: (0, 1, 1), orientation: 6, taken: "2025:06:01 12:00:00")
photo("g_photo.png", type: .png, width: 800, height: 1200, rgb: (1, 0.5, 0))
