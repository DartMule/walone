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

    // The entire tile is an ivory keycap, with a shallow warm-gray lower edge.
    let body = rounded(NSRect(x: 64, y: 64, width: 896, height: 896), radius: 202)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 20
    shadow.set()
    color(0.79, 0.77, 0.72).setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0.88, 0.86, 0.81), ending: color(0.76, 0.74, 0.69))!
        .draw(in: body, angle: -90)

    let face = rounded(NSRect(x: 64, y: 150, width: 896, height: 810), radius: 202)
    NSGradient(starting: color(0.98, 0.96, 0.92), ending: color(0.90, 0.88, 0.83))!
        .draw(in: face, angle: -90)
    NSColor.white.withAlphaComponent(0.45).setStroke()
    face.lineWidth = 2
    face.stroke()

    // Five charcoal sound bars remain legible at small sizes and match the tray.
    let heights: [CGFloat] = [140, 280, 420, 280, 140]
    color(0.24, 0.22, 0.21).setFill()
    for (index, height) in heights.enumerated() {
        rounded(NSRect(x: 257 + CGFloat(index) * 110, y: 550 - height / 2,
                       width: 70, height: height), radius: 35).fill()
    }
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
