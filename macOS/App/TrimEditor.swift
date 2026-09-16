import AppKit
import AVKit
import SwiftUI
import ConvertyCore

@MainActor private final class TrimPreview: ObservableObject {
    let player = AVPlayer()
    @Published var duration = 0.0
    @Published var position = 0.0
    @Published var playing = false
    @Published var loading = true
    @Published var frames: [NSImage] = []
    @Published var message: String?
    private var observer: Any?
    private var rateObserver: NSKeyValueObservation?
    private var generator: AVAssetImageGenerator?
    private var playbackRequest = UUID()

    func load(_ url: URL) async {
        stop()
        duration = 0; position = 0; frames = []; message = nil; loading = true
        defer { loading = false }
        let asset = AVURLAsset(url: url)
        do {
            let seconds = try await asset.load(.duration).seconds
            try Task.checkCancellation()
            guard seconds.isFinite, seconds > 0 else { throw ConvertyError.message("Duration unavailable.") }
            duration = seconds
            player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
            rateObserver = player.observe(\.rate, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.playing = self.player.rate != 0
                }
            }
            observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.04, preferredTimescale: 600), queue: .main) { [weak self] time in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.position = time.seconds.isFinite ? time.seconds : 0
                    self.playing = self.player.rate != 0
                }
            }
            loading = false
            guard FileKind.identify(url) == .video else { return }
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 160, height: 100)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.2, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.2, preferredTimescale: 600)
            self.generator = generator
            await withTaskCancellationHandler {
                for index in 0..<12 {
                    guard !Task.isCancelled else { return }
                    let time = CMTime(seconds: seconds * (Double(index) + 0.5) / 12, preferredTimescale: 600)
                    if let frame = try? await generator.image(at: time), !Task.isCancelled {
                        frames.append(NSImage(cgImage: frame.image, size: .zero))
                    }
                }
            } onCancel: { generator.cancelAllCGImageGeneration() }
            if frames.isEmpty && !Task.isCancelled { message = "Thumbnails unavailable. You can still drag the range or enter times." }
        } catch {
            if !Task.isCancelled { message = "macOS cannot preview this file. Enter start and end times to trim with FFmpeg." }
        }
    }

    func seek(_ seconds: Double) {
        pause()
        player.currentItem?.forwardPlaybackEndTime = .invalid
        position = seconds
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func toggle(start: Double, end: Double) {
        if playing { pause(); return }
        let request = UUID(); playbackRequest = request
        player.currentItem?.forwardPlaybackEndTime = CMTime(seconds: end, preferredTimescale: 600)
        Task {
            let finished = await player.seek(to: CMTime(seconds: start, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
            guard finished, playbackRequest == request, !Task.isCancelled else { return }
            player.play(); playing = true
        }
    }

    func pause() { playbackRequest = UUID(); player.pause(); playing = false }
    func stop() {
        pause(); generator?.cancelAllCGImageGeneration(); generator = nil
        if let observer { player.removeTimeObserver(observer); self.observer = nil }
        rateObserver?.invalidate(); rateObserver = nil
        player.replaceCurrentItem(with: nil)
    }
}

/// Shared by the floating tool panel and the workspace inspector.
struct TrimEditor: View {
    let url: URL
    @Binding var options: ConversionOptions
    var fileCount = 1
    @StateObject private var preview = TrimPreview()
    @State private var dragStart: Double?
    @FocusState private var focusedHandle: Bool?

    private var range: TrimRange { TrimRange(duration: preview.duration, start: options.start, end: options.end) }
    private var valid: Bool { options.start.isFinite && options.end.isFinite && options.start >= 0 && options.end > options.start && options.end <= preview.duration }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NativeMediaPlayer(player: preview.player, showsControls: false)
                .frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 9))
            if preview.loading {
                ProgressView("Loading timeline…").font(.caption)
            } else if preview.duration > 0 {
                timeline
                HStack {
                    Button { preview.toggle(start: options.start, end: options.end) } label: {
                        Image(systemName: preview.playing ? "pause.fill" : "play.fill")
                    }.disabled(!valid)
                        .accessibilityLabel(preview.playing ? "Pause preview" : "Play selected range")
                        .help("Play the selected range")
                    Text("\(stamp(max(0, options.end - options.start))) selected").monospacedDigit()
                    Spacer(minLength: 0)
                    Button("Reset") { options.start = 0; options.end = preview.duration; preview.seek(0) }
                }.font(.caption)
                Text("Drag the handles to choose what to keep.").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                timeField("Start (seconds)", start: true)
                timeField("End (seconds)", start: false)
            }
            if let message = preview.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            if fileCount > 1 {
                Text("Preview shows the first file. These times apply to all \(fileCount) files; each must contain the selected range.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .task(id: url) { await preview.load(url) }
        .onChange(of: preview.duration) { _, duration in
            guard duration > 0 else { return }
            options.start = range.start; options.end = range.end
            preview.seek(options.start)
        }
        .onChange(of: options.start) { _, value in if value.isFinite, preview.duration > 0 { preview.seek(min(preview.duration, max(0, value))) } }
        .onChange(of: options.end) { _, value in if value.isFinite, preview.duration > 0 { preview.seek(min(preview.duration, max(0, value))) } }
        .onDisappear { preview.stop() }
    }

    private var timeline: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width - 28)
            let left = 14 + width * range.start / preview.duration
            let right = 14 + width * range.end / preview.duration
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    if preview.frames.isEmpty {
                        Rectangle().fill(.quaternary).overlay(Image(systemName: FileKind.identify(url) == .audio ? "waveform" : "film").foregroundStyle(.secondary))
                    } else {
                        ForEach(preview.frames.indices, id: \.self) { index in
                            Image(nsImage: preview.frames[index]).resizable().scaledToFill()
                                .frame(width: width / CGFloat(preview.frames.count), height: 52).clipped()
                        }
                    }
                }.frame(width: width, height: 52).offset(x: 14, y: 4)
                Rectangle().fill(.black.opacity(0.55)).frame(width: max(0, left - 14), height: 52).offset(x: 14, y: 4)
                Rectangle().fill(.black.opacity(0.55)).frame(width: max(0, width + 14 - right), height: 52).offset(x: right, y: 4)
                Rectangle().strokeBorder(Color.converty, lineWidth: 3).frame(width: max(1, right - left), height: 60).offset(x: left)
                Rectangle().fill(.white).frame(width: 2, height: 48)
                    .shadow(color: .black, radius: 1).offset(x: 14 + width * min(1, max(0, preview.position / preview.duration)), y: 6)
                    .allowsHitTesting(false)
                handle(start: true, width: width).offset(x: left - 14)
                handle(start: false, width: width).offset(x: right)
            }
        }.frame(height: 60)
    }

    private func handle(start: Bool, width: Double) -> some View {
        RoundedRectangle(cornerRadius: 4).fill(Color.converty)
            .overlay { Image(systemName: "line.3.horizontal").rotationEffect(.degrees(90)).font(.system(size: 10, weight: .bold)).foregroundStyle(.white) }
            .frame(width: 14, height: 60)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(focusedHandle == start ? Color.primary : .clear, lineWidth: 2))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStart == nil { dragStart = start ? range.start : range.end }
                    edit(start: start, value: (dragStart ?? 0) + value.translation.width / width * preview.duration)
                }
                .onEnded { _ in dragStart = nil })
            .focusable().focused($focusedHandle, equals: start)
            .onMoveCommand { direction in
                let step = direction == .left || direction == .down ? -0.1 : 0.1
                edit(start: start, value: (start ? range.start : range.end) + step)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(start ? "Trim start" : "Trim end")
            .accessibilityValue(stamp(start ? range.start : range.end))
            .accessibilityAdjustableAction { direction in
                edit(start: start, value: (start ? range.start : range.end) + (direction == .increment ? 0.1 : -0.1))
            }
            .help("\(start ? "Start" : "End") of selection. Use arrow keys for 0.1-second adjustments.")
    }

    private func timeField(_ title: String, start: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, value: Binding(get: { start ? options.start : options.end }, set: { value in
                if preview.duration > 0 { edit(start: start, value: value) }
                else if start { options.start = value } else { options.end = value }
            }), format: .number.grouping(.never).precision(.fractionLength(0...3)))
                .textFieldStyle(.roundedBorder).monospacedDigit()
        }
    }

    private func edit(start: Bool, value: Double) {
        var next = range
        if start { next.moveStart(to: value) } else { next.moveEnd(to: value) }
        options.start = next.start; options.end = next.end
        preview.seek(start ? next.start : next.end)
    }

    private func stamp(_ value: Double) -> String {
        guard value.isFinite, value >= 0, value < Double(Int.max) else { return "—" }
        return String(format: "%d:%05.2f", Int(value) / 60, value.truncatingRemainder(dividingBy: 60))
    }
}
