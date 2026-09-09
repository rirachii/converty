# Converty design contract

## Native macOS product

The primary product is a SwiftUI and AppKit file utility.
Use SF Symbols, system typography, semantic neutral surfaces, and the adaptive blue accent defined in `macOS/App/NativeStyle.swift`.
A native category sidebar, file queue, toolbar search, and preview inspector make the chosen files, action, and output folder visible together.
Use compact tool rows and a focused empty state, with one primary action.

The identity follows the user's Dex app family: a saturated azure background, a subtle translucent rim, and warm-white sculpted exchange arrows.
`macOS/Artwork/AppIcon.icon/Assets/Converty.png` is the generated opaque master, with its exact prompt and reference provenance in `macOS/Artwork/README.md`.
`macOS/Artwork/AppIcon.icon` is the editable native icon document.
It preserves the generated ceramic artwork without adding a second glass effect to that image layer.
Xcode compiles the native icon resources and a legacy ICNS fallback.

Reserve Liquid Glass for navigation and floating controls.
The wheel embeds its artwork inside an AppKit `NSGlassEffectView`, with a separate glass mode button; selected wedges use a solid blue fill and white text.
Editors use a regular system material, and primary actions use the system glass button style on macOS 26.
Use a popover material and standard prominent buttons on macOS 14 and 15.
Follow system appearance by default; Settings can select Light or Dark for Converty only.
Let system materials handle transparency preferences, retain a visible selection outline, and strengthen wheel separators when Increase Contrast is enabled.
Do not add decorative motion to the workspace or wheel.

The primary interaction is a floating radial selector invoked by Shift during a Finder file drag.
Option switches that selector to contextual tools.
Keep the wheel anchored, highlight the hovered segment, and accept a conversion only after a real drop.
Advanced operations open compact floating editors, with a small progress panel and outputs beside the source. After a successful save, the panel closes automatically without a completion popup or Finder activation. Failures keep the panel open with error and recovery controls.
Finder Open With, the macOS Services menu, native file panels, and the batch workspace remain parallel entry points. Use conventional native controls rather than a browser wrapper. The main window can be closed while the menu-bar utility continues running.

Every operation saves a new file or folder. Show progress from the engine and actual errors; keep Finder reveal actions in the batch workspace. Preserve input order for combined outputs. Never silently replace originals or existing results. The source queue is a session workspace; saved results persist on disk.
Default to saving beside each original in both the workspace and wheel.
Combined outputs use the first source's folder in list order.
The native Save to menu offers Beside originals and a custom folder, with the current choice visible before processing.

Tangerine informed contextual formats, advanced tools, local processing, and quick access from Finder.
Converty has its own name, blue identity, generated icon, layout, sample artwork, and radial artwork.
The local demo was re-analyzed before implementing its drag-to-wheel-to-editor interaction; see `docs/plans/2026-09-08-native-drag-wheel.md`.

Validate the actual native window, radial selector, and floating editors after changes, including keyboard access and narrow window layouts. Use semantic colors for system appearance; do not impose a web-style responsive/mobile layout on the Mac.

## Preserved web edition


The user is someone who wants to change or edit a file without installing an application or handing the file to a conversion service.
The main outcome is a downloadable result alongside an unchanged original.

## Structure

The fixed navigation contains file categories, the tool library, and completed results.
The workspace presents the upload target first, followed by a real file queue and secondary editing tools.
After any operation begins, show the queue so progress, errors, and downloads remain visible.
The primary action is choosing files while empty, then converting ready files once they are present.

## Visual language

Use a cool off-white canvas, quiet gray sidebar, white file rows, lavender input area, and a restrained violet action color.
DM Sans is self-hosted.
Use Lucide icons consistently, with soft category colors used only as supporting cues.
The paper-file illustration is composed from the same reusable file component as the queue.
All sample media is generated locally and is original to Converty.
Keep body and secondary text at accessible contrast; pale decorative strokes are not appropriate for essential labels.

## Interaction

Use native file selection and external drag-and-drop as parallel entry points.
Do not require a modifier key or precision drag gesture to operate the app.
Dialogs use the native HTML dialog element for focus containment and Escape dismissal.
Per-file actions open a preview and suitable controls.
Multi-file operations make their input order visible.
Results stay in session memory, and the interface tells users to download before closing the tab.

## Responsive and motion

Below 700 pixels, navigation becomes a drawer and operation panels stack vertically.
Tool cards use two columns on compact displays.
Avoid horizontal overflow with long filenames.
Focus states, status announcements, keyboard entry points, and reduced-motion behavior are required.
Hover movement is slight and disabled under reduced motion.

## Reference principles

Tangerine informed contextual format choices, separate advanced tools, local processing, and preservation of originals.
The VoltAgent design analyses of Linear and Raycast informed restrained surface hierarchy, small radii, and one primary accent.
Their distinctive branding, marketing compositions, assets, and copy were not copied.
