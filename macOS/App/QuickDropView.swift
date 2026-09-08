import SwiftUI
import AppKit
import ConvertyCore

struct QuickDropView: View {
    @EnvironmentObject var workspace: Workspace
    @State private var targeted = false
    var body: some View {
        VStack(spacing: 16) {
            HStack { Label("Converty", systemImage: "arrow.left.arrow.right").font(.headline); Spacer(); Button { workspace.showWindow?() } label: { Image(systemName: "arrow.up.right.square") }.buttonStyle(.plain).help("Open workspace") }.padding(.top, 18)
            if workspace.isRunning {
                Spacer(); ProgressView(value: workspace.activeProgress); Text("Converting on your Mac…").font(.system(size: 12)); Button("Cancel") { workspace.cancel() }; Spacer()
            } else if let file = workspace.selected.first {
                HStack(spacing: 10) { Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path)).resizable().frame(width: 38, height: 38); VStack(alignment: .leading, spacing: 4) { Text(workspace.selected.count == 1 ? file.url.lastPathComponent : "\(workspace.selected.count) files selected").font(.system(size: 12, weight: .medium)).lineLimit(1); Text(file.status == .done ? "Saved. Ready in your output folder." : "Choose a format below").font(.system(size: 10)).foregroundStyle(.secondary) }; Spacer() }
                if let message = file.message, file.status == .failed { Text(message).font(.system(size: 10)).foregroundStyle(.red).lineLimit(3) }
                Picker("Mode", selection: $workspace.quickAdvanced) { Text("Formats").tag(false); Text("Tools").tag(true) }.pickerStyle(.segmented)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        if workspace.quickAdvanced {
                            ForEach(workspace.availableTools.filter { $0 != .convert }) { tool in
                                Button { workspace.configure(tool); workspace.showWindow?() } label: { VStack(spacing: 7) { Image(systemName: tool.symbol); Text(tool.title).font(.system(size: 9)).lineLimit(2).multilineTextAlignment(.center) }.frame(maxWidth: .infinity, minHeight: 60) }.buttonStyle(.bordered)
                            }
                        } else {
                            ForEach(workspace.commonFormats, id: \.self) { format in
                                Button { workspace.run(format: format) } label: { Text(format.uppercased()).font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity, minHeight: 38) }.buttonStyle(.bordered)
                            }
                        }
                    }
                    if workspace.commonFormats.isEmpty && !workspace.quickAdvanced { Button("Choose formats in workspace") { workspace.showWindow?() } }
                }
                HStack { Button("Add files…") { workspace.chooseFiles() }; Spacer(); if file.status == .done { Button("Show result") { NSWorkspace.shared.activateFileViewerSelecting(file.results) } } else { Text("Drop more files here").font(.system(size: 10)).foregroundStyle(.secondary) } }
            } else {
                Spacer(); Image(systemName: "square.and.arrow.down").font(.system(size: 38, weight: .light)).foregroundStyle(Color.converty)
                Text("Drop files here").font(.system(size: 20, weight: .medium)); Text("Choose a format. Get a fresh copy.").font(.system(size: 12)).foregroundStyle(.secondary)
                Button("Choose files…") { workspace.chooseFiles() }.buttonStyle(.borderedProminent); Spacer()
                Text("⇧⌘Space opens this window anywhere").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }.padding(22).frame(width: 380, height: 390).background(.regularMaterial)
        .overlay { if targeted { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.converty, lineWidth: 3).padding(5).allowsHitTesting(false) } }
        .onDrop(of: [.fileURL], isTargeted: $targeted) { workspace.receive($0) }
    }
}
