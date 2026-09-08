import type { Category, Tool } from "./types";

export const categories: { id: Category; name: string; formats: string }[] = [
  { id: "image", name: "Images", formats: "JPG, PNG, WebP, GIF, SVG, TIFF" },
  { id: "video", name: "Video", formats: "MP4, MOV, MKV, WebM" },
  { id: "audio", name: "Audio", formats: "MP3, WAV, M4A, FLAC, OGG" },
  { id: "document", name: "Documents", formats: "PDF, TXT" },
  { id: "archive", name: "Archives", formats: "ZIP, GZIP" },
];
const extensions: Record<string, Category> = {
  jpg: "image",
  jpeg: "image",
  png: "image",
  webp: "image",
  gif: "image",
  svg: "image",
  tiff: "image",
  tif: "image",
  mp4: "video",
  mov: "video",
  mkv: "video",
  webm: "video",
  mp3: "audio",
  wav: "audio",
  m4a: "audio",
  flac: "audio",
  ogg: "audio",
  aac: "audio",
  pdf: "document",
  txt: "document",
  zip: "archive",
  gz: "archive",
  gzip: "archive",
};
export const extension = (name: string) =>
  name.split(".").pop()?.toLowerCase() || "";
export const categoryOf = (name: string) => extensions[extension(name)];
export const accept = Object.keys(extensions)
  .map((e) => `.${e}`)
  .join(",");
export function formatsFor(category: Category, source: string): string[] {
  if (category === "image")
    return ["png", "jpg", "webp", "tiff", "pdf", "docx"];
  if (category === "video")
    return ["mp4", "mov", "mkv", "webm", "gif", "mp3", "m4a", "wav"];
  if (category === "audio") return ["mp3", "wav", "m4a", "flac", "ogg"];
  if (category === "document")
    return source === "pdf"
      ? ["png", "jpg", "txt", "docx"]
      : ["pdf", "png", "jpg", "docx"];
  return source === "zip" ? ["zip"] : ["zip", "gz"];
}
export function defaultTarget(category: Category, source: string) {
  const formats = formatsFor(category, source);
  return (
    formats.find(
      (f) => f !== source && f !== (source === "jpeg" ? "jpg" : ""),
    ) || formats[0]
  );
}
export const tools: Tool[] = [
  {
    id: "compress",
    name: "Compress files",
    description: "Make a little room. Keep the detail.",
    categories: ["image", "video", "audio", "document"],
  },
  {
    id: "resize",
    name: "Resize images",
    description: "The right dimensions for wherever it goes.",
    categories: ["image"],
  },
  {
    id: "trim",
    name: "Trim audio & video",
    description: "Keep just the part you need.",
    categories: ["video", "audio"],
  },
  {
    id: "merge",
    name: "Merge PDFs",
    description: "Bring your documents together.",
    categories: ["document"],
    multi: true,
  },
  {
    id: "crop",
    name: "Crop images & video",
    description: "Find a better frame.",
    categories: ["image", "video"],
  },
  {
    id: "metadata",
    name: "Remove metadata",
    description: "Leave personal details out of the copy.",
    categories: ["image", "video", "audio", "document"],
  },
  {
    id: "create-pdf",
    name: "Images to PDF",
    description: "One document, a page for every image.",
    categories: ["image"],
    multi: true,
  },
  {
    id: "split",
    name: "Split PDF pages",
    description: "Save the pages you want as separate PDFs.",
    categories: ["document"],
  },
  {
    id: "collage",
    name: "Make a collage",
    description: "Put your images in good company.",
    categories: ["image"],
    multi: true,
  },
  {
    id: "qr",
    name: "Read QR codes",
    description: "Extract QR text from images or PDF pages.",
    categories: ["image", "document"],
  },
  {
    id: "mute",
    name: "Remove audio",
    description: "Make a silent copy of a video.",
    categories: ["video"],
  },
  {
    id: "speed",
    name: "Change video speed",
    description: "Slow down or speed up with pitch preserved.",
    categories: ["video"],
  },
  {
    id: "snapshot",
    name: "Save a video frame",
    description: "Turn a moment into a full-size PNG.",
    categories: ["video"],
  },
  {
    id: "normalize",
    name: "Normalize audio",
    description: "Balance the volume of a recording.",
    categories: ["audio"],
  },
  {
    id: "channels",
    name: "Convert audio channels",
    description: "Save a mono or stereo recording.",
    categories: ["audio"],
  },
  {
    id: "extract",
    name: "Extract an archive",
    description: "Unpack ZIP and GZIP files on your device.",
    categories: ["archive"],
  },
  {
    id: "text",
    name: "Extract PDF text",
    description: "Save selectable text from every page.",
    categories: ["document"],
  },
];
