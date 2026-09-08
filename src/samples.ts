export async function sampleImage(): Promise<File> {
  const canvas = document.createElement("canvas");
  canvas.width = 1200;
  canvas.height = 900;
  const ctx = canvas.getContext("2d")!;
  ctx.fillStyle = "#e9e5f5";
  ctx.fillRect(0, 0, 1200, 900);
  ctx.fillStyle = "#d3bbf1";
  ctx.beginPath();
  ctx.arc(870, 235, 115, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#979bbb";
  ctx.beginPath();
  ctx.moveTo(0, 520);
  ctx.bezierCurveTo(350, 250, 450, 690, 760, 490);
  ctx.bezierCurveTo(1000, 320, 1100, 390, 1200, 470);
  ctx.lineTo(1200, 900);
  ctx.lineTo(0, 900);
  ctx.fill();
  ctx.fillStyle = "#566a68";
  ctx.beginPath();
  ctx.moveTo(0, 770);
  ctx.bezierCurveTo(400, 440, 620, 900, 1200, 650);
  ctx.lineTo(1200, 900);
  ctx.lineTo(0, 900);
  ctx.fill();
  const blob = await new Promise<Blob>((resolve) =>
    canvas.toBlob((b) => resolve(b!), "image/png"),
  );
  return new File([blob], "quiet-hills.png", { type: "image/png" });
}
export function sampleAudio(): File {
  const rate = 22050,
    seconds = 2,
    samples = rate * seconds;
  const buffer = new ArrayBuffer(44 + samples * 2),
    view = new DataView(buffer);
  const str = (offset: number, value: string) => {
    [...value].forEach((c, i) => view.setUint8(offset + i, c.charCodeAt(0)));
  };
  str(0, "RIFF");
  view.setUint32(4, buffer.byteLength - 8, true);
  str(8, "WAVE");
  str(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, rate, true);
  view.setUint32(28, rate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  str(36, "data");
  view.setUint32(40, samples * 2, true);
  for (let i = 0; i < samples; i++) {
    const t = i / rate;
    view.setInt16(
      44 + i * 2,
      Math.sin(2 * Math.PI * (t < 1 ? 261.63 : 329.63) * t) *
        Math.min(t * 8, 1) *
        Math.max(0, 1 - t / seconds) *
        5000,
      true,
    );
  }
  return new File([buffer], "two-little-notes.wav", { type: "audio/wav" });
}
export async function samplePDF(): Promise<File> {
  const { PDFDocument, StandardFonts, rgb } = await import("pdf-lib");
  const doc = await PDFDocument.create(),
    font = await doc.embedFont(StandardFonts.Helvetica);
  for (let i = 0; i < 2; i++) {
    const page = doc.addPage([595, 842]);
    page.drawText(
      i === 0 ? "Small things, made simpler." : "A little room for your ideas.",
      { x: 48, y: 730, size: 25, font, color: rgb(0.3, 0.26, 0.54) },
    );
    page.drawText("An original sample document from Converty.", {
      x: 48,
      y: 675,
      size: 12,
      font,
    });
    page.drawText(
      "Try converting, splitting, or extracting the text from this PDF.",
      { x: 48, y: 645, size: 12, font },
    );
    page.drawText(`Page ${i + 1}`, { x: 48, y: 48, size: 10, font });
  }
  return new File(
    [new Uint8Array(await doc.save()).buffer],
    "a-few-good-ideas.pdf",
    { type: "application/pdf" },
  );
}
