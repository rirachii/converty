import SwiftUI
import AppKit

extension Color {
    static let converty = Color(nsColor: .convertyAccent)
    static let convertyControl = Color(red: 0, green: 0.36, blue: 0.86)
}

extension NSColor {
    static let convertyAccent = NSColor(name: "ConvertyAccent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.26, green: 0.63, blue: 1, alpha: 1)
            : NSColor(srgbRed: 0, green: 0.36, blue: 0.86, alpha: 1)
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { self == .system ? "System" : rawValue.capitalized }
    @MainActor func apply() {
        NSApp.appearance = self == .system ? nil : NSAppearance(named: self == .dark ? .darkAqua : .aqua)
    }
}

enum ConvertyArtwork {
    /// Read the bundled icon directly so an in-place rebuild cannot show a stale Launch Services image.
    static let icon: NSImage = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
        .flatMap { NSImage(contentsOf: $0) } ?? NSImage(named: NSImage.applicationIconName)!
}

struct OutputFolderMenu: View {
    let destination: URL?
    let useOriginals: () -> Void
    let chooseFolder: () -> Void
    var body: some View {
        Menu {
            Button(action: useOriginals) {
                Label("Beside originals", systemImage: destination == nil ? "checkmark" : "doc.on.doc")
            }
            if let destination {
                Label(destination.lastPathComponent, systemImage: "checkmark")
            }
            Divider()
            Button("Choose Folder…", action: chooseFolder)
        } label: {
            Label(destination?.lastPathComponent ?? "Beside originals", systemImage: "folder").lineLimit(1)
        }
        .help(destination?.path ?? "Save each copy in its original's folder. Combined outputs use the first original's folder.")
        .accessibilityLabel("Save to: \(destination?.lastPathComponent ?? "Beside originals")")
    }
}

/// Reserve glass for the floating action layer, with system materials on older Macs.
extension View {
    @ViewBuilder func primaryActionStyle() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glassProminent).tint(.convertyControl).foregroundStyle(.white)
        } else {
            buttonStyle(.borderedProminent).tint(.convertyControl).foregroundStyle(.white)
        }
    }
}

@MainActor func nativeGlassSurface(content: NSView, cornerRadius: CGFloat) -> NSView {
    if #available(macOS 26, *) {
        let glass = NSGlassEffectView()
        glass.cornerRadius = cornerRadius
        glass.style = .regular
        glass.contentView = content
        return glass
    } else {
        let material = NSVisualEffectView()
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = cornerRadius
        material.layer?.masksToBounds = true
        content.autoresizingMask = [.width, .height]
        material.addSubview(content)
        return material
    }
}

/// A round glass control and a separate, accessible mode switch.
final class WheelSurfaceView: NSView {
    private let wheel: DragWheelView
    private let mode = NSButton(title: "", target: nil, action: nil)
    private let disc: NSView
    private let footer: NSView
    override var isFlipped: Bool { true }

    init(wheel: DragWheelView) {
        self.wheel = wheel
        disc = nativeGlassSurface(content: wheel, cornerRadius: 180)
        footer = nativeGlassSurface(content: mode, cornerRadius: 14)
        super.init(frame: CGRect(x: 0, y: 0, width: 360, height: 382))
        disc.frame = CGRect(x: 0, y: 0, width: 360, height: 360)
        footer.frame = CGRect(x: 32, y: 354, width: 296, height: 28)
        wheel.frame = CGRect(x: 0, y: 0, width: 360, height: 360)
        mode.frame = footer.bounds
        mode.isBordered = false
        mode.font = .systemFont(ofSize: 11, weight: .medium)
        mode.target = self
        mode.action = #selector(switchMode)
        addSubview(disc)
        addSubview(footer)
        wheel.onModeChange = { [weak self] in self?.updateMode() }
        updateMode()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func switchMode() { wheel.advanced.toggle(); wheel.hovered = nil }
    private func updateMode() {
        mode.isEnabled = wheel.interactive
        mode.title = wheel.interactive
            ? (wheel.advanced ? "Show formats · Space · Esc to close" : "Show tools · Space · Esc to close")
            : (wheel.advanced ? "Drop to edit · Release ⌥ for formats" : "Drop to convert · Hold ⌥ for tools")
        mode.setAccessibilityLabel(wheel.advanced ? "Show formats" : "Show tools")
    }
}
