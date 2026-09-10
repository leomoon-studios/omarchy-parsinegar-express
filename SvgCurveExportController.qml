import QtQuick
import Quickshell.Io
import "ResourceLimits.js" as Limits
import "LocalPath.js" as Paths

// Instantiate this component only in response to an explicit export action.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    property bool busy: false
    property string errorCode: ""
    property string errorMessage: ""
    property string outputPath: ""
    property string pendingText: ""
    property var exportWarnings: []
    property var pendingOptions: ({})
    property var fontByteView: null
    property int fontByteOffset: 0
    property int requestId: 0
    readonly property url bundledUnicodeFont: Qt.resolvedUrl("assets/fonts/Vazirmatn[wght].ttf")

    signal exported(string path, var warnings)
    signal failed(string code, string message, var details)

    function exportTo(text, fontPath, destinationPath, options) {
        if (busy) return false
        busy = true
        errorCode = ""
        errorMessage = ""
        exportWarnings = []
        outputPath = Paths.LocalPath.absolute(destinationPath)
        try {
            Limits.ResourceLimits.assertTextLength(text, Limits.ResourceLimits.values.maxSvgTextLength, "EXPORT_TEXT_TOO_LARGE")
            pendingText = text
            pendingOptions = options
            requestId++
            fontFile.path = Paths.LocalPath.absolute(fontPath)
            return true
        } catch (error) {
            failExport(error.code, error.message || error, error.details || [])
            return false
        }
    }

    function failExport(code, message, details) {
        fontFile.path = ""
        outputFile.path = ""
        pendingText = ""
        pendingOptions = ({})
        fontByteView = null
        fontByteOffset = 0
        exportWarnings = []
        busy = false
        errorCode = String(code || "EXPORT_FAILED")
        errorMessage = String(message || "Export failed")
        failed(errorCode, errorMessage, details || [])
    }

    function prepareFontBytes() {
        if (!busy) return
        try {
            var data = fontFile.data()
            Limits.ResourceLimits.assertFontBytes(data)
            fontByteView = new Uint8Array(data)
            fontByteOffset = 0
            curveWorker.sendMessage({
                action: "begin",
                id: requestId,
                text: pendingText,
                options: pendingOptions
            })
            copyFontChunk()
        } catch (error) {
            failExport(error.code, error.message || error, error.details || [])
        }
    }

    function copyFontChunk() {
        if (!busy || !fontByteView) return
        var end = Math.min(fontByteOffset + 65536, fontByteView.length)
        var chunk = []
        for (var index = fontByteOffset; index < end; index++) chunk.push(fontByteView[index])
        fontByteOffset = end
        curveWorker.sendMessage({
            action: "chunk",
            id: requestId,
            fontBytes: chunk,
            final: fontByteOffset >= fontByteView.length
        })
        if (fontByteOffset < fontByteView.length) {
            Qt.callLater(copyFontChunk)
            return
        }
        fontByteView = null
        fontFile.path = ""
    }

    function finishWorker(message) {
        if (!busy || message.id !== requestId) return
        pendingText = ""
        pendingOptions = ({})
        if (!message.ok) {
            failExport(message.code, message.message, message.details)
            return
        }
        try {
            Limits.ResourceLimits.assertSvgSize(message.svg)
            exportWarnings = message.warnings || []
            outputFile.path = outputPath
            outputFile.setText(message.svg)
        } catch (error) {
            failExport(error.code, error.message || error, error.details || [])
        }
    }

    WorkerScript {
        id: curveWorker
        source: "SvgCurveWorker.js"
        onMessage: function(message) { root.finishWorker(message) }
    }

    FileView {
        id: fontFile
        preload: true
        watchChanges: false
        blockLoading: false
        onLoaded: root.prepareFontBytes()
        onLoadFailed: function(error) { root.failExport("INVALID_FONT", String(error), []) }
    }

    FileView {
        id: outputFile
        preload: false
        watchChanges: false
        onSaved: {
            if (!root.busy) return
            var savedPath = root.outputPath
            var warnings = root.exportWarnings
            root.busy = false
            path = ""
            root.outputPath = ""
            root.exportWarnings = []
            root.exported(savedPath, warnings)
        }
        onSaveFailed: function(error) {
            if (!root.busy) return
            root.busy = false
            path = ""
            root.outputPath = ""
            root.exportWarnings = []
            root.errorCode = "SAVE_FAILED"
            root.errorMessage = String(error)
            root.failed(root.errorCode, root.errorMessage, [])
        }
    }
}
