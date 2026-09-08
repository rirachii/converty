import { chromium } from "playwright";
import AxeBuilder from "@axe-core/playwright";
import { unzipSync } from "fflate";
import { readFile } from "node:fs/promises";

const origin = "http://127.0.0.1:4173";
const browser = await chromium.launch({ channel: "chrome" });
try {
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
  });
  const page = await context.newPage();
  const errors = [],
    external = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("request", (request) => {
    if (
      request.url().startsWith("http") &&
      new URL(request.url()).origin !== origin
    )
      external.push(request.url());
  });
  await page.goto(origin);
  await page.getByRole("button", { name: "Image", exact: true }).click();
  await page.getByLabel("Edit quiet-hills.png").click();
  await page
    .getByRole("button", { name: "Resize images", exact: true })
    .click();
  await page.getByLabel("Width (px)").fill("500");
  const audit = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
    .analyze();
  const violations = audit.violations.map((v) => ({
    id: v.id,
    nodes: v.nodes.map((n) => ({ target: n.target, reason: n.failureSummary })),
  }));
  await page.getByRole("button", { name: "Apply tool" }).click();
  await page.getByText("quiet-hills-resize.png", { exact: true }).waitFor();
  await page.getByLabel("Clear all files").click();
  await page.getByRole("button", { name: "PDF", exact: true }).click();
  await page.getByRole("button", { name: "Convert file", exact: true }).click();
  await page
    .getByText("a-few-good-ideas-page-2.png", { exact: true })
    .waitFor();
  await page.getByLabel("Clear all files").click();
  await page
    .locator(".sample-row")
    .getByRole("button", { name: "Audio", exact: true })
    .click();
  await page.getByRole("button", { name: "Convert file", exact: true }).click();
  await page.getByText("two-little-notes.mp3", { exact: true }).waitFor();
  const source = await page.request.get(`${origin}/converty-source.zip`);
  const sourceFiles = unzipSync(await source.body());
  if (
    Buffer.from(sourceFiles["converty/src/App.tsx"]).toString() !==
    (await readFile("src/App.tsx", "utf8"))
  )
    throw new Error("Downloadable source differs from the working app source.");
  console.log(
    JSON.stringify(
      {
        production: "Contextual image resize, PDF pages, and audio passed",
        sourceFiles: Object.keys(sourceFiles).length,
        errors,
        externalRequests: external,
        accessibility: violations,
      },
      null,
      2,
    ),
  );
  if (errors.length || external.length || violations.length)
    process.exitCode = 1;
} finally {
  await browser.close();
}
