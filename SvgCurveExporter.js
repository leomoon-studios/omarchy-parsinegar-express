// Copyright (c) 2026 LeoMoon Studios
// Dependency-free SVG curve exporter. Pass Typr explicitly so loading stays lazy.
var SvgCurveExporter = (function () {
    "use strict";

    var OUTLINE_COMMANDS = { M: true, L: true, Q: true, C: true, Z: true };

    function fail(code, message, details) {
        var error = new Error(message);
        error.code = code;
        if (details) error.details = details;
        throw error;
    }

    function finiteNumber(value, fallback, name, allowZero) {
        if (value === undefined || value === null) return fallback;
        var number = Number(value);
        if (!isFinite(number) || (allowZero ? number < 0 : number <= 0))
            fail("INVALID_OPTION", name + " must be a " + (allowZero ? "non-negative" : "positive") + " number");
        return number;
    }

    function fontBuffer(bytes) {
        if (typeof ArrayBuffer !== "undefined" && bytes instanceof ArrayBuffer) return bytes;
        if (typeof ArrayBuffer !== "undefined" && ArrayBuffer.isView && ArrayBuffer.isView(bytes))
            return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
        if (bytes && bytes.buffer instanceof ArrayBuffer) {
            var offset = bytes.byteOffset || 0;
            var length = bytes.byteLength === undefined ? bytes.buffer.byteLength : bytes.byteLength;
            return bytes.buffer.slice(offset, offset + length);
        }
        fail("INVALID_FONT", "Font data must be an ArrayBuffer or typed-array view");
    }

    function defaultFontIndex(fonts) {
        var bestIndex = 0;
        var bestDistance = Infinity;
        for (var index = 0; index < fonts.length; index++) {
            var font = fonts[index];
            if (!font.fvar || !font.fvar[0] || !font.fvar[1] || !font.fvar[1][font._vindex]) continue;
            var axes = font.fvar[0];
            var coordinates = font.fvar[1][font._vindex][2];
            var distance = 0;
            for (var axisIndex = 0; axisIndex < axes.length; axisIndex++) {
                var range = axes[axisIndex][3] - axes[axisIndex][1];
                distance += Math.abs(coordinates[axisIndex] - axes[axisIndex][2]) / (range || 1);
            }
            if (distance < bestDistance) {
                bestDistance = distance;
                bestIndex = index;
            }
        }
        return bestIndex;
    }

    function parseFont(bytes, fontIndex, typr) {
        if (!typr || typeof typr.parse !== "function" || !typr.U)
            fail("MISSING_ENGINE", "A loaded Typr.js API is required");
        var fonts;
        try { fonts = typr.parse(fontBuffer(bytes)); }
        catch (error) { fail("INVALID_FONT", "The selected font could not be read: " + error); }
        var selectedIndex = fontIndex === null ? defaultFontIndex(fonts || []) : fontIndex;
        if (!fonts || !fonts.length || !fonts[selectedIndex])
            fail("INVALID_FONT_INDEX", "The selected font does not contain font index " + selectedIndex);
        return fonts[selectedIndex];
    }

    function codePointLabel(code) {
        var hex = code.toString(16).toUpperCase();
        while (hex.length < 4) hex = "0" + hex;
        return "U+" + hex;
    }

    function missingGlyphs(font, text, typr) {
        var missing = [];
        var seen = {};
        for (var i = 0; i < text.length;) {
            var code = text.codePointAt(i);
            var character = String.fromCodePoint(code);
            i += character.length;
            if (code === 10 || code === 13) continue;
            if (typr.U.codeToGlyph(font, code) === 0 && !seen[code]) {
                seen[code] = true;
                missing.push({ character: character, codePoint: code, label: codePointLabel(code) });
            }
        }
        return missing;
    }

    function outlineBounds(path) {
        var coordinates = path.crds || [];
        var bounds = { minX: 0, minY: 0, maxX: 0, maxY: 0, empty: coordinates.length === 0 };
        for (var i = 0; i < coordinates.length; i += 2) {
            var x = Number(coordinates[i]);
            var y = Number(coordinates[i + 1]);
            if (!isFinite(x) || !isFinite(y)) fail("INVALID_OUTLINE", "The font returned invalid outline coordinates");
            if (bounds.empty || i === 0) {
                bounds.minX = bounds.maxX = x;
                bounds.minY = bounds.maxY = y;
                bounds.empty = false;
            } else {
                bounds.minX = Math.min(bounds.minX, x);
                bounds.maxX = Math.max(bounds.maxX, x);
                bounds.minY = Math.min(bounds.minY, y);
                bounds.maxY = Math.max(bounds.maxY, y);
            }
        }
        return bounds;
    }

    function outlineLine(font, text, typr, axes) {
        var shape = typr.U.shape(font, text, { ltr: true, axs: axes });
        var advance = 0;
        for (var i = 0; i < shape.length; i++) advance += shape[i].ax;
        var path = typr.U.shapeToPath(font, shape, { axs: axes });
        for (var commandIndex = 0; commandIndex < path.cmds.length; commandIndex++) {
            if (!OUTLINE_COMMANDS[path.cmds[commandIndex]])
                fail("UNSUPPORTED_GLYPH", "The selected font uses a color, bitmap, or non-outline glyph that cannot be exported as curves");
        }
        return { advance: advance, path: path, bounds: outlineBounds(path) };
    }

    function rounded(number, precision) {
        var power = Math.pow(10, precision);
        var value = Math.round(number * power) / power;
        return String(Object.is(value, -0) ? 0 : value);
    }

    function escapeAttribute(value) {
        return String(value).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function normalizedOptions(options) {
        options = options || {};
        var bounds = options.bounds || {};
        var alignment = options.alignment || "left";
        if (alignment !== "left" && alignment !== "center" && alignment !== "right")
            fail("INVALID_OPTION", "alignment must be left, center, or right");
        var precision = options.precision === undefined ? 3 : Number(options.precision);
        if (!isFinite(precision) || precision < 0 || precision > 8 || Math.floor(precision) !== precision)
            fail("INVALID_OPTION", "precision must be an integer from 0 to 8");
        return {
            fontSize: finiteNumber(options.fontSize, 48, "fontSize", false),
            lineSpacing: finiteNumber(options.lineSpacing, 1.2, "lineSpacing", false),
            alignment: alignment,
            width: bounds.width === undefined ? null : finiteNumber(bounds.width, null, "bounds.width", false),
            height: bounds.height === undefined ? null : finiteNumber(bounds.height, null, "bounds.height", false),
            padding: finiteNumber(bounds.padding, 0, "bounds.padding", true),
            fill: options.fill === undefined ? "#000000" : String(options.fill),
            precision: precision,
            fontIndex: options.fontIndex === undefined ? null : Number(options.fontIndex),
            axes: options.axes
        };
    }

    function fontIdentity(font) {
        var names = font.name || {};
        return {
            family: names.fontFamily || names.fullName || "",
            fullName: names.fullName || names.fontFamily || "",
            style: names.fontSubfamily || names.typoSubfamilyName || "",
            unitsPerEm: font.head.unitsPerEm
        };
    }

    function inspect(text, bytes, options, typr) {
        if (typeof text !== "string") fail("INVALID_TEXT", "Text must be a string");
        var normalized = normalizedOptions(options);
        var font = parseFont(bytes, normalized.fontIndex, typr);
        return { font: fontIdentity(font), missingGlyphs: missingGlyphs(font, text, typr) };
    }

    function exportSvg(text, bytes, options, typr) {
        if (typeof text !== "string") fail("INVALID_TEXT", "Text must be a string");
        var normalized = normalizedOptions(options);
        if (normalized.fontIndex !== null && (!isFinite(normalized.fontIndex) || normalized.fontIndex < 0 || Math.floor(normalized.fontIndex) !== normalized.fontIndex))
            fail("INVALID_OPTION", "fontIndex must be a non-negative integer");
        var font = parseFont(bytes, normalized.fontIndex, typr);

        var lines = text.replace(/\r\n?/g, "\n").split("\n");
        var outlined = [];
        var maxAdvance = 0;
        var minOutlineX = 0;
        var maxOutlineBeyondAdvance = 0;
        var maxOutlineY = font.hhea.ascender;
        var minOutlineY = font.hhea.descender;
        for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
            var line = outlineLine(font, lines[lineIndex], typr, normalized.axes);
            outlined.push(line);
            maxAdvance = Math.max(maxAdvance, line.advance);
            if (!line.bounds.empty) {
                minOutlineX = Math.min(minOutlineX, line.bounds.minX);
                maxOutlineBeyondAdvance = Math.max(maxOutlineBeyondAdvance, line.bounds.maxX - line.advance);
                maxOutlineY = Math.max(maxOutlineY, line.bounds.maxY);
                minOutlineY = Math.min(minOutlineY, line.bounds.minY);
            }
        }

        var scale = normalized.fontSize / font.head.unitsPerEm;
        var leftOverhang = Math.max(0, -minOutlineX * scale);
        var rightOverhang = Math.max(0, maxOutlineBeyondAdvance * scale);
        var topOverhang = Math.max(0, (maxOutlineY - font.hhea.ascender) * scale);
        var bottomOverhang = Math.max(0, (font.hhea.descender - minOutlineY) * scale);
        var lineHeight = normalized.fontSize * normalized.lineSpacing;
        var naturalWidth = normalized.padding * 2 + leftOverhang + maxAdvance * scale + rightOverhang;
        var naturalHeight = normalized.padding * 2 + topOverhang + (font.hhea.ascender - font.hhea.descender) * scale + bottomOverhang + (lines.length - 1) * lineHeight;
        var width = normalized.width === null ? Math.max(1, naturalWidth) : normalized.width;
        var height = normalized.height === null ? Math.max(1, naturalHeight) : normalized.height;
        if (width + 0.000001 < naturalWidth || height + 0.000001 < naturalHeight)
            fail("BOUNDS_TOO_SMALL", "The requested bounds are smaller than the outlined text");

        var contentWidth = width - normalized.padding * 2 - leftOverhang - rightOverhang;
        var baseline = normalized.padding + topOverhang + font.hhea.ascender * scale;
        var paths = [];
        for (var pathIndex = 0; pathIndex < outlined.length; pathIndex++) {
            var item = outlined[pathIndex];
            if (!item.path.cmds.length) continue;
            var remaining = contentWidth - item.advance * scale;
            var alignedOffset = normalized.alignment === "right" ? remaining : normalized.alignment === "center" ? remaining / 2 : 0;
            var x = normalized.padding + leftOverhang + alignedOffset;
            var y = baseline + pathIndex * lineHeight;
            var transformPrecision = Math.max(6, normalized.precision);
            paths.push('  <path fill="' + escapeAttribute(normalized.fill) + '" transform="translate(' + rounded(x, transformPrecision) + ' ' + rounded(y, transformPrecision) + ') scale(' + rounded(scale, transformPrecision) + ' -' + rounded(scale, transformPrecision) + ')" d="' + escapeAttribute(typr.U.pathToSVG(item.path, normalized.precision)) + '"/>');
        }

        return '<?xml version="1.0" encoding="UTF-8"?>\n' +
            '<svg xmlns="http://www.w3.org/2000/svg" width="' + rounded(width, normalized.precision) + '" height="' + rounded(height, normalized.precision) + '" viewBox="0 0 ' + rounded(width, normalized.precision) + ' ' + rounded(height, normalized.precision) + '">\n' +
            paths.join("\n") + (paths.length ? "\n" : "") + '</svg>\n';
    }

    return { exportSvg: exportSvg, inspect: inspect };
})();
