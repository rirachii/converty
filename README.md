# Converty

<img src="macOS/Artwork/AppIcon.icon/Assets/Converty.png" alt="Converty app icon" width="128" height="128">

An open-source, native macOS file utility inspired by Tangerine's local file workflow.
Built with SwiftUI and AppKit, with image, video, audio, PDF, text, and archive tools.
Files stay on your Mac and every operation creates a separate copy.

[Source](https://github.com/rirachii/converty) · [Report an issue](https://github.com/rirachii/converty/issues) · [Contribute](CONTRIBUTING.md)

Converty is an early source release.
Build the Mac app locally using the instructions below; a signed, notarized download is not available yet.

## Build and open the Mac app

Runs on macOS 14+; building requires Xcode 26+, XcodeGen, and a self-contained FFmpeg executable.
The current local build targets Apple Silicon.

```sh
git clone https://github.com/rirachii/converty.git
cd converty

# Set this to your self-contained FFmpeg binary if it is elsewhere.
export CONVERTY_FFMPEG="$HOME/.local/bin/ffmpeg"
macOS/Scripts/build.sh
open dist-native/Converty.app
open -R dist-native/Converty.app
```

The build script creates a real `.app`, bundles the media engine, and signs it for local use.
It does not install a browser wrapper or require Node.js to run the Mac app.
See [native build instructions](macOS/README.md) for setup and release boundaries.

## Use it

1. Start dragging a file in Finder, then hold **Shift** to reveal the format wheel.
2. Drag onto a format segment and release to convert.
3. Add **Option** while holding Shift to switch to editing tools.
4. Drop onto **Crop** for a floating editor with a movable/resizable crop box, freeform proportions, percentage controls, and a video timeline.
5. Apply the edit. Wheel results are saved **beside the original**, with a unique name, and the compact result panel can reveal them in Finder.

For click and keyboard access, choose **Format Wheel…** from Converty's menu, or press **⇧⌘Space** in the app.
Select files, then click a segment; **Space** switches formats/tools, arrow keys select, **Return** applies, and **Escape** closes the wheel.

The main workspace remains available for batches: add files with **⌘O**, choose settings in the inspector, and run with **⌘Return**.
Workspace outputs also default to **Beside originals**, including batches from different folders.
Combined outputs, such as merged PDFs or collages, are saved beside the first file in list order.
Use the **Save to** menu in the toolbar, inspector, or Settings to choose another folder or switch back to **Beside originals**.
Existing files are preserved; a numeric suffix is added when a result's name is already taken.
Closing the main window keeps the menu-bar utility running; **⌘Q** quits.
The Shift-drag trigger can be disabled in Settings.
Settings also offers System, Light, and Dark appearance.
The Mac edition has a generated blue icon in the Dex app family style, adaptive neutral surfaces, and native Liquid Glass controls on macOS 26.
See [verification](docs/native-verification.md) for completed checks and any remaining physical gesture check.

## Native capabilities

| Files | Outputs | Additional tools |
| --- | --- | --- |
| Images | PNG, JPG, WebP, HEIC, TIFF, PDF | Compress, resize, positioned aspect crop, metadata removal, collage, images-to-PDF, QR reading |
| Video | MP4, MOV, MKV, WebM, GIF, MP3, M4A, WAV | Compress, crop, trim, speed, mute, metadata removal, snapshot, join, split |
| Audio | MP3, M4A, WAV, FLAC, OGG, AIFF | Compress, trim, normalize, mono/stereo, metadata removal, edge silence trimming, cover-image video |
| PDF | PNG/JPG pages, TXT, DOCX | Merge, split, selectable-text extraction, QR reading, document-property cleanup and rewrite |
| TXT, Markdown, RTF | PDF, PNG/JPG pages, DOCX | Unicode text conversion |
| Folders and supported archives | ZIP, TAR, TGZ, single-file GZIP | Extraction through macOS libarchive, with path and link checks |

There are 21 additional tools plus format conversion. Supported input extensions are defined in `macOS/Sources/ConvertyCore/Models.swift`; codec and archive variants can still affect decoding.

## Current boundaries

- Local build, not a notarized public release. No hosted service, account, analytics, or file uploads.
- No OCR, DOCX input, promised-file downloads, or Finder toolbar extension. Finder Open With and a Services entry are included.
- PDF-to-DOCX preserves selectable text, not the original layout or embedded images. PDF rewriting does not downsample images or guarantee smaller files.
- Animated images and multipage TIFF use the first frame/page. Video previews and split timing depend on macOS-readable media; FFmpeg conversion supports more formats.
- Metadata tools remove image tags, file-level media tags/chapters, or PDF document properties. They do not scrub content or nested PDF objects.
- Images are limited to 80 MP and 32,768 pixels per side; archives to 10,000 entries and 2 GB unpacked. Symbolic/hard links are rejected on extraction. GZIP accepts one file.
- The file queue is not restored after quitting. Outputs remain on disk, and the save-location preference and default quality are remembered.

## Development

```sh
CONVERTY_FFMPEG="$HOME/.local/bin/ffmpeg" swift test --package-path macOS
```

Media tests also need `ffprobe` on PATH (or `CONVERTY_FFPROBE`).
See [native architecture](docs/native-architecture.md), [verification](docs/native-verification.md), [design contract](DESIGN.md), and [reference research](docs/reference-research.md).

The earlier React web app is preserved. See [web edition](docs/web-edition.md) for its separate features, limitations, and npm commands.
Contributions and reproducible bug reports are welcome; start with [CONTRIBUTING.md](CONTRIBUTING.md).
GitHub Actions runs the native core tests and the web type checks, unit tests, browser tests, and production build.

## License

Converty source is **GPL-3.0-or-later**. See [LICENSE](LICENSE) and [third-party notices](THIRD_PARTY_NOTICES.md).
Tangerine branding, source, assets, and demo footage are not included.
