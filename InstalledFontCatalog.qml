import QtQuick
import Quickshell.Io
import "FontCatalog.js" as Catalog

Item {
    id: root
    visible: false

    property var entries: []
    property bool ready: false
    property bool scanning: false
    property string error: ""
    property var scanState: null
    property bool cancelled: false
    property bool pageActive: false

    onPageActiveChanged: {
        if (!pageActive) cancel()
        else if (!ready) refresh()
    }

    function refresh() {
        if (scanning || fontList.running) return false
        scanState = Catalog.FontCatalog.create()
        cancelled = false
        error = ""
        scanning = true
        fontList.running = true
        return true
    }

    function cancel() {
        if (!scanning) return
        cancelled = true
        scanning = false
        scanState = null
        fontList.running = false
    }

    function receive(chunk) {
        if (!scanning || !scanState) return
        try {
            Catalog.FontCatalog.append(scanState, chunk)
        } catch (problem) {
            error = String(problem.message || problem)
            cancel()
        }
    }

    property Process fontList: Process {
        command: ["fc-list", "--format", "%{file}\t%{family}\t%{style}\t%{charset}\n"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root.receive(data)
        }
        onExited: function(exitCode) {
            if (root.cancelled) {
                root.cancelled = false
                if (root.pageActive && !root.ready && root.error === "")
                    Qt.callLater(function() { if (root.pageActive && !root.ready) root.refresh() })
                return
            }
            if (!root.scanning) return
            root.scanning = false
            if (exitCode !== 0) {
                root.error = "Font catalog scan failed (fc-list exit " + exitCode + ")"
                root.scanState = null
                return
            }
            try {
                root.entries = Catalog.FontCatalog.finish(root.scanState)
                root.ready = true
                root.error = ""
            } catch (problem) {
                root.error = String(problem.message || problem)
            }
            root.scanState = null
        }
    }
}
