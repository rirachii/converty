import SwiftUI
import AppKit
import AVFoundation
import ImageIO
import ConvertyCore

struct CropEditor: View {
    let url: URL
    @Binding var options: ConversionOptions
    @State private var image: NSImage?
    @State private var sourceSize = CGSize(width: 1, height: 1)
    @State private var duration = 0.0
    @State private var time = 0.0
    @State private var frameInterval = 1.0 / 30
    @State private var aspect = "Freeform"
    @State private var failure: String?
    @State private var dragStart: NormalizedCrop?
    var crop: NormalizedCrop { options.cropRect ?? NormalizedCrop() }
    var video: Bool { FileKind.identify(url) == .video }
    var ratio: Double? { let values = aspect.split(separator: ":").compactMap { Double($0) }; return values.count == 2 ? values[0] / values[1] : nil }
    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { geometry in
                let scale = min(geometry.size.width / sourceSize.width, geometry.size.height / sourceSize.height)
                let size = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
                ZStack {
                    Color(nsColor: .quaternaryLabelColor).opacity(0.25)
                    if let image {
                        ZStack(alignment: .topLeading) {
                            Image(nsImage: image).resizable().frame(width: size.width, height: size.height)
                            let box = CGRect(x: crop.x * size.width, y: crop.y * size.height, width: crop.width * size.width, height: crop.height * size.height)
                            Path { path in path.addRect(CGRect(origin: .zero, size: size)); path.addRect(box) }.fill(.black.opacity(0.45), style: FillStyle(eoFill: true)).allowsHitTesting(false)
                            Rectangle().fill(.clear).contentShape(Rectangle()).overlay(Rectangle().stroke(.white, lineWidth: 1.5))
                                .overlay { thirds }.frame(width: box.width, height: box.height).offset(x: box.minX, y: box.minY)
                                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                                    if dragStart == nil { dragStart = crop }; guard let start = dragStart else { return }
                                    var next = start; next.x = min(1 - start.width, max(0, start.x + value.translation.width / size.width)); next.y = min(1 - start.height, max(0, start.y + value.translation.height / size.height)); options.cropRect = next
                                }.onEnded { _ in dragStart = nil })
                                .accessibilityLabel("Move crop rectangle")
                            ForEach(0..<4) { corner in
                                let left = corner % 2 == 0, top = corner < 2
                                RoundedRectangle(cornerRadius: 3).fill(.white).frame(width: 11, height: 11).shadow(color: .black.opacity(0.4), radius: 2)
                                    .frame(width: 28, height: 28).contentShape(Rectangle())
                                    .position(x: left ? box.minX : box.maxX, y: top ? box.minY : box.maxY)
                                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in resize(corner: corner, translation: value.translation, size: size) }.onEnded { _ in dragStart = nil })
                                    .accessibilityLabel("Resize crop \(top ? "top" : "bottom") \(left ? "left" : "right") corner")
                            }
                        }.frame(width: size.width, height: size.height)
                    } else if let failure { Text(failure).font(.caption).foregroundStyle(.secondary).padding() }
                    else { ProgressView() }
                }.frame(width: geometry.size.width, height: geometry.size.height).clipShape(RoundedRectangle(cornerRadius: 8))
            }.frame(height: 255)
            HStack {
                Text("Aspect ratio").font(.system(size: 12))
                Picker("Aspect ratio", selection: $aspect) { ForEach(["Freeform", "1:1", "4:3", "3:4", "16:9", "9:16"], id: \.self) { Text($0).tag($0) } }.labelsHidden()
                Spacer()
            }
            HStack {
                Button("Reset") { aspect = "Freeform"; options.cropRect = NormalizedCrop() }.controlSize(.small)
                Spacer()
                let pixels = try? crop.pixels(width: Int(sourceSize.width), height: Int(sourceSize.height), even: video)
                Text("\(Int(pixels?.width ?? 0)) × \(Int(pixels?.height ?? 0)) px").font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
            }
            sizeSlider("Width", width: true)
            sizeSlider("Height", width: false)
            if video && duration > 0 {
                HStack(spacing: 9) {
                    Button { time = max(0, time - frameInterval) } label: { Image(systemName: "backward.frame") }.buttonStyle(.plain).help("Previous frame")
                    Slider(value: $time, in: 0...max(0.001, duration - 0.001)).accessibilityLabel("Video preview time")
                    Button { time = min(duration - 0.001, time + frameInterval) } label: { Image(systemName: "forward.frame") }.buttonStyle(.plain).help("Next frame")
                }
                HStack { Text(stamp(time)); Spacer(); Text(stamp(duration)) }.font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
            }
            Text("Drag the box to move it. Drag a corner to resize.").font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .onChange(of: aspect) { _, _ in fitAspect() }
        .task(id: url) { await load() }
        .task(id: time) {
            guard video else { return }
            do { try await Task.sleep(for: .milliseconds(70)); let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url)); generator.appliesPreferredTrackTransform = true; generator.maximumSize = CGSize(width: 900, height: 900)
                let frame = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)); guard !Task.isCancelled else { return }; image = NSImage(cgImage: frame.image, size: .zero)
            } catch { if !Task.isCancelled && image == nil { failure = "Preview unavailable for this video." } }
        }
    }
    private var thirds: some View {
        GeometryReader { geometry in
            Path { path in
                for part in [1.0 / 3, 2.0 / 3] {
                    path.move(to: CGPoint(x: geometry.size.width * part, y: 0)); path.addLine(to: CGPoint(x: geometry.size.width * part, y: geometry.size.height))
                    path.move(to: CGPoint(x: 0, y: geometry.size.height * part)); path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * part))
                }
            }.stroke(.white.opacity(0.45), lineWidth: 0.5)
        }.allowsHitTesting(false)
    }
    private func sizeSlider(_ title: String, width: Bool) -> some View {
        HStack {
            Text(title).font(.system(size: 11)).frame(width: 40, alignment: .leading)
            Slider(value: Binding(get: { width ? crop.width : crop.height }, set: { value in
                var next = crop
                if width { next.width = value; if let ratio { next.height = min(1, value * sourceSize.width / (ratio * sourceSize.height)); next.width = next.height * ratio * sourceSize.height / sourceSize.width } }
                else { next.height = value; if let ratio { next.width = min(1, value * sourceSize.height * ratio / sourceSize.width); next.height = next.width * sourceSize.width / (ratio * sourceSize.height) } }
                next.x = min(1 - next.width, max(0, crop.x + (crop.width - next.width) / 2)); next.y = min(1 - next.height, max(0, crop.y + (crop.height - next.height) / 2)); options.cropRect = next
            }), in: 0.05...1).accessibilityLabel("Crop \(title.lowercased())")
            Text(width ? crop.width : crop.height, format: .percent.precision(.fractionLength(0))).font(.system(size: 11)).monospacedDigit().frame(width: 34)
        }
    }
    private func fitAspect() {
        guard let ratio else { return }
        var next = crop
        let normalizedRatio = ratio * sourceSize.height / sourceSize.width
        next.width = min(crop.width, crop.height * normalizedRatio); next.height = next.width / normalizedRatio
        next.x = crop.x + (crop.width - next.width) / 2; next.y = crop.y + (crop.height - next.height) / 2; options.cropRect = next
    }
    private func resize(corner: Int, translation: CGSize, size: CGSize) {
        if dragStart == nil { dragStart = crop }; guard let start = dragStart else { return }
        let left = corner % 2 == 0, top = corner < 2
        let anchorX = left ? start.x + start.width : start.x, anchorY = top ? start.y + start.height : start.y
        let movingX = min(1, max(0, (left ? start.x : start.x + start.width) + translation.width / size.width))
        let movingY = min(1, max(0, (top ? start.y : start.y + start.height) + translation.height / size.height))
        var w = max(0.03, left ? anchorX - movingX : movingX - anchorX)
        var h = max(0.03, top ? anchorY - movingY : movingY - anchorY)
        let maxW = left ? anchorX : 1 - anchorX, maxH = top ? anchorY : 1 - anchorY
        w = min(w, maxW); h = min(h, maxH)
        if let ratio { let r = ratio * sourceSize.height / sourceSize.width; h = min(w / r, maxH); w = min(h * r, maxW) }
        options.cropRect = NormalizedCrop(x: left ? anchorX - w : anchorX, y: top ? anchorY - h : anchorY, width: w, height: h)
    }
    private func stamp(_ value: Double) -> String { String(format: "%d:%05.2f", Int(value) / 60, value.truncatingRemainder(dividingBy: 60)) }
    private func load() async {
        do {
            if video {
                let asset = AVURLAsset(url: url)
                duration = try await asset.load(.duration).seconds
                guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw ConvertyError.message("This video has no preview track.") }
                let fps = try await track.load(.nominalFrameRate)
                if fps > 0 { frameInterval = 1 / Double(fps) }
                let size = try await track.load(.naturalSize), transform = try await track.load(.preferredTransform)
                let oriented = size.applying(transform); sourceSize = CGSize(width: abs(oriented.width), height: abs(oriented.height))
            } else {
                let result = await Task.detached { () -> (NSImage?, CGSize) in
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1000] as CFDictionary), let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { let ns = NSImage(contentsOf: url); return (ns, ns?.size ?? CGSize(width: 1, height: 1)) }
                    let width = properties[kCGImagePropertyPixelWidth] as? Double ?? Double(cg.width), height = properties[kCGImagePropertyPixelHeight] as? Double ?? Double(cg.height), orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
                    return (NSImage(cgImage: cg, size: .zero), (5...8).contains(orientation) ? CGSize(width: height, height: width) : CGSize(width: width, height: height))
                }.value
                image = result.0; sourceSize = result.1
            }
        } catch { failure = error.localizedDescription }
    }
}
