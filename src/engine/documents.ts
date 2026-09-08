import { PDFDocument, rgb } from "pdf-lib";
import fontkit from "@pdf-lib/fontkit";
import fontURL from "@fontsource/noto-sans/files/noto-sans-latin-400-normal.woff?url";
import type { Options, Result } from "../types";
import {
  bytesBlob,
  canvasBlob,
  createCanvas,
  outputName,
  parsePages,
} from "./utils";
import { imageCanvas, scanQR, textResult } from "./images";

async function loadPDF(file: File) {
  const pdfjs = await import("pdfjs-dist");
  const worker = await import("pdfjs-dist/build/pdf.worker.min.mjs?url");
  pdfjs.GlobalWorkerOptions.workerSrc = worker.default;
  return pdfjs.getDocument({ data: await file.arrayBuffer() }).promise;
}
export async function imagesToPDF(files: File[]): Promise<Result[]> {
  const pdf = await PDFDocument.create();
  for (const file of files) {
    const canvas = await imageCanvas(file, file.name);
    const img = await pdf.embedPng(
      await (await canvasBlob(canvas)).arrayBuffer(),
    );
    const scale = Math.min(1, 1200 / Math.max(img.width, img.height));
    const page = pdf.addPage([img.width * scale, img.height * scale]);
    page.drawImage(img, {
      x: 0,
      y: 0,
      width: page.getWidth(),
      height: page.getHeight(),
    });
  }
  return [
    {
      name:
        files.length === 1
          ? outputName(files[0].name, "pdf")
          : "combined-images.pdf",
      blob: bytesBlob(await pdf.save(), "application/pdf"),
    },
  ];
}
export async function mergePDFs(files: File[]): Promise<Result[]> {
  const output = await PDFDocument.create();
  for (const file of files) {
    const src = await PDFDocument.load(await file.arrayBuffer());
    const pages = await output.copyPages(src, src.getPageIndices());
    for (const page of pages) output.addPage(page);
  }
  return [
    {
      name: "merged-document.pdf",
      blob: bytesBlob(await output.save(), "application/pdf"),
    },
  ];
}
export async function docxResult(file: File, text?: string): Promise<Result[]> {
  const { Document, Packer, Paragraph, ImageRun, TextRun } =
    await import("docx");
  const children = [];
  if (text !== undefined) {
    for (const line of text.split("\n"))
      children.push(new Paragraph({ children: [new TextRun(line)] }));
  } else {
    const canvas = await imageCanvas(file, file.name);
    const scale = Math.min(1, 600 / canvas.width);
    children.push(
      new Paragraph({
        children: [
          new ImageRun({
            type: "png",
            data: new Uint8Array(
              await (await canvasBlob(canvas)).arrayBuffer(),
            ),
            transformation: {
              width: canvas.width * scale,
              height: canvas.height * scale,
            },
          }),
        ],
      }),
    );
  }
  const blob = await Packer.toBlob(new Document({ sections: [{ children }] }));
  return [{ name: outputName(file.name, "docx"), blob }];
}
export async function textToPDF(file: File): Promise<File> {
  if (file.size > 2 * 1024 * 1024)
    throw new Error("Text documents are limited to 2 MB per file.");
  const text = await file.text();
  const pdf = await PDFDocument.create();
  pdf.registerFontkit(fontkit);
  const font = await pdf.embedFont(await (await fetch(fontURL)).arrayBuffer(), {
    subset: true,
  });
  const supported = new Set(font.getCharacterSet());
  if (
    [...text].some(
      (char) =>
        !["\n", "\r", "\t"].includes(char) &&
        !supported.has(char.codePointAt(0)!),
    )
  )
    throw new Error(
      "PDF text export supports the bundled Latin font. Use DOCX to preserve other scripts.",
    );
  let page = pdf.addPage([595, 842]),
    y = 786;
  function draw(line: string) {
    if (y < 56) {
      page = pdf.addPage([595, 842]);
      y = 786;
    }
    page.drawText(line, {
      x: 48,
      y,
      font,
      size: 11,
      color: rgb(0.12, 0.14, 0.18),
    });
    y -= 17;
  }
  for (const paragraph of text
    .replaceAll("\r", "")
    .replaceAll("\t", "    ")
    .split("\n")) {
    let line = "";
    for (const char of paragraph) {
      if (font.widthOfTextAtSize(line + char, 11) > 499) {
        draw(line);
        line = "";
      }
      line += char;
    }
    draw(line);
  }
  return new File(
    [new Uint8Array(await pdf.save()).buffer],
    outputName(file.name, "pdf"),
    { type: "application/pdf" },
  );
}
export async function processDocument(
  file: File,
  options: Options,
): Promise<Result[]> {
  const { operation, format } = options;
  if (
    operation === "split" ||
    operation === "metadata" ||
    operation === "compress"
  ) {
    const source = await PDFDocument.load(await file.arrayBuffer(), {
      updateMetadata: false,
    });
    const indices = parsePages(options.pages, source.getPageCount());
    const groups = operation === "split" ? indices.map((i) => [i]) : [indices];
    const results: Result[] = [];
    for (const group of groups) {
      const doc = await PDFDocument.create();
      for (const page of await doc.copyPages(source, group)) doc.addPage(page);
      doc.setProducer("");
      doc.setCreator("");
      results.push({
        name: outputName(
          file.name,
          "pdf",
          operation === "split" ? `page-${group[0] + 1}` : operation,
        ),
        blob: bytesBlob(
          await doc.save({ useObjectStreams: true }),
          "application/pdf",
        ),
      });
    }
    return results;
  }
  const pdf = await loadPDF(file);
  try {
    const pages = parsePages(options.pages, pdf.numPages);
    const results: Result[] = [],
      texts: string[] = [];
    for (const i of pages) {
      const page = await pdf.getPage(i + 1);
      if (operation === "text" || ["txt", "docx"].includes(format)) {
        const content = await page.getTextContent();
        texts.push(
          content.items
            .map((item) =>
              "str" in item ? item.str + (item.hasEOL ? "\n" : " ") : "",
            )
            .join(""),
        );
      } else {
        // 150 DPI keeps browser allocations bounded. Refuse oversized pages.
        const viewport = page.getViewport({ scale: 150 / 72 });
        const canvas = createCanvas(viewport.width, viewport.height);
        await page.render({
          canvas,
          canvasContext: canvas.getContext("2d")!,
          viewport,
        }).promise;
        if (operation === "qr") {
          const qr = await scanQR(canvas);
          if (qr) texts.push(`Page ${i + 1}: ${qr}`);
        } else {
          results.push({
            name: outputName(file.name, format, `page-${i + 1}`),
            blob: await canvasBlob(
              canvas,
              format === "jpg" ? "image/jpeg" : "image/png",
              options.quality / 100,
            ),
          });
        }
        canvas.width = canvas.height = 1;
      }
      page.cleanup();
    }
    if (operation === "qr") {
      if (!texts.length)
        throw new Error("No readable QR code was found in these pages.");
      return [textResult(outputName(file.name, "txt", "qr"), texts.join("\n"))];
    }
    if (operation === "text" || ["txt", "docx"].includes(format)) {
      const text = texts.join("\n\n");
      if (!text.trim())
        throw new Error(
          "This PDF has no selectable text. Scanned documents need OCR, which is not available here yet.",
        );
      return format === "docx"
        ? docxResult(file, text)
        : [textResult(outputName(file.name, "txt"), text)];
    }
    return results;
  } finally {
    await pdf.loadingTask.destroy();
  }
}
