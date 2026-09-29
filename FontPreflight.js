// Metadata and four-byte signature checks for Linux font files.
var FontPreflight = (function () {
    "use strict";

    function statCode(output, exitCode, maximum) {
        var match = /^([0-9a-fA-F]+) ([0-9]+)\s*$/.exec(String(output));
        if (exitCode !== 0 || !match || (parseInt(match[1], 16) & 0xf000) !== 0x8000)
            return "INVALID_FONT";
        var size = Number(match[2]);
        if (!Number.isSafeInteger(size) || size > maximum) return "FONT_TOO_LARGE";
        return size >= 4 ? "" : "INVALID_FONT";
    }

    function headerCode(output, exitCode) {
        var header = String(output).trim().toLowerCase().replace(/\s+/g, "");
        return exitCode === 0 && (header === "00010000" || header === "4f54544f")
            ? "" : "INVALID_FONT";
    }

    return Object.freeze({ statCode: statCode, headerCode: headerCode });
}());
