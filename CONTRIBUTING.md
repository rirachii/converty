# Contributing to Converty

Converty is an early open-source file utility.
The native SwiftUI/AppKit macOS app is the primary product; the earlier React web edition remains available for local browser use and development.

## Getting started

Fork [rirachii/converty](https://github.com/rirachii/converty), clone your fork, and create a branch for your change.
Read [AGENTS.md](AGENTS.md) for engineering rules and [DESIGN.md](DESIGN.md) before changing the interface.

For the Mac app, follow [macOS/README.md](macOS/README.md).
Building the complete app requires macOS, Xcode 26+, XcodeGen, and a self-contained FFmpeg executable.
The generated Xcode project and app bundle are ignored; edit `macOS/project.yml` to change project configuration.

The conversion core can be tested independently with SwiftPM and a local FFmpeg installation.
Homebrew's [ffmpeg-full](https://formulae.brew.sh/formula/ffmpeg-full) is suitable for tests, although its external libraries make it unsuitable for the app's self-contained bundle.
The regular `ffmpeg` formula omits the Vorbis and WebP encoders used by Converty.

```sh
brew install ffmpeg-full
CONVERTY_FFMPEG="$(brew --prefix ffmpeg-full)/bin/ffmpeg" \
  CONVERTY_FFPROBE="$(brew --prefix ffmpeg-full)/bin/ffprobe" \
  swift test --package-path macOS
```

For the web edition, use Node.js 22.12+ and npm:

```sh
npm ci
npm run dev
```

See [web edition instructions](docs/web-edition.md) for supported browser operations and hosting details.

## Before opening a pull request

- Keep changes focused and explain the user-visible behavior, relevant limitations, and checks performed.
- Preserve input files and keep file processing on the user's device.
- For native changes, run the core tests, build the app, and verify the affected interactions in the actual Mac app.
- For web changes, run `npm run typecheck`, `npm test`, `npm run test:e2e`, and `npm run build`.
  Browser tests use Google Chrome; install it if needed with `npx playwright install chrome`.
- Update the relevant README, architecture notes, or verification document when behavior or setup changes.
- Keep generated artifacts, reference footage, credentials, private paths, and signing material out of commits.

GitHub Actions checks native core behavior on macOS and the web edition on Linux.
It does not build a distributable Mac app or replace manual UI, Finder gesture, minimum-OS, signing, and installation checks.

## Reporting problems

Open an [issue](https://github.com/rirachii/converty/issues) with your macOS or browser version, source revision, reproduction steps, expected result, and actual result.
For conversion bugs, include the file format and operation, plus a small synthetic or public sample when possible.
Do not upload private documents, personal recordings, credentials, or sensitive diagnostic output to a public issue.

## License and releases

Contributions are made under the project's [GPL-3.0-or-later license](LICENSE).
Retain third-party notices and document the provenance of added assets or dependencies.
Tangerine and Dex reference assets are not part of this repository.

Public source and early Apple Silicon DMGs are available through [GitHub Releases](https://github.com/rirachii/converty/releases).
The early download is ad-hoc signed and not notarized by Apple.
Follow the pinned media-source, packaging, and signing requirements in [the Mac release runbook](docs/macos-release.md).
