import AppKit

// Renders the app icon — a film reel (spole) unwinding into one strip of frames, a photo and a video side by
// side — straight into the asset catalog at every size. Sizes up to 64 px leave out the sprocket holes.
// usage: swift scripts/icon.swift App/Assets.xcassets/AppIcon.appiconset
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: 1)
}

let skyTop = hex(0x31557A), skyBottom = hex(0x1A2D44), reel = hex(0xF2EDE3), film = hex(0x16202B)
let photo = hex(0xF2B544), video = hex(0xE0604A), hub = hex(0x8A97A6)

func drawIcon(small: Bool) {
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    let squircle = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
    skyBottom.setFill()
    squircle.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()
    NSGradient(starting: skyTop, ending: skyBottom)!.draw(in: tile, angle: -90)

    // The strip leaves the reel along its bottom edge and runs off to the right.
    let centre = NSPoint(x: tile.midX - 70, y: tile.midY + 70)
    let radius: CGFloat = 270
    let stripHeight: CGFloat = 150
    let strip = NSRect(x: centre.x, y: centre.y - radius - stripHeight + 18, width: tile.maxX - centre.x + 20, height: stripHeight)
    film.setFill()
    strip.fill()
    let frameHeight = stripHeight - 56
    for (i, colour) in [photo, video].enumerated() {
        colour.setFill()
        let frame = NSRect(x: centre.x + 140 + CGFloat(i) * 180, y: strip.midY - frameHeight / 2, width: 160, height: frameHeight)
        NSBezierPath(roundedRect: frame, xRadius: 8, yRadius: 8).fill()
    }
    if !small {
        hub.withAlphaComponent(0.55).setFill()
        var x = centre.x + 20
        while x < tile.maxX {
            NSBezierPath(roundedRect: NSRect(x: x, y: strip.maxY - 20, width: 18, height: 12), xRadius: 3, yRadius: 3).fill()
            NSBezierPath(roundedRect: NSRect(x: x, y: strip.minY + 8, width: 18, height: 12), xRadius: 3, yRadius: 3).fill()
            x += 36
        }
    }

    // The reel: a disc with five windows and a hub, drawn even-odd so the windows show the sky.
    let disc = NSBezierPath(ovalIn: NSRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
    let hole: CGFloat = small ? 74 : 66
    for i in 0..<5 {
        let angle = CGFloat(i) * 2 * .pi / 5 + .pi / 2
        let p = NSPoint(x: centre.x + cos(angle) * 158, y: centre.y + sin(angle) * 158)
        disc.appendOval(in: NSRect(x: p.x - hole, y: p.y - hole, width: hole * 2, height: hole * 2))
    }
    disc.windingRule = .evenOdd
    NSGraphicsContext.current?.saveGraphicsState()
    let lift = NSShadow()
    lift.shadowColor = .black.withAlphaComponent(0.35)
    lift.shadowBlurRadius = 18
    lift.shadowOffset = NSSize(width: 0, height: -6)
    lift.set()
    reel.setFill()
    disc.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    hub.setFill()
    NSBezierPath(ovalIn: NSRect(x: centre.x - 40, y: centre.y - 40, width: 80, height: 80)).fill()
    NSGraphicsContext.current?.restoreGraphicsState()
}

func write(pixels: Int, name: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let k = CGFloat(pixels) / 1024
    NSGraphicsContext.current?.cgContext.scaleBy(x: k, y: k)
    drawIcon(small: pixels <= 64)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
}

for px in [16, 32, 64, 128, 256, 512, 1024] {
    write(pixels: px, name: "icon_\(px).png")
}
