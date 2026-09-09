# Native Converty

SwiftUI macOS app, macOS 14 or later. Local verification used Apple Silicon and macOS 26.
The generated application is `../dist-native/Converty.app`.
The downloadable DMG is an early Apple Silicon release and is not notarized by Apple.
See the [release runbook](../docs/macos-release.md) for packaging and corresponding source.

## Prerequisites

- Xcode 26 or later with the macOS SDK and command-line tools selected, including Icon Composer support.
- XcodeGen, for example `brew install xcodegen`.
- A self-contained FFmpeg executable, selected with `CONVERTY_FFMPEG`. The default lookup for the build script is `~/.local/bin/ffmpeg`.
- A compatible `ffprobe` on PATH, or `CONVERTY_FFPROBE`, for tests.

The FFmpeg build must include the encoders used by Converty, including `libx264`, `libvpx-vp9`, `libopus`, `libmp3lame`, `libvorbis`, and `libwebp`.
For core tests with Homebrew, use [ffmpeg-full](https://formulae.brew.sh/formula/ffmpeg-full) and the explicit executable paths in [CONTRIBUTING.md](../CONTRIBUTING.md).
The regular `ffmpeg` formula omits Vorbis and WebP support.

The build script checks that FFmpeg links only to system libraries and matches the app architectures to the engine. A typical Homebrew FFmpeg executable has Homebrew dylib dependencies and is rejected for app bundling. The release recipe in `Scripts/build-engine.py` builds FFmpeg and its required codecs from pinned source. Set `CONVERTY_ENGINE_DIR` to its work directory to bundle the matching licenses and provenance. Custom local builds can still use `CONVERTY_FFMPEG`; the script does not download a binary automatically.

```sh
CONVERTY_FFMPEG=/path/to/self-contained/ffmpeg ./macOS/Scripts/build.sh
CONVERTY_FFMPEG=/path/to/ffmpeg swift test --package-path macOS
open dist-native/Converty.app
```

For Xcode editing, run the build script once to prepare resources, then open `macOS/Converty.xcodeproj`. Edit `project.yml`, not the generated project file. `ConvertyCore` is also independently buildable with SwiftPM.

## Local build contents

- Native executable and system framework dependencies.
- `Contents/Resources/bin/ffmpeg`, copied from the supplied engine.
- Native icon resources and legacy ICNS compiled by Xcode from `Artwork/AppIcon.icon`, GPL license, third-party notice, and engine version/configuration/hash record.

The icon uses a generated opaque PNG master in the user's Dex app style.
Its native composition and appearance settings are editable in Icon Composer.
Open `Artwork/AppIcon.icon` to change the icon, then rebuild the app; do not edit compiled ICNS or asset catalogs.
The interface uses native Liquid Glass on macOS 26, with standard system materials and controls on macOS 14 and 15.
Settings offers System, Light, and Dark appearance without changing the Mac's global appearance.

No web server, WebView, Node process, or WebAssembly engine is used by the Mac app. The app is not sandboxed, and reads only files selected by the user or required local resources. It makes no application network requests.

## Distribution

`Scripts/package-dmg.py` packages the release app alongside the exact source ZIP, media-engine source archives, build recipe, licenses, provenance, and checksums.
The generated engine records in `Resources/MediaEngine*` are included in the app bundle.
Custom engine binaries still need corresponding source and build material before redistribution.

For a notarized release, use Developer ID signing with hardened runtime, notarize and staple the app or disk image, then test Gatekeeper installation on a clean Mac. Test the minimum supported OS and every offered CPU architecture. The current early DMG is ad-hoc signed, not a notarized release or an App Store submission.
