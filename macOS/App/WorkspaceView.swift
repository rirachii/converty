import SwiftUI
import AppKit
import AVKit
import PDFKit
import ConvertyCore

struct WorkspaceView: View {
    @EnvironmentObject var workspace: Workspace
    @State private var targeted = false
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                List(selection: Binding<WorkspaceSection?>(get: { workspace.section }, set: { if let value = $0 { workspace.section = value } })) {
                    Section("Library") {
                        Label("All files", systemImage: "tray.full").tag(WorkspaceSection.all)
                        ForEach(FileKind.allCases) { kind in Label(kind.title, systemImage: kind.symbol).tag(WorkspaceSection.kind(kind)) }
                    }
                    Section {
                        Label("Tools", systemImage: "slider.horizontal.3").tag(WorkspaceSection.tools)
                        Label("Completed", systemImage: "checkmark.circle").tag(WorkspaceSection.completed)
                    }
                }.listStyle(.sidebar)
                Spacer(minLength: 8)
                VStack(alignment: .leading, spacing: 14) {
                    Button { workspace.showQuickDrop?() } label: {
                        HStack { Image(systemName: "circle.dotted.circle"); Text("Format wheel"); Spacer(); Text("⇧").foregroundStyle(.secondary) }
                    }.buttonStyle(.bordered).controlSize(.large).help("Choose files for the floating format wheel")
                    HStack {
                        Label("On-device processing", systemImage: "lock").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        SettingsLink { Image(systemName: "gearshape") }.buttonStyle(.plain).help("Settings").accessibilityLabel("Settings")
                    }
                }.padding(14)
            }.navigationSplitViewColumnWidth(min: 190, ideal: 204, max: 230)
        } detail: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(workspace.section.title).font(.title2.weight(.semibold))
                            if workspace.section == .tools {
                                Text("Choose a tool to get started.").font(.callout).foregroundStyle(.secondary)
                            } else if !workspace.files.isEmpty {
                                Text("\(workspace.visible.count) \(workspace.visible.count == 1 ? "file" : "files")").font(.callout).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }.padding(24)
                    if workspace.section == .tools { ToolLibrary() }
                    else if workspace.visible.isEmpty { emptyState }
                    else {
                        List(selection: $workspace.selection) {
                            ForEach(workspace.visible) { file in
                                NativeFileRow(file: file).tag(file.id)
                                    .contextMenu {
                                        Menu("Convert to") { ForEach(file.kind.formats(for: file.url), id: \.self) { format in Button(format.uppercased()) { workspace.run(format: format, ids: [file.id]) } } }
                                        Menu("Tools") { ForEach(FileTool.allCases.filter { $0 != .convert && $0.supports(file.url) }) { tool in Button(tool.title) { workspace.selection = [file.id]; DispatchQueue.main.async { workspace.configure(tool) } } } }
                                        Divider()
                                        Button("Show Original in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
                                        Button("Move Up") { workspace.move(file.id, by: -1) }.disabled(workspace.isRunning)
                                        Button("Move Down") { workspace.move(file.id, by: 1) }.disabled(workspace.isRunning)
                                        Button("Remove from List") { workspace.remove([file.id]) }.disabled(workspace.isRunning)
                                    }
                            }
                        }.listStyle(.inset).scrollContentBackground(.hidden).padding(.horizontal, 12)
                        .onDeleteCommand { workspace.remove(workspace.selection) }
                    }
                    bottomBar
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                if !workspace.selected.isEmpty && workspace.section != .tools {
                    Divider()
                    InspectorView().frame(width: 284).background(.bar)
                }
            }.background(Color(nsColor: .controlBackgroundColor))
            .overlay { if targeted { RoundedRectangle(cornerRadius: 10).strokeBorder(Color.converty, style: StrokeStyle(lineWidth: 3, dash: [8])).padding(6).background(Color.converty.opacity(0.05)).allowsHitTesting(false) } }
            .onDrop(of: [.fileURL], isTargeted: $targeted) { workspace.receive($0) }
        }
        .searchable(text: $workspace.query, placement: .toolbar, prompt: workspace.section == .tools ? "Find tools" : "Find files")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                OutputFolderMenu(destination: workspace.destination, useOriginals: workspace.useOriginalLocation, chooseFolder: workspace.chooseDestination).disabled(workspace.isRunning)
                Button { workspace.chooseFiles() } label: { Label("Add files", systemImage: "plus") }.keyboardShortcut("o").help("Add files or folders")
            }
        }
        .onChange(of: workspace.selection) { _, _ in if !workspace.isRunning { workspace.configure(.convert) } }
        .overlay(alignment: .bottom) {
            if let message = workspace.notice {
                HStack(spacing: 12) { Text(message).font(.system(size: 12)).lineLimit(3); Button { workspace.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help("Dismiss message") }
                    .padding(.horizontal, 16).padding(.vertical, 12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor).opacity(0.4))).shadow(color: .black.opacity(0.07), radius: 15, y: 5).padding(.bottom, 18).padding(.horizontal, 24)
            }
        }
    }
    private var emptyState: some View {
        VStack(spacing: 16) {
            if !workspace.query.isEmpty {
                ContentUnavailableView.search(text: workspace.query)
            } else if workspace.section == .completed {
                ContentUnavailableView("No converted files yet", systemImage: "checkmark.circle", description: Text("Your finished copies will appear here."))
            } else {
                Image(nsImage: ConvertyArtwork.icon).resizable().interpolation(.high).frame(width: 88, height: 88).accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text("Drop files to convert").font(.title2.weight(.semibold))
                    Text("Images, video, audio, documents, and archives.").font(.callout).foregroundStyle(.secondary)
                }
                Button("Choose Files…") { workspace.chooseFiles() }.primaryActionStyle().controlSize(.large)
                Button("Try a sample image") { workspace.sample() }.buttonStyle(.link).font(.callout)
                Text("Or hold ⇧ while dragging a file in Finder.").font(.caption).foregroundStyle(.secondary).padding(.top, 10)
            }
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button { workspace.revealDestination() } label: { Label(workspace.destination.map { "Save to \($0.lastPathComponent)" } ?? "Save beside originals", systemImage: "folder") }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary).help(workspace.destination?.path ?? "Show original files or completed copies in Finder").disabled(workspace.destination == nil && workspace.files.isEmpty)
                Spacer()
                if !workspace.files.isEmpty { Button("Clear list") { workspace.remove(Set(workspace.files.map(\.id))) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary).disabled(workspace.isRunning) }
                if workspace.isRunning { Button("Cancel") { workspace.cancel() }.controlSize(.small) }
            }.padding(.horizontal, 26).padding(.vertical, 15)
        }
    }
}

