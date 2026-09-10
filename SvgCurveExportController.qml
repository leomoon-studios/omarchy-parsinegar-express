import QtQuick
import Quickshell.Io
import "SvgCurveAdapter.js" as Curves

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
    property var exportWarnings: []
    readonly property url bundledUnicodeFont: Qt.resolvedUrl("assets/fonts/Vazirmatn[wght].ttf")

    signal exported(string path, var warnings)
    signal failed(string code, string message, var details)

    function localPath(pathOrUrl) {
        var value = String(pathOrUrl)
        return value.indexOf("file://") === 0 ? decodeURIComponent(value.substring(7)) : value
    }

    function exportTo(text, fontPath, destinationPath, options) {
        if (busy) return false
        busy = true
        errorCode = ""
        errorMessage = ""
        exportWarnings = []
        outputPath = localPath(destinationPath)
        try {
            fontFile.path = localPath(fontPath)
            var bytes = fontFile.data()
            exportWarnings = Curves.inspect(text, bytes, options || {}).missingGlyphs
            var svg = Curves.exportSvg(text, bytes, options || {})
            fontFile.path = ""
            bytes = null
            outputFile.path = outputPath
            outputFile.setText(svg)
            svg = ""
            return true
        } catch (error) {
            fontFile.path = ""
            outputFile.path = ""
            exportWarnings = []
            busy = false
            errorCode = String(error.code || "EXPORT_FAILED")
            errorMessage = String(error.message || error)
            failed(errorCode, errorMessage, error.details || [])
            return false
        }
    }

    FileView {
        id: fontFile
        preload: false
        watchChanges: false
        blockLoading: true
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
