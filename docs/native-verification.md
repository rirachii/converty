# Native verification

Local checks on 2026-09-08, Apple Silicon, macOS 26.5.1, Xcode 26.6.
This file separates the baseline native workspace, Finder-wheel implementation, and macOS 26 appearance refresh.

## Automated processing checks

19 XCTest cases pass across conversion outputs and interaction geometry.
The suite checks actual PNG/JPEG/HEIC/TIFF/WebP dimensions, metadata removal, image/PDF QR decoding, Unicode PDF and DOCX content, merge/split/render, ZIP/TAR/TGZ/GZIP round-trips, hidden files and empty directories, unsafe paths and links, collision suffixes, cancellation before work, video conversion/trim/crop/speed/mute/snapshot/join/split, audio encoders/channels/normalization/edge silence/cover video, and freeform image/video crop dimensions.
Radial hit testing includes 4/5/6/8-segment wheels, dead zones and outer bounds; placement includes a secondary screen with negative coordinates.
These are synthetic small-file checks, not every codec or large-file stress coverage.
The save-location checks export real images into two separate source folders, verify collision suffixes and unchanged input bytes, place a combined PDF beside the first original, and confirm that a custom folder overrides the source-folder default.

## Native UI checks completed

The rebuilt workspace opened with Beside originals selected despite the older remembered output folder.
A synthetic PNG converted to a real JPEG beside its source, and a repeated conversion created `original-2.jpg` while preserving both the PNG's SHA-256 hash and the first JPEG.
The output menu successfully selected a custom folder and switched back to Beside originals, with the persisted custom-folder flag disabled afterward.

The native workspace and first-launch surface were visually inspected.
The built app converted its original sample to JPEG and HEIC; Finder selected the actual HEIC output.
The radial format selector was inspected with a real video thumbnail and contextual outputs.
Clicking its MP4 segment ran the bundled engine, displayed real progress, and saved `short.mp4` alongside the copied test MOV in a temporary test directory.
The result reached the completed state with a Show in Finder action.

An initial floating-preview crash was traced to Apple's `_AVKit_SwiftUI` VideoPlayer bridge failing to resolve AVPlayerView metadata on this Mac.
The app now uses an explicit AppKit `AVPlayerView` representable, and immediate conversions enter the progress view before any unnecessary preview is constructed.
The corrected MP4 wheel flow completed without that crash.

The final rounded wheel and its eight video tool segments were visually inspected.
Accessible format/tool buttons are enabled and their actions work.
The final keyboard check passed: Space switched from formats to tools, Right selected Crop, and Return opened the crop editor.
Frame stepping uses the source nominal frame rate; the 12 fps fixture advanced by 0.0833 seconds.
The floating crop editor was tested with a 128 × 96 video: a corner drag reduced the box to 85% width / 80% height, the box was repositioned, and the preview was advanced.
Apply produced an H.264/AAC MP4 measuring exactly 108 × 76 pixels, matching the editor's codec-aligned dimensions.
Finder selected the cropped output beside the MOV and the earlier MP4 result.
SHA-256 hashes confirmed the original MOV was unchanged.

## Remaining physical gesture check

Finder Shift-drag activation and Shift-Option switching through a physical modifier-held drag await the user's response.

The computer-use API cannot hold modifiers during its drag operation.
A focused user check was requested for the actual Finder gesture; a click-based wheel conversion is not counted as proof of that gesture.

## macOS 26 appearance refresh

The final icon was generated with the built-in image tool using the user's BirdDex, FishDex, and CarDex app icons as style references.
The opaque 1254 × 1254 master, exact prompt, and Icon Composer document are included in `macOS/Artwork/`.
Apple's icon tools compiled the document into native icon resources and a legacy ICNS.
The new ceramic arrow artwork was visually confirmed inside the rebuilt app's empty state.

The workspace, compact tool library, native toolbar search, Settings, and floating wheel were inspected in light and dark appearances.
The app's Dark selection persisted through a restart; System appearance was restored after testing.
The workspace was resized to 900 points wide; its tool library reflowed to two columns and the file inspector retained its preview, selectors, and primary action.
Toolbar search matched Crop and displayed the native no-results state for an unmatched query.

The glass wheel preserved accessible format and tool buttons.
Space switched modes, Right selected Crop, and Return opened the floating editor.
The separate native Show tools button also switched modes, and Escape dismissed the wheel.
A real corner drag in the dark crop editor changed the 128 × 96 fixture to the displayed 108 × 76 crop.
Apply completed an H.264/AAC video with those exact dimensions and a 2.02-second duration.
SHA-256 verification confirmed that the source fixture and its test copy remained identical.

The existing 17 XCTest cases passed again during this refresh.
Increase Contrast and Reduce Transparency use the implementation's system-aware paths but were not separately toggled for visual testing.
The appearance changes do not add custom animation.
The remaining physical Finder modifier-drag check above is still separate from these click, keyboard, and crop-drag checks.

## Build and distribution

The app is generated in `dist-native/Converty.app` and contains a self-contained Apple Silicon FFmpeg executable.
The final app was launched and shown in Finder.
The native Release build and preserved web production build passed, and the generated source ZIP includes native sources while excluding built binaries.
The local signature is checked with `codesign --verify --deep --strict`.
Source is published at [rirachii/converty](https://github.com/rirachii/converty).
There is no Developer ID signing or Apple notarization.
The landing page is deployed, and the early Apple Silicon DMG uses the source and packaging process in [the release runbook](macos-release.md).
The minimum macOS 14 target and other CPU architectures have not been tested on physical machines.
The earlier web checks remain recorded separately in `docs/verification.md`.
