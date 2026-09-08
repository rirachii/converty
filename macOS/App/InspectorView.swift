import SwiftUI
import AppKit
import AVKit
import PDFKit
import ImageIO
import ConvertyCore

struct InspectorView: View {
    @EnvironmentObject var workspace: Workspace
    var first: WorkspaceFile? { workspace.selected.first }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack { Text(workspace.selected.count == 1 ? "File preview" : "\(workspace.selected.count) files selected").font(.system(size: 12, weight: .semibold)); Spacer() }
                    if let first {
                        FilePreview(url: first.url, crop: workspace.tool == .crop ? workspace.options : nil).frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 9))
                        Text(first.url.lastPathComponent).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Action").font(.system(size: 11, weight: .semibold))
                        Picker("Action", selection: Binding(get: { workspace.tool }, set: { workspace.configure($0) })) {
                            ForEach(workspace.availableTools) { Text($0.title).tag($0) }
                        }.labelsHidden()
                    }
                    controls
                    if workspace.tool.isGroup {
                        Text("Files are combined in list order. Right-click a file to move it up or down.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    if [.metadata, .compress].contains(workspace.tool), first?.kind == .document {
                        Text("Rewrites the PDF and clears document properties. Embedded images and annotations are preserved; size savings vary.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    if first?.url.pathExtension.lowercased() == "pdf", workspace.options.format == "docx" {
                        Text("Creates an editable text document. Scanned pages need OCR, which is not included.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Save to").font(.system(size: 11, weight: .semibold))
                        OutputFolderMenu(destination: workspace.destination, useOriginals: workspace.useOriginalLocation, chooseFolder: workspace.chooseDestination)
                        if workspace.destination == nil && workspace.tool.isGroup {
                            Text("Combined output is saved beside the first file in list order.").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Text("A new copy is saved. Your original stays untouched.").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }.padding(20)
            }.disabled(workspace.isRunning)
            VStack(spacing: 10) {
                if workspace.isRunning {
                    ProgressView(value: workspace.activeProgress)
                    Button("Cancel") { workspace.cancel() }.frame(maxWidth: .infinity)
                } else {
                    Button { workspace.run() } label: {
                        HStack { Text(workspace.tool == .convert ? "Convert \(workspace.selected.count == 1 ? "file" : "\(workspace.selected.count) files")" : workspace.tool.title); Spacer(); Image(systemName: "arrow.right") }.frame(maxWidth: .infinity)
                    }.primaryActionStyle().controlSize(.large).disabled(!workspace.canRun).keyboardShortcut(.return, modifiers: .command)
                    Text("⌘ Return to run").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }.padding(20)
        }
    }
    @ViewBuilder private var controls: some View {
        if workspace.tool == .convert {
            if !workspace.commonFormats.isEmpty {
                labeled("Output format") {
                    Picker("Output format", selection: Binding(get: { workspace.options.format }, set: { format in for file in workspace.selected { workspace.setFormat(format, for: file.id) } })) {
                        ForEach(workspace.commonFormats, id: \.self) { Text($0.uppercased()).tag($0) }
                    }.labelsHidden()
                }
            } else { Text("Choose an output format on each file in the list.").font(.system(size: 11)).foregroundStyle(.secondary) }
        }
        if [.convert, .compress, .resize, .crop].contains(workspace.tool), [.image, .video, .audio].contains(first?.kind) {
            labeled("Quality") { HStack { Slider(value: $workspace.options.quality, in: 0.1...1); Text(workspace.options.quality, format: .percent.precision(.fractionLength(0))).font(.system(size: 11)).monospacedDigit().frame(width: 32) } }
        }
        if workspace.tool == .resize {
            HStack { number("Width", value: $workspace.options.width); number("Height", value: $workspace.options.height) }
            Text("Pixels. Leave one value at 0 to keep proportions.").font(.system(size: 10)).foregroundStyle(.secondary)
        }
        if workspace.tool == .crop {
            labeled("Aspect ratio") { Picker("Aspect ratio", selection: $workspace.options.aspect) { ForEach(["1:1", "4:3", "3:4", "16:9", "9:16"], id: \.self) { Text($0).tag($0) } }.labelsHidden() }
            labeled("Horizontal position") { Slider(value: $workspace.options.cropX, in: 0...1) }
            labeled("Vertical position") { Slider(value: $workspace.options.cropY, in: 0...1) }
        }
        if [.trim, .snapshot].contains(workspace.tool) {
            decimal(workspace.tool == .snapshot ? "Frame at (seconds)" : "Start (seconds)", value: $workspace.options.start)
            if workspace.tool == .trim { decimal("End (seconds)", value: $workspace.options.end) }
        }
        if workspace.tool == .splitVideo {
            labeled("Split at (seconds)") { TextField("5, 10, 15", text: $workspace.options.splitPoints).textFieldStyle(.roundedBorder) }
            Text("Separate times with commas. Each segment becomes an MP4 in a new folder.").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        if workspace.tool == .speed {
            labeled("Playback speed") { Picker("Playback speed", selection: $workspace.options.speed) { Text("0.5×").tag(0.5); Text("1.5×").tag(1.5); Text("2×").tag(2.0) }.pickerStyle(.segmented) }
        }
        if workspace.tool == .channels {
            labeled("Channels") { Picker("Channels", selection: $workspace.options.channels) { Text("Mono").tag(1); Text("Stereo").tag(2) }.pickerStyle(.segmented) }
        }
        if workspace.tool == .collage {
            Stepper("Columns: \(workspace.options.columns)", value: $workspace.options.columns, in: 1...4)
            Stepper("Gap: \(workspace.options.gap) px", value: $workspace.options.gap, in: 0...100, step: 4)
        }
        if workspace.tool == .splitPDF || (workspace.tool == .convert && first?.url.pathExtension.lowercased() == "pdf" && ["png", "jpg"].contains(workspace.options.format)) {
            labeled("Pages") { TextField("All pages, or 1, 3-5", text: $workspace.options.pages).textFieldStyle(.roundedBorder) }
        }
        if workspace.tool == .audioVideo {
            labeled("Cover image") {
                Button(workspace.options.coverImage?.lastPathComponent ?? "Choose image…") {
                    let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]; panel.allowsMultipleSelection = false
                    panel.begin { if $0 == .OK { workspace.options.coverImage = panel.url } }
                }.lineLimit(1)
            }
        }
        if workspace.tool == .normalize { Text("Balances loudness to −16 LUFS, with a −1.5 dB true-peak target.").font(.system(size: 11)).foregroundStyle(.secondary) }
        if workspace.tool == .silence { Text("Removes silence at the beginning and end below −45 dB. Pauses within the recording remain.").font(.system(size: 11)).foregroundStyle(.secondary) }
        if workspace.tool == .joinVideo { Text("Creates one 720p MP4. Clips keep their proportions and use padding where needed.").font(.system(size: 11)).foregroundStyle(.secondary) }
    }
    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.system(size: 11, weight: .medium)); content() }
    }
    private func number(_ title: String, value: Binding<Int>) -> some View { labeled(title) { TextField(title, value: value, format: .number.grouping(.never)).textFieldStyle(.roundedBorder) } }
    private func decimal(_ title: String, value: Binding<Double>) -> some View { labeled(title) { TextField(title, value: value, format: .number.grouping(.never)).textFieldStyle(.roundedBorder) } }
}

