// Copyright (c) 2026 LeoMoon Studios
// Strict conversion of picker output and local file URLs to absolute paths.
var LocalPath = (function () {
    "use strict";

    function fail(message) {
        var error = new Error(message);
        error.code = "INVALID_PATH";
        throw error;
    }

    function fromPickerOutput(value) {
        if (typeof value !== "string") fail("Picker output must be a string");
        return value.replace(/\r?\n$/, "");
    }

    function absolute(pathOrUrl) {
        if (typeof pathOrUrl !== "string" || pathOrUrl.length === 0) fail("A non-empty local path is required");
        if (pathOrUrl.indexOf("\0") !== -1) fail("Local paths cannot contain a null byte");
        var value = pathOrUrl;
        if (value.indexOf("file://") === 0) {
            var encoded = value.substring(7);
            if (encoded.indexOf("localhost/") === 0) encoded = encoded.substring(9);
            else if (encoded.charAt(0) !== "/") fail("Remote file URLs are not supported");
            try { value = decodeURIComponent(encoded); }
            catch (error) { fail("The local file URL is malformed"); }
        } else if (/^[A-Za-z][A-Za-z0-9+.-]*:/.test(value)) {
            fail("Only local file paths are supported");
        }
        if (value.indexOf("\0") !== -1) fail("Local paths cannot contain a null byte");
        if (value.charAt(0) !== "/") fail("The local path must be absolute");
        if (/(?:^|\/)\.\.?(?:\/|$)/.test(value)) fail("Relative path segments are not supported");
        return value;
    }

    function fileName(pathOrUrl) {
        var value = absolute(pathOrUrl);
        var slash = value.lastIndexOf("/");
        return value.substring(slash + 1);
    }

    return Object.freeze({ absolute: absolute, fileName: fileName, fromPickerOutput: fromPickerOutput });
}());
