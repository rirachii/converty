import AppKit
import ImageIO
import UniformTypeIdentifiers
import Vision

enum ImageEngine {
    static func decode(_ url: URL) throws -> CGImage {
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? Int,
           let height = properties[kCGImagePropertyPixelHeight] as? Int {
            try FileRules.imageSize(width: width, height: height)
            if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(width, height)
            ] as CFDictionary) { return image }
        }
        if let image = NSImage(contentsOf: url), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            try FileRules.imageSize(width: cg.width, height: cg.height); return cg
        }
        throw ConvertyError.message("This image cannot be decoded by macOS.")
    }
    static func context(width: Int, height: Int) throws -> CGContext {
        try FileRules.imageSize(width: width, height: height)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ConvertyError.message("Not enough memory for this image.") }
        context.interpolationQuality = .high; return context
    }
    static func encode(_ image: CGImage, to url: URL, quality: Double, control: JobControl) throws {
        try control.check()
        let ext = url.pathExtension.lowercased()
        if ext == "webp" {
            guard let ffmpeg = LocalProcess.ffmpeg else { throw ConvertyError.message("The bundled media engine is missing.") }
            let temporary = url.deletingLastPathComponent().appendingPathComponent("\(UUID().uuidString).png")
            defer { try? FileManager.default.removeItem(at: temporary) }
            try encode(image, to: temporary, quality: 1, control: control)
            try LocalProcess.run(ffmpeg, args: ["-nostdin", "-v", "error", "-i", temporary.path, "-quality", String(Int(quality * 100)), url.path], control: control)
            return
        }
        let type: UTType
        switch ext { case "jpg", "jpeg": type = .jpeg; case "heic", "heif": type = .heic; case "tif", "tiff": type = .tiff; default: type = .png }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else { throw ConvertyError.message("macOS cannot create this output format.") }
        var output = image
        if type == .jpeg {
            let ctx = try context(width: image.width, height: image.height)
            ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            output = ctx.makeImage()!
        }
        CGImageDestinationAddImage(destination, output, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ConvertyError.message("Could not encode the image. Try PNG or JPG.") }
    }
    static func convert(_ input: URL, options: ConversionOptions, to output: URL, control: JobControl) throws {
        var image = try decode(input)
        if options.tool == .crop, let rect = options.cropRect {
            guard let cropped = image.cropping(to: try rect.pixels(width: image.width, height: image.height)) else { throw ConvertyError.message("This crop could not be created.") }
            image = cropped
        } else if options.tool == .crop {
            let parts = options.aspect.split(separator: ":").compactMap { Double($0) }
            guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { throw ConvertyError.message("Choose a valid aspect ratio.") }
            let ratio = parts[0] / parts[1], width = Double(image.width), height = Double(image.height)
            let cw = min(width, height * ratio), ch = min(height, width / ratio)
            let x = (width - cw) * min(1, max(0, options.cropX)), y = (height - ch) * min(1, max(0, options.cropY))
            guard let crop = image.cropping(to: CGRect(x: x, y: y, width: cw, height: ch).integral) else { throw ConvertyError.message("This crop could not be created.") }
            image = crop
        }
        if options.tool == .resize || options.tool == .compress {
            let width = options.width > 0 ? options.width : options.height > 0 ? Int(Double(image.width) * Double(options.height) / Double(image.height)) : image.width
            let height = options.height > 0 ? options.height : Int(Double(image.height) * Double(width) / Double(image.width))
            let ctx = try context(width: width, height: height)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height)); image = ctx.makeImage()!
        }
        try encode(image, to: output, quality: options.quality, control: control)
    }
    static func collage(_ inputs: [URL], options: ConversionOptions, to output: URL, control: JobControl) throws {
        guard (1...4).contains(options.columns), (0...100).contains(options.gap) else { throw ConvertyError.message("Choose 1-4 columns and spacing from 0 to 100.") }
        let cols = min(inputs.count, options.columns), rows = Int(ceil(Double(inputs.count) / Double(cols))), cell = 640, gap = options.gap
        let ctx = try context(width: cols * cell + (cols + 1) * gap, height: rows * cell + (rows + 1) * gap)
        ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
        for (index, input) in inputs.enumerated() {
            try control.check(); let image = try decode(input), side = min(image.width, image.height)
            let cropped = image.cropping(to: CGRect(x: (image.width - side) / 2, y: (image.height - side) / 2, width: side, height: side))!
            ctx.draw(cropped, in: CGRect(x: gap + (index % cols) * (cell + gap), y: ctx.height - gap - (index / cols + 1) * cell - (index / cols) * gap, width: cell, height: cell))
        }
        try encode(ctx.makeImage()!, to: output, quality: options.quality, control: control)
    }
    static func readQR(_ image: CGImage) throws -> [String] {
        let request = VNDetectBarcodesRequest(); request.symbologies = [.qr]
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap(\.payloadStringValue)
    }
}
