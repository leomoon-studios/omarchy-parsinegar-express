import QtQuick
import Quickshell.Io
import "ResourceLimits.js" as Limits
import "LocalPath.js" as Paths
import "FontPreflight.js" as Checks

// Checks metadata and the four-byte signature without loading the font into QML.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    property bool checking: false
    property string currentPath: ""
    property string queuedPath: ""
    property string statText: ""
    property string headerText: ""
    property bool statOutputFinished: false
    property bool statExited: false
    property int statExitCode: -1
    property bool headerOutputFinished: false
    property bool headerExited: false
    property int headerExitCode: -1
    signal checked(string path, string code)

    function check(path) {
        try { queuedPath = Paths.LocalPath.absolute(path) }
        catch (error) {
            checked(String(path), "INVALID_FONT")
            return
        }
        if (!checking) startNext()
    }
    function startNext() {
        if (queuedPath === "") return
        currentPath = queuedPath
        queuedPath = ""
        checking = true
        statText = ""
        statOutputFinished = false
        statExited = false
        statExitCode = -1
        statProcess.command = ["/usr/bin/stat", "-Lc", "%f %s", "--", currentPath]
        statProcess.running = true
    }
    function finish(code) {
        var path = currentPath
        checking = false
        checked(path, code)
        startNext()
    }
    function finishStatIfReady() {
        if (!statOutputFinished || !statExited) return
        var code = Checks.FontPreflight.statCode(statText, statExitCode,
            Limits.ResourceLimits.values.maxFontBytes)
        if (code !== "") {
            finish(code)
            return
        }
        headerText = ""
        headerOutputFinished = false
        headerExited = false
        headerExitCode = -1
        headerProcess.command = ["/usr/bin/od", "-An", "-tx1", "-N4", "--", currentPath]
        headerProcess.running = true
    }
    function finishHeaderIfReady() {
        if (!headerOutputFinished || !headerExited) return
        finish(Checks.FontPreflight.headerCode(headerText, headerExitCode))
    }

    Process {
        id: statProcess
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.statText = text
                root.statOutputFinished = true
                root.finishStatIfReady()
            }
        }
        onExited: function(exitCode) {
            root.statExitCode = exitCode
            root.statExited = true
            root.finishStatIfReady()
        }
    }
    Process {
        id: headerProcess
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.headerText = text
                root.headerOutputFinished = true
                root.finishHeaderIfReady()
            }
        }
        onExited: function(exitCode) {
            root.headerExitCode = exitCode
            root.headerExited = true
            root.finishHeaderIfReady()
        }
    }
}
