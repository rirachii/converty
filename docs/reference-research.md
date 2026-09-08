# Tangerine reference research

Research date: 2026-09-08.
Primary source: [Tangerine for Mac](https://tangerineformac.com/).
One unique embedded video was present: [the 22.5-second demo](https://tangerineformac.com/videos/tangerine-demo.mp4).
The HTML and rendered category panels were inspected, and the video was sampled visually at two-second intervals.
There was no audio stream.
No additional videos were supplied in the conversation.

## What the video actually demonstrates

| Time | Observed behavior | Web adaptation |
| --- | --- | --- |
| 0-4 seconds | A selected MOV file is dragged into a radial format selector; a progress panel reports MP4 conversion. | File queue with an explicit output format and real progress. |
| 4-8 seconds | A separate MP4 appears next to the original MOV; Shift reopens the format wheel. | Results are separately downloadable; original File objects remain untouched. |
| 8-10 seconds | Adding Option switches the wheel from formats to advanced tools. | A contextual tool list and searchable tool library work on desktop and touch. |
| 10-16 seconds | Crop Video opens a preview with aspect ratio, dimensions, controls, and Apply; a cropped copy is created. | Centered aspect-ratio cropping with a local preview and a separate output. Freehand positioning is not yet implemented. |
| 18-22 seconds | The advanced wheel opens again and highlights Split among the available tools. | Tool selection is supported. The footage does not show a completed split; video splitting is not implemented in Converty. |

The video visually shows an interface and completion feedback.
This research did not install the native Mac app or validate its output files.

## Site behavior and claims

The site markets 82 conversion options and 20 advanced file tools for Apple silicon Macs running macOS 13 or later.
These are vendor claims, not independently verified capability counts.
Its interactive playground uses sample files and simulated conversion results, rather than transforming visitor-provided files.
The playground advertises Shift-drag for formats, Shift-Option-drag for tools, Enter/arrow-key navigation, Escape cancellation, and touch hold-to-convert.
The web implementation replaces the radial wheel with an accessible queue and contextual controls suited to touch and keyboard input.

## Preserved web edition feature comparison

| Reference feature | Converty web status |
| --- | --- |
| Images: JPG, PNG, WebP, TIFF, HEIC, SVG input | JPG/PNG/WebP/GIF/SVG/TIFF input; HEIC deferred. SVG is rasterized for output. |
| Image compression, cropping, metadata removal | Implemented; crop is centered aspect ratio. Re-encoding removes source tags. |
| Multiple images to PDF/collage | Implemented in workspace order; collage has column and spacing controls. |
| QR reading in images/PDFs | Implemented, one QR per image/page. |
| Video MP4/MOV/MKV conversion, GIF/audio export | Implemented, plus WebM and WAV output. Preview depends on browser codec support. |
| Video compression, trim, crop, speed, mute, snapshot, metadata | Implemented. Speed uses an audio tempo filter to preserve pitch. |
| Video joining and splitting | Deferred. |
| MP3/M4A/WAV/FLAC conversion | Implemented, plus OGG. |
| Audio compression, normalize, trim, channel conversion, metadata | Implemented. |
| Automatic edge-silence removal; still-image audio-to-video | Deferred. |
| PDF merge, split, metadata removal | Implemented; page selections preserve specified order. |
| PDF compression | Rebuild with compact object streams; no image downsampling. |
| PDF to images at 300 DPI | Implemented at 150 DPI to bound browser memory. |
| PDF text extraction | Implemented for selectable text; no OCR. |
| PDF to DOCX with text/images fallback | Text-only DOCX implemented; layout and scanned-page fallback deferred. |
| UTF-8 TXT to PDF/images | Implemented with a Latin font; unsupported glyphs are rejected explicitly. DOCX preserves other scripts. |
| ZIP/TAR/GZIP/RAR extraction and conversion | ZIP and GZIP implemented; TAR and RAR deferred. |
| Finder-wide zero-click gesture | Not available to an ordinary browser app; explicit file picker and drop area replace it. |
| No file uploads | Implemented. Conversion inputs remain in browser memory. Engines/fonts are same-origin static assets. |
| Open source, self hosting, cross-platform web | Added by Converty. GPL-3.0-or-later, static deployment, no accounts. |

## Implementation sources

- [FFmpeg.wasm usage and self-hosted core setup](https://ffmpegwasm.netlify.app/docs/getting-started/usage/).
- [PDF-lib creation, copying, and embedding](https://pdf-lib.js.org/).
- [PDF.js rendering examples](https://mozilla.github.io/pdf.js/examples/).
- [UTIF.js TIFF decoder and encoder](https://github.com/photopea/UTIF.js).
- [VoltAgent design analyses](https://github.com/VoltAgent/awesome-design-md), with Linear and Raycast examined for surface and hierarchy principles.

Converty does not distribute Tangerine's JavaScript, artwork, video, icons, or branding.

## Native implementation after the local-video clarification

The user subsequently supplied the local demo and explicitly requested its interaction rather than the workspace-first adaptation.
A second pass sampled the video every half second and inspected full-resolution wheel/editor frames.
The step-by-step plan was written before the wheel implementation in [the native drag plan](plans/2026-09-08-native-drag-wheel.md).

The native edition adds contextual radial formats, Shift/Option drag handling, a compact editor and progress flow, sibling outputs, freeform positioned crop with video-frame scrubbing, HEIC, TAR/TGZ and libarchive extraction, native multi-code QR reading, video joining/splitting, edge silence trimming, and cover-image audio-to-video.
Its capabilities and verification state are documented separately in the [README](../README.md) and [native verification](native-verification.md).
The earlier web limitations in the comparison table are not claims about the native edition.
