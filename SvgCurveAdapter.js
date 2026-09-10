// QML bridge for the lazily instantiated curve-export controller.
.import "vendor/typr.js" as TyprLibrary
.import "SvgCurveExporter.js" as Exporter
.import "ResourceLimits.js" as Limits

function exportSvg(text, fontBytes, options) {
    return Exporter.SvgCurveExporter.exportSvg(text, fontBytes, options, TyprLibrary.Typr, Limits.ResourceLimits)
}

function inspect(text, fontBytes, options) {
    return Exporter.SvgCurveExporter.inspect(text, fontBytes, options, TyprLibrary.Typr, Limits.ResourceLimits)
}
