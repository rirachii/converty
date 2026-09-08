# Native architecture

Converty's primary product is the native macOS app in `macOS/`. The React app is preserved independently in `src/`.

## Modules

`App/Workspace.swift` owns the in-memory file queue, selection, operation settings, serial job scheduling, error states, and output preferences. `WorkspaceView` presents the sidebar and file list; `InspectorView` supplies previews and contextual controls. The earlier `QuickDropView` grid remains as a secondary implementation, while the radial flow is primary.

`ConvertyApp` integrates SwiftUI windows, the menu bar, native file opening, an NSServices provider, and the Command-Shift-Space Carbon hotkey. The global registration requires no accessibility event-tap permission. The new `DragWheelController` observes mouse-button events and samples the current Shift/Option state only during a potential drag.
It uses a nonactivating panel and an AppKit drag destination; no general clipboard or Finder Apple-event inspection is used. Finder's Open With works through document-type declarations; the Services entry depends on macOS service registration.

`ConvertyCore` is a local Swift package:

- ImageIO/CoreGraphics/AppKit decode, orient, resize, crop, render, and encode images. Native HEIC encoding; FFmpeg supplies WebP encoding. Vision reads QR codes.
- PDFKit handles PDFs and CoreText lays out Unicode text. DOCX is a small OOXML text package, zipped with `/usr/bin/zip`.
- A bundled FFmpeg subprocess handles audio/video. Arguments are passed as an array, never interpolated into a shell. Native AVFoundation supplies duration and preview metadata.
- macOS system libarchive handles archives through public C declarations vendored from v3.7.7. Keep header copyright notices intact.

## Radial interaction and compact editors

`DragWheelView` draws original segments, uses shared `WheelGeometry` for hover/drop hit testing, and exposes accessible button actions for explicit click mode.
`WheelSurfaceView` embeds that drawing view inside a circular `NSGlassEffectView` on macOS 26 and provides a separate native button for switching modes.
The glass content view keeps the same 360-point wheel coordinate space and existing hit geometry.
On earlier supported systems it uses `NSVisualEffectView` with a popover material.
Mouse-down establishes the drag-pasteboard baseline; a changed file drag plus Shift opens the wheel.
The named drag pasteboard is only a preflight hint; `NSDraggingInfo.draggingPasteboard` is re-read and validated on the accepted drop.
Option switches formats/tools, while the wheel stays anchored and screen-clamped.
No operation runs on hover, centre drops, unsupported payloads, or cancelled drops.

`FloatingFlowController` owns a compact editor/progress panel; `FloatingJob` calls the same core engine without changing the batch selection.
Single-file outputs default to each original's directory; group outputs use the first source's directory, with an explicit folder control before Apply.
`CropEditor` loads oriented dimensions and preview frames, edits a normalized rectangle, and provides freeform/fixed aspect, move/resize, percentage controls, and timeline scrubbing.
`NormalizedCrop` validates and maps this rectangle to actual pixels; video crop coordinates and dimensions are rounded to even pixels for codec compatibility.

The native media preview uses an AppKit `AVPlayerView` representable, avoiding the `_AVKit_SwiftUI` VideoPlayer metadata crash observed on the verification Mac.

## Processing and file lifetime

Jobs run away from the main actor, sequentially. Each conversion gets a unique temporary directory; no engine writes to an input path. Successful results are copied into the chosen destination with a numeric suffix when a name exists. A partially failed export removes only copies made by that job. Temporary job directories are removed on success, failure, or cancellation.

`JobControl` coordinates cancellation with the active subprocess. The process runner drains stdout, stores stderr in a temporary log, parses FFmpeg progress, and terminates jobs after ten minutes. Native operations check cancellation at operation/page/entry boundaries. Progress for native operations is coarse, not a fabricated countdown.

Output files persist on disk.
Removing or clearing rows affects only the queue; the queue and result references are session-only.
`ConversionRequest.destination` is optional: nil saves beside the request's first input.
The workspace and floating flow submit separate requests for independent batch items, so a batch from several folders saves into each original's own folder.
Group operations submit one ordered request and save beside the first original.
A selected custom destination overrides this behavior for every request.
`OutputFolderMenu` exposes both choices consistently in the workspace, inspector, Settings, and floating editor.
UserDefaults stores `native.useCustomOutputFolder`, the custom output-folder path, and default quality, never file contents.
The new output-mode preference defaults to Beside originals, including when upgrading a checkout with an older remembered Downloads folder.
QR output is written as text without opening links.

## Limits

Image allocations are bounded to 80 million pixels, 32,768 on a side. Text input is bounded to 10 MB. Archives reject unsafe names, symbolic/hard links, duplicate files, and special entries; extraction counts actual expanded bytes against 2 GB and 10,000 entries. Archive creation preserves hidden files and empty subdirectories, with relative paths normalized across macOS `/var` aliases.

The app is intended for user-chosen files and uses system decoders plus the bundled engine. No network conversion or telemetry path exists. It is not a sandboxed arbitrary-file analysis service.

## Build source of truth

`macOS/project.yml` defines the app target; `Package.swift` defines the core package and tests.
The tracked `Artwork/AppIcon.icon` document and generated PNG artwork are the icon source of truth.
Xcode 26 compiles them into `Assets.car` and a legacy `AppIcon.icns`; generated projects, compiled icons, build outputs, and supplied media binaries are ignored.
`Scripts/build.sh` copies a self-contained engine, builds matching CPU architectures, and applies ad-hoc signatures.
`NativeStyle.swift` centralizes the blue accent, appearance selection, glass wrappers, and primary button style.
The `native.appearance` preference controls `NSApp.appearance`, including floating AppKit panels; the wheel invalidates its drawing when its effective appearance changes.
See `macOS/README.md` for the separate public-release gates.

## Native appearance references

The macOS 26 refresh follows Apple's [AppKit glass guidance](https://developer.apple.com/videos/play/wwdc2025/310/) and [SwiftUI glass guidance](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views).
The generated Dex-style artwork is packaged with [Icon Composer](https://developer.apple.com/icon-composer/).
Only public APIs available in the selected SDK are used; the app retains its macOS 14 deployment target.
