import AppKit

// Vector master. Render every macOS icon size directly so small variants stay crisp.
// From repository root: xcrun swift tool/app_icon.swift macos/Runner/Assets.xcassets/AppIcon.appiconset windows/runner/resources/app_icon.ico
let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
}

func rounded(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func render(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = AffineTransform(scale: CGFloat(size) / 1024)
    (transform as NSAffineTransform).concat()

    let tile = rounded(NSRect(x: 64, y: 64, width: 896, height: 896), radius: 202)
    NSGraphicsContext.saveGraphicsState()
    let tileShadow = NSShadow()
    tileShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    tileShadow.shadowOffset = NSSize(width: 0, height: -14)
    tileShadow.shadowBlurRadius = 20
    tileShadow.set()
    color(0.18, 0.11, 0.18).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0.30, 0.19, 0.29), ending: color(0.16, 0.11, 0.17))!
        .draw(in: tile, angle: -65)

    // A continuous W-shaped wave, with round ends and two balanced valleys.
    let wave = NSBezierPath()
    wave.move(to: NSPoint(x: 218, y: 624))
    wave.curve(to: NSPoint(x: 356, y: 406),
               controlPoint1: NSPoint(x: 272, y: 568),
               controlPoint2: NSPoint(x: 292, y: 406))
    wave.curve(to: NSPoint(x: 512, y: 558),
               controlPoint1: NSPoint(x: 420, y: 406),
               controlPoint2: NSPoint(x: 452, y: 558))
    wave.curve(to: NSPoint(x: 668, y: 406),
               controlPoint1: NSPoint(x: 572, y: 558),
               controlPoint2: NSPoint(x: 604, y: 406))
    wave.curve(to: NSPoint(x: 806, y: 624),
               controlPoint1: NSPoint(x: 732, y: 406),
               controlPoint2: NSPoint(x: 752, y: 568))
    wave.lineWidth = 112
    wave.lineCapStyle = .round
    wave.lineJoinStyle = .round
    NSGraphicsContext.saveGraphicsState()
    let waveShadow = NSShadow()
    waveShadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    waveShadow.shadowOffset = NSSize(width: 0, height: -8)
    waveShadow.shadowBlurRadius = 10
    waveShadow.set()
    color(1, 0.72, 0.52).setStroke()
    wave.stroke()
    NSGraphicsContext.restoreGraphicsState()
    // Clip a subtle peach gradient to the stroke without raster source artwork.
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current!.cgContext.addPath(wave.cgPath)
    NSGraphicsContext.current!.cgContext.setLineWidth(112)
    NSGraphicsContext.current!.cgContext.setLineCap(.round)
    NSGraphicsContext.current!.cgContext.setLineJoin(.round)
    NSGraphicsContext.current!.cgContext.replacePathWithStrokedPath()
    NSGraphicsContext.current!.cgContext.clip()
    NSGradient(starting: color(1, 0.87, 0.67), ending: color(0.98, 0.64, 0.43))!
        .draw(in: NSRect(x: 160, y: 348, width: 704, height: 334), angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    try render(size: size).write(to: destination.appendingPathComponent("app_icon_\(size).png"))
}

// ICO entries use the same directly rendered PNGs as macOS.
if CommandLine.arguments.count > 2 {
    let sizes = [16, 32, 48, 64, 128, 256]
    let images = sizes.map { render(size: $0) }
    var ico = Data()
    func append(_ value: Int, bytes: Int) {
        for shift in 0..<bytes {
            ico.append(UInt8(truncatingIfNeeded: value >> (shift * 8)))
        }
    }
    append(0, bytes: 2)
    append(1, bytes: 2)
    append(sizes.count, bytes: 2)
    var offset = 6 + 16 * sizes.count
    for (size, data) in zip(sizes, images) {
        append(size == 256 ? 0 : size, bytes: 1)
        append(size == 256 ? 0 : size, bytes: 1)
        append(0, bytes: 2)
        append(1, bytes: 2)
        append(32, bytes: 2)
        append(data.count, bytes: 4)
        append(offset, bytes: 4)
        offset += data.count
    }
    for data in images { ico.append(data) }
    try ico.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
