import type { Options, Result } from "../types";
import { bytesBlob, canvasBlob, createCanvas, outputName } from "./utils";
import { extension } from "../catalog";

export async function imageCanvas(
  file: Blob,
  name = "",
): Promise<HTMLCanvasElement> {
  if (["tif", "tiff"].includes(extension(name))) {
    const { default: UTIF } = await import("utif");
    const buffer = await file.arrayBuffer();
    const pages = UTIF.decode(buffer);
    if (!pages.length) throw new Error("This TIFF has no readable image.");
    const page = pages[0];
    // Validate dimensions before allocating the decoded buffer.
    createCanvas(
      (page.t256 as number[])?.[0] || 0,
      (page.t257 as number[])?.[0] || 0,
    );
    UTIF.decodeImage(buffer, page);
    const canvas = createCanvas(page.width, page.height);
    canvas
      .getContext("2d")!
      .putImageData(
        new ImageData(
          new Uint8ClampedArray(UTIF.toRGBA8(page)),
          page.width,
          page.height,
        ),
        0,
        0,
      );
    return canvas;
  }
  const url = URL.createObjectURL(file);
  try {
    const img = new Image();
    img.src = url;
    await img.decode().catch(() => {
      throw new Error(
        "This image could not be decoded. Try PNG, JPG, WebP, GIF, SVG, or TIFF.",
      );
    });
    const canvas = createCanvas(img.naturalWidth, img.naturalHeight);
    canvas.getContext("2d")!.drawImage(img, 0, 0);
    return canvas;
  } finally {
    URL.revokeObjectURL(url);
  }
}
export async function encodeCanvas(
  canvas: HTMLCanvasElement,
  format: string,
  quality: number,
) {
  if (format === "tiff") {
    const { default: UTIF } = await import("utif");
    const rgba = canvas
      .getContext("2d")!
      .getImageData(0, 0, canvas.width, canvas.height).data;
    return new Blob(
      [
        UTIF.encodeImage(
          new Uint8Array(rgba.buffer),
          canvas.width,
          canvas.height,
        ),
      ],
      { type: "image/tiff" },
    );
  }
  if (format === "jpg") {
    const ctx = canvas.getContext("2d")!;
    ctx.globalCompositeOperation = "destination-over";
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.globalCompositeOperation = "source-over";
  }
  return canvasBlob(
    canvas,
    `image/${format === "jpg" ? "jpeg" : format}`,
    quality / 100,
  );
}
export async function processImage(
  file: File,
  options: Options,
): Promise<Result[]> {
  const source = await imageCanvas(file, file.name);
  let sx = 0,
    sy = 0,
    sw = source.width,
    sh = source.height;
  if (options.operation === "crop") {
    const [a, b] = options.aspect.split(":").map(Number),
      ratio = a / b;
    if (!Number.isFinite(ratio) || ratio <= 0)
      throw new Error("Choose a valid crop ratio.");
    if (sw / sh > ratio) {
      sw = sh * ratio;
      sx = (source.width - sw) / 2;
    } else {
      sh = sw / ratio;
      sy = (source.height - sh) / 2;
    }
  }
  let width = sw,
    height = sh;
  if (options.operation === "resize" || options.operation === "compress") {
    if (options.width) {
      width = options.width;
      height = (sh * width) / sw;
    }
    if (options.height) {
      height = options.height;
      if (!options.width) width = (sw * height) / sh;
    }
  }
  const canvas = createCanvas(width, height);
  canvas
    .getContext("2d")!
    .drawImage(source, sx, sy, sw, sh, 0, 0, width, height);
  return [
    {
      name: outputName(
        file.name,
        options.format,
        options.operation === "convert" ? "" : options.operation,
      ),
      blob: await encodeCanvas(canvas, options.format, options.quality),
    },
  ];
}
export async function makeCollage(
  files: File[],
  options: Options,
): Promise<Result[]> {
  if (
    !Number.isInteger(options.columns) ||
    options.columns < 1 ||
    options.columns > 4 ||
    !Number.isFinite(options.gap) ||
    options.gap < 0 ||
    options.gap > 100
  )
    throw new Error("Choose 1-4 columns and spacing between 0 and 100 pixels.");
  const cols = Math.min(files.length, Math.max(1, options.columns));
  const cell = 640,
    gap = options.gap;
  const rows = Math.ceil(files.length / cols);
  const canvas = createCanvas(
    cols * cell + (cols + 1) * gap,
    rows * cell + (rows + 1) * gap,
  );
  const ctx = canvas.getContext("2d")!;
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  for (let i = 0; i < files.length; i++) {
    const src = await imageCanvas(files[i], files[i].name);
    const side = Math.min(src.width, src.height);
    ctx.drawImage(
      src,
      (src.width - side) / 2,
      (src.height - side) / 2,
      side,
      side,
      gap + (i % cols) * (cell + gap),
      gap + Math.floor(i / cols) * (cell + gap),
      cell,
      cell,
    );
  }
  return [{ name: "collage.png", blob: await canvasBlob(canvas) }];
}
export async function scanQR(canvas: HTMLCanvasElement) {
  const { default: jsQR } = await import("jsqr");
  const data = canvas
    .getContext("2d")!
    .getImageData(0, 0, canvas.width, canvas.height);
  return jsQR(data.data, data.width, data.height)?.data;
}
export const textResult = (name: string, text: string): Result => ({
  name,
  blob: bytesBlob(new TextEncoder().encode(text), "text/plain;charset=utf-8"),
});
