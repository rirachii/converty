import { cp, mkdir } from "node:fs/promises";
// Self-host the pinned engine: no third-party CDN or file uploads at runtime.
await mkdir("public/engines", { recursive: true });
for (const name of ["ffmpeg-core.js", "ffmpeg-core.wasm"]) {
  await cp(
    `node_modules/@ffmpeg/core/dist/esm/${name}`,
    `public/engines/${name}`,
  );
}
console.log("Local media engine ready.");
