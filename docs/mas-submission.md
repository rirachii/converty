# Mac App Store submission

Converty ships two ways in parallel.
The direct-download DMG is unchanged: GPL engine, not sandboxed, sold through Stripe (see `macos-release.md` and `paid-delivery.md`).
The Mac App Store (MAS) edition is a separate Xcode target, `Converty-MAS`, built from the same source.
Licensing questions are in `mas-licensing.md`.

Nothing has been uploaded to App Store Connect, no App Store Connect record has been created, and no money has been spent.

## Running checklist

Status as of September 30, 2026.

### Done and verified

- [x] LGPL engine variant: `build-engine.py --variant lgpl` built FFmpeg 9.0.1 without GPL, nonfree, x264, or network protocols; `ffmpeg -L` reports LGPL-2.1-or-later.
- [x] H.264 encoding falls back to VideoToolbox (`h264_videotoolbox`) when the engine has no x264.
- [x] Core tests: 24 of 24 pass with the LGPL engine and with the rebuilt full GPL engine, including a new test that encodes every advertised video format.
- [x] `Converty-MAS` target and scheme in `macOS/project.yml`: App Sandbox, hardened runtime, arm64, MAS entitlements, engine as `Contents/Helpers/ffmpeg`.
- [x] Entitlements: app has `app-sandbox`, `files.user-selected.read-write`, `files.bookmarks.app-scope`; helper has only `app-sandbox` and `inherit`; no network entitlement.
- [x] Info.plist: `LSApplicationCategoryType` = `public.app-category.utilities`, `ITSAppUsesNonExemptEncryption` = `false`, `LSMinimumSystemVersion` = 14.0.
- [x] Privacy manifest `Resources/PrivacyInfo.xcprivacy`, matched against the symbols the app and engine import.
- [x] Sandboxed end-to-end test (see "Sandbox verification").
- [x] Xcode build: after an Xcode stall cleared, `build-mas.sh` built `Converty-MAS` (arm64 app and helper), passed `codesign --verify --deep --strict`, and verified the entitlements.
  A copy of that product, re-signed ad-hoc under a test bundle ID, converted a 720p MP4 to H.264/AAC MOV in the sandbox after the folder prompt; the original was unchanged and no job folders remained.
- [x] `macOS/Scripts/build-mas.sh`: stages the LGPL engine, builds, signs, verifies entitlements, packages a signed `.pkg`, and optionally validates it; never uploads.
- [x] The DMG packager refuses the LGPL engine, and `build-mas.sh` refuses the GPL engine.

### Blocked

- [ ] **Evergood Holdings signing.**
  The keychain on the build Mac has only two "Apple Development: Michelle Weng" identities.
  There is no Apple Distribution or 3rd Party Mac Developer Installer (Mac Installer Distribution) identity for any team, and the Evergood Holdings team ID has not been confirmed.
  Automated inspection of the local App Store Connect API key configuration was not permitted, so no certificate, App ID, or profile was created.
- [ ] **Validation** with `xcrun altool --validate-app` needs the signed `.pkg` and an App Store Connect API key.

### Decisions for Michelle

- [ ] **Licensing**: choose an option in `mas-licensing.md` after legal advice.
- [ ] **Bundle ID**: keep `com.myko.converty` for both editions, or choose a new one for the Evergood Holdings team.
  App IDs are unique across all Apple teams; if `com.myko.converty` is already registered to another team, Evergood Holdings cannot register it.
  Keeping one ID for both editions keeps settings and Services consistent, but both apps installed on one Mac would share an identity in Launch Services.
- [ ] **Pricing**: see "Pricing options".
- [ ] **Privacy policy URL**: publish the draft below on the website.
- [ ] **App Store Connect record**: create it only after the above are decided.

### What Michelle needs to provide

1. The Evergood Holdings team ID, and confirmation that this Mac's Apple ID has the Admin or App Manager role in that team.
2. An **Apple Distribution** certificate and a **Mac Installer Distribution** certificate for Evergood Holdings in this Mac's keychain.
   Xcode > Settings > Accounts > Evergood Holdings > Manage Certificates can create both after signing in (this may need 2FA).
3. An explicit App ID for the chosen bundle ID and a **Mac App Store Connect** provisioning profile for it.
4. For validation, an App Store Connect API key with the Developer role, stored outside the repository.
5. Put the values in the ignored file `macOS/Signing/mas.local.env`:

```sh
CONVERTY_MAS_ENGINE_DIR=/path/to/engine-lgpl
CONVERTY_MAS_TEAM_ID=XXXXXXXXXX
CONVERTY_MAS_APP_IDENTITY="Apple Distribution: Evergood Holdings (XXXXXXXXXX)"
CONVERTY_MAS_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Evergood Holdings (XXXXXXXXXX)"
CONVERTY_MAS_PROFILE=/path/to/Converty_Mac_App_Store.provisionprofile
CONVERTY_ASC_KEY_ID=XXXXXXXXXX
CONVERTY_ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Then `macOS/Scripts/build-mas.sh --validate` builds, signs, packages, and validates without uploading.
The script checks that the profile belongs to the team, matches the bundle ID, and is a distribution profile.

## Build

```sh
python3 macOS/Scripts/build-engine.py --variant lgpl --work-dir /tmp/converty-engine-lgpl \
  --source-dir dist-native/engine/sources
