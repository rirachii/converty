import Foundation

public final class JobControl: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var process: Process?
    public init() {}
    public func cancel() {
        lock.lock(); cancelled = true; let active = process; lock.unlock()
        if active?.isRunning == true { active?.terminate() }
    }
    public func check() throws {
        lock.lock(); let value = cancelled; lock.unlock()
        if value { throw CancellationError() }
    }
    func attach(_ value: Process?) throws {
        lock.lock(); process = value; let stopped = cancelled; lock.unlock()
        if stopped { if value?.isRunning == true { value?.terminate() }; throw CancellationError() }
    }
}

public enum LocalProcess {
    public static var ffmpeg: URL? {
        let paths = [
            ProcessInfo.processInfo.environment["CONVERTY_FFMPEG"],
            Bundle.main.url(forResource: "ffmpeg", withExtension: nil, subdirectory: "bin")?.path,
            "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/ffmpeg").path
        ].compactMap { $0 }
        return paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map { URL(fileURLWithPath: $0) }
    }
    @discardableResult
    static func run(_ executable: URL, args: [String], directory: URL? = nil, control: JobControl, progress: (@Sendable (Double) -> Void)? = nil, duration: Double = 0) throws -> String {
        try control.check()
        let process = Process(), pipe = Pipe()
        let logURL = FileManager.default.temporaryDirectory.appendingPathComponent("converty-log-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let log = try FileHandle(forWritingTo: logURL)
        defer { try? log.close(); try? FileManager.default.removeItem(at: logURL) }
        process.executableURL = executable; process.arguments = args; process.currentDirectoryURL = directory
        process.standardError = log; process.standardOutput = pipe; process.standardInput = FileHandle.nullDevice
        try control.attach(process)
        try process.run()
        do { try control.check() } catch { if process.isRunning { process.terminate() }; throw error }
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 600, execute: timeout)
        var captured = Data(), lineBuffer = ""
        while true {
            let data = pipe.fileHandleForReading.availableData
            if data.isEmpty { break }
            if captured.count < 1_000_000 { captured.append(data) }
            if duration > 0, let text = String(data: data, encoding: .utf8) {
                lineBuffer += text
                let lines = lineBuffer.components(separatedBy: "\n"); lineBuffer = lines.last ?? ""
                for line in lines.dropLast() where line.hasPrefix("out_time_us=") {
                    if let time = Double(line.dropFirst(12)) { progress?(min(0.98, max(0.02, time / 1_000_000 / duration))) }
                }
            }
        }
        process.waitUntilExit(); timeout.cancel(); try control.attach(nil); try control.check()
        guard process.terminationStatus == 0 else {
            let details = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            let meaningful = details.components(separatedBy: "\n").filter { !$0.isEmpty }.suffix(3).joined(separator: " ")
            throw ConvertyError.message(meaningful.isEmpty ? "The local engine could not process this file." : String(meaningful.prefix(600)))
        }
        return String(data: captured, encoding: .utf8) ?? ""
    }
}
