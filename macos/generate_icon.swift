import AppKit
import Foundation

func renderPNG(image: NSImage, size: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    image.draw(
        in: CGRect(x: 0, y: 0, width: size, height: size),
        from: .zero,
        operation: .copy,
        fraction: 1,
        respectFlipped: false,
        hints: nil
    )
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

@main enum GenerateAppIcon {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 3 else { fatalError("pass the build directory and output ICNS") }
        let projectDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
        let sourceImage = MultiBrandIcon.shift
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("MultiSwitcher-icon-" + UUID().uuidString)
        let iconset = temporary.appendingPathComponent("MultiSwitcher.iconset")
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        var entries: [[String: String]] = []
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
                let data = renderPNG(image: sourceImage, size: points * scale)
                try data.write(to: iconset.appendingPathComponent(name))
                entries.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
            }
        }
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconset.path, "-o", CommandLine.arguments[2]]
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { fatalError("iconutil failed") }
        let master = renderPNG(image: sourceImage, size: 1024)
        for name in ["icon-light.png", "icon-dark.png", "MultiShift-icon-preview.png"] {
            try master.write(to: projectDirectory.appendingPathComponent(name))
        }
        print("MultiShift: shared monochrome application tile rendered")
    }
}
