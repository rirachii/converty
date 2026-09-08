# Web verification

This records the earlier browser build. See [native verification](native-verification.md) for the current macOS app.

Verified locally on 2026-09-08 using installed Google Chrome on macOS.

## Automated checks

- TypeScript typecheck: passed.
- Unit validation suite: 16 passed.
- Browser suite: 11 passed.
- Production build: passed.
- Production smoke: contextual resize, PDF page rendering, and audio conversion passed.
- Production source download: ZIP contents match the working application source.
- Observed production smoke requests: no external origins and no file uploads.
- Observed production runtime errors: none.

The browser suite checks actual JPEG/PNG/MP3/MP4 bytes, image dimensions, PDF page counts, archive entries, TIFF round-trip, DOCX output, Latin Unicode text round-trip, QR reading, collage dimensions, supported video formats, crop/trim/speed/mute/snapshot operations, audio operations, cancellation, unsupported inputs, tool entry before upload, and responsive navigation.
This is functional coverage with synthetic small fixtures, not a claim that every possible codec or large file has been tested.

## Rendered and accessibility checks

The workspace was inspected in the real browser at 1440 pixels wide and at 390 pixels with touch emulation.
There was no horizontal overflow at 390 pixels.
Automated WCAG A/AA checks passed for the desktop entry surface, mobile navigation, and the production resize dialog.
Reduced motion and Escape dismissal were checked in the browser suite.
Contrast findings from the initial iteration were corrected before handoff.

## Distribution state

The local development server is at http://127.0.0.1:5173.
The built production preview is at http://127.0.0.1:4173.
The static distribution is generated in `dist/`.
The source archive is available at `/converty-source.zip` and through the app's Open source dialog.
Source is published at [rirachii/converty](https://github.com/rirachii/converty).
There is no public web deployment or release tag.

## Remaining boundaries

No physical mobile device, Safari, Firefox, screen reader, or large-file stress test was performed.
There is no full native Tangerine parity claim; see `reference-research.md` and the README for explicit omissions.
The build reports a large lazy-loaded PDF/font-processing chunk; this is fetched when that functionality is used, not in the initial application bundle.
Media processing loads a roughly 32 MB self-hosted engine on first use.
