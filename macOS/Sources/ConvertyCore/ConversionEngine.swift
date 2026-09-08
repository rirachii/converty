import Foundation

public enum ConversionEngine {
    public static func run(_ request: ConversionRequest, control: JobControl = JobControl(), progress: @escaping @Sendable (Double) -> Void = { _ in }) throws -> [URL] {
        guard let input = request.inputs.first, let kind = FileKind.identify(input) else { throw ConvertyError.message("Choose a supported file first.") }
        let options = request.options
        let destination = request.destination ?? input.deletingLastPathComponent()
        guard request.inputs.allSatisfy({ options.tool.supports($0) }), options.quality.isFinite, (0.1...1).contains(options.quality) else { throw ConvertyError.message("These files or settings do not match the chosen tool.") }
        if [.mergePDF, .collage, .joinVideo].contains(options.tool), request.inputs.count < 2 { throw ConvertyError.message("Choose at least two files for this tool.") }
        try control.check()
        let fm = FileManager.default, work = fm.temporaryDirectory.appendingPathComponent("Converty-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        let suffix = options.tool == .convert ? "" : "-\(options.tool.rawValue)"
        let stem = input.deletingPathExtension().lastPathComponent
        var format = options.format
        if [.makePDF, .mergePDF].contains(options.tool) { format = "pdf" }
        if [.collage, .snapshot].contains(options.tool) { format = "png" }
        if [.readQR, .extractText].contains(options.tool) { format = "txt" }
        if [.audioVideo, .joinVideo, .splitVideo].contains(options.tool) { format = "mp4" }
        guard !format.isEmpty, format.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { throw ConvertyError.message("Choose a valid output format.") }
        let output = work.appendingPathComponent("\(stem)\(suffix).\(format)")
        progress(0.02)
        let results: [URL]
        switch options.tool {
        case .makePDF: try DocumentEngine.imagesPDF(request.inputs, to: output, control: control); results = [output]
        case .mergePDF: try DocumentEngine.merge(request.inputs, to: output, control: control); results = [output]
        case .collage: try ImageEngine.collage(request.inputs, options: options, to: output, control: control); results = [output]
        case .joinVideo: results = [try MediaEngine.join(request.inputs, work: work, control: control, progress: progress)]
        case .splitVideo: results = [try MediaEngine.split(input, options: options, work: work, control: control, progress: progress)]
        default:
            switch kind {
            case .image:
                if options.tool == .readQR {
                    let codes = try ImageEngine.readQR(ImageEngine.decode(input))
                    guard !codes.isEmpty else { throw ConvertyError.message("No QR codes were found in this image.") }
                    try codes.joined(separator: "\n").write(to: output, atomically: true, encoding: .utf8)
                } else if format == "pdf" { try DocumentEngine.imagesPDF([input], to: output, control: control) }
                else { try ImageEngine.convert(input, options: options, to: output, control: control) }
                results = [output]
            case .document:
                var documentOptions = options; documentOptions.format = format
                results = try DocumentEngine.convert(input, options: documentOptions, work: work, control: control)
            case .video, .audio:
                try MediaEngine.convert(input, options: options, to: output, control: control, progress: progress); results = [output]
            case .archive:
                let folder = work.appendingPathComponent(stem + "-extracted")
                let isFolder = (try? input.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                if isFolder {
                    guard options.tool != .extractArchive else { throw ConvertyError.message("This is already a folder. Choose a format to archive it.") }
                    try ArchiveEngine.write(folder: input, to: output, control: control); results = [output]
                } else {
                    try ArchiveEngine.extract(input, to: folder, control: control)
                    if options.tool == .extractArchive { results = [folder] }
                    else { try ArchiveEngine.write(folder: folder, to: output, control: control); results = [output] }
                }
            }
        }
        try control.check(); progress(0.98)
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        var exported: [URL] = []
        do {
            for result in results {
                try control.check()
                if (try result.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]).isRegularFile) == true,
                   (try result.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) == 0 { throw ConvertyError.message("The engine produced an empty file. Check the selected time range.") }
                exported.append(try export(result, into: destination))
            }
        } catch { for url in exported { try? fm.removeItem(at: url) }; throw error }
        progress(1); return exported
    }
    static func export(_ source: URL, into directory: URL) throws -> URL {
        let fm = FileManager.default
        let isFolder = (try? source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let stem = isFolder ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent
        let ext = isFolder || source.pathExtension.isEmpty ? "" : "." + source.pathExtension
        for index in 1...10_000 {
            let name = stem + (index == 1 ? "" : "-\(index)") + ext
            let target = directory.appendingPathComponent(name)
            do { try fm.copyItem(at: source, to: target); return target }
            catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError { continue }
        }
        throw ConvertyError.message("Too many files with this name already exist in the output folder.")
    }
}
