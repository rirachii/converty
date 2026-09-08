import Foundation
import UniformTypeIdentifiers

public enum FileKind: String, CaseIterable, Identifiable, Sendable {
    case image, video, audio, document, archive
    public var id: String { rawValue }
    public var title: String {
        switch self { case .image: return "Images"; case .video: return "Video"; case .audio: return "Audio"; case .document: return "Documents"; case .archive: return "Archives" }
    }
    public var symbol: String {
        switch self { case .image: return "photo"; case .video: return "film"; case .audio: return "waveform"; case .document: return "doc.text"; case .archive: return "archivebox" }
    }
    public static func identify(_ url: URL) -> FileKind? {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { return .archive }
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "webp", "heic", "heif", "tiff", "tif", "gif", "bmp", "svg": return .image
        case "mp4", "mov", "mkv", "webm", "avi", "m4v": return .video
        case "mp3", "wav", "m4a", "flac", "ogg", "aac", "aiff", "aif": return .audio
        case "pdf", "txt", "md", "rtf": return .document
        case "zip", "tar", "gz", "gzip", "tgz", "rar", "7z", "bz2", "xz": return .archive
        default: return nil
        }
    }
    public func formats(for url: URL) -> [String] {
        switch self {
        case .image: return ["png", "jpg", "webp", "heic", "tiff", "pdf"]
        case .video: return ["mp4", "mov", "mkv", "webm", "gif", "mp3", "m4a", "wav"]
        case .audio: return ["mp3", "m4a", "wav", "flac", "ogg", "aiff"]
        case .document: return url.pathExtension.lowercased() == "pdf" ? ["png", "jpg", "txt", "docx"] : ["pdf", "png", "jpg", "docx"]
        case .archive: return ["zip", "tar", "tgz", "gz"]
        }
    }
}

public enum FileTool: String, CaseIterable, Identifiable, Sendable {
    case convert, compress, resize, crop, metadata, makePDF, collage, readQR
    case trim, mute, speed, snapshot, normalize, channels, mergePDF, splitPDF, extractText, extractArchive
    case joinVideo, splitVideo, audioVideo, silence
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .convert: return "Convert format"; case .compress: return "Compress"; case .resize: return "Resize image"
        case .crop: return "Crop"; case .metadata: return "Remove metadata"; case .makePDF: return "Images to PDF"
        case .collage: return "Make a collage"; case .readQR: return "Read QR codes"; case .trim: return "Trim"
        case .mute: return "Remove audio"; case .speed: return "Change speed"; case .snapshot: return "Save video frame"
        case .normalize: return "Normalize volume"; case .channels: return "Audio channels"; case .mergePDF: return "Merge PDFs"
        case .splitPDF: return "Split PDF pages"; case .extractText: return "Extract text"; case .extractArchive: return "Extract archive"
        case .joinVideo: return "Join videos"; case .splitVideo: return "Split video"; case .audioVideo: return "Audio to video"
        case .silence: return "Trim edge silence"
        }
    }
    public var symbol: String {
        switch self {
        case .convert: return "arrow.triangle.2.circlepath"; case .compress: return "arrow.down.right.and.arrow.up.left"
        case .resize: return "arrow.up.left.and.arrow.down.right"; case .crop: return "crop"; case .metadata: return "tag.slash"
        case .makePDF, .mergePDF: return "doc.on.doc"; case .collage: return "square.grid.2x2"; case .readQR: return "qrcode.viewfinder"
        case .trim, .silence: return "scissors"; case .mute: return "speaker.slash"; case .speed: return "speedometer"
        case .snapshot: return "camera"; case .normalize: return "waveform"; case .channels: return "speaker.wave.2"
        case .splitPDF, .splitVideo: return "rectangle.split.2x1"; case .extractText: return "text.alignleft"
        case .extractArchive: return "shippingbox"; case .joinVideo: return "film.stack"; case .audioVideo: return "music.note.tv"
        }
    }
    public var isGroup: Bool { [.makePDF, .collage, .mergePDF, .joinVideo].contains(self) }
    public func supports(_ url: URL) -> Bool {
        guard let kind = FileKind.identify(url) else { return false }
        if self == .convert { return true }
        switch kind {
        case .image: return [.compress, .resize, .crop, .metadata, .makePDF, .collage, .readQR].contains(self)
        case .video: return [.compress, .crop, .metadata, .trim, .mute, .speed, .snapshot, .joinVideo, .splitVideo].contains(self)
        case .audio: return [.compress, .metadata, .trim, .normalize, .channels, .audioVideo, .silence].contains(self)
        case .document: return url.pathExtension.lowercased() == "pdf" && [.compress, .metadata, .mergePDF, .splitPDF, .extractText, .readQR].contains(self)
        case .archive: return self == .extractArchive
        }
    }
}

public struct ConversionOptions: Sendable {
    public var tool: FileTool = .convert
    public var format = "png"
    public var quality: Double = 0.82
    public var width = 0
    public var height = 0
    public var aspect = "1:1"
    public var cropX: Double = 0.5
    public var cropY: Double = 0.5
    public var cropRect: NormalizedCrop?
    public var start: Double = 0
    public var end: Double = 5
    public var speed: Double = 2
    public var channels = 1
    public var pages = ""
    public var columns = 2
    public var gap = 16
    public var splitPoints = "5, 10"
    public var coverImage: URL?
    public init() {}
}

public struct ConversionRequest: Sendable {
    public let inputs: [URL]
    /// Nil saves beside the first input. Callers submit each independent batch item separately.
    public let destination: URL?
    public let options: ConversionOptions
    public init(inputs: [URL], destination: URL? = nil, options: ConversionOptions) { self.inputs = inputs; self.destination = destination; self.options = options }
}

public enum ConvertyError: LocalizedError {
    case message(String)
    public var errorDescription: String? { switch self { case .message(let value): return value } }
}

public enum FileRules {
    public static func pages(_ value: String, count: Int) throws -> [Int] {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return Array(0..<count) }
        var pages: [Int] = []
        for part in value.split(separator: ",", omittingEmptySubsequences: false) {
            let pieces = part.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false)
            guard (1...2).contains(pieces.count), let start = Int(pieces[0].trimmingCharacters(in: .whitespaces)), let end = Int(pieces.last!.trimmingCharacters(in: .whitespaces)), start > 0, end >= start, end <= count else { throw ConvertyError.message("Choose pages between 1 and \(count), such as 1, 3-5.") }
            for page in start...end where !pages.contains(page - 1) { pages.append(page - 1) }
        }
        return pages
    }
    public static func safeArchivePath(_ path: String) throws -> String {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        let parts = normalized.split(separator: "/")
        guard !normalized.hasPrefix("/"), !normalized.contains("\0"), !parts.contains(".."), !(parts.first.map({ $0.contains(":") }) ?? false) else { throw ConvertyError.message("The archive contains an unsafe file path.") }
        let result = parts.filter { $0 != "." }.joined(separator: "/")
        guard !result.isEmpty else { throw ConvertyError.message("The archive contains an empty file path.") }
        return result
    }
    public static func imageSize(width: Int, height: Int) throws {
        guard width > 0, height > 0, width <= 32768, height <= 32768, Int64(width) * Int64(height) <= 80_000_000 else { throw ConvertyError.message("Choose image dimensions up to 32,768 pixels per side and 80 megapixels total.") }
    }
}