struct FilePreview: View {
    let url: URL
    var crop: ConversionOptions?
    @State private var image: NSImage?
    @State private var player: AVPlayer?
    var body: some View {
        ZStack {
            Color(nsColor: .quaternaryLabelColor).opacity(0.25)
            if let image {
                GeometryReader { geometry in
                    let size = fitted(image.size, into: geometry.size)
                    ZStack {
                        Image(nsImage: image).resizable().scaledToFit().frame(width: geometry.size.width, height: geometry.size.height)
                        if let crop {
                            let parts = crop.aspect.split(separator: ":").compactMap { Double($0) }
                            let ratio = parts.count == 2 ? parts[0] / parts[1] : 1
                            let width = min(size.width, size.height * ratio)
                            let height = width / ratio
                            Rectangle().strokeBorder(.white, lineWidth: 2).shadow(color: .black.opacity(0.7), radius: 1)
                                .frame(width: width, height: height)
                                .position(x: (geometry.size.width - size.width) / 2 + width / 2 + (size.width - width) * crop.cropX, y: (geometry.size.height - size.height) / 2 + height / 2 + (size.height - height) * crop.cropY)
                        }
                    }
                }
            } else if let player { NativeMediaPlayer(player: player) }
            else { Image(systemName: FileKind.identify(url)?.symbol ?? "doc").font(.system(size: 45, weight: .light)).foregroundStyle(.secondary) }
        }
        .task(id: url) {
            player?.pause(); player = nil; image = nil
            let kind = FileKind.identify(url)
            if kind == .image {
                image = await Task.detached {
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1000] as CFDictionary) else { return NSImage(contentsOf: url) }
                    return NSImage(cgImage: cg, size: .zero)
                }.value
            } else if url.pathExtension.lowercased() == "pdf" {
                image = await Task.detached { PDFDocument(url: url)?.page(at: 0)?.thumbnail(of: NSSize(width: 450, height: 400), for: .mediaBox) }.value
            } else if kind == .video || kind == .audio { player = AVPlayer(url: url) }
        }
        .onDisappear { player?.pause() }
    }
    private func fitted(_ size: CGSize, into bounds: CGSize) -> CGSize { let scale = min(bounds.width / max(size.width, 1), bounds.height / max(size.height, 1)); return CGSize(width: size.width * scale, height: size.height * scale) }
}

