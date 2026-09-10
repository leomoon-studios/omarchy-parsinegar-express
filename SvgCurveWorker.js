// Font parsing and SVG outline generation run outside the QML scene/UI thread.
Qt.include("vendor/typr.js");
Qt.include("ResourceLimits.js");
Qt.include("SvgCurveExporter.js");

var currentJob = null;

function fail(message, error) {
    currentJob = null;
    WorkerScript.sendMessage({
        id: message.id,
        ok: false,
        code: String(error && error.code || "EXPORT_FAILED"),
        message: String(error && error.message || error),
        details: error && error.details || []
    });
}

function finish(message) {
    try {
        var bytes = new Uint8Array(currentJob.fontBytes);
        ResourceLimits.assertFontBytes(bytes);
        var warnings = SvgCurveExporter.inspect(
            currentJob.text, bytes, currentJob.options, Typr, ResourceLimits
        ).missingGlyphs;
        var svg = SvgCurveExporter.exportSvg(
            currentJob.text, bytes, currentJob.options, Typr, ResourceLimits
        );
        ResourceLimits.assertSvgSize(svg);
        currentJob = null;
        WorkerScript.sendMessage({
            id: message.id,
            ok: true,
            svg: svg,
            warnings: warnings
        });
    } catch (error) { fail(message, error); }
}

WorkerScript.onMessage = function (message) {
    if (message.action === "begin") {
        currentJob = { id: message.id, text: message.text, options: message.options, fontBytes: [] };
        return;
    }
    if (message.action !== "chunk" || !currentJob || currentJob.id !== message.id) return;
    try {
        for (var index = 0; index < message.fontBytes.length; index++)
            currentJob.fontBytes.push(message.fontBytes[index]);
        if (message.final) finish(message);
    } catch (error) { fail(message, error); }
};
