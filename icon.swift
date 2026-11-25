import AppKit

let canvas: CGFloat = 1024
let lime = NSColor(srgbRed: 0xF1 / 255, green: 0xF1 / 255, blue: 0x70 / 255, alpha: 1)
let olive = NSColor(srgbRed: 0x64 / 255, green: 0x67 / 255, blue: 0x29 / 255, alpha: 1)

func card(center: NSPoint, size: NSSize, angle: CGFloat) -> NSBezierPath {
    let p = NSBezierPath(roundedRect: NSRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
                         xRadius: 34, yRadius: 34)
    var t = AffineTransform(translationByX: center.x, byY: center.y)
    t.rotate(byDegrees: angle)
    p.transform(using: t)
    return p
}

func shadowed(_ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow()
    s.shadowColor = NSColor.black.withAlphaComponent(0.22)
    s.shadowBlurRadius = 28
    s.shadowOffset = NSSize(width: 0, height: -12)
    s.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

let image = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    shadowed {
        NSColor(white: 0.08, alpha: 1).setFill()
        NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185).fill()
    }
    let gloss = NSGradient(colors: [NSColor.white.withAlphaComponent(0.12), NSColor.white.withAlphaComponent(0)])
    gloss?.draw(in: NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185), angle: -90)

    let size = NSSize(width: 330, height: 420)
    let back = card(center: NSPoint(x: 462, y: 540), size: size, angle: 11)
    let front = card(center: NSPoint(x: 568, y: 512), size: size, angle: -7)
    shadowed {
        lime.setFill()
        back.fill()
    }
    shadowed {
        NSColor.white.setFill()
        front.fill()
    }
    olive.setFill()
    var t = AffineTransform(translationByX: 568, byY: 512)
    t.rotate(byDegrees: -7)
    for (i, w) in [CGFloat(190), 150, 170].enumerated() {
        let line = NSBezierPath(roundedRect: NSRect(x: -110, y: 90 - CGFloat(i) * 62, width: w, height: 26), xRadius: 13, yRadius: 13)
        line.transform(using: t)
        NSColor.black.withAlphaComponent(i == 0 ? 0.75 : 0.18).setFill()
        line.fill()
    }
    let dot = NSBezierPath(ovalIn: NSRect(x: -110, y: -150, width: 44, height: 44))
    dot.transform(using: t)
    olive.setFill()
    dot.fill()
    return true
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = out.deletingPathExtension().appendingPathExtension("iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: px, height: px)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
        NSGraphicsContext.restoreGraphicsState()
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
