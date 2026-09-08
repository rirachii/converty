import { test, expect, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { readFile } from "node:fs/promises";
import { PDFDocument } from "pdf-lib";
import { unzipSync } from "fflate";

const sampleImage = async (page: Page) =>
  page.getByRole("button", { name: "Image", exact: true }).click();
async function downloadBytes(page: Page, action: () => Promise<unknown>) {
  const pending = page.waitForEvent("download");
  await action();
  const download = await pending;
  const data = await readFile((await download.path())!);
  return { name: download.suggestedFilename(), data };
}

test("image conversion produces a real JPEG and leaves its original in the queue", async ({
  page,
}) => {
  const uploads: string[] = [];
  page.on("request", (req) => {
    if (["POST", "PUT", "PATCH"].includes(req.method()))
      uploads.push(req.url());
  });
  await page.goto("/");
  await sampleImage(page);
  await expect(
    page.getByText("quiet-hills.png", { exact: true }),
  ).toBeVisible();
  await page
    .getByLabel("Output format for quiet-hills.png")
    .selectOption("jpg");
  await page.getByRole("button", { name: "Convert file", exact: true }).click();
  await expect(
    page.getByText("quiet-hills.jpg", { exact: true }),
  ).toBeVisible();
  const result = await downloadBytes(page, () =>
    page.getByRole("button", { name: "quiet-hills.jpg", exact: true }).click(),
  );
  expect(result.data.subarray(0, 3).toString("hex")).toBe("ffd8ff");
  expect(uploads).toEqual([]);
  await expect(
    page.getByText("quiet-hills.png", { exact: true }),
  ).toBeVisible();
});

test("resize UI exports the requested dimensions and preserves aspect ratio", async ({
  page,
}) => {
  await page.goto("/");
  await sampleImage(page);
  await page.getByRole("button", { name: /^Resize images The/ }).click();
  await page.getByLabel("Width (px)").fill("400");
  await page.getByRole("button", { name: "Apply tool" }).click();
  await expect(
    page.getByText("quiet-hills-resize.png", { exact: true }),
  ).toBeVisible();
  const result = await downloadBytes(page, () =>
    page
      .getByRole("button", { name: "quiet-hills-resize.png", exact: true })
      .click(),
  );
  expect(result.data.readUInt32BE(16)).toBe(400);
  expect(result.data.readUInt32BE(20)).toBe(300);
});

test("PDF conversion renders every page, and downloads a ZIP containing both outputs", async ({
  page,
}) => {
  await page.goto("/");
  await page.getByRole("button", { name: "PDF", exact: true }).click();
  await page.getByRole("button", { name: "Convert file", exact: true }).click();
  await expect(
    page.getByText("a-few-good-ideas-page-2.png", { exact: true }),
  ).toBeVisible({ timeout: 45000 });
  const result = await downloadBytes(page, () =>
    page.getByRole("button", { name: "Download all as ZIP" }).click(),
  );
  const entries = unzipSync(result.data);
  expect(Object.keys(entries)).toHaveLength(2);
  for (const bytes of Object.values(entries))
    expect(Buffer.from(bytes).subarray(0, 8).toString("hex")).toBe(
      "89504e470d0a1a0a",
    );
});

test("split validates PDF page ranges, then creates the selected page", async ({
  page,
}) => {
  await page.goto("/");
  await page.getByRole("button", { name: "PDF", exact: true }).click();
  // The sample is generated asynchronously; wait for its queue row before navigating.
  await expect(page.getByText("a-few-good-ideas.pdf", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Explore all tools" }).click();
  await page.getByRole("button", { name: /^Split PDF pages/ }).click();
  await page.getByLabel("Pages", { exact: true }).fill("9");
  await page.getByRole("button", { name: "Apply tool" }).click();
  await page.getByRole("button", { name: /^All files/ }).click();
  await expect(page.getByText("Choose pages between 1 and 2.")).toBeVisible();
  await page.getByRole("button", { name: "Explore all tools" }).click();
  await page.getByRole("button", { name: /^Split PDF pages/ }).click();
  await page.getByLabel("Pages", { exact: true }).fill("2");
  await page.getByRole("button", { name: "Apply tool" }).click();
  await page.getByRole("button", { name: /^Completed/ }).click();
  await expect(
    page.getByText("a-few-good-ideas-page-2.pdf", { exact: true }),
  ).toBeVisible();
  const result = await downloadBytes(page, () =>
    page
      .getByRole("button", { name: "a-few-good-ideas-page-2.pdf", exact: true })
      .click(),
  );
  expect((await PDFDocument.load(result.data)).getPageCount()).toBe(1);
});

test("audio sample converts to a playable MP3 in the browser", async ({
  page,
}) => {
  await page.goto("/");
  await page
    .locator(".sample-row")
    .getByRole("button", { name: "Audio", exact: true })
    .click();
  await page.getByRole("button", { name: "Convert file", exact: true }).click();
  await expect(
    page.getByText("two-little-notes.mp3", { exact: true }),
  ).toBeVisible({ timeout: 90000 });
  const result = await downloadBytes(page, () =>
    page
      .getByRole("button", { name: "two-little-notes.mp3", exact: true })
      .click(),
  );
  expect(result.data.subarray(0, 3).toString()).toBe("ID3");
  expect(result.data.length).toBeGreaterThan(1000);
});

test("the local media engine converts a MOV fixture to MP4 and can be cancelled", async ({
  page,
}) => {
  await page.goto("/");
  await page
    .getByLabel("Choose files", { exact: true })
    .setInputFiles("tests/fixtures/short.mov");
  await page.getByRole("button", { name: "Convert file", exact: true }).click();
  await expect(page.getByText("short.mp4", { exact: true })).toBeVisible({
    timeout: 90000,
  });
  const result = await downloadBytes(page, () =>
    page.getByRole("button", { name: "short.mp4", exact: true }).click(),
  );
  expect(result.data.subarray(4, 8).toString()).toBe("ftyp");
  await page.reload();
  await page.route("**/engines/ffmpeg-core.wasm", async (route) => {
    await new Promise((resolve) => setTimeout(resolve, 2000));
    await route.continue().catch(() => {});
  });
  await page
    .getByLabel("Choose files", { exact: true })
    .setInputFiles("tests/fixtures/short.mov");
  await page.getByRole("button", { name: "Convert file", exact: true }).click();
  await page.getByRole("button", { name: "Cancel processing" }).click();
  await expect(
    page.getByText("Processing cancelled. Your originals are unchanged."),
  ).toBeVisible();
});

test("unsupported inputs are rejected without creating fake rows", async ({
  page,
}) => {
  await page.goto("/");
  await page.getByLabel("Choose files", { exact: true }).setInputFiles({
    name: "sample.heic",
    mimeType: "image/heic",
    buffer: Buffer.from("not a real HEIC"),
  });
  await expect(page.getByRole("status")).toContainText(
    "this format is not supported",
  );
  await expect(page.locator(".file-row")).toHaveCount(0);
});

test("tool selection works before files have been added", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: /^Compress files Make/ }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page
    .getByLabel("Choose files", { exact: true })
    .setInputFiles("tests/fixtures/tiny.png");
  await expect(page.getByRole("button", { name: "Apply tool" })).toBeEnabled();
  await page.getByRole("button", { name: "Apply tool" }).click();
  await expect(
    page.getByText("tiny-compress.webp", { exact: true }),
  ).toBeVisible();
});

test("desktop and mobile layouts have no horizontal overflow or serious accessibility failures", async ({
  page,
}) => {
  await page.goto("/");
  const desktop = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
    .analyze();
  expect(
    desktop.violations.map((v) => ({
      id: v.id,
      nodes: v.nodes.map((n) => ({
        target: n.target,
        summary: n.failureSummary,
      })),
    })),
  ).toEqual([]);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ reducedMotion: "reduce" });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  await page.screenshot({
    // Record the compact acceptance surface after the accessibility audit.
    path: "/tmp/converty-mobile-390.png",
    fullPage: true,
  });
  await page.getByLabel("Open navigation").click();
  const mobile = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
    .analyze();
  expect(
    mobile.violations.map((v) => ({
      id: v.id,
      targets: v.nodes.map((n) => n.target),
    })),
  ).toEqual([]);
  await page.getByRole("button", { name: "All tools 17", exact: true }).click();
  await page.getByLabel("Find a tool").fill("QR");
  await expect(page.locator(".tool-card")).toHaveCount(1);
  await page.getByRole("button", { name: /^Read QR codes/ }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog")).toHaveCount(0);
});

