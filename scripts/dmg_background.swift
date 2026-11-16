import AppKit

// Custom Finder artwork; installation itself remains Finder's standard drag and drop.
let name = CommandLine.arguments[1].lowercased()
let destination = URL(fileURLWithPath: CommandLine.arguments[2])
let shift = name == "multishift"
let size = NSSize(width: 760, height: 500)
let image = NSImage(size: size)
let ink = NSColor(white: 0.10, alpha: 1)
let accent = ink
for scale in [1, 2] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 760 * scale,
        pixelsHigh: 500 * scale, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor(white: 0.96, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
    func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat,
              _ weight: NSFont.Weight = .regular, _ color: NSColor = ink) {
        (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
    }
    // A quiet print-like grid connects the two independently distributed products.
    accent.withAlphaComponent(0.13).setFill()
    for x in stride(from: 40, through: 740, by: 20) {
        for y in stride(from: 140, through: 340, by: 20) {
            NSBezierPath(ovalIn: NSRect(x: CGFloat(x), y: CGFloat(y), width: 1.5, height: 1.5)).fill()
        }
    }
    text(name, 44, 450, 16, .semibold, accent)
    text("один жест — и вы дома.", 44, 392, 34, .semibold)
    text("перетащите приложение в «Программы»", 44, 360, 16, .regular, ink.withAlphaComponent(0.75))
    for x: CGFloat in [200, 560] {
        NSColor.white.withAlphaComponent(0.58).setFill()
        NSBezierPath(ovalIn: NSRect(x: x - 85, y: 155, width: 170, height: 170)).fill()
        let orbit = NSBezierPath(ovalIn: NSRect(x: x - 94, y: 146, width: 188, height: 188))
        orbit.lineWidth = 1
        accent.withAlphaComponent(0.28).setStroke(); orbit.stroke()
    }
    // Dashed trajectory guides the actual drag, without imitating an app control.
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 306, y: 240)); path.line(to: NSPoint(x: 454, y: 240))
    path.lineWidth = 1.8
    path.setLineDash([3, 6], count: 2, phase: 0)
    accent.setStroke(); path.stroke()
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 443, y: 249)); arrow.line(to: NSPoint(x: 454, y: 240)); arrow.line(to: NSPoint(x: 443, y: 231))
    arrow.lineWidth = 1.8; arrow.lineJoinStyle = .round; arrow.stroke()
    text("01", 114, 310, 12, .medium, accent)
    text("02", 634, 310, 12, .medium, accent)
    let divider = NSBezierPath()
    divider.move(to: NSPoint(x: 44, y: 115)); divider.line(to: NSPoint(x: 716, y: 115))
    divider.lineWidth = 0.7; accent.withAlphaComponent(0.35).setStroke(); divider.stroke()
    text(shift ? "меньше рутины. больше готовых файлов." : "мысль — на своём языке. текст — тоже.", 44, 76, 17, .medium)
    text("после копирования откройте приложение из «Программ»", 44, 48, 13, .regular, ink.withAlphaComponent(0.72))
    text("drag to Applications · open after copying", 44, 25, 11, .regular, ink.withAlphaComponent(0.55))
    NSGraphicsContext.restoreGraphicsState()
    image.addRepresentation(bitmap)
}
try image.tiffRepresentation!.write(to: destination)
