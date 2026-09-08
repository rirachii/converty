# Finder drag wheel and compact editing plan

Status: plan written before implementation; implementation complete, native conversion and crop flows verified, physical Finder modifier-drag check awaiting user feedback.

## Evidence

The supplied `tangerine-demo.mp4` is 22.5 seconds, 1316 × 1080, 60 fps, with no audio.
It was sampled every half second and important frames were inspected at full resolution.
Reference frames remain outside Git; no footage or reference artwork is included in the app.

| Time | Observed behavior | Converty acceptance |
| --- | --- | --- |
| 0–1.5 s | A desktop MOV is dragged, then Shift reveals a wheel around its starting pointer position. | A native floating wheel appears during a supported file drag while Shift is held, without activating the main window. |
| 1.5–3.5 s | Five format segments surround a file thumbnail; hover changes the highlighted segment and center label. | Contextual formats, stable wheel center, actual pointer hit testing, and clear active choice. |
| 4–6 s | A compact conversion progress panel appears; a separate MP4 is created beside the MOV. | Real engine progress, cancel, collision-safe sibling output, no modification or relocation of the source. |
| 8.5–11 s | Shift shows formats; Option switches to an advanced wheel; Crop is chosen. | Modifier switching within the same drag, using tools compatible with all dragged files. |
| 11–15 s | Crop Video opens in a compact panel with a video preview, adjustable crop, Freeform ratio, Reset, dimensions, width/height percentages, and frame timeline. | Floating editor with draggable/resizable crop rectangle, fixed/free aspect, live pixel size, timeline, Reset, Apply. |
| 15–18 s | Apply closes the editor, progress appears, and a cropped copy arrives beside the source. | Same compact progress flow and sibling-output policy. |
| 18–22.5 s | The new file is dragged and the wheel switches modes and highlights several tools. | Newly produced files work as normal inputs; all displayed choices route to real tools. |

The video does not demonstrate a completed split operation, every format, or the app's permission setup.
The current implementation already has real conversions and 21 tools, but its main-workspace and grid-drop UI do not satisfy this interaction.

## Step 1: drag lifecycle and window plumbing

Add `macOS/App/DragWheelController.swift` and a small pure interaction model in `ConvertyCore`.
Observe mouse drags and current modifier state using public AppKit APIs.
Use a borderless, nonactivating NSPanel positioned at the initial pointer, clamped to the current screen.
Register a native NSView as a file drag destination.
Use the live `NSDraggingInfo.draggingPasteboard` as the authority for accepted files; the named drag pasteboard is only a preflight hint.
Never read the general clipboard, use Apple events to inspect Finder selection, or synthesize user input.
Dismiss on cancelled drag, release outside a segment, unsupported payload, or loss of the Shift trigger.
Keep idle polling small and stop event monitors at termination.

## Step 2: contextual radial selection

Add `DragWheelView.swift` with original translucent segments and SF Symbols.
The subsequent macOS 26 appearance refresh replaces the first violet treatment with neutral glass and a blue selection; the current contract is in `DESIGN.md`.
Use shared geometry for rendering and hit testing: center dead zone, outer bound, gaps, and screen clamping.
Show source thumbnail/name and the active choice in the center.
Offer formats supported by every dragged file; Option selects compatible advanced tools.
Do not include meaningless same-format conversion in the default wheel.
Allow explicit click-based access through the menu for keyboard and discoverability fallback.

## Step 3: drop execution and compact progress

Add a coordinator independent of the batch workspace's current selection/settings.
A format drop starts the existing ConversionEngine immediately after an accepted AppKit drop.
Advanced tool drops open a floating editor without showing the main workspace.
Save each single-file result beside its source by default; group outputs use the first source's folder, with the destination visible in the editor.
Keep collision protection, real progress, cancellation, and errors from ConvertyCore.
A small status panel offers Show in Finder and Retry when appropriate.

## Step 4: video crop editor and reusable tool controls

Add `FloatingToolEditor.swift` and `CropEditor.swift`.
Extend `ConversionOptions` with a normalized crop rectangle, keeping older aspect-ratio callers working.
Share crop validation and pixel rounding between image and video engines.
Provide freeform drag/resize, fixed aspect choices, width/height percentages, live dimensions, Reset, frame stepping, timeline scrubbing, and Apply.
Reuse parameter controls for trim, split points, resize, quality, audio settings, and document page ranges in other compact editors.
Use real preview frames and asset dimensions, with actionable errors where a media preview cannot be decoded.

## Step 5: integration and discoverability

Initialize the drag controller with the app lifecycle.
Make the wheel primary in menu commands, empty-state guidance, and settings; preserve the existing workspace for batch operations.
Keep native Finder Open With, output-folder access, and application shutdown behavior.
Replace documentation that calls radial selection or drag interception unimplemented only after those components exist.

## Step 6: validation and delivery

Run geometry/state tests, normalized crop validation, actual image/video crop outputs, and the existing conversion suite.
Build with `macOS/Scripts/build.sh` and verify the signed app bundle and bundled engine.
Inspect the real wheel, editor, progress, and Finder result.
Exercise the exact Finder Shift-drag interaction if the available UI automation can hold a modifier through a drag; otherwise request a focused manual gesture check and distinguish that from completed automated coverage.
Do not claim Finder gesture verification from a click-based wheel demo alone.

Commands: `CONVERTY_FFMPEG="$HOME/.local/bin/ffmpeg" swift test --package-path macOS`, `macOS/Scripts/build.sh`, and `git diff --check`.

## Native API references

- [Apple: event monitors](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html) distinguishes local/global events and keyboard accessibility requirements.
- [Apple: dragging destinations](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/DragandDrop/Concepts/dragdestination.html) documents the drag lifecycle and warns that the named drag pasteboard is not authoritative across processes.
- [Apple: draggingUpdated](https://developer.apple.com/documentation/appkit/nsdraggingdestination/draggingupdated(_:)) supports location-dependent drop decisions and periodic updates.
- [Apple: nonactivating panels](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel) and [orderFrontRegardless](https://developer.apple.com/documentation/appkit/nswindow/orderfrontregardless()) support an overlay that leaves Finder active.

## Implementation outcome

The planned controller, radial view, floating job/editor flow, and shared crop geometry are implemented.
The final automated suite passes 17 cases.
The native wheel converted MOV to MP4; the compact crop editor's resize/move/timeline/Apply flow produced a video whose dimensions matched the preview.
Both outputs were revealed beside their source in Finder and original bytes were preserved.
The exact held-modifier Finder drag remains a separate physical check, as described in [native verification](../native-verification.md).
