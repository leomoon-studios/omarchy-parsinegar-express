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
    property string pendingFontPath: ""
    property var exportWarnings: []
    property var pendingOptions: ({})
    property var fontByteView: null
    property int fontByteOffset: 0
    property int requestId: 0
    property var fontReadOutput: null
    property bool fontReadOutputFinished: false
    property bool fontReadExited: false
    property int fontReadExitCode: -1
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
            pendingFontPath = Paths.LocalPath.absolute(fontPath)
            fontPreflight.check(pendingFontPath)
            return true
        } catch (error) {
            failExport(error.code, error.message || error, error.details || [])
            return false
        }
    }

    function failExport(code, message, details) {
        fontReader.running = false
        outputFile.path = ""
        pendingText = ""
        pendingFontPath = ""
        pendingOptions = ({})
        fontByteView = null
        fontByteOffset = 0
        fontReadOutput = null
        exportWarnings = []
        busy = false
        errorCode = String(code || "EXPORT_FAILED")
        errorMessage = String(message || "Export failed")
        failed(errorCode, errorMessage, details || [])
    }

    function beginBoundedFontRead(path) {
        if (!busy) return
        fontReadOutput = null
        fontReadOutputFinished = false
        fontReadExited = false
        fontReadExitCode = -1
        fontReader.command = ["/usr/bin/bash",
            Paths.LocalPath.absolute(String(Qt.resolvedUrl("FontRead.sh"))), path]
        fontReader.running = true
    }

    function prepareFontBytes() {
        if (!busy || !fontReadOutputFinished || !fontReadExited) return
        try {
            if (fontReadExitCode !== 0)
                throw { code: fontReadExitCode === 2 ? "FONT_TOO_LARGE" : "INVALID_FONT",
                    message: "Font validation or bounded read failed." }
            var raw = fontReadOutput
            fontReadOutput = null
            if (!raw || typeof raw.byteLength !== "number")
                throw { code: "INVALID_FONT", message: "The selected font could not be read." }
            if (raw.byteLength > Limits.ResourceLimits.values.maxFontBytes)
                throw { code: "FONT_TOO_LARGE", message: "Font exceeds the supported size." }
            fontByteView = new Uint8Array(raw)
            Limits.ResourceLimits.assertFontBytes(fontByteView)
            if (fontByteView.length < 4 || !(
                fontByteView[0] === 0 && fontByteView[1] === 1 &&
                fontByteView[2] === 0 && fontByteView[3] === 0) && !(
                fontByteView[0] === 0x4f && fontByteView[1] === 0x54 &&
                fontByteView[2] === 0x54 && fontByteView[3] === 0x4f))
                throw { code: "INVALID_FONT", message: "The selected file is not TrueType or OpenType." }
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

    FontPreflight {
        id: fontPreflight
        onChecked: function(path, code) {
            if (!root.busy || path !== root.pendingFontPath) return
            if (code !== "") root.failExport(code, "Font validation failed", [])
            else root.beginBoundedFontRead(path)
        }
    }

    Process {
        id: fontReader
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.fontReadOutput = this.data
                root.fontReadOutputFinished = true
                root.prepareFontBytes()
            }
        }
        onExited: function(exitCode) {
            root.fontReadExitCode = exitCode
            root.fontReadExited = true
            root.prepareFontBytes()
        }
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
