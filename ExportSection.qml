import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import qs.Commons
import "InterfaceStrings.js" as Strings
import "ResourceLimits.js" as Limits
import "LocalPath.js" as Paths

Column {
    id: root

    required property var controller
    required property var host
    required property Typography typography
    property bool expanded: false
    property bool advancedExpanded: false
    readonly property string bundledUnicodeFontPath: String(Qt.resolvedUrl("assets/fonts/Vazirmatn[wght].ttf"))
    property string unicodeFontPath: bundledUnicodeFontPath
    property string compatibilityFontPath: ""
    property string pendingText: ""
    property string pendingDestination: ""
    property var pendingOptions: ({})
    property string pickerKind: ""
    property string pickerOutput: ""
    property bool pickerExited: false
    property bool pickerOutputFinished: false
    property int pickerExitCode: -1
    readonly property string activeMode: host ? host.conversionMode : "unicode"
    readonly property string selectedFontPath: activeMode === "compatibility" ? compatibilityFontPath : unicodeFontPath
    readonly property bool pickerActive: pickerKind !== ""
    readonly property bool exportBusy: exportLoader.active || pickerActive
    width: parent ? parent.width : 0
    spacing: Style.space(8)
    LayoutMirroring.enabled: controller && controller.uiLanguage === "fa"
    LayoutMirroring.childrenInherit: true

    function uiText(key) { return Strings.InterfaceStrings.text(controller ? controller.uiLanguage : "en", key) }
    function selectedFontLabel() {
        if (activeMode === "unicode" && Paths.LocalPath.absolute(selectedFontPath) === Paths.LocalPath.absolute(bundledUnicodeFontPath))
            return "Vazirmatn Regular"
        return Paths.LocalPath.fileName(selectedFontPath)
    }
    function positiveValue(field, fallback, allowEmpty) {
        var value = String(field.text).trim()
        if (allowEmpty && value === "") return undefined
        var number = Number(value)
        if (!isFinite(number) || number <= 0) throw new Error("INVALID_OPTION")
        return number === undefined ? fallback : number
    }
    function nonNegativeValue(field, fallback) {
        var value = String(field.text).trim()
        var number = value === "" ? fallback : Number(value)
        if (!isFinite(number) || number < 0) throw new Error("INVALID_OPTION")
        return number
    }
    function exportOptions() {
        var bounds = { padding: nonNegativeValue(paddingField, 16) }
        var width = positiveValue(widthField, undefined, true)
        var height = positiveValue(heightField, undefined, true)
        if (width !== undefined) bounds.width = width
        if (height !== undefined) bounds.height = height
        var result = {
            fontSize: positiveValue(fontSizeField, 48, false),
            lineSpacing: positiveValue(lineSpacingField, 1.2, false),
            alignment: alignment,
            bounds: bounds
        }
        var limits = Limits.ResourceLimits.values
        if (result.fontSize > limits.maxFontSize || result.lineSpacing > limits.maxLineSpacing ||
            bounds.padding > limits.maxPadding || (bounds.width !== undefined && bounds.width > limits.maxDimension) ||
            (bounds.height !== undefined && bounds.height > limits.maxDimension)) throw new Error("INVALID_OPTION")
        return result
    }
    function reportError(code, message, details) {
        var key = "export.error.generic"
        if (code === "INVALID_OPTION") key = "export.error.invalidOption"
        else if (code === "INVALID_FONT" || code === "INVALID_FONT_INDEX" || code === "MISSING_ENGINE") key = "export.error.invalidFont"
        else if (code === "EXPORT_TEXT_TOO_LARGE") key = "export.error.textTooLarge"
        else if (code === "FONT_TOO_LARGE") key = "export.error.fontTooLarge"
        else if (code === "SVG_TOO_LARGE") key = "export.error.svgTooLarge"
        else if (code === "INVALID_DIMENSIONS") key = "export.error.dimensions"
        else if (code === "MISSING_GLYPHS") key = "export.error.missingGlyphs"
        else if (code === "BOUNDS_TOO_SMALL") key = "export.error.bounds"
        else if (code === "UNSUPPORTED_GLYPH" || code === "INVALID_OUTLINE") key = "export.error.unsupportedGlyph"
        else if (code === "SAVE_FAILED") key = "export.error.save"
        var suffix = ""
        if (code === "MISSING_GLYPHS" && details && details.length) {
            var labels = []
            for (var i = 0; i < details.length; i++) labels.push(details[i].label)
            suffix = " " + labels.join(", ")
        }
        controller.setExportStatus(uiText(key) + suffix, true)
        cleanupExport()
    }
    function cleanupExport() {
        pendingText = ""
        pendingDestination = ""
        pendingOptions = ({})
        exportLoader.active = false
    }
    function setHostPickerActive(active) {
        if (host) host.filePickerActive = active
    }
    function svgPath(path) {
        var value = Paths.LocalPath.absolute(path)
        return value.toLowerCase().lastIndexOf(".svg") === value.length - 4 ? value : value + ".svg"
    }
    function openPicker(kind) {
        if (pickerActive) return
        var command
        if (kind === "font") {
            command = ["omarchy", "file", "select", "--title", uiText("export.chooseFont"), "--extensions", "ttf otf ttc"]
        } else {
            command = ["/usr/bin/zenity", "--file-selection", "--save",
                "--title=" + uiText("export.save"),
                "--filename=" + Quickshell.env("HOME") + "/parsinegar.svg",
                "--file-filter=SVG files | *.svg"]
        }
        startPickerProcess(kind, command)
    }
    function startPickerProcess(kind, command) {
        pickerKind = kind
        pickerOutput = ""
        pickerExited = false
        pickerOutputFinished = false
        pickerExitCode = -1
        picker.command = command
        setHostPickerActive(true)
        picker.running = true
    }
    function startDestinationCheck(destination) {
        pendingDestination = destination
        startPickerProcess("destinationCheck", ["/usr/bin/test", "-e", destination])
    }
    function startOverwriteConfirmation() {
        startPickerProcess("overwriteConfirmation", ["/usr/bin/zenity", "--question",
            "--title=" + uiText("export.overwriteTitle"), "--text=" + uiText("export.overwriteQuestion"),
            "--ok-label=" + uiText("export.replace"), "--cancel-label=" + uiText("export.cancel")])
    }
    function continueConfirmedExport() {
        var destination = pendingDestination
        pendingDestination = ""
        setHostPickerActive(false)
        beginExport(destination)
    }
    function finishPickerIfReady() {
        if (!pickerExited || !pickerOutputFinished || !pickerActive) return
        var kind = pickerKind
        var output = Paths.LocalPath.fromPickerOutput(pickerOutput)
        var exitCode = pickerExitCode
        pickerKind = ""
        if (kind === "destinationCheck") {
            if (exitCode === 0) startOverwriteConfirmation()
            else if (exitCode === 1) continueConfirmedExport()
            else {
                setHostPickerActive(false)
                controller.setExportStatus(uiText("export.error.destinationCheck"), true)
                cleanupExport()
            }
            return
        }
        if (kind === "overwriteConfirmation") {
            if (exitCode === 0) continueConfirmedExport()
            else {
                setHostPickerActive(false)
                cleanupExport()
            }
            return
        }
        if (exitCode === 0 && output !== "") {
            try {
                output = Paths.LocalPath.absolute(output)
                if (kind === "font") {
                    setHostPickerActive(false)
                    if (activeMode === "compatibility") compatibilityFontPath = output
                    else unicodeFontPath = output
                    controller.setExportStatus("", false)
                } else startDestinationCheck(svgPath(output))
            } catch (error) {
                setHostPickerActive(false)
                controller.setExportStatus(uiText("export.error.invalidPath"), true)
                cleanupExport()
            }
        } else if (exitCode !== 0 && exitCode !== 1) {
            setHostPickerActive(false)
            controller.setExportStatus(uiText("export.error.picker"), true)
            cleanupExport()
        } else setHostPickerActive(false)
    }
    function collapse() {
        expanded = false
        advancedExpanded = false
        cleanupExport()
    }
    function chooseDestination() {
        if (!controller || controller.sourceText.length === 0) {
            controller.setExportStatus(uiText("export.error.noText"), true)
            return
        }
        if (selectedFontPath === "") {
            controller.setExportStatus(uiText("export.error.fontRequired"), true)
            return
        }
        try {
            Limits.ResourceLimits.assertTextLength(controller.sourceText, Limits.ResourceLimits.values.maxSvgTextLength, "EXPORT_TEXT_TOO_LARGE")
            exportOptions()
        }
        catch (error) {
            controller.setExportStatus(uiText(error && error.code === "EXPORT_TEXT_TOO_LARGE"
                ? "export.error.textTooLarge" : "export.error.invalidOption"), true)
            return
        }
        openPicker("destination")
    }
    function beginExport(destination) {
        try {
            pendingText = controller.convertForExport()
            pendingDestination = Paths.LocalPath.absolute(destination)
            pendingOptions = exportOptions()
            exportLoader.active = true
        } catch (error) {
            controller.setExportStatus(uiText(error && error.code === "EXPORT_TEXT_TOO_LARGE"
                ? "export.error.textTooLarge" : "export.error.generic"), true)
            cleanupExport()
        }
    }

    property string alignment: "right"

    component ActionButton: Ui.Button {
        fontFamily: root.typography ? root.typography.family : ""
        fontSize: Style.font.body
        foreground: root.controller ? root.controller.foreground : Color.foreground
        accent: Color.accent
        bordered: true
        focusable: true
    }

    component NumberField: Controls.TextField {
        font.family: root.typography ? root.typography.family : ""
        font.pixelSize: Style.font.body
        color: root.controller ? root.controller.foreground : Color.foreground
        placeholderTextColor: Color.muted
        horizontalAlignment: TextInput.AlignLeft
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: false
        selectByMouse: true
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        background: Rectangle {
            color: Util.alpha(root.controller ? root.controller.foreground : Color.foreground, 0.03)
            border.color: parent.activeFocus ? Color.accent : Util.alpha(root.controller ? root.controller.foreground : Color.foreground, 0.25)
            border.width: Math.max(1, Style.normalBorderWidth)
            radius: Style.cornerRadius
        }
    }

    ActionButton {
        width: parent.width
        text: root.uiText("export.title") + (root.expanded ? "  ▴" : "  ▾")
        selected: root.expanded
        enabled: !root.exportBusy
        onClicked: {
            root.expanded = !root.expanded
            if (!root.expanded) root.collapse()
        }
    }

    Rectangle {
        width: parent.width
        height: exportColumn.implicitHeight + Style.space(24)
        visible: root.expanded
        color: Util.alpha(root.controller ? root.controller.foreground : Color.foreground, 0.025)
        border.color: Util.alpha(root.controller ? root.controller.foreground : Color.foreground, 0.2)
        border.width: Math.max(1, Style.normalBorderWidth)
        radius: Style.cornerRadius

        Column {
            id: exportColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(12)
            spacing: Style.space(10)

            RowLayout {
                width: parent.width
                Text {
                    text: root.uiText("export.mode")
                    color: Color.muted
                    font.family: root.typography ? root.typography.family : ""
                    font.pixelSize: Style.font.caption
                }
                Text {
                    Layout.fillWidth: true
                    text: root.uiText(root.activeMode === "compatibility" ? "mode.compatibility" : "mode.unicode")
                    color: root.controller ? root.controller.foreground : Color.foreground
                    font.family: root.typography ? root.typography.family : ""
                    font.pixelSize: Style.font.body
                    font.bold: true
                    horizontalAlignment: root.controller && root.controller.uiLanguage === "fa" ? Text.AlignLeft : Text.AlignRight
                }
            }

            Text {
                width: parent.width
                text: root.uiText("export.font")
                color: Color.muted
                font.family: root.typography ? root.typography.family : ""
                font.pixelSize: Style.font.caption
            }

            RowLayout {
                width: parent.width
                spacing: Style.space(8)
                Text {
                    Layout.fillWidth: true
                    text: root.selectedFontPath === "" ? root.uiText("export.fontRequired") : root.selectedFontLabel()
                    color: root.selectedFontPath === "" ? Color.urgent : (root.controller ? root.controller.foreground : Color.foreground)
                    font.family: root.typography ? root.typography.family : ""
                    font.pixelSize: Style.font.body
                    elide: Text.ElideMiddle
                    textFormat: Text.PlainText
                }
                ActionButton {
                    text: root.uiText("export.chooseFont")
                    enabled: !root.exportBusy
                    onClicked: root.openPicker("font")
                }
            }

            RowLayout {
                width: parent.width
                spacing: Style.space(8)
                Text {
                    Layout.fillWidth: true
                    text: root.uiText("export.fontSize")
                    color: root.controller ? root.controller.foreground : Color.foreground
                    font.family: root.typography ? root.typography.family : ""
                    font.pixelSize: Style.font.body
                }
                NumberField {
                    id: fontSizeField
                    Layout.preferredWidth: Style.space(90)
                    text: "48"
                }
            }

            ActionButton {
                width: parent.width
                text: root.uiText("export.moreOptions") + (root.advancedExpanded ? "  ▴" : "  ▾")
                selected: root.advancedExpanded
                enabled: !root.exportBusy
                onClicked: root.advancedExpanded = !root.advancedExpanded
            }

            GridLayout {
                width: parent.width
                visible: root.advancedExpanded
                columns: 2
                columnSpacing: Style.space(8)
                rowSpacing: Style.space(8)

                Text {
                    text: root.uiText("export.lineSpacing")
                    color: root.controller ? root.controller.foreground : Color.foreground
                    font.family: root.typography ? root.typography.family : ""
                    font.pixelSize: Style.font.body
                }
                NumberField { id: lineSpacingField; Layout.fillWidth: true; text: "1.2" }

                Text {
                    text: root.uiText("export.width")
                    color: root.controller ? root.controller.foreground : Color.foreground
                    font.family: root.typography ? root.typography.family : ""
                    font.pixelSize: Style.font.body
                }
                NumberField { id: widthField; Layout.fillWidth: true; placeholderText: root.uiText("export.auto") }

                Text {
                    text: root.uiText("export.height")
                    color: root.controller ? root.controller.foreground : Color.foreground
                    font.family: root.typography ? root.typography.family : ""
                    font.pixelSize: Style.font.body
                }
                NumberField { id: heightField; Layout.fillWidth: true; placeholderText: root.uiText("export.auto") }

                Text {
                    text: root.uiText("export.padding")
                    color: root.controller ? root.controller.foreground : Color.foreground
                    font.family: root.typography ? root.typography.family : ""
                    font.pixelSize: Style.font.body
                }
                NumberField { id: paddingField; Layout.fillWidth: true; text: "16" }

                Text {
                    Layout.columnSpan: 2
                    text: root.uiText("export.alignment")
                    color: root.controller ? root.controller.foreground : Color.foreground
                    font.family: root.typography ? root.typography.family : ""
                    font.pixelSize: Style.font.body
                }

                GridLayout {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: Style.space(6)
                    ActionButton {
                        Layout.fillWidth: true
                        text: root.uiText("export.alignLeft")
                        selected: root.alignment === "left"
                        onClicked: root.alignment = "left"
                    }
                    ActionButton {
                        Layout.fillWidth: true
                        text: root.uiText("export.alignCenter")
                        selected: root.alignment === "center"
                        onClicked: root.alignment = "center"
                    }
                    ActionButton {
                        Layout.fillWidth: true
                        text: root.uiText("export.alignRight")
                        selected: root.alignment === "right"
                        onClicked: root.alignment = "right"
                    }
                }
            }

            ActionButton {
                width: parent.width
                text: root.uiText("export.save")
                enabled: !root.exportBusy && root.controller && root.controller.sourceText.length > 0
                onClicked: root.chooseDestination()
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.controller ? root.controller.statusText : ""
                textFormat: Text.PlainText
                color: root.controller && root.controller.statusError ? Color.urgent
                    : root.controller && root.controller.statusWarning ? Color.accent
                    : (root.controller ? root.controller.foreground : Color.foreground)
                font.family: root.typography ? root.typography.family : ""
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
            }
        }
    }

    Process {
        id: picker
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.pickerOutput = typeof text === "string" ? text : ""
                root.pickerOutputFinished = true
                root.finishPickerIfReady()
            }
        }
        onExited: function(exitCode) {
            root.pickerExited = true
            root.pickerExitCode = exitCode
            root.finishPickerIfReady()
        }
    }

    Loader {
        id: exportLoader
        active: false
        source: "SvgCurveExportController.qml"
        onLoaded: {
            item.exported.connect(function(path, warnings) {
                if (warnings && warnings.length) {
                    var labels = []
                    for (var index = 0; index < warnings.length; index++)
                        labels.push(warnings[index].character + " (" + warnings[index].label + ")")
                    root.controller.setExportStatus(root.uiText("export.warning.missingGlyphs") + " " + labels.join(", "), false, true)
                } else {
                    root.controller.setExportStatus(root.uiText("export.success"), false)
                }
                Qt.callLater(root.cleanupExport)
            })
            item.failed.connect(root.reportError)
            if (!item.exportTo(root.pendingText, root.selectedFontPath, root.pendingDestination, root.pendingOptions))
                Qt.callLater(root.cleanupExport)
        }
    }

    Component.onDestruction: {
        setHostPickerActive(false)
        cleanupExport()
    }
}