CONVERTY_MAS_ENGINE_DIR=/tmp/converty-engine-lgpl macOS/Scripts/build-mas.sh
```

Without signing settings, the script ad-hoc signs `dist-native/mas/Converty.app` with the MAS entitlements for local sandbox testing, and makes no package.
With them, it embeds the profile, signs the helper and app with Apple Distribution, and writes `dist-native/mas/Converty-<version>-mas.pkg` signed with the installer identity.
Bump `CFBundleVersion` in `macOS/Info.plist` for every uploaded build.

## Differences between the editions

The MAS edition offers the same formats and tools as the DMG; no advertised format or operation is lost.

| Area | Direct DMG | Mac App Store |
| --- | --- | --- |
| H.264 video encoding (MP4, MOV, MKV, join, split, audio-to-video) | x264, quality from CRF | VideoToolbox; the quality slider maps to VideoToolbox quality 20-75. Compressed sizes differ from the DMG; low-quality settings produce larger files than x264. |
| Saving beside originals | Saves directly | The first save into a folder asks for permission with a standard folder panel; the grant is remembered. Declining saves nothing. |
| Custom Save to folder | Remembered by path | Remembered as a security-scoped bookmark |
| FFmpeg network protocols | Compiled in, unused | Not compiled |
| Development ffmpeg fallbacks | Homebrew and `~/.local/bin` for tests | Only the bundled helper |

## Sandbox verification

September 30, 2026, macOS 27.0, Apple Silicon.
The first test bundle was compiled from this branch with `swiftc`, because `xcodebuild` was temporarily unavailable; the Xcode product was checked later (see the checklist).
It used the test bundle ID `com.myko.converty.mastest`, so its container was separate from the installed app, and was signed with `Signing/Converty-MAS.entitlements` and `Signing/FFmpeg-MAS.entitlements`.
`codesign --verify --deep --strict` passed, and `codesign -d --entitlements -` showed the expected entitlements.
The app ran in its container, `~/Library/Containers/com.myko.converty.mastest`.

Files outside the container were opened through Launch Services, then converted through the workspace UI via accessibility actions:

- `testcard.mp4` (1080p H.264) to MOV: H.264 1920x1080 plus AAC, 6.0 s, encoded by VideoToolbox in the sandboxed helper.
- `tone.wav` to MP3: MP3 via LAME, 3.0 s.
- The first save opened the "Allow Converty to save here" panel for the originals' folder; after Allow, both files were saved beside the originals.
- `clip.mov` to MP4 with an existing `clip.mp4`: saved as `clip-2.mp4`; the existing file was unchanged; no second prompt.
- After quitting and relaunching, `tone.wav` to MP3 saved `tone-2.mp3` with no prompt, so the bookmark persisted.
- In a new folder, choosing Cancel in the panel saved nothing and re-enabled Convert.
- Every original's SHA-1 was unchanged, and the container's `tmp` had no `Converty-*` job folders left.

Not yet verified in the sandbox: the Shift-drag format wheel (needs a physical Finder drag), Finder Services, and WebM/VP9.
The notice banner is not exposed to accessibility, so its text after declining was not read back.

## App Store Connect drafts

### Name and subtitle

- Name: Converty
- Subtitle (30 characters max): Convert files on your Mac

### Description

```text
Converty converts and edits everyday files on your Mac. Your files never leave your computer, and every result is saved as a new copy beside the original.

Start dragging a file in Finder and hold Shift to open the format wheel. Drop onto a format to convert, or hold Option to switch to editing tools. For batches, add files to the workspace, choose settings, and convert them all at once.

IMAGES
Convert between PNG, JPG, WebP, HEIC, TIFF, and PDF. Compress, resize, crop, remove metadata, make a collage or a PDF from images, and read QR codes.

VIDEO
Convert to MP4, MOV, MKV, WebM, or GIF, or extract MP3, M4A, and WAV audio. Compress, crop with a visual editor, trim with a timeline, change speed, remove audio, save a frame, join clips, or split a video.

AUDIO
Convert between MP3, M4A, WAV, FLAC, OGG, and AIFF. Trim, normalize volume, switch between mono and stereo, trim edge silence, remove metadata, or turn audio into a video with a cover image.

DOCUMENTS AND ARCHIVES
Turn PDFs into PNG or JPG pages, text, or DOCX with selectable text. Merge and split PDFs. Convert text, Markdown, and RTF to PDF, images, or DOCX. Extract archives and create ZIP, TAR, TGZ, and GZIP files.