struct PreferencesView: View {
    @EnvironmentObject var workspace: Workspace
    @AppStorage("native.dragWheel") private var dragWheelEnabled = true
    @AppStorage("native.appearance") private var appearance = AppAppearance.system
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
            }
            Section("Files") {
                LabeledContent("Save to") { OutputFolderMenu(destination: workspace.destination, useOriginals: workspace.useOriginalLocation, chooseFolder: workspace.chooseDestination).disabled(workspace.isRunning) }
                LabeledContent("Default quality") { Slider(value: $workspace.options.quality, in: 0.1...1); Text(workspace.options.quality, format: .percent.precision(.fractionLength(0))).monospacedDigit() }
            }
            Section("Format wheel") { Toggle("Show wheel during Shift-drag", isOn: $dragWheelEnabled); LabeledContent("Formats", value: "⇧ drag"); LabeledContent("Tools", value: "⇧⌥ drag"); Text("Drag a file in Finder while Converty is running. Wheel results are saved beside the source.").font(.caption).foregroundStyle(.secondary) }
            Section { Text("Converty 0.1 · Open source under GPL-3.0\nFiles are processed locally with macOS frameworks and FFmpeg.").font(.caption).foregroundStyle(.secondary) }
        }.formStyle(.grouped).frame(width: 460, height: 470)
            .onChange(of: appearance) { _, value in value.apply() }
            .onChange(of: workspace.options.quality) { _, value in UserDefaults.standard.set(value, forKey: "native.quality") }
    }
}


struct NativeMediaPlayer: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView(); view.player = player; view.controlsStyle = .floating; view.showsFullScreenToggleButton = false; return view
    }
    func updateNSView(_ view: AVPlayerView, context: Context) { if view.player !== player { view.player?.pause(); view.player = player } }
    static func dismantleNSView(_ view: AVPlayerView, coordinator: ()) { view.player?.pause(); view.player = nil }
}
