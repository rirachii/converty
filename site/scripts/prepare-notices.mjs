import { readFile, writeFile } from "node:fs/promises";

const dependencies = ["@fontsource-variable/manrope", "lucide"];
let notices =
  "Converty landing page\nOriginal code and Converty artwork: GPL-3.0-or-later.\nSource: https://github.com/rirachii/converty/tree/main/site\n\n";
for (const name of dependencies) {
  const root = new URL(`../node_modules/${name}/`, import.meta.url);
  const { version } = JSON.parse(
    await readFile(new URL("package.json", root), "utf8"),
  );
  notices += `${name} ${version}\n\n${await readFile(new URL("LICENSE", root), "utf8")}\n\n`;
}
await writeFile(new URL("../public/notices.txt", import.meta.url), notices);
console.log("Landing page third-party notices ready.");