PRIVATE BY DESIGN
No account, no uploads, no analytics. Converty uses macOS frameworks and a built-in media engine. Originals are never changed, and existing files are never overwritten.
```

Check the description against the final build before submission.
PDF-to-DOCX keeps text only, not layout or images; say so if a reviewer asks.

### Keywords (100 characters max)

```text
convert,converter,video,audio,image,pdf,mp4,mp3,heic,webp,compress,resize,trim,zip,gif,file
```

### URLs

- Support URL: https://converty.halfwind.studio
- Marketing URL: https://converty.halfwind.studio
- Privacy policy URL: required, not published yet. Proposed: https://converty.halfwind.studio/privacy
  Publishing it changes the public website, so it needs Michelle's approval.

### Privacy policy draft

```text
Converty privacy policy

Converty processes your files on your Mac. It does not upload, transmit, or store your files anywhere else.
Converty does not collect personal data, usage analytics, crash reports, advertising identifiers, or device information, and it makes no network requests.
Converty stores only its own settings on your Mac, such as your preferred output folder, quality, and appearance, plus macOS permission records for folders you allow it to save into.
If you contact support by email, we use your message only to reply.
Questions: [support email to be decided]
```

### App Privacy answers

- Data collection: **No, we do not collect data from this app.**
  Converty has no analytics, accounts, crash reporting, or network requests, and the engine is built without network protocols.
- Tracking: none. `NSPrivacyTracking` is false, and no tracking domains are listed.

### Privacy manifest

`Resources/PrivacyInfo.xcprivacy` declares no collected data and these required-reason APIs:

| Category | Reason | Why |
| --- | --- | --- |
| User defaults | CA92.1 | App settings are stored in UserDefaults |
| File timestamps | 3B52.1, C617.1 | The engine calls `stat`, `fstat`, and `lstat` on user-chosen files and on files inside the app container |

Symbol scan (`nm -u`) found no disk-space, system-boot-time, or active-keyboard APIs in the app or engine.
Rescan after changing the app or engine.

### Export compliance

`ITSAppUsesNonExemptEncryption` is `false`: Converty has no network access and implements no encryption.
FFmpeg's library code contains cryptographic routines for media protocols and formats, but the MAS build disables network protocols.
Confirm this answer in App Store Connect's export compliance questions.

### Age rating

Answer "None" to every content question, and "No" to unrestricted web access, user-generated content, messaging, gambling, and advertising.
The expected rating is 4+.

### Category

- Primary: Utilities
- Secondary: Productivity

### Screenshots

Mac App Store screenshots are 16:10, at 1280x800, 1440x900, 2560x1600, or 2880x1800; use 2880x1800 for all of them, up to 10.
Capture the real MAS build with the original sample media in the repository, in light appearance, with one dark-appearance variant.

1. Workspace with a mixed queue and the inspector (the website's `workspace.png` composition).
2. Format wheel over a Finder window during a Shift-drag.
3. Crop editor on a video.
4. Trim editor with the timeline.
5. Batch completed, showing "Saved" results beside the originals.
6. Settings, showing Save to and appearance.

### Review notes

```text
Converty converts files locally. No account or sign-in is needed, and the app makes no network requests.

To test quickly: open Converty, click "Try a sample image", choose a format in the inspector, and click Convert. You can also add your own files with File > Add Files (Command-O).

Because the app is sandboxed, the first time you save beside an original in a new folder, Converty shows a standard folder panel asking you to allow access to that folder. Choose Allow. Converty remembers the folder; declining saves nothing.

Media conversion uses a bundled, sandboxed helper (Contents/Helpers/ffmpeg, an LGPL build of FFmpeg) that inherits the app's sandbox. H.264 video is encoded by Apple's VideoToolbox.

The format wheel appears when you start dragging files in Finder and hold Shift. It can also be opened from the Convert menu or the menu bar item with Shift-Command-Space. Converty observes mouse-button events only to detect that drag; it does not read keystrokes.
```

## Pricing options

The direct edition costs $9 once through Stripe.
Michelle decides the MAS pricing; these are options, not a recommendation.

1. **Same price, paid upfront ($9 tier).**
   Simplest and consistent with the website.
   Apple keeps 15% under the App Store Small Business Program (if enrolled) or 30% otherwise, so net revenue per sale is lower than Stripe.
2. **Slightly higher MAS price** (for example, the $9.99 tier) to offset commission and reflect automatic updates through the App Store.
   Buyers comparing channels see different prices.
3. **Free download with a one-time In-App Purchase unlock.**
   Lets people try Converty before buying, but needs StoreKit code, a trial or limit design, and review of what stays free.
   Not implemented.

Stripe purchases cannot be transferred to App Store licenses, and App Store purchases cannot unlock the DMG.
Decide how to answer existing buyers who ask for the App Store version.
