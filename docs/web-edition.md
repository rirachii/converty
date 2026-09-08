# Converty web edition

A free, open-source file toolkit for the web.
Convert files and use 17 editing tools without uploading file content to a server.
This is the preserved browser edition. The primary product is now the native macOS app in `macOS/`.

## Run locally

Requires Node.js 22.12+ and npm.

```sh
npm ci
npm run dev
```

Open http://127.0.0.1:5173.
The install step copies the pinned FFmpeg WebAssembly engine into `public/engines/`.
Your browser loads that engine on the first audio/video operation.
No external API key, conversion service, or account is needed.

## What works

| Files | Conversion outputs | Tools |
| --- | --- | --- |
| JPG, PNG, WebP, GIF, SVG, TIFF | JPG, PNG, WebP, TIFF, PDF, DOCX | Compression, resize, centered aspect-ratio crop, image metadata removal, collage, images-to-PDF, QR reading |
| MP4, MOV, MKV, WebM | MP4, MOV, MKV, WebM, GIF, MP3, M4A, WAV | Compression, trim with range preview, crop, speed, mute, PNG snapshot, file metadata removal |
| MP3, WAV, M4A, FLAC, OGG, AAC | MP3, WAV, M4A, FLAC, OGG | Compression, trim, loudness normalization, mono/stereo conversion, file metadata removal |
| PDF | PNG/JPG pages, TXT, DOCX | Merge, split selected pages, compact object streams, document-level metadata removal, selectable-text extraction, QR reading |
| TXT | PDF, PNG/JPG pages, DOCX | Conversion |
| ZIP, GZIP | ZIP, GZIP for one file | Extraction and repacking |

The workspace supports drag-and-drop, format selection per file, sequential batch conversion, real progress from the media engine, cancellation, error recovery, individual downloads, and ZIP downloads.
Three original sample files are generated locally so visitors can try it immediately.

## Deliberate limits

- Up to 50 input files, 200 MB per file, and 40 megapixels per image.
- Files and results exist in tab memory only; download results before reloading or closing.
- The app needs its assets available from a local or hosted server; it does not currently install an offline service worker.
- Browser codecs affect media previews; the WebAssembly engine supports more inputs than the preview player.
- GIF/TIFF image conversions use the first frame/page.
- HEIC, TAR, RAR, OCR, video joining/splitting, silence detection, and audio-to-video are not implemented.
- PDF pages render at 150 DPI with a 40-megapixel ceiling.
- PDF-to-Word extracts selectable text without layout or embedded images; scanned PDFs require OCR elsewhere.
- Text-to-PDF uses a bundled Latin font and explicitly rejects unsupported characters; DOCX preserves other scripts.
- Crop is centered and selected by aspect ratio; freehand crop positioning is not implemented.
- PDF compression compacts object streams; it does not downsample existing images.
- Metadata removal is scoped to image tags, media file-level tags/chapters, or PDF document-level metadata.
  Page content, annotations, visible text, spoken content, and nested objects can still contain personal information.
- QR reading returns one code per image or PDF page and never opens decoded links automatically.
- Existing optimized files may not shrink; the app reports this when compression produces a larger copy.

## Check and build

```sh
npm run typecheck
npm test
npm run test:e2e
npm run build
npm run preview
```

With the production preview running, `node scripts/smoke-production.mjs` verifies generated assets, source-download consistency, local-only requests, and the editing dialog's accessibility.

Browser tests use an installed Google Chrome (`channel: 'chrome'`).
Tests cover binary outputs, PDF page counts, archive contents, Unicode text behavior, media encoding, cancellation, input rejection, accessibility, and mobile navigation.
The tiny image and video fixtures were synthesized for this project with FFmpeg, with no third-party media.
The QR fixture was generated from the project test URL using the open-source `qrcode` CLI.

## Self-host

Deploy the contents of `dist/` to a static host, keeping `/engines/` alongside the app.
The current configuration expects hosting at the domain root.
Serve `.wasm` as `application/wasm`, JavaScript modules with a JavaScript MIME type, and use HTTPS outside localhost.
No database, backend process, cross-origin isolation, or third-party CDN is required.
For production security headers and deployment details, see [docs/architecture.md](architecture.md).

## Research and project contracts

- [Reference research and feature comparison](reference-research.md)
- [Architecture and processing boundaries](architecture.md)
- [Design contract](../DESIGN.md)
- [Contributor instructions](../AGENTS.md)
- [Third-party notices](../THIRD_PARTY_NOTICES.md)

## License

Converty is licensed under **GPL-3.0-or-later**.
The project includes GPL-licensed FFmpeg core binaries; other dependencies retain their own licenses.
See [LICENSE](../LICENSE) and [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
Tangerine branding, site code, demo footage, and artwork are not included in this project.
