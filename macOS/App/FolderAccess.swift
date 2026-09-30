import AppKit
import ConvertyCore

/// The Mac App Store build runs in the App Sandbox. There, Converty can read the files a user chose,
/// but can write only inside folders the user chose. Folder grants are kept as security-scoped
/// bookmarks, so saving beside originals and a custom Save to folder keep working across launches.
/// The direct-download build is not sandboxed and never asks.
@MainActor enum FolderAccess {
    private static let key = "native.folderBookmarks", limit = 50
    private static var granted: [URL] = []

    static func restore() {
        guard LocalProcess.isSandboxed else { return }
        var changed = false
        granted = (UserDefaults.standard.array(forKey: key) as? [Data] ?? []).compactMap { data in
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale),
                  url.startAccessingSecurityScopedResource() else { changed = true; return nil }
            if stale { changed = true }
            return url
        }
        if changed { save() }
    }
    static func remember(_ folder: URL) {
        guard LocalProcess.isSandboxed else { return }
        let folder = folder.standardizedFileURL
        if !granted.contains(folder) { _ = folder.startAccessingSecurityScopedResource() }
        granted.removeAll { $0 == folder }
        granted.insert(folder, at: 0)
        while granted.count > limit { granted.removeLast().stopAccessingSecurityScopedResource() }
        save()
    }
    static func canWrite(in folder: URL) -> Bool {
        guard LocalProcess.isSandboxed else { return true }
        let path = canonical(folder)
        // The app container, including its temporary and cache folders, is always writable.
        return ([URL(fileURLWithPath: NSHomeDirectory())] + granted).contains { root in
            let base = canonical(root)
            return path == base || path.hasPrefix(base.hasSuffix("/") ? base : base + "/")
        }
    }
    /// Asks once for each output folder without a grant. Returns false when the user declines.
    static func requestWrite(in folders: [URL]) async -> Bool {
        var seen = Set<String>()
        for folder in folders where seen.insert(canonical(folder)).inserted && !canWrite(in: folder) {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = false
            panel.directoryURL = folder; panel.prompt = "Allow"; panel.title = "Allow Converty to save here"
            panel.message = "Converty saves new copies in “\(folder.lastPathComponent)”. Choose Allow to give it access to this folder. Originals are never changed."
            NSApp.activate(ignoringOtherApps: true)
            let response = await withCheckedContinuation { continuation in panel.begin { continuation.resume(returning: $0) } }
            guard response == .OK, let url = panel.url else { return false }
            remember(url)
            guard canWrite(in: folder) else { return false }
        }
        return true
    }
    private static func save() {
        UserDefaults.standard.set(granted.compactMap { try? $0.bookmarkData(options: .withSecurityScope) }, forKey: key)
    }
    private static func canonical(_ url: URL) -> String { url.standardizedFileURL.resolvingSymlinksInPath().path }
}
