import AppKit
import PDFKit
import CoreText

enum DocumentEngine {
    static func pdf(_ url: URL) throws -> PDFDocument {
        guard let doc = PDFDocument(url: url), !doc.isLocked else { throw ConvertyError.message("This PDF could not be opened, or requires a password.") }
        guard doc.pageCount > 0 else { throw ConvertyError.message("This PDF has no pages.") }; return doc
    }
    static func save(_ pdf: PDFDocument, to url: URL) throws {
        guard pdf.write(to: url) else { throw ConvertyError.message("The PDF could not be saved.") }
    }
    static func imagesPDF(_ inputs: [URL], to output: URL, control: JobControl) throws {
        let pdf = PDFDocument()
        for input in inputs {
            try control.check(); let image = try ImageEngine.decode(input)
            guard let page = PDFPage(image: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))) else { throw ConvertyError.message("This image cannot be embedded in a PDF.") }
            pdf.insert(page, at: pdf.pageCount)
        }
        try save(pdf, to: output)
    }
    static func merge(_ inputs: [URL], to output: URL, control: JobControl) throws {
        let result = PDFDocument()
        for input in inputs {
            let source = try pdf(input)
            for i in 0..<source.pageCount { try control.check(); if let page = source.page(at: i) { result.insert(page, at: result.pageCount) } }
        }
        try save(result, to: output)
    }
    static func render(_ page: PDFPage, dpi: Double = 150) throws -> CGImage {
        let bounds = page.bounds(for: .mediaBox), scale = dpi / 72
        let ctx = try ImageEngine.context(width: Int(ceil(bounds.width * scale)), height: Int(ceil(bounds.height * scale)))
        ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
        ctx.scaleBy(x: scale, y: scale); ctx.translateBy(x: -bounds.minX, y: -bounds.minY); page.draw(with: .mediaBox, to: ctx)
        return ctx.makeImage()!
    }
    static func text(_ url: URL) throws -> String {
        if url.pathExtension.lowercased() == "rtf" { return try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string }
        guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 10_000_000 else { throw ConvertyError.message("Text files are limited to 10 MB.") }
        return try String(contentsOf: url, encoding: .utf8)
    }
    static func textPDF(_ text: String, to output: URL, control: JobControl) throws {
        let attr = NSAttributedString(string: text.isEmpty ? " " : text, attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.black])
        let framesetter = CTFramesetterCreateWithAttributedString(attr)
        var media = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let ctx = CGContext(output as CFURL, mediaBox: &media, nil) else { throw ConvertyError.message("The PDF writer could not start.") }
        var location = 0
        while location < attr.length {
            try control.check(); ctx.beginPDFPage(nil)
            let path = CGPath(rect: CGRect(x: 48, y: 48, width: 499, height: 746), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
            CTFrameDraw(frame, ctx); let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else { throw ConvertyError.message("The text could not be laid out on the page.") }
            location += visible.length; ctx.endPDFPage()
        }
        ctx.closePDF()
    }
    static func word(_ text: String, to output: URL, control: JobControl) throws {
        let folder = output.deletingLastPathComponent().appendingPathComponent("word-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("_rels"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("word"), withIntermediateDirectories: true)
        let escaped = text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        let paragraphs = escaped.components(separatedBy: "\n").map { "<w:p><w:r><w:t xml:space=\"preserve\">\($0)</w:t></w:r></w:p>" }.joined()
        try "<?xml version=\"1.0\" encoding=\"UTF-8\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>\(paragraphs)<w:sectPr/></w:body></w:document>".write(to: folder.appendingPathComponent("word/document.xml"), atomically: true, encoding: .utf8)
        try "<?xml version=\"1.0\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>".write(to: folder.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
        try "<?xml version=\"1.0\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>".write(to: folder.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
        let zip = output.deletingPathExtension().appendingPathExtension("zip")
        // System zip includes the required .rels file, which is hidden by filename.
        try LocalProcess.run(URL(fileURLWithPath: "/usr/bin/zip"), args: ["-q", "-r", zip.path, "."], directory: folder, control: control)
        try FileManager.default.moveItem(at: zip, to: output)
    }
    static func convert(_ input: URL, options: ConversionOptions, work: URL, control: JobControl) throws -> [URL] {
        let source: PDFDocument
        let stem = input.deletingPathExtension().lastPathComponent
        if input.pathExtension.lowercased() != "pdf" {
            let text = try text(input)
            if options.format == "docx" { let url = work.appendingPathComponent(stem + ".docx"); try word(text, to: url, control: control); return [url] }
            let temp = work.appendingPathComponent(stem + ".pdf"); try textPDF(text, to: temp, control: control)
            if options.format == "pdf" { return [temp] }; source = try pdf(temp)
        } else { source = try pdf(input) }
        let indices = try FileRules.pages(options.pages, count: source.pageCount)
        if options.tool == .metadata || options.tool == .compress {
            let result = PDFDocument()
            for index in indices { try control.check(); if let page = source.page(at: index) { result.insert(page, at: result.pageCount) } }
            result.documentAttributes = [:]
            let url = work.appendingPathComponent("\(stem)-\(options.tool.rawValue).pdf"); try save(result, to: url); return [url]
        }
        if options.tool == .extractText || (options.tool == .convert && ["txt", "docx"].contains(options.format)) {
            let text = indices.compactMap { source.page(at: $0)?.string }.joined(separator: "\n\n")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ConvertyError.message("This PDF has no selectable text. OCR is not included yet.") }
            let url = work.appendingPathComponent(stem + (options.format == "docx" ? ".docx" : ".txt"))
            if options.format == "docx" { try word(text, to: url, control: control) } else { try text.write(to: url, atomically: true, encoding: .utf8) }; return [url]
        }
        let folder = work.appendingPathComponent(stem + "-pages")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var qr: [String] = [], outputs: [URL] = []
        for index in indices {
            try control.check(); guard let page = source.page(at: index) else { continue }
            if options.tool == .splitPDF {
                let doc = PDFDocument(); doc.insert(page, at: 0)
                let url = folder.appendingPathComponent("page-\(index + 1).pdf"); try save(doc, to: url); outputs.append(url)
            } else {
                let image = try render(page)
                if options.tool == .readQR { qr += try ImageEngine.readQR(image).map { "Page \(index + 1): \($0)" } }
                else { let url = folder.appendingPathComponent("\(stem)-page-\(index + 1).\(options.format)"); try ImageEngine.encode(image, to: url, quality: options.quality, control: control); outputs.append(url) }
            }
        }
        if options.tool == .readQR {
            guard !qr.isEmpty else { throw ConvertyError.message("No QR codes were found in these pages.") }
            let url = work.appendingPathComponent(stem + "-qr.txt"); try qr.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8); return [url]
        }
        return outputs.count == 1 ? outputs : [folder]
    }
}
