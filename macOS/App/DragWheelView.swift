import AppKit
import QuickLookThumbnailing
import ConvertyCore

struct WheelChoice: Equatable {
    let title: String
    let format: String?
    let tool: FileTool?
    var symbol: String? { tool?.symbol }
    static func choices(for urls: [URL], advanced: Bool) -> [WheelChoice] {
        guard let first = urls.first, let kind = FileKind.identify(first) else { return [] }
        if advanced {
            return FileTool.allCases.filter { tool in
                tool != .convert && urls.allSatisfy { tool.supports($0) } && (![FileTool.collage, .mergePDF, .joinVideo].contains(tool) || urls.count >= 2)
            }.map { .init(title: $0.title, format: nil, tool: $0) }
        }
        let preferred = kind == .video ? ["mp4", "mov", "mkv", "gif", "mp3", "m4a"] : kind.formats(for: first)
        let formats = preferred.filter { format in urls.allSatisfy { FileKind.identify($0)?.formats(for: $0).contains(format) == true } && !urls.allSatisfy { $0.pathExtension.lowercased() == format } }
        return formats.map { .init(title: $0.uppercased(), format: $0, tool: nil) }
    }
}

final class WheelPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class DragWheelView: NSView {
    weak var controller: DragWheelController?
    var urls: [URL] = [] { didSet { if oldValue != urls { loadThumbnail(); refreshAccessibility() }; needsDisplay = true } }
    private var thumbnail: NSImage?
    var advanced = false { didSet { if oldValue != advanced { refreshAccessibility(); onModeChange?() }; needsDisplay = true } }
    var hovered: Int? { didSet { if oldValue != hovered { needsDisplay = true; setAccessibilityValue(hovered.flatMap { choices.indices.contains($0) ? choices[$0].title : nil } ?? "Choose a format or tool") } } }
    var interactive = false { didSet { onModeChange?() } }
    var onModeChange: (() -> Void)?
    var optionHeld = false
    let geometry = WheelGeometry()
    var choices: [WheelChoice] { WheelChoice.choices(for: urls, advanced: advanced) }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    private var accessibilityChoices: [WheelAccessibleChoice] = []
    private var tracking: NSTrackingArea?
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        setAccessibilityElement(true); setAccessibilityRole(.group); setAccessibilityLabel("Converty format wheel")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(tracking!); super.updateTrackingAreas()
    }
    override func draw(_ dirtyRect: NSRect) {
        let center = geometry.center, count = choices.count
        guard count > 0 else { return }
        let step = 2 * Double.pi / Double(count)
        for (index, choice) in choices.enumerated() {
            let angle = -Double.pi / 2 + Double(index) * step
            let path = segment(from: angle - step / 2 + 0.055, to: angle + step / 2 - 0.055)
            let active = hovered == index
            let contrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            (active ? NSColor(srgbRed: 0, green: 0.36, blue: 0.86, alpha: 1) : NSColor.labelColor.withAlphaComponent(contrast ? 0.10 : 0.045)).setFill(); path.fill()
            (active ? NSColor.white.withAlphaComponent(0.55) : NSColor.separatorColor.withAlphaComponent(contrast ? 0.85 : 0.3)).setStroke()
            path.lineWidth = active || contrast ? 1.5 : 0.75; path.stroke()
            let radius = (geometry.innerRadius + geometry.outerRadius) / 2
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            let color = active ? NSColor.white : NSColor.labelColor
            if let symbol = choice.symbol, let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: choice.title)?.withSymbolConfiguration(.init(pointSize: 17, weight: .medium)) {
                let tinted = NSImage(size: icon.size, flipped: false) { rect in icon.draw(in: rect); color.setFill(); rect.fill(using: .sourceAtop); return true }
                tinted.draw(in: CGRect(x: point.x - 10, y: point.y - 23, width: 20, height: 20))
            }
            drawText(choice.title, rect: CGRect(x: point.x - 43, y: point.y + (choice.symbol == nil ? -9 : 3), width: 86, height: 36), font: .systemFont(ofSize: choice.symbol == nil ? 13 : 9, weight: .semibold), color: color)
        }
        if let first = urls.first {
            let icon = thumbnail ?? NSWorkspace.shared.icon(forFile: first.path)
            icon.draw(in: CGRect(x: center.x - 27, y: center.y - 37, width: 54, height: 54), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            let label = hovered.flatMap { choices.indices.contains($0) ? choices[$0].title : nil } ?? (urls.count > 1 ? "\(urls.count) files" : first.lastPathComponent)
            drawText(label, rect: CGRect(x: 122, y: 202, width: 116, height: 28), font: .systemFont(ofSize: 10, weight: .semibold), color: .labelColor)
        }
    }
    private func loadThumbnail() {
        thumbnail = nil
        guard let url = urls.first else { return }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 72, height: 72), scale: 2, representationTypes: .all)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            DispatchQueue.main.async { guard let self, self.urls.first == url else { return }; self.thumbnail = representation?.nsImage; self.needsDisplay = true }
        }
    }
    private func segment(from start: Double, to end: Double) -> NSBezierPath {
        let path = NSBezierPath(), outer = geometry.outerRadius, inner = geometry.innerRadius, corner = 7.0
        func point(_ radius: Double, _ angle: Double) -> CGPoint { CGPoint(x: geometry.center.x + cos(angle) * radius, y: geometry.center.y + sin(angle) * radius) }
        path.move(to: point(inner + corner, start)); path.line(to: point(outer - corner, start))
        path.curve(to: point(outer, start + corner / outer), controlPoint1: point(outer, start), controlPoint2: point(outer, start))
        for i in 1...28 { path.line(to: point(outer, start + corner / outer + (end - start - 2 * corner / outer) * Double(i) / 28)) }
        path.curve(to: point(outer - corner, end), controlPoint1: point(outer, end), controlPoint2: point(outer, end))
        path.line(to: point(inner + corner, end))
        path.curve(to: point(inner, end - corner / inner), controlPoint1: point(inner, end), controlPoint2: point(inner, end))
        for i in 1...28 { path.line(to: point(inner, end - corner / inner - (end - start - 2 * corner / inner) * Double(i) / 28)) }
        path.curve(to: point(inner + corner, start), controlPoint1: point(inner, start), controlPoint2: point(inner, start)); path.close(); return path
    }
    func refreshAccessibility() {
        accessibilityChoices = choices.enumerated().map { index, choice in
            let element = WheelAccessibleChoice()
            element.setAccessibilityEnabled(true); element.setAccessibilityRole(.button); element.setAccessibilityLabel(choice.title); element.setAccessibilityParent(self)
            let angle = -Double.pi / 2 + Double(index) * 2 * Double.pi / Double(max(1, choices.count))
            let point = CGPoint(x: 180 + cos(angle) * 115, y: 180 + sin(angle) * 115)
            element.setAccessibilityFrame(window?.convertToScreen(convert(CGRect(x: point.x - 35, y: point.y - 25, width: 70, height: 50), to: nil)) ?? .zero)
            element.action = { [weak self] in guard let self, self.interactive else { return false }; return self.controller?.accept(self.urls, choice: choice) ?? false }
            return element
        }
        setAccessibilityChildren(accessibilityChoices)
    }
    private func drawText(_ text: String, rect: CGRect, font: NSFont, color: NSColor) {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
    }
    func update(at point: CGPoint) { hovered = geometry.index(at: point, count: choices.count) }
    override func mouseMoved(with event: NSEvent) { update(at: convert(event.locationInWindow, from: nil)) }
    override func mouseExited(with event: NSEvent) { hovered = nil }
    func updateOption(_ held: Bool) {
        guard held != optionHeld else { return }
        optionHeld = held; advanced = held; hovered = nil
    }
    override func flagsChanged(with event: NSEvent) { updateOption(event.modifierFlags.contains(.option)) }
    override func mouseDown(with event: NSEvent) {
        guard interactive else { return }
        let point = convert(event.locationInWindow, from: nil)
        update(at: point)
        if let hovered, choices.indices.contains(hovered) { controller?.accept(urls, choice: choices[hovered]) }
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { controller?.dismiss() }
        else if event.keyCode == 49 || event.charactersIgnoringModifiers == " " { advanced.toggle(); hovered = nil }
        else if [123, 124, 125, 126].contains(event.keyCode), !choices.isEmpty { hovered = ((hovered ?? 0) + ([123, 126].contains(event.keyCode) ? choices.count - 1 : 1)) % choices.count }
        else if event.keyCode == 36, let hovered, choices.indices.contains(hovered) { controller?.accept(urls, choice: choices[hovered]) }
        else { super.keyDown(with: event) }
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let files = DragWheelController.files(from: sender.draggingPasteboard)
        guard !files.isEmpty else { return [] }
        urls = files
        return draggingUpdated(sender)
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard NSEvent.modifierFlags.contains(.shift) || interactive else { controller?.dismiss(); return [] }
        advanced = NSEvent.modifierFlags.contains(.option)
        update(at: convert(sender.draggingLocation, from: nil))
        return sender.draggingSourceOperationMask.contains(.copy) ? .copy : []
    }
    override func wantsPeriodicDraggingUpdates() -> Bool { true }
    override func draggingExited(_ sender: NSDraggingInfo?) { hovered = nil }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { hovered != nil && !DragWheelController.files(from: sender.draggingPasteboard).isEmpty }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        update(at: convert(sender.draggingLocation, from: nil))
        guard let hovered, choices.indices.contains(hovered) else { return false }
        let files = DragWheelController.files(from: sender.draggingPasteboard)
        guard !files.isEmpty else { return false }
        return controller?.accept(files, choice: choices[hovered]) ?? false
    }
    override func draggingEnded(_ sender: NSDraggingInfo) { controller?.dismiss() }
}

@MainActor final class WheelAccessibleChoice: NSAccessibilityElement {
    var action: (() -> Bool)?
    override func accessibilityPerformPress() -> Bool { action?() ?? false }
}
