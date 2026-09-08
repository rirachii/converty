import XCTest
import PDFKit
import ImageIO
@testable import ConvertyCore

final class ConversionTests: XCTestCase {
    var root: URL!
    var output: URL { root.appendingPathComponent("output") }
    var fixtures: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("tests/fixtures") }
    override func setUpWithError() throws { root = FileManager.default.temporaryDirectory.appendingPathComponent("converty-test-\(UUID().uuidString)"); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    @discardableResult func run(_ inputs: [URL], tool: FileTool = .convert, format: String = "png", configure: (inout ConversionOptions) -> Void = { _ in }) throws -> URL {
        var options = ConversionOptions(); options.tool = tool; options.format = format; configure(&options)
        let results = try ConversionEngine.run(.init(inputs: inputs, destination: output, options: options))
        return try XCTUnwrap(results.first)
    }
    func text(_ name: String = "hello.txt", contents: String = "Hello Converty! Café & 日本語\nSecond line.") throws -> URL { let url = root.appendingPathComponent(name); try contents.write(to: url, atomically: true, encoding: .utf8); return url }
    var probeExecutable: URL? {
        let paths = [ProcessInfo.processInfo.environment["CONVERTY_FFPROBE"]].compactMap { $0 } + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/ffprobe" }
        return paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map { URL(fileURLWithPath: $0) }
    }
    func probe(_ url: URL) throws -> [String: Any] {
        let result = try LocalProcess.run(try XCTUnwrap(probeExecutable), args: ["-v", "error", "-show_streams", "-show_format", "-of", "json", url.path], control: JobControl())
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any])
    }
    func testImageFormatsAndOriginalPreservation() throws {
        let input = fixtures.appendingPathComponent("tiny.png"), before = try Data(contentsOf: input)
        let original = try ImageEngine.decode(input)
        for format in ["jpg", "png", "heic", "tiff", "webp"] {
            let result = try run([input], format: format), decoded = try ImageEngine.decode(result)
            XCTAssertEqual(decoded.width, original.width, format); XCTAssertEqual(decoded.height, original.height, format)
        }
        XCTAssertEqual(try Data(contentsOf: input), before)
    }
    func testResizeCropAndCollage() throws {
        let input = fixtures.appendingPathComponent("tiny.png")
        let resized = try run([input], tool: .resize) { $0.width = 100; $0.height = 50 }
        XCTAssertEqual(try ImageEngine.decode(resized).width, 100); XCTAssertEqual(try ImageEngine.decode(resized).height, 50)
        let cropped = try run([resized], tool: .crop) { $0.aspect = "1:1"; $0.cropX = 1 }
        XCTAssertEqual(try ImageEngine.decode(cropped).width, 50)
        let collage = try run([input, resized], tool: .collage)
        XCTAssertEqual(try ImageEngine.decode(collage).width, 1328)
    }
    func testFreeformCropProducesMatchingPixels() throws {
        let input = fixtures.appendingPathComponent("tiny.png")
        let resized = try run([input], tool: .resize) { $0.width = 200; $0.height = 100 }
        let cropped = try run([resized], tool: .crop) { $0.cropRect = NormalizedCrop(x: 0.25, y: 0.1, width: 0.5, height: 0.6) }
        XCTAssertEqual(try ImageEngine.decode(cropped).width, 100); XCTAssertEqual(try ImageEngine.decode(cropped).height, 60)
        let video = fixtures.appendingPathComponent("short.mov")
        let original = try XCTUnwrap((probe(video)["streams"] as? [[String: Any]])?.first)
        let result = try run([video], tool: .crop, format: "mp4") { $0.cropRect = NormalizedCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6) }
        let stream = try XCTUnwrap((probe(result)["streams"] as? [[String: Any]])?.first)
        let expected = try NormalizedCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6).pixels(width: XCTUnwrap(original["width"] as? Int), height: XCTUnwrap(original["height"] as? Int), even: true)
        XCTAssertEqual(stream["width"] as? Int, Int(expected.width)); XCTAssertEqual(stream["height"] as? Int, Int(expected.height))
    }
    func testImageMetadataRemoval() throws {
        let input = fixtures.appendingPathComponent("tiny.png")
        let tagged = root.appendingPathComponent("tagged.jpg")
        let writer = try XCTUnwrap(CGImageDestinationCreateWithURL(tagged as CFURL, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(writer, try ImageEngine.decode(input), [kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "private-test"]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(writer))
        let result = try run([tagged], tool: .metadata, format: "jpg")
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(result as CFURL, nil))
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        XCTAssertFalse(String(describing: props).contains("private-test"))
    }
    func testQRFromImageAndPDF() throws {
        let qr = fixtures.appendingPathComponent("qr.png")
        let decoded = try run([qr], tool: .readQR)
        let message = try String(contentsOf: decoded); XCTAssertFalse(message.isEmpty)
        let pdf = try run([qr], tool: .makePDF, format: "pdf")
        let pdfQR = try run([pdf], tool: .readQR)
        XCTAssertTrue(try String(contentsOf: pdfQR).contains(message.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
    func testTextPDFMergeSplitAndRender() throws {
        let input = try text(), pdf = try run([input], format: "pdf")
        XCTAssertTrue(try XCTUnwrap(PDFDocument(url: pdf)?.string).contains("Café"))
        let merged = try run([pdf, pdf], tool: .mergePDF, format: "pdf")
        XCTAssertEqual(PDFDocument(url: merged)?.pageCount, 2)
        let split = try run([merged], tool: .splitPDF, format: "pdf")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: split, includingPropertiesForKeys: nil).count, 2)
        let image = try run([merged], format: "png") { $0.pages = "2" }
        XCTAssertGreaterThan(try ImageEngine.decode(image).width, 1000)
        let extracted = try run([pdf], tool: .extractText, format: "txt")
        XCTAssertTrue(try String(contentsOf: extracted).contains("Second line"))
    }
    func testDOCXHasRelationshipsAndEscapedText() throws {
        let docx = try run([text()], format: "docx"), unpacked = root.appendingPathComponent("word")
        try ArchiveEngine.extract(docx, to: unpacked, control: JobControl())
        XCTAssertTrue(FileManager.default.fileExists(atPath: unpacked.appendingPathComponent("_rels/.rels").path))
        let xml = try String(contentsOf: unpacked.appendingPathComponent("word/document.xml"))
        XCTAssertTrue(xml.contains("Café &amp; 日本語"))
    }
    func testArchiveFormatsAndHiddenFilesRoundTrip() throws {
        let folder = root.appendingPathComponent("source"); try FileManager.default.createDirectory(at: folder.appendingPathComponent("nested"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("empty"), withIntermediateDirectories: true)
        try Data("visible".utf8).write(to: folder.appendingPathComponent("nested/file.txt")); try Data("hidden".utf8).write(to: folder.appendingPathComponent(".hidden"))
        for format in ["zip", "tar", "tgz"] {
            let archive = try run([folder], format: format), extracted = try run([archive], tool: .extractArchive)
            XCTAssertTrue((try extracted.appendingPathComponent("empty").resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true)
            XCTAssertEqual(try String(contentsOf: extracted.appendingPathComponent(".hidden")), "hidden")
            XCTAssertEqual(try String(contentsOf: extracted.appendingPathComponent("nested/file.txt")), "visible")
        }
    }
    func testGzipAndArchiveLinks() throws {
        let folder = root.appendingPathComponent("single"); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("payload".utf8).write(to: folder.appendingPathComponent("file.txt"))
        let gz = try run([folder], format: "gz"), extracted = try run([gz], tool: .extractArchive)
        let files = try FileManager.default.contentsOfDirectory(at: extracted, includingPropertiesForKeys: nil)
        XCTAssertEqual(try String(contentsOf: XCTUnwrap(files.first)), "payload")
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("link"), withDestinationURL: folder.appendingPathComponent("file.txt"))
        XCTAssertThrowsError(try run([folder], format: "zip"))
    }
    func testTraversalPageAndDimensionValidation() throws {
        for path in ["../escape", "/absolute", "C:/escape", "a/../../b", "a\\..\\..\\b", ""] { XCTAssertThrowsError(try FileRules.safeArchivePath(path), path) }
        XCTAssertEqual(try FileRules.safeArchivePath("./one/two.txt"), "one/two.txt")
        XCTAssertEqual(try FileRules.pages("3, 1-2, 3", count: 3), [2, 0, 1])
        for pages in ["0", "4", "2-1", "1,", "1-99", "hello"] { XCTAssertThrowsError(try FileRules.pages(pages, count: 3)) }
        XCTAssertThrowsError(try FileRules.imageSize(width: 32768, height: 32768))
    }
    func testCollisionNamesAndCancelledJob() throws {
        let input = fixtures.appendingPathComponent("tiny.png")
        let first = try run([input], format: "jpg"), second = try run([input], format: "jpg")
        XCTAssertNotEqual(first, second); XCTAssertTrue(second.lastPathComponent.hasSuffix("-2.jpg"))
        let control = JobControl(); control.cancel()
        XCTAssertThrowsError(try ConversionEngine.run(.init(inputs: [input], destination: root.appendingPathComponent("cancelled"), options: .init()), control: control)) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("cancelled").path))
    }
    func testDefaultOutputsStayBesideEachOriginalWithoutReplacingFiles() throws {
        let original = try Data(contentsOf: fixtures.appendingPathComponent("tiny.png"))
        for name in ["first folder", "second folder"] {
            let directory = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let input = directory.appendingPathComponent("image.png")
            try original.write(to: input)
            var options = ConversionOptions(); options.format = "png"
            let first = try XCTUnwrap(ConversionEngine.run(.init(inputs: [input], options: options)).first)
            let second = try XCTUnwrap(ConversionEngine.run(.init(inputs: [input], options: options)).first)
            XCTAssertEqual(first.deletingLastPathComponent().path, directory.path)
            XCTAssertEqual(second.deletingLastPathComponent().path, directory.path)
            XCTAssertEqual(first.lastPathComponent, "image-2.png")
            XCTAssertEqual(second.lastPathComponent, "image-3.png")
            XCTAssertEqual(try Data(contentsOf: input), original)
            XCTAssertEqual(try ImageEngine.decode(first).width, try ImageEngine.decode(input).width)
        }
    }
    func testCombinedOutputUsesFirstOriginalAndCustomFolderOverridesDefault() throws {
        let firstFolder = root.appendingPathComponent("first"), secondFolder = root.appendingPathComponent("second")
        for directory in [firstFolder, secondFolder] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        let first = firstFolder.appendingPathComponent("one.png"), second = secondFolder.appendingPathComponent("two.png")
        let original = try Data(contentsOf: fixtures.appendingPathComponent("tiny.png"))
        try original.write(to: first); try original.write(to: second)
        var options = ConversionOptions(); options.tool = .makePDF
        let combined = try XCTUnwrap(ConversionEngine.run(.init(inputs: [first, second], options: options)).first)
        XCTAssertEqual(combined.deletingLastPathComponent().path, firstFolder.path)
        XCTAssertEqual(PDFDocument(url: combined)?.pageCount, 2)
        options.tool = .convert; options.format = "jpg"
        let overridden = try XCTUnwrap(ConversionEngine.run(.init(inputs: [second], destination: firstFolder, options: options)).first)
        XCTAssertEqual(overridden.deletingLastPathComponent().path, firstFolder.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondFolder.appendingPathComponent("two.jpg").path))
        XCTAssertEqual(try Data(contentsOf: first), original)
        XCTAssertEqual(try Data(contentsOf: second), original)
    }
    func testVideoFormatTrimCropSpeedAndMute() throws {
        let video = fixtures.appendingPathComponent("short.mov")
        let mp4 = try run([video], format: "mp4")
        let info = try probe(mp4); XCTAssertEqual((info["streams"] as? [[String: Any]])?.first?["codec_name"] as? String, "h264")
        let trim = try run([video], tool: .trim, format: "mp4") { $0.start = 0.2; $0.end = 0.7 }
        XCTAssertEqual(MediaEngine.duration(trim), 0.5, accuracy: 0.12)
        let crop = try run([video], tool: .crop, format: "mp4") { $0.aspect = "1:1" }
        let stream = (try probe(crop)["streams"] as? [[String: Any]])?.first
        XCTAssertEqual(stream?["width"] as? Int, stream?["height"] as? Int)
        let speed = try run([video], tool: .speed, format: "mp4") { $0.speed = 2 }
        XCTAssertEqual(MediaEngine.duration(speed), MediaEngine.duration(video) / 2, accuracy: 0.15)
        let muted = try run([video], tool: .mute, format: "mp4")
        XCTAssertFalse((try probe(muted)["streams"] as? [[String: Any]] ?? []).contains { $0["codec_type"] as? String == "audio" })
        let frame = try run([video], tool: .snapshot) { $0.start = 0.2 }
        XCTAssertGreaterThan(try ImageEngine.decode(frame).width, 0)
    }
    func testJoinAndSplitVideo() throws {
        let video = fixtures.appendingPathComponent("short.mov")
        let joined = try run([video, video], tool: .joinVideo, format: "mp4")
        XCTAssertEqual(MediaEngine.duration(joined), MediaEngine.duration(video) * 2, accuracy: 0.25)
        let clips = try run([video], tool: .splitVideo, format: "mp4") { $0.splitPoints = "0.4, 0.8" }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: clips, includingPropertiesForKeys: nil).count, 3)
    }
    func testAudioFormatsChannelsNormalizeAndCoverVideo() throws {
        let audio = root.appendingPathComponent("tone.wav")
        try LocalProcess.run(XCTUnwrap(LocalProcess.ffmpeg), args: ["-v", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=1", audio.path], control: JobControl())
        for format in ["mp3", "m4a", "flac", "ogg", "aiff"] { let file = try run([audio], format: format); XCTAssertGreaterThan((try probe(file)["streams"] as? [[String: Any]])?.count ?? 0, 0) }
        let stereo = try run([audio], tool: .channels, format: "wav") { $0.channels = 2 }
        XCTAssertEqual((try probe(stereo)["streams"] as? [[String: Any]])?.first?["channels"] as? Int, 2)
        _ = try run([audio], tool: .normalize, format: "wav")
        _ = try run([audio], tool: .silence, format: "wav")
        let video = try run([audio], tool: .audioVideo, format: "mp4") { $0.coverImage = fixtures.appendingPathComponent("tiny.png") }
        XCTAssertTrue((try probe(video)["streams"] as? [[String: Any]] ?? []).contains { $0["codec_type"] as? String == "video" })
    }
}

final class InteractionGeometryTests: XCTestCase {
    func testWheelCenterOuterBoundaryAndEverySegment() {
        let geometry = WheelGeometry()
        for count in [4, 5, 6, 8] {
            XCTAssertNil(geometry.index(at: geometry.center, count: count))
            XCTAssertNil(geometry.index(at: CGPoint(x: 359, y: 180), count: count))
            for index in 0..<count {
                let angle = -Double.pi / 2 + Double(index) * 2 * Double.pi / Double(count)
                let point = CGPoint(x: 180 + cos(angle) * 110, y: 180 + sin(angle) * 110)
                XCTAssertEqual(geometry.index(at: point, count: count), index)
            }
        }
        XCTAssertNil(geometry.index(at: CGPoint(x: 180, y: 60), count: 0))
    }
    func testWheelClampsToPositiveAndNegativeScreens() {
        for screen in [CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: -1920, y: 0, width: 1920, height: 1080)] {
            for center in [screen.origin, CGPoint(x: screen.maxX, y: screen.maxY)] {
                let frame = WheelGeometry.frame(center: center, size: CGSize(width: 360, height: 382), screen: screen)
                XCTAssertTrue(screen.contains(frame))
            }
        }
    }
    func testCropPixelBoundsAndCodecAlignment() throws {
        let crop = NormalizedCrop(x: 0.2, y: 0.1, width: 0.5, height: 0.6)
        XCTAssertEqual(try crop.pixels(width: 100, height: 100), CGRect(x: 20, y: 10, width: 50, height: 60))
        let even = try crop.pixels(width: 101, height: 99, even: true)
        XCTAssertEqual(Int(even.width) % 2, 0); XCTAssertEqual(Int(even.height) % 2, 0)
        for bad in [NormalizedCrop(x: -0.1), NormalizedCrop(width: 0), NormalizedCrop(x: 0.9, width: 0.2), NormalizedCrop(height: .nan)] { XCTAssertThrowsError(try bad.pixels(width: 100, height: 100)) }
    }
}
