# Omarchy ParsiNegar Express

An Omarchy 4 shell plugin by LeoMoon Studios that prepares Persian, Arabic, Kurdish, Urdu, and Hebrew text for applications with incomplete shaping or bidirectional-text support.

## What it does

Use **Unicode mode** for applications that accept Unicode text but do not shape or order right-to-left text correctly. It prepares the text before copying it, while the destination application still uses its own suitable Unicode font.

Use **Compatibility mode** for older applications that do not support Unicode text and require legacy Maryam/LMN-compatible fonts. Select the matching font in the destination application after pasting; this mode does not support Hebrew.

The **Hebrew** shaping profile is Unicode-only. It bypasses JsParsiReshaper and uses JsBidi only for bidirectional visual ordering, without Arabic-style contextual shaping.

## Use

Click **پ** in the bar, type or paste text, choose a shaping profile and conversion mode, then click **Convert**. The converted result is copied to the clipboard.

The header provides Document, Undo, Redo, Export SVG, Text Tools, Settings, and Help actions. Source history retains up to 100 edits while the panel remains loaded. The localized Help page describes every option and workflow.

### Direction and text tools

**Apply bidi visual ordering** is enabled by default. It processes each hard-separated paragraph independently, which preserves the direction of mixed Persian and Latin text. Leave it disabled when the destination application already handles bidirectional text correctly.

Each editor paragraph uses its first strong character for direction. Latin text is left-aligned, while Persian, Arabic, Urdu, Kurdish, and Hebrew text is right-aligned.

Text Tools update the source text immediately before conversion. They include Persian normalization, writing cleanup, and alternate character forms.

### Export SVG

Use **Export SVG** to create editable, font-specific vector curves from converted text. Unicode export starts with bundled Vazirmatn. Compatibility export requires selecting a Maryam-compatible font. The exporter reports missing glyphs and can save warnings separately from the editor conversion status.

### Settings and privacy

Settings provides the interface language, shaping profiles, applicable text-shaping and named-ligature options, and the persistent editor text size. Hold `Ctrl` while scrolling over the editor to change its text size from 10 to 48 pixels.

The plugin saves those preferences in `~/.config/leomoon-studios.omarchy-parsinegar-express/settings.json`. It does not save drafts, converted text, clipboard contents, or undo history. The UI uses bundled Vazirmatn, so no separate UI-font installation is needed.

## Keyboard shortcuts

- `Ctrl+Enter`: Convert
- `Ctrl+,`: Toggle Settings
- `Ctrl+T`: Toggle Text Tools
- `Ctrl+E`: Toggle Export
- `Ctrl+H`: Toggle Help
- `Ctrl+wheel`: Change editor text size

## Preview

**ParsiNegar Express - English**

![ParsiNegar Express in English](preview.png)

**ParsiNegar Express - Persian**

![ParsiNegar Express in Persian](preview-persian.png)

**Settings**

![ParsiNegar Express settings](preview-settings.png)

## Features

- Contextual Persian text shaping and bidirectional reordering for applications with incomplete RTL support
- Unicode mode for standard Persian-capable fonts
- Hebrew Unicode support using bidi visual ordering without contextual reshaping
- Compatibility mode for legacy applications using Maryam-compatible fonts
- One-click conversion and clipboard copying
- Bounded source-text Undo and Redo with cursor, selection, and paragraph preservation
- RTL and LTR input controls, optional bidi visual ordering, and VideoStudio Pro conversion
- Persian/Arabic and Kurdish/Urdu contextual-shaping profiles, plus a Hebrew bidi-only profile
- Configurable diacritics, tatweel, ZWJ, and named ligatures including the Rial sign for applicable shaping profiles
- SVG curve export using the selected Unicode or compatibility font, with missing-glyph warnings
- English, Persian, and Arabic interfaces with persistent settings
- Lazy-loaded background processing with no activity while the menu is closed

## Install

From GitHub:

```sh
omarchy plugin add https://github.com/leomoon-studios/omarchy-parsinegar-express --enable
```

The plugin defaults to the right side of the bar. It bundles Vazirmatn v33.003 for its UI, JsBidi for bidirectional ordering, and JsParsiReshaper for contextual reshaping, so it works offline without a system Vazirmatn installation or JavaScript package installation. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for licenses and source links, [JsBidi](https://github.com/leomoon-studios/js-bidi) for its API, and [JsParsiReshaper](https://github.com/leomoon-studios/js-parsi-reshaper) for reshaper options.

## Remove

```sh
omarchy plugin remove leomoon-studios.omarchy-parsinegar-express
rm -rf ~/.config/leomoon-studios.omarchy-parsinegar-express
```

The second command is optional and permanently removes the plugin's saved settings.

## Compatibility

Omarchy 4.0+ on Wayland is the only supported environment.
