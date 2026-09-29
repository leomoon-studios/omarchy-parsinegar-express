// Copyright (c) 2026 LeoMoon Studios
// Small, bounded parser for fc-list's tab-delimited font records.
var FontCatalog = (function () {
    "use strict";

    var maxLineLength = 64 * 1024;
    var maxOutputLength = 8 * 1024 * 1024;
    var maxRecords = 20000;
    var unicodeSample = "The quick brown fox jumps over the lazy dog · روباه قهوه‌ای سریع از روی سگ تنبل می‌پرد · 0123456789 · ۰۱۲۳۴۵۶۷۸۹";
    var compatibilitySample = "0123456789 joQÂ¶ ®L¹U ªw Á»n pH ÍÄow ÁH½¼¿¤ ½IM»n";

    function fail(message) {
        var error = new Error(message);
        error.code = "FONT_CATALOG_LIMIT";
        throw error;
    }

    function create() {
        return { remainder: "", length: 0, records: 0, entries: [] };
    }

    function parseLine(state, line) {
        state.records++;
        if (state.records > maxRecords) fail("Too many font catalog records");
        if (line.length === 0 || line.length > maxLineLength) return;
        var fields = line.split("\t");
        if (fields.length !== 4) return;
        var path = fields[0];
        if (path.charAt(0) !== "/" || /[\x00-\x1f]/.test(path) || /(?:^|\/)\.\.?(?:\/|$)/.test(path) ||
            !/\.(?:ttf|otf)$/i.test(path)) return;
        var family = fields[1].split(",")[0].trim();
        var style = fields[2].split(",")[0].trim();
        if (!family || family.length > 256 || style.length > 256 || /[\x00-\x1f]/.test(family + style)) return;
        var charset = fields[3].trim();
        if (charset.length > 48 * 1024 || /[^0-9a-fA-F\s-]/.test(charset)) return;
        state.entries.push({ path: path, family: family, style: style, charset: charset });
    }

    function append(state, chunk) {
        if (typeof chunk !== "string") fail("Invalid font catalog output");
        state.length += chunk.length;
        if (state.length > maxOutputLength) fail("Font catalog output is too large");
        var start = 0;
        var newline;
        while ((newline = chunk.indexOf("\n", start)) !== -1) {
            var line = state.remainder + chunk.substring(start, newline);
            if (line.length > maxLineLength) fail("Font catalog record is too long");
            parseLine(state, line);
            state.remainder = "";
            start = newline + 1;
        }
        state.remainder += chunk.substring(start);
        if (state.remainder.length > maxLineLength) fail("Font catalog record is too long");
    }

    function charsetRanges(charset) {
        var tokens = charset.split(/\s+/);
        var ranges = [];
        for (var i = 0; i < tokens.length; i++) {
            var match = /^([0-9a-fA-F]+)(?:-([0-9a-fA-F]+))?$/.exec(tokens[i]);
            if (!match) continue;
            var first = parseInt(match[1], 16);
            var last = match[2] ? parseInt(match[2], 16) : first;
            if (first <= last && last <= 0x10ffff) ranges.push([first, last]);
        }
        ranges.sort(function (left, right) { return left[0] - right[0]; });
        return ranges;
    }

    function supports(ranges, codepoint) {
        var low = 0;
        var high = ranges.length - 1;
        while (low <= high) {
            var middle = (low + high) >> 1;
            if (codepoint < ranges[middle][0]) high = middle - 1;
            else if (codepoint > ranges[middle][1]) low = middle + 1;
            else return true;
        }
        return false;
    }

    function previewWithRanges(ranges, sample) {
        var result = "";
        for (var i = 0; i < sample.length; i++) {
            var codepoint = sample.charCodeAt(i);
            if (codepoint >= 0xd800 && codepoint <= 0xdbff && i + 1 < sample.length) {
                var low = sample.charCodeAt(i + 1);
                if (low >= 0xdc00 && low <= 0xdfff) {
                    codepoint = 0x10000 + ((codepoint - 0xd800) << 10) + low - 0xdc00;
                    i++;
                }
            }
            var character = String.fromCodePoint(codepoint);
            result += /\s/.test(character) || codepoint >= 0x200b && codepoint <= 0x200f ||
                supports(ranges, codepoint) ? character : "□";
        }
        return result;
    }

    function previewWithoutFallback(charset, sample) {
        return previewWithRanges(charsetRanges(charset), sample);
    }

    function finish(state) {
        if (state.remainder !== "") parseLine(state, state.remainder);
        state.remainder = "";
        var seenPaths = Object.create(null);
        var seenFaces = Object.create(null);
        var result = [];
        for (var i = 0; i < state.entries.length; i++) {
            var entry = state.entries[i];
            var face = entry.family.toLowerCase() + "\n" + entry.style.toLowerCase();
            if (seenPaths[entry.path] || seenFaces[face]) continue;
            seenPaths[entry.path] = true;
            seenFaces[face] = true;
            var ranges = charsetRanges(entry.charset);
            result.push({
                key: entry.path,
                path: entry.path,
                family: entry.family,
                style: entry.style,
                display: !entry.style || entry.style.toLowerCase() === "regular"
                    ? entry.family : entry.family + " - " + entry.style,
                charset: entry.charset,
                unicodePreview: previewWithRanges(ranges, unicodeSample),
                compatibilityPreview: previewWithRanges(ranges, compatibilitySample),
                bundled: false
            });
        }
        result.sort(function (left, right) {
            var familyOrder = left.family.localeCompare(right.family);
            return familyOrder || left.style.localeCompare(right.style);
        });
        return result;
    }

    function isLegacy(entry) {
        return entry.family.indexOf("F_") === 0 || entry.family.indexOf("LMN ") === 0;
    }

    function forMode(entries, mode, bundledPath, bundledFamily, bundledDisplay) {
        var result = [];
        if (mode === "unicode") result.push({
            key: bundledPath, path: bundledPath, family: bundledFamily,
            style: "", display: bundledDisplay, charset: "", unicodePreview: unicodeSample,
            compatibilityPreview: compatibilitySample, bundled: true
        });
        for (var i = 0; i < entries.length; i++) {
            if (isLegacy(entries[i]) === (mode === "compatibility")) result.push(entries[i]);
        }
        return result;
    }

    function selectedEntry(entries, path) {
        if (!path) return null;
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].path === path) return entries[i];
        }
        var name = path.substring(path.lastIndexOf("/") + 1);
        return { key: path, path: path, family: "", style: "", display: name, charset: "",
            unicodePreview: "", compatibilityPreview: "", custom: true };
    }

    return Object.freeze({ create: create, append: append, finish: finish, forMode: forMode,
        selectedEntry: selectedEntry, isLegacy: isLegacy, previewWithoutFallback: previewWithoutFallback,
        unicodeSample: unicodeSample, compatibilitySample: compatibilitySample });
}());
