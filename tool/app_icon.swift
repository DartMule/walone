import AppKit

// Vector master. Render every macOS icon size directly so small variants stay crisp.
// From repository root: xcrun swift tool/app_icon.swift macos/Runner/Assets.xcassets/AppIcon.appiconset
let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
}

func rounded(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func render(size: Int, name: String) throws {
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
    color(0.03, 0.45, 0.48).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0.16, 0.83, 0.79), ending: color(0.02, 0.40, 0.46))!
        .draw(in: tile, angle: -65)

    // A substantial keycap with a recessed side wall and a softly lit face.
    let side = rounded(NSRect(x: 230, y: 214, width: 564, height: 548), radius: 124)
    NSGraphicsContext.saveGraphicsState()
    let keyShadow = NSShadow()
    keyShadow.shadowColor = color(0.01, 0.19, 0.23).withAlphaComponent(0.38)
    keyShadow.shadowOffset = NSSize(width: 0, height: -24)
    keyShadow.shadowBlurRadius = 32
    keyShadow.set()
    color(0.64, 0.79, 0.75).setFill()
    side.fill()
    NSGraphicsContext.restoreGraphicsState()
    let face = rounded(NSRect(x: 230, y: 272, width: 564, height: 528), radius: 124)
    NSGradient(starting: color(0.99, 1, 0.96), ending: color(0.84, 0.92, 0.85))!
        .draw(in: face, angle: -90)
    NSColor.white.withAlphaComponent(0.65).setStroke()
    face.lineWidth = 3
    face.stroke()

    // The waveform is readable as a single mark even in the 16 px Dock variant.
    let heights: [CGFloat] = [84, 164, 244, 164, 84]
    color(0.02, 0.38, 0.40).setFill()
    for (index, height) in heights.enumerated() {
        rounded(NSRect(x: 358 + CGFloat(index) * 66, y: 533 - height / 2,
                       width: 44, height: height), radius: 22).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    let data = bitmap.representation(using: .png, properties: [:])!
    try data.write(to: destination.appendingPathComponent(name))
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    try render(size: size, name: "app_icon_\(size).png")
}
