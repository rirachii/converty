# Converty landing page

The marketing site for the native Mac app lives here, alongside the original application source.
The earlier browser converter remains in the parent project's `src/` directory.

## Run and build

Use Node.js 22.12 or later.

```sh
cd site
npm ci
npm run dev
```

The development server uses port 5174.
Run `npm run build` to produce a standalone static site in `dist/`, or `npm run preview` to serve that build on port 4174.
The page needs no backend, API keys, or external font service.
Third-party notices are generated before development and production builds.

## Editing

- `index.html` contains the copy, navigation, accessible file-type panels, and native HTML FAQ disclosures.
- `src/style.css` defines responsive layouts and reduced-motion behavior; `src/tokens.css` defines the color palette.
- `src/main.js` installs the selected Lucide icons and adds keyboard-accessible tab behavior.
- `public/converty.png` is the original native Converty icon, copied from the app artwork.
- `public/workspace.png` is a screenshot of Converty's actual Tools view on macOS 26, with no user files displayed.
- `PRODUCT.md` and `DESIGN.md` describe the page's audience and visual contract.

Keep capability claims aligned with the root README and native implementation.
The primary CTA links directly to the versioned GitHub DMG asset.
The early release is explicitly labeled as Apple Silicon and not notarized by Apple.
Installation-help links expand the relevant FAQ disclosure; source-build instructions remain available separately.
The Homebrew link leads to a selectable install command with a copy button when the Clipboard API is available.
The command remains readable without JavaScript; clipboard failures show manual-copy guidance.
Keep the command aligned with the canonical [Homebrew tap](https://github.com/rirachii/homebrew-tap).
The format-wheel scene is an original workflow illustration, explicitly labeled as such; it does not accept or convert files.
The format explorer switches explanations only.

## Hosting

Any static host can serve the contents of `dist/`.
The public site uses the Vercel project `converty` in `rirachiis-projects`, connected to `rirachii/converty` on GitHub.
Set the Vercel Root Directory to `site` and Node.js version to `22.x`.
`vercel.json` selects Vite, installs with `npm ci`, runs `npm run build`, and serves `dist/`.
The production branch is `main`.

For a manual deployment, run these commands from the parent repository root:

```sh
npm ci --prefix site
npm run build --prefix site
vercel link --yes --project converty --scope rirachiis-projects
vercel deploy --prod --scope rirachiis-projects
```

The root `.vercelignore` limits CLI uploads to the landing-page source and excludes dependencies, local builds, environment files, and Sites metadata.
Keep the generated `.vercel/` project link ignored.
Verify the public production URL without authentication after deploying, including the DMG download and Homebrew command.

The earlier private Sites preview is recorded separately in `.openai/hosting.json`.
That manifest contains no credential and is not part of Vercel deployments.
Keep authoring changes in this parent repository; do not create a nested Git repository in `site/`.

## License and references

Original page code and Converty artwork are GPL-3.0-or-later; see `LICENSE`.
Manrope is SIL OFL 1.1, and Lucide uses ISC with MIT notices for Feather-derived icons.
The deployed Credits link serves their complete license notices.
See [landing-page research](../docs/landing-page.md) for the reference deconstruction and verification record.
