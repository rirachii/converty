import type { Options, Result } from "../types";
import { categoryOf, extension } from "../catalog";
import { outputName } from "./utils";

export async function processFiles(
  files: File[],
  options: Options,
  report: (value: number, message?: string) => void,
  signal: AbortSignal,
): Promise<Result[]> {
  signal.throwIfAborted();
  report(5, "Processing on your device…");
  if (!files.length) throw new Error("Choose a file first.");
  const file = files[0],
    category = categoryOf(file.name);
  if (options.operation === "merge")
    return (await import("./documents")).mergePDFs(files);
  if (options.operation === "create-pdf")
    return (await import("./documents")).imagesToPDF(files);
  if (options.operation === "collage")
    return (await import("./images")).makeCollage(files, options);
  if (category === "video" || category === "audio")
    return (await import("./media")).processMedia(
      file,
      options,
      report,
      signal,
    );
  if (category === "archive") {
    const archive = await import("./archives");
    return options.operation === "extract"
      ? archive.extractArchive(file)
      : archive.processArchive(file, options.format);
  }
  if (category === "document") {
    const docs = await import("./documents");
    if (extension(file.name) === "txt") {
      if (options.format === "docx")
        return docs.docxResult(file, await file.text());
      const pdf = await docs.textToPDF(file);
      return options.format === "pdf"
        ? [{ name: pdf.name, blob: pdf }]
        : docs.processDocument(pdf, options);
    }
    return docs.processDocument(file, options);
  }
  if (category === "image") {
    const images = await import("./images");
    if (options.operation === "qr") {
      const text = await images.scanQR(
        await images.imageCanvas(file, file.name),
      );
      if (!text)
        throw new Error("No readable QR code was found in this image.");
      return [images.textResult(outputName(file.name, "txt", "qr"), text)];
    }
    if (options.format === "pdf")
      return (await import("./documents")).imagesToPDF([file]);
    if (options.format === "docx")
      return (await import("./documents")).docxResult(file);
    return images.processImage(file, options);
  }
  throw new Error("This file type is not supported yet.");
}
