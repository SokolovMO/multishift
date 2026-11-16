import AppKit
import SwiftUI

@main struct SettingsToggleChecks {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let rows = [
            ("включить multishift", "действия с файлами прямо из finder"),
            ("показывать уведомления", "системные баннеры о завершении фоновых операций"),
            ("показывать результаты в окне", "карточку готовой операции можно закрыть. история и файлы сохраняются.")
        ]
        let view = NSHostingView(rootView: VStack(spacing: 12) {
            ForEach(0..<3) { index in
                SettingsToggleRow(title: rows[index].0, detail: rows[index].1, isOn: .constant(true))
                    .frame(width: 560, height: 70)
            }
        }.padding(20).frame(width: 600, height: 274).background(Color.white)
            .tint(Color(nsColor: MultiDesign.accent)).preferredColorScheme(.light))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 274),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = view
        window.orderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        view.layoutSubtreeIfNeeded()
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let path = ProcessInfo.processInfo.environment["MULTI_TOGGLE_COMPONENT_RENDER"] ?? "/tmp/multishift-toggle-component.png"
        try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
        var bounds: [(Int, Int)] = []
        let scale = Double(bitmap.pixelsWide) / 600
        for index in 0..<3 {
            var left = bitmap.pixelsWide, right = 0
            for y in Int(Double(20 + index * 82) * scale)..<Int(Double(90 + index * 82) * scale) {
                for x in Int(490 * scale)..<bitmap.pixelsWide {
                    let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                    // Inactive native switches are gray; the test window never steals focus.
                    if color.alphaComponent > 0.9 && max(color.redComponent, color.greenComponent, color.blueComponent) < 0.94 {
                        left = min(left, x); right = max(right, x)
                    }
                }
            }
            precondition(right > left, "native switch not rendered in row \(index)")
            bounds.append((left, right))
        }
        precondition(bounds.allSatisfy { abs($0.0 - bounds[0].0) <= 1 && abs($0.1 - bounds[0].1) <= 1 },
                     "switch size or trailing edge differs: \(bounds)")
        print("SettingsToggleChecks PASS: all three native switches share bounds \(bounds)")
        window.orderOut(nil)
    }
}
