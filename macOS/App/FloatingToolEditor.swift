import AppKit
import SwiftUI
import ConvertyCore

@MainActor final class FloatingJob: ObservableObject {
    let inputs: [URL]
    @Published var options = ConversionOptions()
    @Published var progress = 0.0
    @Published var running = false
    @Published var finished = false
    @Published var results: [URL] = []
    @Published var error: String?
    @Published var destination: URL?
    var onStart: (() -> Void)?
    var onFinish: (() -> Void)?
    var onEdit: (() -> Void)?
    var onClose: (() -> Void)?
    private var control: JobControl?
    init(inputs: [URL], choice: WheelChoice) {
        self.inputs = inputs
        options.tool = choice.tool ?? .convert
        if let format = choice.format { options.format = format }
        else {
            switch FileKind.identify(inputs[0]) {
            case .video: options.format = "mp4"
            case .audio: options.format = options.tool == .compress ? "mp3" : ["mp3", "m4a", "wav", "flac", "ogg", "aiff"].contains(inputs[0].pathExtension.lowercased()) ? inputs[0].pathExtension.lowercased() : "wav"
            case .document: options.format = "pdf"
            case .archive: options.format = "zip"
            default: options.format = options.tool == .compress ? "jpg" : ["png", "jpg", "webp", "heic", "tiff"].contains(inputs[0].pathExtension.lowercased()) ? inputs[0].pathExtension.lowercased() : "png"
            }
        }
        if options.tool == .crop { options.cropRect = NormalizedCrop() }
    }
    var title: String { options.tool == .convert ? "Convert to \(options.format.uppercased())" : options.tool.title }
    func start() {
        guard !running else { return }
        let control = JobControl(), options = self.options, destination = self.destination
        self.control = control; running = true; finished = false; error = nil; progress = 0; results = []; onStart?()
        let groups = options.tool.isGroup ? [inputs] : inputs.map { [$0] }
        Task {
            do {
                for (index, group) in groups.enumerated() {
                    let request = ConversionRequest(inputs: group, destination: destination, options: options)
                    let result = try await Task.detached(priority: .userInitiated) {
                        try ConversionEngine.run(request, control: control) { value in Task { @MainActor in self.progress = (Double(index) + value) / Double(groups.count) } }
                    }.value
                    results += result
                }
                finished = true; progress = 1
            } catch is CancellationError { error = "Cancelled. Your original files are unchanged." }
            catch { self.error = error.localizedDescription }
            running = false; self.control = nil; onFinish?()
        }
    }
    func cancel() { control?.cancel() }
    func chooseDestination() {
        let picker = NSOpenPanel(); picker.canChooseFiles = false; picker.canChooseDirectories = true; picker.canCreateDirectories = true; picker.directoryURL = destination ?? inputs[0].deletingLastPathComponent(); picker.prompt = "Save here"
        picker.begin { if $0 == .OK, let url = picker.url { self.destination = url } }
    }
}

@MainActor final class FloatingFlowController {
    private var panel: NSPanel?
    private var job: FloatingJob?
    var isBusy: Bool { job?.running == true }
    func raise() { panel?.makeKeyAndOrderFront(nil) }
    func cancel() { job?.cancel() }
    func begin(urls: [URL], choice: WheelChoice, near anchor: CGRect) {
        panel?.orderOut(nil)
        let job = FloatingJob(inputs: urls, choice: choice); self.job = job
        let panel = WheelPanel(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = job.title; panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true; panel.isFloatingPanel = true; panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false; panel.level = .floating; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if choice.tool == nil { job.running = true }
        panel.contentView = NSHostingView(rootView: FloatingToolEditor(job: job).tint(.converty))
        self.panel = panel
        job.onStart = { [weak self] in self?.resize(to: CGSize(width: 360, height: 205)) }
        job.onEdit = { [weak self, weak job] in guard let job else { return }; job.error = nil; self?.resize(to: CGSize(width: 420, height: job.options.tool == .crop ? 640 : 570)) }
        job.onClose = { [weak self] in self?.panel?.orderOut(nil) }
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) ?? NSScreen.main!
        let size = choice.tool == nil ? CGSize(width: 360, height: 205) : CGSize(width: 420, height: choice.tool == .crop ? 640 : 570)
        panel.setFrame(WheelGeometry.frame(center: CGPoint(x: anchor.midX, y: anchor.midY), size: size, screen: screen.visibleFrame.insetBy(dx: 12, dy: 12)), display: true)
        panel.makeKeyAndOrderFront(nil)
        if choice.tool == nil { job.running = false; job.start() }
    }
    private func resize(to size: CGSize) {
        guard let panel else { return }
        let screen = panel.screen ?? NSScreen.main!
        panel.setFrame(WheelGeometry.frame(center: CGPoint(x: panel.frame.midX, y: panel.frame.midY), size: size, screen: screen.visibleFrame.insetBy(dx: 12, dy: 12)), display: true, animate: false)
    }
}

