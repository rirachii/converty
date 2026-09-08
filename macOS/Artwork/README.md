# Converty icon

The user requested an icon matching the existing Dex app family on 2026-09-08.
The approved `AppIcon.appiconset/AppIcon.png` assets for BirdDex, FishDex, and CarDex were inspected as style references, together with the Dex repository's `DESIGN.md` icon contract.
Those reference assets stay in the Dex repository and are not redistributed here.

`AppIcon.icon/Assets/Converty.png` is the original built-in imagegen output, an opaque 1254 × 1254 PNG.
The native Icon Composer document frames this artwork on the system icon canvas and disables additional glass effects on the image layer to preserve its ceramic material.
Xcode's asset compiler produces the application resources and legacy ICNS from this document.
The earlier vector-arrow concept was replaced by the user's requested generated style.

## Exact generation prompt

Image 1 was a temporary rendering of the earlier Converty arrow concept.
Images 2, 3, and 4 were the BirdDex, FishDex, and CarDex app icons respectively.

```text
Create the finished Converty macOS app icon in the exact visual family of the supplied Dex app icons. Image 1 is the current Converty icon: keep only its recognizable idea of two opposing exchange arrows, upper pointing right and lower pointing left. Images 2, 3 and 4 are the user's BirdDex, FishDex and CarDex app icons: these are the authoritative STYLE REFERENCES. Match their tactile warm-white ceramic/clay sculpting, soft rounded bevels, gentle upper-left studio lighting, soft contact shadows, rich saturated background, and subtle inset translucent rounded-square rim. Replace the flat/glassy arrow material of image 1 with a single bold warm ivory dimensional exchange emblem: two thick softly rounded arrows, upper right and lower left, clearly separate and immediately readable, with a slight overlap and natural depth. Both arrows must be the SAME warm ivory material, like the bird/fish/car subjects in the references, not blue translucent glass. The symbol should fill approximately 72 percent of the square width, with balanced breathing room, centered optically, viewed almost straight-on with subtle sculptural depth. Background: saturated clean azure-blue with the same gentle tonal depth and restrained fine texture as BirdDex, full-bleed edge-to-edge. A delicate translucent rounded-square rim should sit very close to the edges like the Dex references, not a thick border. Finish as one 1024 by 1024 opaque square app icon with NO outer transparent margin, no external mockup, no app name, no words, no letters, no tiny symbols, no decorative sparkles, no separate objects, no grid. This should look like a new sibling in the user's Dex icon family, beautifully crafted, simple and legible at small Dock sizes.
```

The requested generation dimensions were 1024 × 1024; the tool returned the 1254 × 1254 master recorded above.
Keep the master unchanged and let the native icon compiler render the required sizes.
