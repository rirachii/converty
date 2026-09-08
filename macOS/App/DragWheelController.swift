import AppKit
import SwiftUI
import ConvertyCore

@MainActor final class DragWheelController {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var timer: Timer?
    private var baseline = NSPasteboard(name: .drag).changeCount
    private var dragConfirmed = false
    private var cachedDragChange = -1
    private var cachedDragFiles: [URL] = []
    private var wheel: WheelPanel?
    private var wheelView: DragWheelView?
    private let flow = FloatingFlowController()
    private var enabled: Bool { UserDefaults.standard.object(forKey: "native.dragWheel") as? Bool ?? true }
    func start() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in self?.observe(event) }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask.union([.keyDown, .flagsChanged])) { [weak self] event in
            if let view = self?.wheelView, self?.wheel?.isVisible == true, view.interactive {
                if event.type == .keyDown, [36, 49, 53, 123, 124, 125, 126].contains(event.keyCode) || event.charactersIgnoringModifiers == " " { view.keyDown(with: event); return nil }
                if event.type == .flagsChanged { view.updateOption(event.modifierFlags.contains(.option)) }
            }
            self?.observe(event); return event
        }
    }
    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }; if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        timer?.invalidate(); timer = nil; dismiss(); flow.cancel()
    }
    private func observe(_ event: NSEvent) {
        guard enabled else { return }
        if event.type == .leftMouseDown {
            baseline = NSPasteboard(name: .drag).changeCount; dragConfirmed = false; cachedDragChange = -1; cachedDragFiles = []
            timer?.invalidate()
            timer = Timer(timeInterval: 0.04, repeats: true) { [weak self] _ in Task { @MainActor in self?.pollDrag() } }
            RunLoop.main.add(timer!, forMode: .common)
        } else if event.type == .leftMouseDragged { pollDrag() }
        else if event.type == .leftMouseUp {
            timer?.invalidate(); timer = nil
            // AppKit delivers performDragOperation in the same release cycle.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in if self?.wheelView?.interactive == false { self?.dismiss() } }
        }
    }
    private func pollDrag() {
        guard NSEvent.pressedMouseButtons & 1 != 0 else {
            timer?.invalidate(); timer = nil
            if wheelView?.interactive == false { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.dismiss() } }
            return
        }
        let pasteboard = NSPasteboard(name: .drag)
        if pasteboard.changeCount != baseline { dragConfirmed = true }
        guard dragConfirmed, enabled, !flow.isBusy else { return }
        guard NSEvent.modifierFlags.contains(.shift) else { if wheelView?.interactive == false { dismiss() }; return }
        if cachedDragChange != pasteboard.changeCount { cachedDragFiles = Self.files(from: pasteboard); cachedDragChange = pasteboard.changeCount }
        let urls = cachedDragFiles
        guard !urls.isEmpty else { return }
        if wheel?.isVisible != true { present(urls, at: NSEvent.mouseLocation, interactive: false) }
        wheelView?.advanced = NSEvent.modifierFlags.contains(.option)
        if let wheel, let view = wheelView { view.update(at: view.convert(wheel.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)) }
    }
    static func files(from pasteboard: NSPasteboard) -> [URL] {
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        let urls = objects.isEmpty ? (pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] ?? []).map { URL(fileURLWithPath: $0) } : objects
        guard urls.count <= 500, !urls.isEmpty, urls.allSatisfy({ $0.isFileURL && FileKind.identify($0) != nil && FileManager.default.fileExists(atPath: $0.path) }) else { return [] }
        var seen = Set<URL>()
        return urls.map(\.standardizedFileURL).filter { seen.insert($0).inserted }
    }
    func showSelection(_ urls: [URL]) {
        guard !flow.isBusy else { flow.raise(); return }
        if urls.isEmpty {
            let picker = NSOpenPanel(); picker.canChooseFiles = true; picker.canChooseDirectories = true; picker.allowsMultipleSelection = true; picker.title = "Choose files for the format wheel"; picker.prompt = "Show wheel"
            picker.begin { response in if response == .OK { let files = picker.urls.filter { FileKind.identify($0) != nil }; if !files.isEmpty { self.present(files, at: NSEvent.mouseLocation, interactive: true) } } }
        } else { present(urls, at: NSEvent.mouseLocation, interactive: true) }
    }
    private func present(_ urls: [URL], at location: CGPoint, interactive: Bool) {
        guard !urls.isEmpty, !Workspace.shared.isRunning else { return }
        if let view = wheelView, view.interactive != interactive { wheel?.orderOut(nil); wheel = nil; wheelView = nil }
        if wheel == nil {
            let panel = WheelPanel(contentRect: CGRect(x: 0, y: 0, width: 360, height: 382), styleMask: interactive ? [.borderless] : [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "Converty Format Wheel"; panel.identifier = NSUserInterfaceItemIdentifier("ConvertyWheel")
            panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true; panel.hidesOnDeactivate = false
            panel.level = .popUpMenu; panel.isReleasedWhenClosed = false; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.acceptsMouseMovedEvents = true; panel.becomesKeyOnlyIfNeeded = false
            let view = DragWheelView(frame: CGRect(x: 0, y: 0, width: 360, height: 382)); view.controller = self
            panel.contentView = WheelSurfaceView(wheel: view); wheel = panel; wheelView = view
        }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) ?? NSScreen.main!
        let frame = WheelGeometry.frame(center: CGPoint(x: location.x, y: location.y - 11), size: CGSize(width: 360, height: 382), screen: screen.visibleFrame.insetBy(dx: 8, dy: 8))
        wheelView?.urls = urls; wheelView?.interactive = interactive; wheelView?.optionHeld = NSEvent.modifierFlags.contains(.option); wheelView?.advanced = NSEvent.modifierFlags.contains(.option); wheelView?.hovered = nil
        wheel?.setFrame(frame, display: true); wheelView?.refreshAccessibility()
        if interactive { NSApp.activate(ignoringOtherApps: true); wheel?.makeKeyAndOrderFront(nil); wheel?.makeFirstResponder(wheelView) }
        else { wheel?.orderFrontRegardless() }
    }
    func dismiss() { wheel?.orderOut(nil); wheelView?.hovered = nil }
    @discardableResult func accept(_ urls: [URL], choice: WheelChoice) -> Bool {
        guard !flow.isBusy, !Workspace.shared.isRunning, WheelChoice.choices(for: urls, advanced: choice.tool != nil).contains(choice) else { return false }
        let anchor = wheel?.frame ?? CGRect(origin: NSEvent.mouseLocation, size: .zero)
        dismiss(); flow.begin(urls: urls, choice: choice, near: anchor); return true
    }
}