struct NativeFileRow: View {
    @EnvironmentObject var workspace: Workspace
    let file: WorkspaceFile
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 13) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path)).resizable().interpolation(.high).frame(width: 38, height: 42).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(file.url.lastPathComponent).font(.system(size: 13, weight: .medium)).lineLimit(1).truncationMode(.middle)
                    HStack(spacing: 6) { Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)); if file.status == .done { Text("· Saved").foregroundStyle(.green) }; if file.status == .failed { Text("· Needs attention").foregroundStyle(.red) } }.font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if file.status == .working { ProgressView(value: file.progress).frame(width: 70); Text(file.progress, format: .percent.precision(.fractionLength(0))).font(.system(size: 10)).monospacedDigit() }
                else if let result = file.results.first, file.status == .done {
                    Button { NSWorkspace.shared.activateFileViewerSelecting([result]) } label: { Image(systemName: "folder.badge.checkmark") }.buttonStyle(.borderless).help("Show converted file in Finder").accessibilityLabel("Show \(result.lastPathComponent) in Finder")
                } else {
                    Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                    Picker("Output format for \(file.url.lastPathComponent)", selection: Binding(get: { file.format }, set: { workspace.setFormat($0, for: file.id) })) { ForEach(file.kind.formats(for: file.url), id: \.self) { Text($0.uppercased()).tag($0) } }.labelsHidden().frame(width: 87).disabled(workspace.isRunning)
                }
            }
            if let message = file.message { Text(message).font(.system(size: 10)).foregroundStyle(file.status == .failed ? Color.red : .secondary).fixedSize(horizontal: false, vertical: true) }
            if !file.results.isEmpty { ForEach(file.results, id: \.self) { url in Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Label(url.lastPathComponent, systemImage: "checkmark").lineLimit(1).truncationMode(.middle) }.font(.system(size: 10)).buttonStyle(.link) } }
        }.padding(.vertical, 10).padding(.horizontal, 3)
    }
}

struct ToolLibrary: View {
    @EnvironmentObject var workspace: Workspace
    private var tools: [FileTool] {
        FileTool.allCases.filter { $0 != .convert && (workspace.query.isEmpty || $0.title.localizedCaseInsensitiveContains(workspace.query)) }
    }
    var body: some View {
        if tools.isEmpty {
            ContentUnavailableView.search(text: workspace.query).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else { ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 265), spacing: 20)], spacing: 2) {
                ForEach(tools) { tool in
                    Button {
                        let matching = workspace.files.filter { tool.supports($0.url) }
                        if matching.isEmpty { workspace.pendingTool = tool; workspace.chooseFiles() }
                        else { workspace.selection = Set(tool.isGroup ? matching.map(\.id) : Array(matching.prefix(1)).map(\.id)); workspace.section = .all; DispatchQueue.main.async { workspace.configure(tool) } }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: tool.symbol).font(.system(size: 19, weight: .regular)).foregroundStyle(Color.converty).frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tool.title).font(.system(size: 13, weight: .medium))
                                Text(tool.isGroup ? "Combine files" : tool.fileTypes).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                        }.frame(maxWidth: .infinity, minHeight: 46, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 9).contentShape(Rectangle())
                    }.buttonStyle(ToolRowStyle())
                }
            }.padding(.horizontal, 16).padding(.bottom, 24)
        } }
    }
}

private struct ToolRowStyle: ButtonStyle {
    @Environment(\.colorSchemeContrast) private var contrast
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.converty.opacity(0.14) : Color.primary.opacity(contrast == .increased ? 0.07 : 0.025), in: RoundedRectangle(cornerRadius: 10))
    }
}

private extension FileTool {
    var fileTypes: String {
        switch self {
        case .resize, .collage, .makePDF: return "Images"
        case .crop: return "Images and video"
        case .compress, .metadata, .convert: return "Images, media, and PDF"
        case .readQR: return "Images and PDF"
        case .trim: return "Video and audio"
        case .mute, .speed, .snapshot, .joinVideo, .splitVideo: return "Video"
        case .normalize, .channels, .audioVideo, .silence: return "Audio"
        case .mergePDF, .splitPDF, .extractText: return "PDF documents"
        case .extractArchive: return "Archives"
        }
    }
}
