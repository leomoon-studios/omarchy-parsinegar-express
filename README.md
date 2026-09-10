# Omarchy ParsiNegar Express

An Omarchy 4 shell plugin by LeoMoon Studios that prepares Persian text for applications that display its letters disconnected or in the wrong direction, such as some graphics, video-editing, and older applications.

**Unicode mode** converts the text into contextually shaped Unicode characters, joining letters into their appropriate forms and optionally rearranging them for right-to-left display. Use this mode when the destination application accepts Unicode but does not handle Persian shaping or text direction correctly. Use a Persian-capable Unicode font in that application.

**Compatibility mode** converts the shaped text into a legacy character mapping for special Maryam-compatible fonts. Use this mode for older applications that cannot use the Unicode output. After pasting, select the appropriate Maryam font in the destination application; otherwise the text will appear as unrelated characters. Maryam fonts are not bundled with the plugin.

Click **پ** in the bar, type or paste your text, choose a mode, and click **Convert** to copy the result. Expand **Export SVG** below Convert to save the converted text as font-specific vector curves; Unicode starts with bundled Vazirmatn, while Compatibility export requires choosing a Maryam-compatible font. **Reverse words** is enabled by default for visual ordering; the **RTL** and **LTR** buttons control the input box's alignment. The Settings view provides language, shaping, and all named ligature options; these are saved in `~/.config/leomoon-studios.omarchy-parsinegar-express/settings.json`, while draft text is never saved. The plugin UI uses bundled Vazirmatn, so no separate UI font installation is needed.

## Install

From GitHub:

```sh
omarchy plugin add https://github.com/leomoon-studios/omarchy-parsinegar-express --enable
```

The plugin defaults to the right side of the bar. It bundles Vazirmatn v33.003 for its UI, JsBidi for bidirectional ordering, and JsParsiReshaper for contextual reshaping, so it works offline without a system Vazirmatn installation or JavaScript package installation. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for licenses and source links, [JsBidi](https://github.com/leomoon-studios/js-bidi) for its API, and [JsParsiReshaper](https://github.com/leomoon-studios/js-parsi-reshaper) for reshaper options.

## Remove

```sh
omarchy plugin remove leomoon-studios.omarchy-parsinegar-express
```
