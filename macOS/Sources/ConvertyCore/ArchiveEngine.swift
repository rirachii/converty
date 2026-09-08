import Foundation
import CArchive

enum ArchiveEngine {
    static let maxBytes: Int64 = 2_000_000_000
    static let maxEntries = 10_000
    static func error(_ archive: OpaquePointer) -> ConvertyError {
        .message(archive_error_string(archive).map { String(cString: $0) } ?? "This archive could not be processed.")
    }
    static func extract(_ input: URL, to folder: URL, control: JobControl) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let archive = archive_read_new() else { throw ConvertyError.message("The archive reader could not start.") }
        defer { archive_read_free(archive) }
        archive_read_support_filter_all(archive); archive_read_support_format_all(archive); archive_read_support_format_raw(archive)
        guard archive_read_open_filename(archive, input.path, 65536) == ARCHIVE_OK else { throw error(archive) }
        var entry: OpaquePointer?, total: Int64 = 0, count = 0
        while true {
            try control.check()
            let status = archive_read_next_header(archive, &entry)
            if status == ARCHIVE_EOF { break }
            guard status >= ARCHIVE_WARN, let entry, let name = archive_entry_pathname(entry) else { throw error(archive) }
            count += 1
            guard count <= maxEntries else { throw ConvertyError.message("Archives are limited to 10,000 entries.") }
            guard archive_entry_symlink(entry) == nil, archive_entry_hardlink(entry) == nil else { throw ConvertyError.message("Archives containing symbolic or hard links are not extracted.") }
            let nameString = String(cString: name)
            if archive_entry_filetype(entry) == 16384, [".", "./"].contains(nameString) { continue }
            var path = try FileRules.safeArchivePath(nameString)
            if archive_format(archive) == ARCHIVE_FORMAT_RAW, path == "data" { path = input.deletingPathExtension().lastPathComponent }
            let target = folder.appendingPathComponent(path)
            let type = archive_entry_filetype(entry)
            if type == 16384 { try fm.createDirectory(at: target, withIntermediateDirectories: true); continue }
            guard type == 32768 else { throw ConvertyError.message("This archive contains a special file that cannot be extracted.") }
            guard archive_entry_size(entry) <= maxBytes else { throw ConvertyError.message("An archive entry exceeds the 2 GB limit.") }
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard !fm.fileExists(atPath: target.path), fm.createFile(atPath: target.path, contents: nil) else { throw ConvertyError.message("This archive contains duplicate file paths.") }
            let handle = try FileHandle(forWritingTo: target)
            defer { try? handle.close() }
            var buffer = [UInt8](repeating: 0, count: 65536)
            while true {
                try control.check()
                let read = archive_read_data(archive, &buffer, buffer.count)
                if read == 0 { break }
                guard read > 0 else { throw error(archive) }
                total += Int64(read)
                guard total <= maxBytes else { throw ConvertyError.message("Unpacked archives are limited to 2 GB.") }
                try handle.write(contentsOf: Data(buffer.prefix(read)))
            }
        }
        guard count > 0 else { throw ConvertyError.message("The archive is empty.") }
    }
    static func write(folder: URL, to output: URL, control: JobControl) throws {
        let fm = FileManager.default
        let folder = folder.resolvingSymlinksInPath().standardizedFileURL
        guard let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]) else { throw ConvertyError.message("This folder cannot be read.") }
        var inputs: [URL] = [], total: Int64 = 0
        for case let url as URL in enumerator {
            try control.check(); let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
            if values.isSymbolicLink == true { throw ConvertyError.message("Folders containing symbolic links cannot be archived.") }
            if values.isRegularFile == true || values.isDirectory == true { inputs.append(url.resolvingSymlinksInPath().standardizedFileURL) }
            if values.isRegularFile == true { total += Int64(values.fileSize ?? 0) }
            guard total <= maxBytes, inputs.count <= maxEntries else { throw ConvertyError.message("Archive creation is limited to 2 GB and 10,000 files.") }
        }
        guard !inputs.isEmpty else { throw ConvertyError.message("The folder has no files to archive.") }
        guard let archive = archive_write_new() else { throw ConvertyError.message("The archive writer could not start.") }
        defer { archive_write_free(archive) }
        switch output.pathExtension {
        case "zip": archive_write_set_format_zip(archive)
        case "gz":
            guard inputs.count == 1, (try inputs[0].resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { throw ConvertyError.message("GZIP contains one file. Choose ZIP or TAR.GZ for a folder.") }
            archive_write_set_format_raw(archive); archive_write_add_filter_gzip(archive)
        case "tgz": archive_write_set_format_pax_restricted(archive); archive_write_add_filter_gzip(archive)
        default: archive_write_set_format_pax_restricted(archive)
        }
        guard archive_write_open_filename(archive, output.path) == ARCHIVE_OK else { throw error(archive) }
        for input in inputs.sorted(by: { $0.path < $1.path }) {
            try control.check()
            let prefix = folder.path.hasSuffix("/") ? folder.path : folder.path + "/"
            guard input.path.hasPrefix(prefix) else { throw ConvertyError.message("A file is outside the selected folder.") }
            let relative = try FileRules.safeArchivePath(String(input.path.dropFirst(prefix.count)))
            let entry = archive_entry_new()!; defer { archive_entry_free(entry) }
            let directory = (try input.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            archive_entry_set_pathname(entry, relative); archive_entry_set_filetype(entry, directory ? 16384 : 32768); archive_entry_set_perm(entry, directory ? 0o755 : 0o644)
            archive_entry_set_size(entry, directory ? 0 : Int64(try input.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0))
            guard archive_write_header(archive, entry) == ARCHIVE_OK else { throw error(archive) }
            if directory { guard archive_write_finish_entry(archive) == ARCHIVE_OK else { throw error(archive) }; continue }
            let handle = try FileHandle(forReadingFrom: input); defer { try? handle.close() }
            while let data = try handle.read(upToCount: 65536), !data.isEmpty {
                try control.check()
                let written = data.withUnsafeBytes { archive_write_data(archive, $0.baseAddress, $0.count) }
                guard written == data.count else { throw error(archive) }
            }
            guard archive_write_finish_entry(archive) == ARCHIVE_OK else { throw error(archive) }
        }
        guard archive_write_close(archive) == ARCHIVE_OK else { throw error(archive) }
    }
}
