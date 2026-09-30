# Mac App Store licensing questions

> **Not legal advice.**
> This page records the facts of the build and the open licensing questions for the Mac App Store (MAS) edition.
> Michelle should get advice from a lawyer experienced in open-source licensing before submitting the MAS build.
> The `LICENSE` file has not been changed and must not be changed without her approval.

## What each edition ships

| Component | Direct-download DMG | Mac App Store build |
| --- | --- | --- |
| Converty app code (`macOS/App`, `macOS/Sources`) | GPL-3.0-or-later | Same source; license for this binary is undecided (see below) |
| FFmpeg 9.0.1 | Built with `--enable-gpl`, so the binary is GPL-2.0-or-later | Built without `--enable-gpl` or `--enable-nonfree`, so the binary is LGPL-2.1-or-later |
| x264 (H.264 encoder) | GPL-2.0-or-later, statically linked | Not included; H.264 is encoded by macOS VideoToolbox |
| LAME (MP3 encoder) | LGPL-2.0-or-later | LGPL-2.0-or-later |
| libvpx, Opus, libogg, libvorbis, libwebp | BSD-style | BSD-style |
| zlib, bzip2, iconv, libarchive | macOS system libraries | macOS system libraries |
| libarchive headers vendored in `macOS/Sources/CArchive` | BSD-2-Clause | BSD-2-Clause |

`macOS/Scripts/build-engine.py --variant lgpl` builds the MAS engine.
It fails the build if the FFmpeg configuration contains `--enable-gpl`, `--enable-nonfree`, `--enable-version3`, or x264, or if `ffmpeg -L` reports a license other than the LGPL.
`macOS/Scripts/build-mas.sh` repeats the configuration check and refuses any engine whose provenance is not the `lgpl` variant.
The engine is also built with `--disable-network`, matching the app's lack of a network entitlement.

## Question 1: Converty's own GPL code in the App Store

The Free Software Foundation's position is that the App Store's terms conflict with the GPL.
The App Store Terms of Service Usage Rules and Apple's standard licensed-application EULA restrict copying, redistribution, and the number of devices.
GPLv3 section 10 forbids imposing "further restrictions" on recipients.
Section 12 says that a distributor who cannot satisfy both sets of obligations may not distribute at all.
The FSF raised this in 2010 about GNU Go, and VLC was removed from the iOS App Store in 2011 after a similar complaint about GPLv2 code.

A copyright holder is not bound by their own license.
Only the copyright holders can grant permission to distribute on other terms.
The git history (checked September 30, 2026) contains commits only from Michelle's accounts (`rirachii` and `Michelle Weng`).
That suggests she holds the copyright in the app code, but a lawyer should confirm it, including for any material copied from elsewhere.
`CONTRIBUTING.md` currently accepts outside contributions under GPL-3.0-or-later without a contributor license agreement.
Any future outside contribution included in the MAS build would need its author's permission for the MAS terms.

Options for Michelle to discuss with counsel:

1. **Dual license, MAS binary under a separate license.**
   Michelle distributes the MAS binary under Apple's standard EULA, or her own EULA entered in App Store Connect.
   The public source stays GPL-3.0-or-later, and the DMG stays GPL.
   To keep this possible, adopt a CLA or copyright assignment for outside contributions, or keep outside code out of the MAS build.
2. **GPLv3 section 7 additional permission.**
   Add an explicit exception that allows distribution through app stores whose terms impose the usual restrictions.
   This changes `LICENSE` terms and applies to everyone who redistributes, so it needs Michelle's approval.
3. **Relicense the app code** under a license without the "no further restrictions" clause, such as MPL-2.0, Apache-2.0, or MIT.
   This is broader than the MAS question and affects every future recipient.
4. **Do not ship on the Mac App Store** and keep the direct DMG only.

Whatever is chosen, the in-app license text needs to match it.
The MAS target currently sets `NSHumanReadableCopyright` to "Converty contributors." without a license name.
Settings still says "Open source under GPL-3.0".
Update both once the decision is made.

## Question 2: LGPL FFmpeg and LAME in the App Store

Switching to an LGPL engine removes the GPL x264 and GPL-enabled FFmpeg code, but the LGPL still has obligations:

- Ship the license texts and notices.
  `Resources/MediaEngineNotices.txt` in the app bundle contains every component's license file.
- Provide the corresponding source for the exact binary.
  `build-engine.py` pins every source archive by SHA-256, and `MediaEngineProvenance.json` records the engine hash.
  Publish the MAS engine's source archives and recipe with each MAS release, as the DMG release already does for its engine.
- LGPL-2.1 section 6 expects users to be able to modify the library and use the modified version with the application.
  Here the whole `ffmpeg` executable is the LGPL work, and Converty runs it as a separate process rather than linking to it.
  In a signed, sandboxed App Store bundle, a user cannot replace `Contents/Helpers/ffmpeg` without breaking the signature.
  LGPL-2.1 section 10 also forbids further restrictions, which raises the same App Store terms question as above.

Many App Store apps ship LGPL FFmpeg builds, and FFmpeg publishes a [legal checklist](https://ffmpeg.org/legal.html) for this case.
Whether Converty's layout satisfies the LGPL in the App Store is a judgment for counsel.
Possible mitigations to discuss: link to the exact engine source and rebuild instructions from the app and App Store listing, and state that the engine is LGPL software.

## Question 3: codec patents

Copyright licenses do not cover patents.
The MAS build encodes H.264 with Apple's VideoToolbox, which Apple licenses, instead of x264.
FFmpeg's built-in decoders (H.264, HEVC, and others) and its native AAC encoder are included in both editions.
MP3 patents have expired; VP9, Opus, Vorbis, and WebP are royalty-free by design.
Ask counsel whether any remaining decoder or the native AAC encoder needs attention for App Store distribution.
If needed, AAC encoding can move to AudioToolbox (`aac_at`), which the engine already contains; that would be a separate, tested change.

## Summary for Michelle

- The engine question has a technical answer: the MAS build uses an LGPL-only engine and loses no advertised format (see `mas-submission.md`).
- The app-code question needs a decision only Michelle can make, as the copyright holder, with legal advice.
- The LGPL engine question needs a legal opinion on App Store distribution and a published source archive for each MAS release.
- Nothing has been uploaded to App Store Connect.
