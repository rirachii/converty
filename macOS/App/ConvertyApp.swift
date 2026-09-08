import SwiftUI
import AppKit
import Carbon
import ConvertyCore

@main struct ConvertyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var workspace = Workspace.shared
    var body: some Scene {
        Window("Converty", id: "workspace") {
            WorkspaceView().environmentObject(workspace)
                .frame(minWidth: 900, minHeight: 600)
                .tint(Color.converty)
                .onOpenURL { workspace.add([$0]) }
                .background(WindowAccessor())
        }
        .defaultSize(width: 1120, height: 760)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { Button("Add Files…") { workspace.chooseFiles() }.keyboardShortcut("o") }
            CommandMenu("Convert") {
                Button("Convert Selected Files") { workspace.run() }.keyboardShortcut(.return, modifiers: .command).disabled(!workspace.canRun)
                Button("Format Wheel…") { delegate.toggleQuickDrop() }.keyboardShortcut(.space, modifiers: [.command, .shift])
                Divider()
                Button("Show Output Folder") { workspace.revealDestination() }.keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
        MenuBarExtra("Converty", systemImage: "arrow.left.arrow.right") {
            Button("Open Converty") { delegate.showMainWindow() }
            Button("Format Wheel…  ⇧⌘Space") { delegate.toggleQuickDrop() }
            Button("Add Files…") { delegate.showMainWindow(); workspace.chooseFiles() }
            Divider()
            Button("Show Output Folder") { workspace.revealDestination() }
            Divider()
            Button("Quit Converty") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
        Settings { PreferencesView().environmentObject(workspace).tint(.converty) }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var instance: AppDelegate?
    var quickPanel: NSPanel?
    let dragWheel = DragWheelController()
    var hotKey: EventHotKeyRef?
    var handler: EventHandlerRef?
    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.instance = self
        AppAppearance(rawValue: UserDefaults.standard.string(forKey: "native.appearance") ?? "system")?.apply()
        dragWheel.start()
        Workspace.shared.showWindow = { [weak self] in self?.showMainWindow() }
        Workspace.shared.showQuickDrop = { [weak self] in self?.toggleQuickDrop() }
        NSApp.servicesProvider = self; NSUpdateDynamicServices()
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { AppDelegate.instance?.toggleQuickDrop() }; return noErr
        }, 1, &event, nil, &handler)
        let id = EventHotKeyID(signature: 0x43565254, id: 1)
        let status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(cmdKey | shiftKey), id, GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr { Workspace.shared.notice = "The Quick Drop shortcut is in use. Open Quick Drop from the menu bar instead." }
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationWillTerminate(_ notification: Notification) {
        dragWheel.stop()
        Workspace.shared.cancel()
        if let hotKey { UnregisterEventHotKey(hotKey) }; if let handler { RemoveEventHandler(handler) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func application(_ application: NSApplication, open urls: [URL]) { Workspace.shared.add(urls); showMainWindow() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMainWindow(); return true }
    @objc func convertFiles(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        Workspace.shared.add(urls); showMainWindow()
    }
    func showMainWindow() {
        quickPanel?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "ConvertyWorkspace" }) { window.makeKeyAndOrderFront(nil) }
        else { NSApp.windows.first(where: { !($0 is NSPanel) })?.makeKeyAndOrderFront(nil) }
    }
    func toggleQuickDrop() {
        dragWheel.showSelection(Workspace.shared.selected.map(\.url))
    }
    func toggleGridDrop() {
        if let panel = quickPanel, panel.isVisible { panel.orderOut(nil); return }
        if quickPanel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 390), styleMask: [.titled, .closable, .utilityWindow, .fullSizeContentView], backing: .buffered, defer: false)
            panel.title = "Converty Quick Drop"; panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true
            panel.isFloatingPanel = true; panel.level = .floating; panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: QuickDropView().environmentObject(Workspace.shared).tint(.converty))
            quickPanel = panel
        }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main!
        let origin = NSPoint(x: min(max(NSEvent.mouseLocation.x - 190, screen.visibleFrame.minX), screen.visibleFrame.maxX - 380), y: min(max(NSEvent.mouseLocation.y - 200, screen.visibleFrame.minY), screen.visibleFrame.maxY - 420))
        quickPanel?.setFrameOrigin(origin); NSApp.activate(ignoringOtherApps: true); quickPanel?.makeKeyAndOrderFront(nil)
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.identifier = NSUserInterfaceItemIdentifier("ConvertyWorkspace")
            view.window?.isReleasedWhenClosed = false
        }
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}
