import Foundation
import AVFoundation

enum MediaEngine {
    static func duration(_ url: URL) -> Double {
        let seconds = AVURLAsset(url: url).duration.seconds
        return seconds.isFinite ? seconds : 0
    }
    static func convert(_ input: URL, options: ConversionOptions, to output: URL, control: JobControl, progress: @escaping @Sendable (Double) -> Void) throws {
        guard let executable = LocalProcess.ffmpeg else { throw ConvertyError.message("The media engine is missing. Rebuild Converty with FFmpeg bundled.") }
        let kind = FileKind.identify(input), format = output.pathExtension, duration = duration(input)
        var args = ["-nostdin", "-v", "error", "-progress", "pipe:1", "-i", input.path]
        let audioOnly = ["mp3", "m4a", "wav", "flac", "ogg", "aiff"].contains(format)
        var vf: [String] = [], af: [String] = []
        if options.tool == .audioVideo {
            guard let cover = options.coverImage else { throw ConvertyError.message("Choose a still image for the video.") }
            let png = output.deletingLastPathComponent().appendingPathComponent("cover-\(UUID().uuidString).png")
            defer { try? FileManager.default.removeItem(at: png) }
            try ImageEngine.encode(ImageEngine.decode(cover), to: png, quality: 1, control: control)
            try LocalProcess.run(executable, args: ["-nostdin", "-v", "error", "-progress", "pipe:1", "-loop", "1", "-i", png.path, "-i", input.path, "-c:v", "libx264", "-tune", "stillimage", "-preset", "fast", "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-c:a", "aac", "-pix_fmt", "yuv420p", "-shortest", "-movflags", "+faststart", output.path], control: control, progress: progress, duration: duration)
            return
        }
        if options.tool == .trim || options.tool == .snapshot {
            guard options.start.isFinite, options.start >= 0, duration == 0 || options.start < duration else { throw ConvertyError.message("The start time must be within the file.") }
            args += ["-ss", String(options.start)]
        }
        if options.tool == .trim {
            guard options.end.isFinite, options.end > options.start, duration == 0 || options.end <= duration + 0.1 else { throw ConvertyError.message("Choose an end time after the start and within the file.") }
            args += ["-t", String(options.end - options.start)]
        }
        if options.tool == .snapshot {
            args += ["-frames:v", "1", output.path]
            try LocalProcess.run(executable, args: args, control: control); return
        }
        if audioOnly { args += ["-vn"] }
        if options.tool == .mute { args += ["-an"] }
        if options.tool == .metadata { args += ["-map_metadata", "-1", "-map_chapters", "-1"] }
        if options.tool == .crop, let rect = options.cropRect {
            guard let track = AVURLAsset(url: input).tracks(withMediaType: .video).first else { throw ConvertyError.message("macOS could not read this video for cropping.") }
            let transformed = track.naturalSize.applying(track.preferredTransform)
            let pixels = try rect.pixels(width: Int(abs(transformed.width)), height: Int(abs(transformed.height)), even: true)
            vf += ["crop=\(Int(pixels.width)):\(Int(pixels.height)):\(Int(pixels.minX)):\(Int(pixels.minY))"]
        } else if options.tool == .crop {
            let p = options.aspect.split(separator: ":").compactMap { Double($0) }
            guard p.count == 2, p[0] > 0, p[1] > 0 else { throw ConvertyError.message("Choose a valid crop ratio.") }
            let ratio = p[0] / p[1], x = min(1, max(0, options.cropX)), y = min(1, max(0, options.cropY))
            vf += ["crop='trunc(min(iw,ih*\(ratio))/2)*2':'trunc(min(ih,iw/\(ratio))/2)*2':'(iw-ow)*\(x)':'(ih-oh)*\(y)'"]
        }
        if options.tool == .speed {
            guard [0.5, 1.5, 2.0].contains(options.speed) else { throw ConvertyError.message("Choose 0.5, 1.5, or 2 times speed.") }
            vf += ["setpts=(PTS-STARTPTS)/\(options.speed)"]; af += ["atempo=\(options.speed)"]
            if duration > 0 { args += ["-t", String(duration / options.speed)] }
        }
        if options.tool == .normalize { af += ["loudnorm=I=-16:TP=-1.5:LRA=11"] }
        if options.tool == .channels { args += ["-ac", options.channels == 2 ? "2" : "1"] }
        if options.tool == .silence { af += ["silenceremove=start_periods=1:start_duration=0.05:start_threshold=-45dB", "areverse", "silenceremove=start_periods=1:start_duration=0.05:start_threshold=-45dB", "areverse"] }
        if format == "gif" { vf += ["fps=12", "scale='min(800,iw)':-1:flags=lanczos"] }
        else if kind == .video && !audioOnly { vf += ["scale=trunc(iw/2)*2:trunc(ih/2)*2"] }
        if !vf.isEmpty { args += ["-vf", vf.joined(separator: ",")] }
        if !af.isEmpty { args += ["-af", af.joined(separator: ",")] }
        if kind == .video && !audioOnly && format != "gif" {
            if format == "webm" { args += ["-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "32", "-c:a", "libopus"] }
            else { args += ["-c:v", "libx264", "-preset", "fast", "-crf", String(Int(38 - options.quality * 22)), "-pix_fmt", "yuv420p", "-c:a", "aac"] }
            if ["mp4", "mov"].contains(format) { args += ["-movflags", "+faststart"] }
        }
        if audioOnly {
            switch format {
            case "mp3": args += ["-c:a", "libmp3lame", "-b:a", options.quality < 0.7 ? "96k" : "192k"]
            case "m4a": args += ["-c:a", "aac", "-b:a", options.quality < 0.7 ? "96k" : "192k"]
            case "wav": args += ["-c:a", "pcm_s16le"]
            case "flac": args += ["-c:a", "flac"]
            case "ogg": args += ["-c:a", "libvorbis"]
            default: args += ["-c:a", "pcm_s16be"]
            }
        }
        args.append(output.path)
        try LocalProcess.run(executable, args: args, control: control, progress: progress, duration: options.tool == .trim ? options.end - options.start : duration / (options.tool == .speed ? options.speed : 1))
    }
    static func join(_ inputs: [URL], work: URL, control: JobControl, progress: @escaping @Sendable (Double) -> Void) throws -> URL {
        guard let executable = LocalProcess.ffmpeg else { throw ConvertyError.message("The media engine is missing.") }
        var list = ""
        for (index, input) in inputs.enumerated() {
            try control.check()
            let output = work.appendingPathComponent("segment-\(index).mp4")
            let hasAudio = !AVURLAsset(url: input).tracks(withMediaType: .audio).isEmpty
            var args = ["-nostdin", "-v", "error", "-i", input.path]
            if !hasAudio { args += ["-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo"] }
            args += ["-vf", "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1", "-r", "30", "-c:v", "libx264", "-preset", "fast", "-crf", "23", "-c:a", "aac", "-ar", "48000", "-ac", "2", "-shortest", output.path]
            try LocalProcess.run(executable, args: args, control: control)
            list += "file 'segment-\(index).mp4'\n"; progress(Double(index + 1) / Double(inputs.count + 1))
        }
        let manifest = work.appendingPathComponent("join.txt"); try list.write(to: manifest, atomically: true, encoding: .utf8)
        let output = work.appendingPathComponent("joined-video.mp4")
        try LocalProcess.run(executable, args: ["-nostdin", "-v", "error", "-f", "concat", "-safe", "1", "-i", manifest.path, "-c", "copy", "-movflags", "+faststart", output.path], control: control)
        return output
    }
    static func split(_ input: URL, options: ConversionOptions, work: URL, control: JobControl, progress: @escaping @Sendable (Double) -> Void) throws -> URL {
        let duration = duration(input)
        let parts = options.splitPoints.split(separator: ",", omittingEmptySubsequences: false)
        let points = parts.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard duration > 0, points.count == parts.count, !points.isEmpty, points.count <= 100, points.allSatisfy({ $0.isFinite && $0 > 0 && $0 < duration }), Set(points).count == points.count else { throw ConvertyError.message("Enter unique split times in seconds, within the video's duration.") }
        let times = [0.0] + points.sorted() + [duration]
        let folder = work.appendingPathComponent(input.deletingPathExtension().lastPathComponent + "-clips")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for index in 0..<(times.count - 1) {
            var segment = options; segment.tool = .trim; segment.start = times[index]; segment.end = times[index + 1]; segment.format = "mp4"
            try convert(input, options: segment, to: folder.appendingPathComponent("clip-\(index + 1).mp4"), control: control, progress: { _ in })
            progress(Double(index + 1) / Double(times.count - 1))
        }
        return folder
    }
}
