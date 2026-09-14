# Third-party notices

Omarchy ParsiNegar Express uses the following independently replaceable JavaScript libraries and bundled UI font. Their supplied documentation and notices are retained, and modifications are identified below. Dependencies are downloaded and copied manually; no runtime download is performed.

The root [MIT license](LICENSE) covers the original LeoMoon Studios plugin code. Bundled libraries and fonts retain their separate licenses and notices listed below.

## JsBidi

[JsBidi v0.1.0](https://github.com/leomoon-studios/js-bidi/releases/tag/v0.1.0) is distributed under LGPL-3.0-or-later. Its build is `vendor/js-bidi.js`. The supplied [LGPL text](vendor/js-bidi/LICENSE), [accompanying GPL text](vendor/js-bidi/COPYING), and [Unicode notice](vendor/js-bidi/UNICODE-LICENSE.txt) are included without changes, along with the library's own README and source/modification notices in `vendor/js-bidi/`. Copyright notices also remain embedded in the build. The exact library source and contributor build scripts are available at [the pinned source commit](https://github.com/leomoon-studios/js-bidi/tree/f5e88b19cce608404d87d58c3cf23afadbd4b9c6).

## JsParsiReshaper

[JsParsiReshaper v0.1.0](https://github.com/leomoon-studios/js-parsi-reshaper/releases/tag/v0.1.0) provides contextual reshaping for Persian (Parsi), Arabic, and other supported Arabic-script languages. Its build is `vendor/js-parsi-reshaper.js`. The supplied [MIT license and copyright notice](vendor/js-parsi-reshaper/LICENSE), README, and source/modification notices are included without changes in `vendor/js-parsi-reshaper/`. Copyright notices also remain embedded in the build. The exact library source and contributor build scripts are available at [the pinned source commit](https://github.com/leomoon-studios/js-parsi-reshaper/tree/9f7a6b36f639ccd569598ba386f2576e5e33dbe3).

## Typr.js

[Typr.js](https://github.com/photopea/Typr.js) supplies the font parser and outline reader used only by explicit SVG curve exports. `vendor/typr.js` combines upstream `src/Typr.js` and `src/Typr.U.js` from commit `02c121057750d8ab607873c1b369e717e858a643`. The supplied [MIT license](vendor/typr/LICENSE) and README are retained. The vendored file removes parser debug output, replaces one `String.replaceAll` call with the equivalent `split`/`join` form for the QML JavaScript runtime, and accesses optional `TextDecoder`, `TextEncoder`, and `UPNG` globals without assuming a browser `window`. Optional HarfBuzz, bitmap, color-font, canvas, and network paths are not used by the plugin.

## Integration and replacement

The plugin-local adapters, conversion core, and SVG exporter are separate files. JsBidi and JsParsiReshaper have not been modified for this integration; Typr.js has only the compatibility changes listed above. Users may replace library files with compatible modified versions and load them through the same adapters. Library replacement needs no manifest or checksum updates. Retain the applicable notices and rerun the relevant tests. Relative links in the retained library documentation refer to the full library repositories; use the source links above for files not bundled here.

## Vazirmatn

The UI bundles the unchanged variable font from [Vazirmatn v33.003](https://github.com/rastikerdar/vazirmatn/releases/tag/v33.003), source commit `83629f877e8f084cc07b47030b5d3a0ff06c76ec`. Copyright 2015 The Vazirmatn Project Authors. The complete supplied SIL Open Font License 1.1 is included at [assets/fonts/OFL.txt](assets/fonts/OFL.txt). The font supports the UI's regular, medium, and semibold weights in one file; no system font installation or runtime download is required.

Bundled file: `assets/fonts/Vazirmatn[wght].ttf`. Download replacement font files manually from the official project and retain the supplied license.

## Material Symbols

The plugin bundles a subset of [Material Symbols Rounded](https://github.com/google/material-design-icons) from commit `40a7a292a79d9394157e1ea24f83d52d5e17c556`. Copyright Google LLC. Material Symbols is distributed under the Apache License 2.0 retained at `assets/fonts/MaterialSymbols-LICENSE.txt`.

Bundled file: `assets/fonts/MaterialSymbolsRounded.ttf`. It was generated from the unchanged upstream variable font with fonttools `pyftsubset` and contains only settings, light mode, dark mode, export, back, forward, left-to-right text direction, right-to-left text direction, and handyman glyphs. No outlines were modified.
