import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 1024)
        transform.concat()
        let background = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880),
                                      xRadius: 202, yRadius: 202)
        NSGradient(starting: NSColor(srgbRed: 0.43, green: 0.40, blue: 0.93, alpha: 1),
                   ending: NSColor(srgbRed: 0.22, green: 0.19, blue: 0.66, alpha: 1))!.draw(in: background, angle: -70)
        for (x, symbol) in [(CGFloat(184), "⌃"), (CGFloat(536), "⇧")] {
            let key = NSBezierPath(roundedRect: NSRect(x: x, y: 337, width: 304, height: 326), xRadius: 58, yRadius: 58)
            NSColor.white.withAlphaComponent(0.17).setFill()
            key.fill()
            NSColor.white.withAlphaComponent(0.40).setStroke()
            key.lineWidth = 5
            key.stroke()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 210, weight: .medium), .foregroundColor: NSColor.white,
            ]
            let text = symbol as NSString
            let bounds = text.size(withAttributes: attributes)
            text.draw(at: NSPoint(x: x + (304 - bounds.width) / 2, y: 337 + (326 - bounds.height) / 2),
                      withAttributes: attributes)
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let url = directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
}
