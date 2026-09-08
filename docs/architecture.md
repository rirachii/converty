# Web architecture and processing boundaries

This document covers the preserved web edition. See [native architecture](native-architecture.md) for the primary macOS app.

## Application

React and TypeScript run on Vite with a static build.
`src/catalog.ts` is the visible capability catalog.
`src/App.tsx` owns session files, navigation, dialogs, processing status, object URL lifetime, and download actions.
`src/engine/index.ts` routes supported operations to independent image, document, archive, and media modules.

## Processing

Image operations use Canvas and UTIF.js for TIFF.
PDF creation/manipulation uses PDF-lib; PDF rendering and selectable text use PDF.js in a worker.
DOCX output uses `docx`.
QR decoding uses jsQR.
ZIP and GZIP use fflate worker APIs.
Audio/video use the pinned single-thread FFmpeg WebAssembly core from same-origin `/engines/` assets.
The media engine is shared and jobs run sequentially to avoid virtual-filesystem contention and excessive memory use.
Engine input/output files are removed after each operation, and cancellation terminates the worker.

Source inputs are browser File objects and are never modified.
Outputs are Blob objects with temporary object URLs.
Removing files, clearing the workspace, replacing results, or unmounting revokes the appropriate URLs.
Download-all creates one ZIP with collision-safe names.
Only default quality is saved to localStorage, with storage failure handled gracefully.

## Limits and recovery

The app accepts at most 50 files and 200 MB per file.
Canvas allocation rejects dimensions above 16,384 per side or 40 million pixels.
PDF page ranges are validated before processing and support order-preserving de-duplication.
ZIP entries are filtered for unsafe paths, a maximum of 500 entries, and a declared unpacked total of 300 MB.
GZIP validates the declared uncompressed size and checks actual output size.
These are resource safeguards, not guarantees against all malicious compressed data or decoder vulnerabilities.
The application is designed for user-chosen files; a public service should keep decoder dependencies patched and avoid claiming arbitrary untrusted inputs are risk-free.
Text documents are limited to 2 MB for PDF generation.
FFmpeg jobs have a three-minute processing timeout.
Errors remain attached to the original row and can be retried through the format selector or tool dialog.
Cancellation discards incomplete outputs and preserves already completed results.

## Hosting

Build with `npm ci && npm run build` and serve `dist/` at the domain root.
No fallback conversion server is configured.
The single-thread engine avoids a SharedArrayBuffer/cross-origin-isolation requirement.
Serve WASM with `application/wasm`, workers as JavaScript, and all assets from the app origin.
The app fetches static runtime files and fonts; it sends no file content, filenames, or processing requests.
The app is local-processing rather than a guaranteed offline PWA.
A local static server can serve all assets without internet access after installation.

Suggested host headers:

```text
X-Content-Type-Options: nosniff
Referrer-Policy: no-referrer
Content-Security-Policy: default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; worker-src 'self' blob:; img-src 'self' blob: data:; media-src 'self' blob:; font-src 'self'; connect-src 'self'; style-src 'self' 'unsafe-inline'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'
```

These headers are deployment recommendations and are not a claim that every static host has already applied them.
Source is published at [rirachii/converty](https://github.com/rirachii/converty).
There is no public web deployment.

## Open-source delivery

`scripts/prepare-source.mjs` creates a source ZIP from the project allowlist.
It excludes node_modules, built binaries, local notes, test results, and reference media.
`public/converty-source.zip` and engine assets are generated and ignored by Git.
The source bundle includes the dependency lockfile and build instructions so a recipient can reproduce the application.
Third-party package licensing and the FFmpeg core source reference are documented separately.