test("advanced image and media tools produce meaningful transformed outputs", async ({
  page,
}) => {
  await page.goto("/");
  const mov = [...(await readFile("tests/fixtures/short.mov"))];
  const qr = [...(await readFile("tests/fixtures/qr.png"))];
  const results = await page.evaluate(
    async ({ mov, qr }) => {
      const { processFiles } = await import(String("/src/engine/index.ts"));
      const { defaultOptions } = await import(String("/src/types.ts"));
      const { sampleImage, sampleAudio } = await import(
        String("/src/samples.ts")
      );
      const { imageCanvas } = await import(String("/src/engine/images.ts"));
      const image = await sampleImage(),
        audio = sampleAudio();
      const video = new File([new Uint8Array(mov)], "clip.mov", {
        type: "video/quicktime",
      });
      const run = (files: File[], options: Record<string, unknown>) =>
        processFiles(
          files,
          { ...defaultOptions, ...options },
          () => {},
          new AbortController().signal,
        );
      const imageCrop = (
        await run([image], { operation: "crop", format: "png", aspect: "1:1" })
      )[0];
      const cropCanvas = await imageCanvas(imageCrop.blob);
      const collage = (
        await run([image, image], {
          operation: "collage",
          format: "png",
          columns: 2,
          gap: 10,
        })
      )[0];
      const collageCanvas = await imageCanvas(collage.blob);
      const code = (
        await run([new File([new Uint8Array(qr)], "qr.png")], {
          operation: "qr",
          format: "txt",
        })
      )[0];
      const results: Record<string, number> = {};
      for (const format of [
        "mp4",
        "mov",
        "mkv",
        "webm",
        "gif",
        "mp3",
        "m4a",
        "wav",
      ]) {
        results[`video-${format}`] = (
          await run([video], { format })
        )[0].blob.size;
      }
      for (const operation of [
        "crop",
        "trim",
        "speed",
        "mute",
        "snapshot",
        "metadata",
        "compress",
      ]) {
        const output = (
          await run([video], { operation, format: "mp4", start: 0.2, end: 1.2 })
        )[0];
        results[operation] = output.blob.size;
        if (operation === "crop") {
          const url = URL.createObjectURL(output.blob);
          const el = document.createElement("video");
          el.src = url;
          await new Promise<void>((resolve, reject) => {
            el.onloadedmetadata = () => resolve();
            el.onerror = () => reject(new Error("Invalid cropped video"));
          });
          results.cropWidth = el.videoWidth;
          results.cropHeight = el.videoHeight;
          URL.revokeObjectURL(url);
        }
      }
      for (const operation of [
        "normalize",
        "channels",
        "trim",
        "metadata",
        "compress",
      ]) {
        results[`audio-${operation}`] = (
          await run([audio], { operation, format: "mp3", start: 0.1, end: 1 })
        )[0].blob.size;
      }
      return {
        imageCrop: [cropCanvas.width, cropCanvas.height],
        collage: [collageCanvas.width, collageCanvas.height],
        code: await code.blob.text(),
        media: results,
      };
    },
    { mov, qr },
  );
  expect(results.imageCrop).toEqual([900, 900]);
  expect(results.collage).toEqual([1310, 660]);
  expect(results.code).toBe("https://example.com/converty-test");
  expect(results.media.cropWidth).toBe(96);
  expect(results.media.cropHeight).toBe(96);
  for (const size of Object.values(results.media))
    expect(size).toBeGreaterThan(0);
});

