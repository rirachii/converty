# Mac DMG releases

Converty's first downloadable release is a DMG for Apple Silicon Macs running macOS 14 or later.
The application is verified on macOS 26; macOS 14 and 15 still need release testing.
This early release is ad-hoc signed and is not notarized by Apple.
Keep that status visible on the website, release notes, and installation instructions.
Do not describe it as Developer ID signed, Apple verified, or universally compatible.

## Build the media engine

The release engine is built from source rather than repackaging a binary of unknown provenance.
`macOS/Engine/sources.json` pins each source URL and SHA-256 digest.
The build includes FFmpeg, x264, libvpx, Opus, LAME, libogg, libvorbis, and libwebp.
Only macOS system libraries remain dynamically linked.
The recipe removes libvorbis 1.3.7's obsolete `-force_cpusubtype_ALL` configure flag for compatibility with current Apple linkers.
It explicitly links macOS's system `libiconv` for FFmpeg's text conversion support.

Prerequisites are an Apple Silicon Mac, Xcode command-line tools, Python 3, GNU make as supplied by macOS, and `pkg-config`.
Building the app additionally requires Xcode 26 and XcodeGen.
Building the source ZIP requires the root npm dependencies installed with `npm ci`.

```sh
python3 macOS/Scripts/build-engine.py \
  --work-dir /tmp/converty-engine-arm64 \
  --source-dir dist-native/engine/sources

CONVERTY_FFMPEG=/tmp/converty-engine-arm64/prefix/bin/ffmpeg \
CONVERTY_FFPROBE=/tmp/converty-engine-arm64/prefix/bin/ffprobe \
swift test --package-path macOS
```

The recipe verifies every archive, compiles static libraries, checks the resulting architectures and dynamic dependencies, and records licenses and build provenance.
It caches successful builds keyed by source and recipe checksums.
Use a fresh work directory to force a clean rebuild.
The compiler, SDK, and generated engine hash are recorded in `provenance.json`; bit-for-bit reproducibility across different Xcode versions is not promised.

The media-source release archive includes the original source archives, this guide, the manifest, the exact build script, license notices, and the build provenance.
To rebuild from that downloaded archive without fetching source, extract it, enter its top-level directory, and run:

```sh
python3 macOS/Scripts/build-engine.py \
  --work-dir /tmp/converty-engine-rebuild \
  --source-dir sources
```

## Package the DMG

Commit the exact source before packaging.
The package command refuses a dirty checkout or an engine that does not match its manifest and recipe.
The explicit early-release flag allows an unnotarized build without claiming Apple notarization.

```sh
python3 macOS/Scripts/package-dmg.py \
  --engine-dir /tmp/converty-engine-arm64 \
  --allow-unnotarized
```

The command builds the native app and writes release artifacts beneath `dist-native/releases/v<version>/`.
It includes the `.app`, an Applications shortcut, and installation instructions in a compressed, read-only DMG.
It verifies the disk image, mounts it read-only, checks the packaged signatures and payload hashes, and detaches it afterward.
It also creates the application source ZIP, matching media-source archive, `release.json`, and `SHA256SUMS.txt`.
Existing release artifacts are preserved; move an earlier failed attempt aside before retrying.

Upload these assets together to the same GitHub release.
Keep binaries and source tarballs out of Git history.
Use an exact versioned GitHub release-asset URL for the website's download anchors, so clicking Get Converty starts the DMG download directly.
GitHub serves release assets as attachments; the download does not depend on client-side JavaScript or an intermediate release page.
Publish and verify the actual asset before deploying website links to it.

## Publish the Homebrew cask

The canonical cask lives in [`rirachii/homebrew-tap`](https://github.com/rirachii/homebrew-tap), at `Casks/converty.rb`.
Users install it with `brew install --cask rirachii/tap/converty`.
It downloads the same release DMG, checks its SHA-256 digest, and installs the application in Applications.
Do not maintain a second cask copy in this repository.

After publishing a new verified DMG, update the cask's version and SHA-256 from that release's `SHA256SUMS.txt` and `release.json`.
Keep its architecture and minimum macOS dependency aligned with the actual app bundle.
Keep the unnotarized caveat until signing and notarization are complete.
Run Homebrew style and audit checks and verify a real installation before publishing the tap update.
The tap's CI checks the cask and installs, verifies, and uninstalls the app on a disposable macOS runner.
Never add quarantine removal, Gatekeeper changes, or destructive preference cleanup to the cask.

## Installation and future notarization

Users open the DMG, drag Converty into Applications, and open it from Applications.
The media engine is included; developer tools are not needed to use the download.
For this early unnotarized release, macOS may block the first launch.
Link to [Apple's instructions](https://support.apple.com/en-us/102445) for users who choose to trust an app from an unidentified developer.
Do not remove quarantine attributes or disable Gatekeeper in packaging or installation scripts.

For a notarized release, obtain a Developer ID Application identity, enable hardened-runtime signing, and submit the final application or container with `notarytool`.
The build script accepts `CONVERTY_SIGNING_IDENTITY` and adds timestamp and hardened-runtime options for a named identity.
Notarization still requires the appropriate Apple account credentials and must be completed and verified before changing the website's status.
The current package script builds the app itself, so any notarization/stapling step must be integrated after that build and before packaging a notarized release.
Test Gatekeeper installation on a clean Mac and every advertised OS and architecture before broad distribution.
