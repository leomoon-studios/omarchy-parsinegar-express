// Copyright (c) 2026 LeoMoon Studios
// Small, bounded parser for fc-list's tab-delimited font records.
var FontCatalog = (function () {
    "use strict";

    var maxLineLength = 64 * 1024;
    var maxOutputLength = 8 * 1024 * 1024;
    var maxRecords = 20000;

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
            !/\.(?:ttf|otf|ttc)$/i.test(path)) return;
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
            result.push({
                key: entry.path,
                path: entry.path,
                family: entry.family,
                style: entry.style,
                display: !entry.style || entry.style.toLowerCase() === "regular"
                    ? entry.family : entry.family + " - " + entry.style,
                charset: entry.charset,
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
            style: "", display: bundledDisplay, charset: "", bundled: true
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
        return { key: path, path: path, family: "", style: "", display: name, charset: "", custom: true };
    }

    return Object.freeze({ create: create, append: append, finish: finish, forMode: forMode,
        selectedEntry: selectedEntry, isLegacy: isLegacy });
}());
