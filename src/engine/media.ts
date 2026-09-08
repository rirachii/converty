import { FFmpeg } from "@ffmpeg/ffmpeg";
import type { Options, Result } from "../types";
import { categoryOf, extension } from "../catalog";
import { bytesBlob, outputName } from "./utils";

let engine: FFmpeg | undefined;
let loading: Promise<FFmpeg> | undefined;
export function cancelMedia() {
  engine?.terminate();
  engine = undefined;
  loading = undefined;
}
async function getEngine(report: (value: number, message?: string) => void) {
  if (engine?.loaded) return engine;
  if (loading) return loading;
  const current = new FFmpeg();
  engine = current;
  report(1, "Loading the local media engine (32 MB)…");
  loading = current
    .load({
      coreURL: `${location.origin}/engines/ffmpeg-core.js`,
      wasmURL: `${location.origin}/engines/ffmpeg-core.wasm`,
    })
    .then(() => current)
    .catch((error) => {
      if (engine === current) {
        engine = undefined;
        loading = undefined;
      }
      throw error;
    });
  return loading;
}
export function mediaArgs(
  input: string,
  output: string,
  isVideo: boolean,
  options: Options,
) {
  const { operation, format, quality, start, end, speed, channels, aspect } =
    options;
  if (
    ["trim", "snapshot"].includes(operation) &&
    (!Number.isFinite(start) || start < 0)
  )
    throw new Error("The start time must be zero or greater.");
  if (operation === "trim" && (!Number.isFinite(end) || end <= start))
    throw new Error("The end time must be after the start time.");
  const args: string[] = ["-i", input];
  if (operation === "trim")
    args.push("-ss", String(start), "-t", String(end - start));
  if (operation === "snapshot")
    return [...args, "-ss", String(start), "-frames:v", "1", output];
  const audioOnly = ["mp3", "wav", "m4a", "flac", "ogg"].includes(format);
  if (audioOnly) args.push("-vn");
  const vf: string[] = [],
    af: string[] = [];
  if (operation === "crop") {
    const [a, b] = aspect.split(":").map(Number),
      r = a / b;
    if (!Number.isFinite(r) || r <= 0)
      throw new Error("Choose a valid aspect ratio.");
    vf.push(`crop='trunc(min(iw,ih*${r})/2)*2':'trunc(min(ih,iw/${r})/2)*2'`);
  }
  if (operation === "speed") {
    if (![0.5, 1.5, 2].includes(speed))
      throw new Error("Choose a supported playback speed.");
    vf.push(`setpts=PTS/${speed}`);
    af.push(`atempo=${speed}`);
  }
  if (operation === "mute") args.push("-an");
  if (operation === "normalize") af.push("loudnorm=I=-16:TP=-1.5:LRA=11");
  if (operation === "channels")
    args.push("-ac", String(channels === 2 ? 2 : 1));
  if (operation === "metadata")
    args.push("-map_metadata", "-1", "-map_chapters", "-1");
  if (format === "gif")
    vf.push("fps=12", "scale='min(640,iw)':-1:flags=lanczos");
  else if (isVideo && !audioOnly) vf.push("scale=trunc(iw/2)*2:trunc(ih/2)*2");
  if (vf.length) args.push("-vf", vf.join(","));
  if (af.length) args.push("-af", af.join(","));
  if (isVideo && !audioOnly && format !== "gif") {
    if (format === "webm")
      args.push("-c:v", "libvpx", "-b:v", "1M", "-c:a", "libvorbis");
    else
      args.push(
        "-c:v",
        "libx264",
        "-preset",
        "ultrafast",
        "-crf",
        String(Math.round(38 - quality * 0.22)),
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
      );
    if (["mp4", "mov"].includes(format)) args.push("-movflags", "+faststart");
  }
  if (audioOnly) {
    if (format === "mp3")
      args.push("-c:a", "libmp3lame", "-b:a", quality < 70 ? "96k" : "192k");
    if (format === "m4a")
      args.push("-c:a", "aac", "-b:a", quality < 70 ? "96k" : "192k");
    if (format === "wav") args.push("-c:a", "pcm_s16le");
    if (format === "flac") args.push("-c:a", "flac");
    if (format === "ogg") args.push("-c:a", "libvorbis");
  }
  return [...args, output];
}
export async function processMedia(
  file: File,
  options: Options,
  report: (value: number, message?: string) => void,
  signal: AbortSignal,
): Promise<Result[]> {
  const ffmpeg = await getEngine(report);
  signal.throwIfAborted();
  const id = crypto.randomUUID(),
    input = `${id}.${extension(file.name)}`;
  const format = options.operation === "snapshot" ? "png" : options.format;
  const output = `${id}-out.${format}`;
  const messages: string[] = [];
  const progress = ({ progress }: { progress: number }) =>
    report(
      Math.min(98, Math.max(4, Math.round(progress * 100))),
      "Processing on your device…",
    );
  const log = ({ message }: { message: string }) => {
    messages.push(message);
    if (messages.length > 30) messages.shift();
  };
  ffmpeg.on("progress", progress);
  ffmpeg.on("log", log);
  const cancel = () => cancelMedia();
  signal.addEventListener("abort", cancel, { once: true });
  try {
    await ffmpeg.writeFile(input, new Uint8Array(await file.arrayBuffer()));
    report(4, "Processing on your device…");
    const code = await ffmpeg.exec(
      mediaArgs(input, output, categoryOf(file.name) === "video", {
        ...options,
        format,
      }),
      180000,
    );
    signal.throwIfAborted();
    if (code !== 0)
      throw new Error(
        code === 1
          ? "This file could not be processed. Check its format, codec, and time range."
          : "Processing timed out. Try a smaller file or shorter clip.",
      );
    const bytes = await ffmpeg.readFile(output);
    if (typeof bytes === "string" || !bytes.length)
      throw new Error("No output was produced. Check the chosen time range.");
    const mime: Record<string, string> = {
      mp4: "video/mp4",
      mov: "video/quicktime",
      mkv: "video/x-matroska",
      webm: "video/webm",
      gif: "image/gif",
      png: "image/png",
      mp3: "audio/mpeg",
      m4a: "audio/mp4",
      wav: "audio/wav",
      flac: "audio/flac",
      ogg: "audio/ogg",
    };
    return [
      {
        name: outputName(
          file.name,
          format,
          options.operation === "convert" ? "" : options.operation,
        ),
        blob: bytesBlob(bytes, mime[format]),
      },
    ];
  } finally {
    signal.removeEventListener("abort", cancel);
    ffmpeg.off("progress", progress);
    ffmpeg.off("log", log);
    if (ffmpeg.loaded)
      await Promise.allSettled([
        ffmpeg.deleteFile(input),
        ffmpeg.deleteFile(output),
      ]);
  }
}
