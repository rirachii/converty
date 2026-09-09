# Converty landing page

The landing page markets the native SwiftUI and AppKit Mac app, preserving the older React browser converter separately.
Its canonical source is `site/` in this repository.
The primary action leads to the native build guide because Converty is an early source release without a signed, notarized installer.

## Reference research

Research was performed on September 8, 2026, using the requested [recent.design collection](https://recent.design/websites) and [Tangerine for Mac](https://tangerineformac.com/).

| Reference | Useful principle | Converty adaptation |
| --- | --- | --- |
| [Tangerine for Mac](https://tangerineformac.com/) | A short file gesture is easier to understand when the product workflow is visible; file-family exploration keeps detailed capabilities approachable. | A split hero explains the original/new-copy outcome, followed by three steps and an accessible format explorer. |
| [Paste on recent.design](https://recent.design/i/7s9nhu5-paste) and [Paste](https://pasteapp.io/) | Layered product imagery supplies depth; concise feature sections connect a utility to an everyday task. | Original file objects surround Converty's own icon, with short practical examples and a real workspace screenshot. |
| [Amie on recent.design](https://recent.design/i/lrqqbee-amie) | The archived gallery design uses overlapping interface panels, generous space, and an approachable tone. | Quiet spacing and a tactile composition, using Converty blue instead of the reference's pastel palette. |

The Amie reference is the design shown in the gallery, not a claim about the current live product.
No competitor copy, artwork, code, video, screenshots, prices, testimonials, or conversion counts are included.
The file artwork is an original CSS illustration; the app icon and native workspace screenshot come from Converty.

## Product and interaction contract

- Introduce the local Mac workflow before listing formats.
- Keep original inputs and generated copies clearly distinguished.
- Represent source-release availability honestly and link to the real GitHub build guide.
- Use semantic HTML, keyboard-operable tabs, visible focus states, native FAQ disclosures, and reduced-motion alternatives.
- Keep fonts and icons self-hosted, with license notices available from the footer.
- Keep the page static, with no uploads, accounts, analytics, fabricated progress, or simulated conversion.

## Validation

The site must build independently with `npm ci` and `npm run build` in `site/`.
Verify desktop and mobile rendering, all five file-family panels, arrow-key and Home/End tab navigation, FAQ disclosure controls, in-page navigation, local assets, source links, and reduced-motion behavior before release.
The landing page does not alter native processing or the earlier browser converter.

The initial implementation passed the production build and source-archive generation.
Browser checks covered 1440 px desktop rendering, 390 px mobile rendering, and a 320 px overflow check.
All five file panels, arrow-key and Home/End navigation, the primary CTA, FAQ expansion, and image loading passed.
The axe-core WCAG 2 A/AA and WCAG 2.1 AA scan reported zero violations, with 26 checks passing.
The CSS includes reduced-motion alternatives, and the no-JavaScript fallback exposes every file-family panel.
The generated source archive includes the landing-page sources and original assets, excluding dependency and build directories.
