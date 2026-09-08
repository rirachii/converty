import type { Result } from "../types";

export const MAX_FILE_SIZE = 200 * 1024 * 1024;
export const MAX_EXPANDED_SIZE = 300 * 1024 * 1024;
export const MAX_PIXELS = 40_000_000;
export function baseName(name: string) {
  return name.replace(/\.[^.]+$/, "");
}
export function outputName(name: string, format: string, suffix = "") {
  return `${baseName(name)}${suffix ? `-${suffix}` : ""}.${format}`;
}
export function formatSize(bytes: number) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
}
export function parsePages(input: string, count: number): number[] {
  if (!input.trim()) return Array.from({ length: count }, (_, i) => i);
  const result: number[] = [];
  for (const part of input.split(",")) {
    const match = part.trim().match(/^(\d+)(?:\s*-\s*(\d+))?$/);
    if (!match) throw new Error("Use page numbers or ranges, such as 1, 3-5.");
    const start = Number(match[1]),
      end = Number(match[2] || match[1]);
    if (start < 1 || end > count || start > end)
      throw new Error(`Choose pages between 1 and ${count}.`);
    for (let page = start; page <= end; page++)
      if (!result.includes(page - 1)) result.push(page - 1);
  }
  return result;
}
export function safePath(name: string) {
  const parts = name.replaceAll("\\", "/").split("/");
  if (
    name.startsWith("/") ||
    /^[a-z]:/i.test(name) ||
    parts.some((p) => p === "..") ||
    name.includes("\0")
  )
    throw new Error("This archive contains an unsafe file path.");
  return parts.filter((p) => p && p !== ".").join("/");
}
export function uniqueNames(results: Result[]): Result[] {
  const used = new Set<string>();
  return results.map((result) => {
    let name = result.name,
      index = 2;
    while (used.has(name.toLowerCase())) {
      const ext = result.name.includes(".")
        ? result.name.split(".").pop()!
        : "";
      name = ext
        ? `${baseName(result.name)}-${index++}.${ext}`
        : `${result.name}-${index++}`;
    }
    used.add(name.toLowerCase());
    return { ...result, name };
  });
}
export const bytesBlob = (bytes: Uint8Array, type: string) =>
  new Blob([new Uint8Array(bytes).buffer], { type });
export function canvasBlob(
  canvas: HTMLCanvasElement,
  type = "image/png",
  quality = 0.82,
): Promise<Blob> {
  return new Promise((resolve, reject) =>
    canvas.toBlob(
      (blob) =>
        blob && blob.type === type
          ? resolve(blob)
          : reject(new Error(`Your browser cannot export ${type}.`)),
      type,
      quality,
    ),
  );
}
export function createCanvas(width: number, height: number) {
  if (
    !Number.isFinite(width) ||
    !Number.isFinite(height) ||
    width < 1 ||
    height < 1 ||
    width * height > MAX_PIXELS ||
    width > 16384 ||
    height > 16384
  )
    throw new Error(
      "Choose dimensions up to 16,384 pixels per side and 40 megapixels total.",
    );
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(width);
  canvas.height = Math.round(height);
  return canvas;
}
