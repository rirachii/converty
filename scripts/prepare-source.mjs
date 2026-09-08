import { readFile, readdir, mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { zipSync } from "fflate";
import { renderToStaticMarkup } from "react-dom/server";
import { createElement } from "react";
import { ArrowRightLeft } from "lucide-react";

const included = [
  "src",
  "macOS/App",
  "macOS/Artwork",
  "macOS/Sources",
  "macOS/Tests",
  "macOS/Scripts",
  "macOS/Package.swift",
  "macOS/project.yml",
  "macOS/Info.plist",
  "macOS/README.md",
  "macOS/Resources/THIRD_PARTY_NOTICES.txt",
  "scripts",
  "docs",
  "tests",
  "public/SOURCE.md",
  ".gitignore",
  ".github",
  "AGENTS.md",
  "CONTRIBUTING.md",
  "DESIGN.md",
  "README.md",
  "LICENSE",
  "THIRD_PARTY_NOTICES.md",
  "index.html",
  "package.json",
  "package-lock.json",
  "tsconfig.json",
  "vite.config.ts",
  "vitest.config.ts",
  "playwright.config.ts",
];
const files = {};
async function add(path) {
  let entries;
  try {
    entries = await readdir(path, { withFileTypes: true });
  } catch {
    files[`converty/${path}`] = new Uint8Array(await readFile(path));
    return;
  }
  for (const entry of entries)
    if (!entry.name.startsWith(".")) await add(join(path, entry.name));
}
await mkdir("public", { recursive: true });
for (const path of included) await add(path);
// Preserve bundled dependency notices in source and static distributions.
const lockfile = JSON.parse(await readFile("package-lock.json", "utf8"));
let notices = await readFile("THIRD_PARTY_NOTICES.md", "utf8");
for (const [path, info] of Object.entries(lockfile.packages)) {
  if (!path || info.dev) continue;
  try {
    const names = await readdir(path);
    for (const name of names.filter((name) =>
      /^(license|licence|copying|ofl|notice)([.\-]|$)/i.test(name),
    )) {
      const content = await readFile(join(path, name), "utf8");
      notices += `\n\n${path.replace("node_modules/", "")} ${info.version} / ${name}\n\n${content}`;
    }
  } catch {
    /* Some upstream packages supply an SPDX identifier only. */
  }
}
await writeFile("public/third-party-notices.txt", notices);
files["converty/third-party-notices.txt"] = new TextEncoder().encode(notices);
await writeFile("public/converty-source.zip", zipSync(files, { level: 6 }));
const icon = renderToStaticMarkup(
  createElement(ArrowRightLeft, {
    color: "#7060ce",
    size: 32,
    strokeWidth: 2.5,
  }),
);
await writeFile("public/favicon.svg", icon);
console.log(`Source archive ready (${Object.keys(files).length} files).`);
