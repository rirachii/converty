# Third-party notices

Converty application source is GPL-3.0-or-later.
Dependencies retain the licenses in their distributed packages.
Native engine and libarchive notices are in [macOS/Resources/THIRD_PARTY_NOTICES.txt](macOS/Resources/THIRD_PARTY_NOTICES.txt). The supplied native FFmpeg executable is a local build input, not a committed binary.

The following dependencies belong to the preserved web edition. Exact versions are recorded in `package-lock.json`.

| Component | License | Source |
| --- | --- | --- |
| React / React DOM | MIT | https://github.com/facebook/react |
| Lucide icons | ISC | https://github.com/lucide-icons/lucide |
| FFmpeg.wasm JavaScript wrapper | MIT | https://github.com/ffmpegwasm/ffmpeg.wasm |
| FFmpeg core 0.12.10 | GPL-2.0-or-later | https://github.com/ffmpegwasm/ffmpeg.wasm/tree/v12.15 |
| PDF-lib | MIT | https://github.com/Hopding/pdf-lib |
| PDF.js | Apache-2.0 | https://github.com/mozilla/pdf.js |
| docx | MIT | https://github.com/dolanmiu/docx |
| fflate | MIT | https://github.com/101arrowz/fflate |
| UTIF.js | MIT | https://github.com/photopea/UTIF.js |
| jsQR | Apache-2.0 | https://github.com/cozmo/jsQR |
| PDF-lib fontkit | MIT | https://github.com/Hopding/fontkit |
| DM Sans / Noto Sans fonts | SIL Open Font License 1.1 | https://github.com/google/fonts |

The application serves the unmodified single-thread FFmpeg core from the pinned npm package.
The source tag above includes the Docker build recipe and the underlying codec/library source versions.
The compiled FFmpeg core includes additional codec libraries governed by the upstream build's license terms.
Keep this notice and corresponding build/source information with redistributed builds.
The complete license texts provided with npm dependencies are available after `npm ci`.

The web favicon and web interface icons are rendered from Lucide.
The native interface uses Apple's SF Symbols, and its app icon uses generated artwork in `macOS/Artwork/AppIcon.icon`.
The user's BirdDex, FishDex, and CarDex icons informed its visual style; those reference files are not included in Converty.
The landscape image, two-note audio, PDF samples, and test fixtures were created for this project.
No Tangerine branding, source code, icon files, images, or demo video is distributed.