struct FloatingToolEditor: View {
    @ObservedObject var job: FloatingJob
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: job.finished ? "checkmark.circle.fill" : job.options.tool.symbol).foregroundStyle(Color.converty)
                Text(job.finished ? "Your copy is ready" : job.title).font(.system(size: 14, weight: .semibold))
                Spacer()
            }.padding(.top, 15)
            if job.running || job.finished || job.error != nil { status }
            else {
                if job.options.tool == .crop { CropEditor(url: job.inputs[0], options: $job.options) }
                else {
                    FilePreview(url: job.inputs[0]).frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 9))
                    ScrollView { CompactToolOptions(inputs: job.inputs, options: $job.options).frame(maxWidth: .infinity, alignment: .leading) }
                }
                Spacer(minLength: 0)
                HStack {
                    OutputFolderMenu(destination: job.destination, useOriginals: { job.destination = nil }, chooseFolder: job.chooseDestination).font(.system(size: 11))
                    Spacer()
                    Button("Apply") { job.start() }.primaryActionStyle().controlSize(.large).keyboardShortcut(.defaultAction)
                }
            }
        }.padding(.horizontal, 22).padding(.bottom, 20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(.regularMaterial)
    }
    private var status: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(job.inputs.count == 1 ? job.inputs[0].lastPathComponent : "\(job.inputs.count) files").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            if job.running { ProgressView(value: job.progress); HStack { Text(job.progress, format: .percent.precision(.fractionLength(0))).monospacedDigit().foregroundStyle(.secondary); Spacer(); Button("Cancel") { job.cancel() } }.font(.system(size: 11)) }
            else if let error = job.error { Text(error).font(.system(size: 11)).foregroundStyle(.red).lineLimit(3); HStack { Button("Close") { job.onClose?() }; Spacer(); if job.options.tool != .convert { Button("Edit settings") { job.onEdit?() } } else { Button("Save elsewhere…") { job.chooseDestination() }; Button("Retry") { job.start() } } } }
            else { HStack { Button("Done") { job.onClose?() }; Spacer(); Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(job.results) }.primaryActionStyle() } }
        }
    }
}

struct CompactToolOptions: View {
    let inputs: [URL]
    @Binding var options: ConversionOptions
    private var kind: FileKind? { inputs.first.flatMap(FileKind.identify) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(inputs.count == 1 ? inputs[0].lastPathComponent : "\(inputs.count) files, in selection order").font(.system(size: 11)).foregroundStyle(.secondary)
            if [.compress, .convert].contains(options.tool) { Text("Quality").font(.caption); HStack { Slider(value: $options.quality, in: 0.1...1); Text(options.quality, format: .percent.precision(.fractionLength(0))).font(.caption).monospacedDigit() } }
            if options.tool == .resize { HStack { field("Width (px)", value: $options.width); field("Height (px)", value: $options.height) }; Text("Leave one value at 0 to keep proportions.").font(.caption).foregroundStyle(.secondary) }
            if [.trim, .snapshot].contains(options.tool) { decimal("Start (seconds)", value: $options.start); if options.tool == .trim { decimal("End (seconds)", value: $options.end) } }
            if options.tool == .splitVideo { Text("Split at (seconds)").font(.caption); TextField("5, 10", text: $options.splitPoints).textFieldStyle(.roundedBorder) }
            if options.tool == .speed { Picker("Speed", selection: $options.speed) { Text("0.5×").tag(0.5); Text("1.5×").tag(1.5); Text("2×").tag(2.0) }.pickerStyle(.segmented) }
            if options.tool == .channels { Picker("Channels", selection: $options.channels) { Text("Mono").tag(1); Text("Stereo").tag(2) }.pickerStyle(.segmented) }
            if options.tool == .collage { Stepper("Columns: \(options.columns)", value: $options.columns, in: 1...4); Stepper("Gap: \(options.gap) px", value: $options.gap, in: 0...100, step: 4) }
            if options.tool == .splitPDF { Text("Pages").font(.caption); TextField("All, or 1, 3-5", text: $options.pages).textFieldStyle(.roundedBorder) }
            if options.tool == .audioVideo { Button(options.coverImage?.lastPathComponent ?? "Choose cover image…") { let picker = NSOpenPanel(); picker.allowedContentTypes = [.image]; picker.begin { if $0 == .OK { options.coverImage = picker.url } } } }
            if options.tool == .normalize { Text("Target loudness: −16 LUFS. True peak: −1.5 dB.").font(.caption).foregroundStyle(.secondary) }
            if options.tool == .silence { Text("Trim silence at the beginning and end below −45 dB. Interior pauses stay intact.").font(.caption).foregroundStyle(.secondary) }
            if options.tool == .metadata { Text("Removes file metadata. Visible and embedded content stays intact.").font(.caption).foregroundStyle(.secondary) }
            if options.tool == .joinVideo { Text("Join clips in selection order into one 720p MP4.").font(.caption).foregroundStyle(.secondary) }
            if kind == .document && options.tool == .compress { Text("Rewrites PDF structure without downsampling images. Size savings vary.").font(.caption).foregroundStyle(.secondary) }
        }.font(.system(size: 12))
    }
    private func field(_ title: String, value: Binding<Int>) -> some View { VStack(alignment: .leading) { Text(title); TextField(title, value: value, format: .number.grouping(.never)).textFieldStyle(.roundedBorder) } }
    private func decimal(_ title: String, value: Binding<Double>) -> some View { HStack { Text(title); Spacer(); TextField(title, value: value, format: .number.grouping(.never)).textFieldStyle(.roundedBorder).frame(width: 95) } }
}
