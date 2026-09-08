import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ConvertyCore

enum WorkspaceSection: Hashable {
    case all, kind(FileKind), tools, completed
    var title: String { switch self { case .all: return "All files"; case .kind(let kind): return kind.title; case .tools: return "Tools"; case .completed: return "Completed" } }
}
enum FileStatus { case ready, working, done, failed }
struct WorkspaceFile: Identifiable {
    let id = UUID()
    let url: URL
    let kind: FileKind
    var format: String
    var status: FileStatus = .ready
    var progress: Double = 0
    var results: [URL] = []
    var message: String?
    var size: Int64 { Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
}

@MainActor final class Workspace: ObservableObject {
    static let shared = Workspace()
    @Published var files: [WorkspaceFile] = []
    @Published var selection = Set<UUID>()
    @Published var section: WorkspaceSection = .all
    @Published var tool: FileTool = .convert
    @Published var options = ConversionOptions()
    @Published var isRunning = false
    @Published var notice: String?
    @Published var query = ""
    @Published var destination: URL?
    @Published var activeProgress: Double = 0
    @Published var quickAdvanced = false
    var pendingTool: FileTool?
    private var control: JobControl?
    var showWindow: (() -> Void)?
    var showQuickDrop: (() -> Void)?

    init() {
        if UserDefaults.standard.bool(forKey: "native.useCustomOutputFolder") {
            destination = UserDefaults.standard.string(forKey: "native.outputFolder").map { URL(fileURLWithPath: $0) }
        }
        let quality = UserDefaults.standard.double(forKey: "native.quality")
        options.quality = (0.1...1).contains(quality) ? quality : 0.82
    }
    var selected: [WorkspaceFile] { files.filter { selection.contains($0.id) } }
    var visible: [WorkspaceFile] {
        files.filter { file in
            let matches: Bool
            switch section { case .all, .tools: matches = true; case .kind(let kind): matches = file.kind == kind; case .completed: matches = !file.results.isEmpty }
            return matches && (query.isEmpty || file.url.lastPathComponent.localizedCaseInsensitiveContains(query))
        }
    }
    var availableTools: [FileTool] {
        guard !selected.isEmpty else { return [] }
        return FileTool.allCases.filter { tool in selected.allSatisfy { tool.supports($0.url) } }
    }
    var commonFormats: [String] {
        guard let first = selected.first else { return [] }
        return first.kind.formats(for: first.url).filter { format in selected.allSatisfy { $0.kind.formats(for: $0.url).contains(format) } }
    }
    var canRun: Bool { !isRunning && !selected.isEmpty && selected.allSatisfy { tool.supports($0.url) } && (![FileTool.mergePDF, .collage, .joinVideo].contains(tool) || selected.count >= 2) }
    func chooseFiles() {
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = true; panel.allowsMultipleSelection = true
        panel.title = "Add files to Converty"; panel.prompt = "Add files"
        panel.begin { response in if response == .OK { self.add(panel.urls); self.showWindow?(); if let tool = self.pendingTool { self.pendingTool = nil; DispatchQueue.main.async { self.configure(tool) } } } else { self.pendingTool = nil } }
    }
    func add(_ urls: [URL]) {
        var added: [UUID] = [], errors: [String] = []
        for url in urls {
            guard url.isFileURL else { continue }
            let url = url.standardizedFileURL
            guard let kind = FileKind.identify(url) else { errors.append("\(url.lastPathComponent) is not a supported file type."); continue }
            if let existing = files.first(where: { $0.url == url }) { added.append(existing.id); continue }
            guard files.count < 500 else { errors.append("The workspace holds up to 500 files."); break }
            let formats = kind.formats(for: url), ext = url.pathExtension.lowercased()
            let file = WorkspaceFile(url: url, kind: kind, format: formats.first(where: { $0 != ext }) ?? formats[0])
            files.append(file); added.append(file.id)
        }
        if !added.isEmpty { selection = Set(added); section = .all; query = ""; configure(.convert) }
        if !errors.isEmpty { notice = errors.joined(separator: "\n") }
    }
    func receive(_ providers: [NSItemProvider]) -> Bool {
        let supported = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        Task {
            var urls: [URL] = []
            // Preserve Finder's provider order even if individual item loads finish at different times.
            for provider in supported {
                let url: URL? = await withCheckedContinuation { continuation in
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        if let url = item as? URL { continuation.resume(returning: url) }
                        else if let data = item as? Data { continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil)) }
                        else { continuation.resume(returning: nil) }
                    }
                }
                if let url { urls.append(url) }
            }
            add(urls)
        }
        return !supported.isEmpty
    }
    func configure(_ selectedTool: FileTool) {
        let quality = options.quality
        options = ConversionOptions(); options.quality = quality
        tool = selectedTool; options.tool = selectedTool
        guard let first = selected.first else { return }
        options.format = first.format
        guard selectedTool != .convert else { return }
        switch first.kind {
        case .image: options.format = selectedTool == .compress ? "jpg" : ["png", "jpg", "heic", "tiff", "webp"].contains(first.url.pathExtension.lowercased()) ? first.url.pathExtension.lowercased() : "png"
        case .video: options.format = "mp4"
        case .audio: options.format = selectedTool == .compress ? "mp3" : ["mp3", "wav", "m4a", "flac", "aiff", "ogg"].contains(first.url.pathExtension.lowercased()) ? first.url.pathExtension.lowercased() : "wav"
        case .document: options.format = "pdf"
        case .archive: options.format = "zip"
        }
    }
    func chooseDestination() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.directoryURL = destination ?? selected.first?.url.deletingLastPathComponent(); panel.prompt = "Use folder"; panel.title = "Save converted files to"
        panel.begin { response in if response == .OK, let url = panel.url {
            self.destination = url
            UserDefaults.standard.set(url.path, forKey: "native.outputFolder")
            UserDefaults.standard.set(true, forKey: "native.useCustomOutputFolder")
        } }
    }
    func useOriginalLocation() {
        destination = nil
        UserDefaults.standard.set(false, forKey: "native.useCustomOutputFolder")
    }
    func revealDestination() {
        guard let destination else {
            let chosen = selected.isEmpty ? files : selected
            let urls = chosen.flatMap { $0.results.isEmpty ? [$0.url] : $0.results }
            if !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(urls) }
            return
        }
        do { try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true); NSWorkspace.shared.open(destination) }
        catch { notice = error.localizedDescription }
    }
    func setFormat(_ format: String, for id: UUID) {
        if let index = files.firstIndex(where: { $0.id == id }) { files[index].format = format }
        if selection.contains(id) { options.format = format }
    }
    func remove(_ ids: Set<UUID>) { guard !isRunning else { return }; files.removeAll { ids.contains($0.id) }; selection.subtract(ids) }
    func move(_ id: UUID, by distance: Int) {
        guard !isRunning, let index = files.firstIndex(where: { $0.id == id }), files.indices.contains(index + distance) else { return }
        files.swapAt(index, index + distance)
    }
    func cancel() { control?.cancel() }
    func run(format: String? = nil, ids: Set<UUID>? = nil) {
        guard !isRunning else { return }
        let chosen = files.filter { (ids ?? selection).contains($0.id) }
        guard !chosen.isEmpty else { return }
        var options = self.options
        if let format { options.tool = .convert; options.format = format }
        let groups = options.tool.isGroup ? [chosen] : chosen.map { [$0] }
        let destination = self.destination, control = JobControl()
        self.control = control; notice = nil; isRunning = true; activeProgress = 0; section = .all
        Task {
            var completed = 0
            for group in groups {
                do { try control.check() } catch { break }
                let id = group[0].id
                patch(id) { $0.status = .working; $0.progress = 0; $0.message = nil }
                var job = options
                if options.tool == .convert && format == nil { job.format = group[0].format }
                let request = ConversionRequest(inputs: group.map(\.url), destination: destination, options: job)
                do {
                    let results = try await Task.detached(priority: .userInitiated) {
                        try ConversionEngine.run(request, control: control) { value in
                            Task { @MainActor in self.activeProgress = value; self.patch(id) { $0.progress = value } }
                        }
                    }.value
                    patch(id) { file in
                        file.status = .done; file.progress = 1; file.results = results
                        if job.tool == .compress, let first = results.first,
                           let size = try? first.resourceValues(forKeys: [.fileSizeKey]).fileSize, Int64(size) >= file.size { file.message = "This copy is not smaller. The original is unchanged." }
                    }
                    completed += 1
                } catch is CancellationError { patch(id) { $0.status = .ready; $0.message = "Cancelled. The original is unchanged." }; break }
                catch { patch(id) { $0.status = .failed; $0.message = error.localizedDescription } }
            }
            isRunning = false; self.control = nil
            if completed > 0 {
                let location = destination.map { "to \($0.lastPathComponent)" } ?? (options.tool.isGroup ? "beside the first original" : "beside the originals")
                notice = "Saved \(completed == 1 ? "your file" : "\(completed) results") \(location)."
            }
        }
    }
    private func patch(_ id: UUID, update: (inout WorkspaceFile) -> Void) {
        if let index = files.firstIndex(where: { $0.id == id }) { update(&files[index]) }
    }
    func sample() {
        do {
            let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Converty/Samples")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("Quiet Hills.png")
            if !FileManager.default.fileExists(atPath: url.path) {
                let image = NSImage(size: NSSize(width: 1200, height: 900), flipped: false) { rect in
                    NSColor(red: 0.89, green: 0.87, blue: 0.95, alpha: 1).setFill(); rect.fill()
                    NSColor(red: 0.75, green: 0.66, blue: 0.91, alpha: 1).setFill(); NSBezierPath(ovalIn: NSRect(x: 780, y: 530, width: 200, height: 200)).fill()
                    NSColor(red: 0.51, green: 0.58, blue: 0.68, alpha: 1).setFill()
                    let mountain = NSBezierPath(); mountain.move(to: .zero); mountain.line(to: NSPoint(x: 470, y: 510)); mountain.line(to: NSPoint(x: 950, y: 0)); mountain.close(); mountain.fill()
                    NSColor(red: 0.36, green: 0.46, blue: 0.43, alpha: 1).setFill()
                    let hill = NSBezierPath(); hill.move(to: .zero); hill.curve(to: NSPoint(x: 1200, y: 230), controlPoint1: NSPoint(x: 560, y: 440), controlPoint2: NSPoint(x: 820, y: 100)); hill.line(to: NSPoint(x: 1200, y: 0)); hill.close(); hill.fill(); return true
                }
                let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
                try bitmap.representation(using: .png, properties: [:])!.write(to: url)
            }
            add([url])
        } catch { notice = error.localizedDescription }
    }
}