test("engine outputs round-trip for TIFF, PDF merge, text and Word, and archive extraction", async ({
  page,
}) => {
  await page.goto("/");
  const result = await page.evaluate(async () => {
    const { processFiles } = await import(String("/src/engine/index.ts"));
    const { defaultOptions } = await import(String("/src/types.ts"));
    const { sampleImage, samplePDF } = await import(String("/src/samples.ts"));
    const { imageCanvas } = await import(String("/src/engine/images.ts"));
    const { createZip, extractArchive } = await import(
      String("/src/engine/archives.ts")
    );
    const { PDFDocument } = await import(
      String("/node_modules/.vite/deps/pdf-lib.js")
    );
    const run = (files: File[], format: string, operation = "convert") =>
      processFiles(
        files,
        { ...defaultOptions, format, operation },
        () => {},
        new AbortController().signal,
      );
    const image = await sampleImage();
    const pdf = await samplePDF();
    const tiff = (await run([image], "tiff"))[0];
    const decoded = await imageCanvas(tiff.blob, tiff.name);
    const merged = (await run([pdf, pdf], "pdf", "merge"))[0];
    const mergedDoc = await PDFDocument.load(await merged.blob.arrayBuffer());
    const text = (await run([pdf], "txt"))[0];
    const word = (await run([pdf], "docx"))[0];
    const textFile = new File(["Hello, café. A text document."], "notes.txt", {
      type: "text/plain",
    });
    const textPDF = (await run([textFile], "pdf"))[0];
    const readBack = (
      await run([new File([textPDF.blob], textPDF.name)], "txt")
    )[0];
    const zip = await createZip([text, text]);
    const extracted = await extractArchive(new File([zip], "test.zip"));
    return {
      tiff: [decoded.width, decoded.height],
      mergedPages: mergedDoc.getPageCount(),
      text: await text.blob.text(),
      word: [...new Uint8Array(await word.blob.arrayBuffer()).slice(0, 2)],
      readBack: await readBack.blob.text(),
      extracted: extracted.map((r: { name: string }) => r.name),
    };
  });
  expect(result.tiff).toEqual([1200, 900]);
  expect(result.mergedPages).toBe(4);
  expect(result.text).toContain("Small things, made simpler.");
  expect(result.word).toEqual([80, 75]);
  expect(result.readBack).toContain("Hello, café.");
  expect(result.extracted).toHaveLength(2);
  expect(result.extracted[0]).not.toBe(result.extracted[1]);
});
