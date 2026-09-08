# Converty source

This web application is free software under GPL-3.0-or-later.

Download the application source archive from this server:

[converty-source.zip](./converty-source.zip)

Extract it, install Node.js 22.12 or later, and run:

```sh
npm ci
npm run dev
```

The source includes the native macOS app in `macOS/`, the preserved web app, the dependency lockfile, tests, documentation, and build scripts.
For native setup, follow `macOS/README.md` inside the archive.
Native FFmpeg binaries are supplied at build time and are not included in the source ZIP.
The public source repository is [rirachii/converty on GitHub](https://github.com/rirachii/converty).

FFmpeg core is separately licensed under GPL-2.0-or-later.
Its upstream versioned build sources are linked in THIRD_PARTY_NOTICES.md inside the archive.
Other dependencies retain their respective licenses, distributed with their npm packages.

This project is independent of Tangerine for Mac.
