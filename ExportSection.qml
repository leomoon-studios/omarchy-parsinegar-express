import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import qs.Commons
import "InterfaceStrings.js" as Strings
import "ResourceLimits.js" as Limits
import "LocalPath.js" as Paths

FocusScope {
    id: root

    required property var controller
    required property var host
    required property Typography typography
    property bool advancedExpanded: false
    property bool automaticWidth: true
    property bool automaticHeight: true
    property bool preparingExport: false
    property string exportStatusText: ""
    property bool exportStatusError: false
    property bool exportStatusWarning: false
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
    readonly property bool exportBusy: preparingExport || exportLoader.active || pickerActive
    readonly property Item focusItem: backButton
    signal backRequested()
    LayoutMirroring.enabled: controller && controller.uiLanguage === "fa"
    LayoutMirroring.childrenInherit: true

    function uiText(key) { return Strings.InterfaceStrings.text(controller ? controller.uiLanguage : "en", key) }
    function setStatus(message, isError, isWarning) {
        exportStatusText = String(message || "")
        exportStatusError = isError === true
        exportStatusWarning = isWarning === true
    }
    function selectedFontLabel() {
        if (activeMode === "unicode" && Paths.LocalPath.absolute(selectedFontPath) === Paths.LocalPath.absolute(bundledUnicodeFontPath))
            return uiText("export.bundledFont")
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
    function optionalNonNegativeInteger(field) {
        var value = String(field.text).trim()
        if (value === "") return undefined
        var number = Number(value)
        if (!isFinite(number) || number < 0 || Math.floor(number) !== number) throw new Error("INVALID_OPTION")
        return number
    }
    function axesValue() {
        var value = String(axesField.text).trim()
        if (value === "") return undefined
        var parts = value.split(",")
        var result = []
        for (var index = 0; index < parts.length; index++) {
            var number = Number(parts[index].trim())
            if (!isFinite(number)) throw new Error("INVALID_OPTION")
            result.push(number)
        }
        return result
    }
    function validFillColor(value) {
        return /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(String(value).trim())
    }
    function exportOptions() {
        var bounds = { padding: nonNegativeValue(paddingField, 16) }
        var width = automaticWidth ? undefined : positiveValue(widthField, undefined, false)
        var height = automaticHeight ? undefined : positiveValue(heightField, undefined, false)
        var fill = String(fillField.text).trim()
        if (!validFillColor(fill)) throw new Error("INVALID_OPTION")
        if (width !== undefined) bounds.width = width
        if (height !== undefined) bounds.height = height
        var result = {
            fontSize: positiveValue(fontSizeField, 48, false),
            lineSpacing: positiveValue(lineSpacingField, 1.2, false),
            alignment: alignment,
            bounds: bounds,
            fill: fill,
            precision: nonNegativeValue(precisionField, 3)
        }
        var fontIndex = optionalNonNegativeInteger(fontIndexField)
        var axes = axesValue()
        if (fontIndex !== undefined) result.fontIndex = fontIndex
        if (axes !== undefined) result.axes = axes
        var limits = Limits.ResourceLimits.values
        if (result.fontSize > limits.maxFontSize || result.lineSpacing > limits.maxLineSpacing ||
            bounds.padding > limits.maxPadding || (bounds.width !== undefined && bounds.width > limits.maxDimension) ||
            (bounds.height !== undefined && bounds.height > limits.maxDimension) || result.precision > 8) throw new Error("INVALID_OPTION")
        return result
    }
    function loadSavedSettings(value) {
        var settings = value || ({})
        advancedExpanded = settings.advancedExpanded === true
        automaticWidth = settings.automaticWidth !== false
        automaticHeight = settings.automaticHeight !== false
        unicodeFontPath = settings.unicodeFontPath || bundledUnicodeFontPath
        compatibilityFontPath = settings.compatibilityFontPath || ""
        alignment = ["left", "center", "right"].indexOf(settings.alignment) !== -1 ? settings.alignment : "right"
        fontSizeField.text = settings.fontSize === undefined ? "48" : settings.fontSize
        lineSpacingField.text = settings.lineSpacing === undefined ? "1.2" : settings.lineSpacing
        widthField.text = settings.width === undefined ? "800" : settings.width
        heightField.text = settings.height === undefined ? "300" : settings.height
        paddingField.text = settings.padding === undefined ? "16" : settings.padding
        precisionField.text = settings.precision === undefined ? "3" : settings.precision
        fontIndexField.text = settings.fontIndex || ""
        fillField.text = settings.fill || "#000000"
        axesField.text = settings.axes || ""
    }
    function saveSettings() {
        if (!host || !controller || !controller.settingsReady) return
        host.exportSettings = {
            advancedExpanded: advancedExpanded,
            automaticWidth: automaticWidth,
            automaticHeight: automaticHeight,
            unicodeFontPath: unicodeFontPath === bundledUnicodeFontPath ? "" : unicodeFontPath,
            compatibilityFontPath: compatibilityFontPath,
            alignment: alignment,
            fontSize: fontSizeField.text,
            lineSpacing: lineSpacingField.text,
            width: widthField.text,
            height: heightField.text,
            padding: paddingField.text,
            precision: precisionField.text,
            fontIndex: fontIndexField.text,
            fill: fillField.text,
            axes: axesField.text
        }
        controller.saveSettings()
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
        setStatus(uiText(key) + suffix, true)
        cleanupExport()
    }
    function cleanupExport() {
        preparingExport = false
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
    function continueExport(destination) {
        pendingDestination = destination
        preparingExport = true
        setStatus(uiText("export.processing"), false)
        setHostPickerActive(false)
        Qt.callLater(function() {
            if (root.preparingExport) root.beginExport()
        })
    }
    function finishPickerIfReady() {
        if (!pickerExited || !pickerOutputFinished || !pickerActive) return
        var kind = pickerKind
        var output = Paths.LocalPath.fromPickerOutput(pickerOutput)
        var exitCode = pickerExitCode
        pickerKind = ""
        if (exitCode === 0 && output !== "") {
            try {
                output = Paths.LocalPath.absolute(output)
                if (kind === "font") {
                    setHostPickerActive(false)
                    if (activeMode === "compatibility") compatibilityFontPath = output
                    else unicodeFontPath = output
                    saveSettings()
                    setStatus("", false)
                } else continueExport(svgPath(output))
            } catch (error) {
                setHostPickerActive(false)
                setStatus(uiText("export.error.invalidPath"), true)
                cleanupExport()
            }
        } else if (exitCode !== 0 && exitCode !== 1) {
            setHostPickerActive(false)
            setStatus(uiText("export.error.picker"), true)
            cleanupExport()
        } else setHostPickerActive(false)
    }
    function collapse() {
        advancedExpanded = false
        cleanupExport()
    }
    function toggleAdvancedOptions() {
        if (exportBusy) return
        advancedExpanded = !advancedExpanded
        saveSettings()
    }
    function focusPage() { backButton.forceActiveFocus() }
    function chooseDestination() {
        if (!controller || controller.sourceText.length === 0) {
            setStatus(uiText("export.error.noText"), true)
            return
        }
        if (selectedFontPath === "") {
            setStatus(uiText("export.error.fontRequired"), true)
            return
        }
        try {
            Limits.ResourceLimits.assertTextLength(controller.sourceText, Limits.ResourceLimits.values.maxSvgTextLength, "EXPORT_TEXT_TOO_LARGE")
            exportOptions()
        }
        catch (error) {
            setStatus(uiText(error && error.code === "EXPORT_TEXT_TOO_LARGE"
                ? "export.error.textTooLarge" : "export.error.invalidOption"), true)
            return
        }
        openPicker("destination")
    }
    function beginExport() {
        try {
            pendingDestination = Paths.LocalPath.absolute(pendingDestination)
            pendingOptions = exportOptions()
            if (!controller.requestExportConversion()) throw new Error("Export conversion is busy")
        } catch (error) {
            setStatus(uiText(error && error.code === "EXPORT_TEXT_TOO_LARGE"
                ? "export.error.textTooLarge" : "export.error.generic"), true)
            cleanupExport()
        }
    }
    function continueAfterConversion(output) {
        if (!preparingExport) return
        pendingText = output
        exportLoader.active = true
        preparingExport = false
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

    component PrimaryAction: Ui.Button {
        id: primaryControl
        property string label: ""

        text: ""
        fontFamily: root.typography ? root.typography.family : ""
        foreground: Color.background
        background: Color.accent
        accent: Color.accent
        bordered: false
        focusable: true
        implicitHeight: Style.space(44)
        Accessible.role: Accessible.Button
        Accessible.name: label

        Text {
            anchors.centerIn: parent
            text: primaryControl.label
            textFormat: Text.PlainText
            color: primaryControl.foreground
            font.family: primaryControl.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
        }
    }

    component NumberField: TextField {
        property real minimumValue: 0
        property real maximumValue: Limits.ResourceLimits.values.maxDimension
        property int decimalPlaces: 4
        property bool allowEmpty: false
        readonly property bool validNumber: (allowEmpty && text.trim() === "") || acceptableInput

        opacity: enabled ? 1.0 : 0.5
        font.family: root.typography ? root.typography.family : ""
        font.pixelSize: Style.font.body
        color: root.controller ? root.controller.foreground : Color.foreground
        placeholderTextColor: Color.muted
        horizontalAlignment: TextInput.AlignLeft
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: false
        selectByMouse: true
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        validator: DoubleValidator {
            bottom: parent.minimumValue
            top: parent.maximumValue
            decimals: parent.decimalPlaces
            notation: DoubleValidator.StandardNotation
        }
        background: Rectangle {
            color: Util.alpha(root.controller ? root.controller.foreground : Color.foreground, 0.03)
            border.color: parent.activeFocus ? Color.accent
                : parent.validNumber ? Util.alpha(root.controller ? root.controller.foreground : Color.foreground, 0.25)
                : Color.urgent
            border.width: Math.max(1, Style.normalBorderWidth)
            radius: Style.cornerRadius
        }
    }

    component ValueField: TextField {
        property bool validValue: true

        font.family: root.typography ? root.typography.family : ""
        font.pixelSize: Style.font.body
        color: root.controller ? root.controller.foreground : Color.foreground
        placeholderTextColor: Color.muted
        selectByMouse: true
        background: Rectangle {
            color: Util.alpha(root.controller ? root.controller.foreground : Color.foreground, 0.03)
            border.color: !parent.validValue ? Color.urgent
                : parent.activeFocus ? Color.accent
                : Util.alpha(root.controller ? root.controller.foreground : Color.foreground, 0.25)
            border.width: Math.max(1, Style.normalBorderWidth)
            radius: Style.cornerRadius
        }
    }

    Keys.onEscapePressed: function(event) {
        if (!root.exportBusy) root.backRequested()
        event.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(10)

        RowLayout {
            id: exportHeader
            Layout.fillWidth: true
            spacing: Style.space(6)

            Text {
                Layout.fillWidth: true
                text: root.uiText("export.title")
                color: root.controller ? root.controller.foreground : Color.foreground
                font.family: root.typography ? root.typography.family : ""
                font.pixelSize: Style.font.heading
                font.bold: true
                elide: Text.ElideRight
            }

            HeaderActionButton {
                id: backButton
                objectName: "exportBackButton"
                iconText: root.controller && root.controller.uiLanguage === "fa"
                    ? root.typography.iconForward : root.typography.iconBack
                fontFamily: root.typography ? root.typography.iconFamily : ""
                fontSize: Style.font.heading
                size: Style.space(42)
                enabled: !root.exportBusy
                toolTipText: root.uiText("button.back")
                toolTipFontFamily: root.typography ? root.typography.family : ""
                Accessible.name: root.uiText("button.back")
                onClicked: root.backRequested()
            }
        }

        ScrollView {
            id: exportScroll
            readonly property bool overflowing: exportContent.implicitHeight > height + 0.5
            readonly property real scrollGutter: overflowing ? exportScroll.ScrollBar.vertical.width + Style.space(6) : 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            leftPadding: root.controller && root.controller.uiLanguage === "fa" ? scrollGutter : 0
            rightPadding: root.controller && root.controller.uiLanguage === "fa" ? 0 : scrollGutter
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Column {
                id: exportContent
                width: exportScroll.availableWidth
                spacing: Style.space(10)

                Rectangle {
                    id: modeCard
                    width: parent.width
                    height: modeColumn.implicitHeight + Style.space(24)
                    color: Util.alpha(root.controller ? root.controller.foreground : Color.foreground, 0.025)
                    border.color: Util.alpha(root.controller ? root.controller.foreground : Color.foreground, 0.2)
                    border.width: Math.max(1, Style.normalBorderWidth)
                    radius: Style.cornerRadius

                    Column {
                        id: modeColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Style.space(12)
                        spacing: Style.space(8)

                        SectionHeading {
                            width: parent.width
                            label: root.uiText("export.mode")
                            foreground: root.controller ? root.controller.foreground : Color.foreground
                            fontFamily: root.typography ? root.typography.family : ""
                            rightToLeft: root.controller && root.controller.uiLanguage === "fa"
                        }

                        GridLayout {
                            width: parent.width
                            columns: 2
                            columnSpacing: Style.space(6)

                            ActionButton {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                text: root.uiText("mode.unicode")
                                selected: root.activeMode === "unicode"
                                enabled: !root.exportBusy
                                onClicked: root.controller.setConversionMode("unicode")
                            }
                            ActionButton {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                text: root.uiText("mode.compatibility")
                                selected: root.activeMode === "compatibility"
                                enabled: !root.exportBusy && !root.controller.hebrewProfile
                                onClicked: root.controller.setConversionMode("compatibility")
                            }
                        }

                        SectionHeading {
                            width: parent.width
                            label: root.uiText("export.font")
                            foreground: root.controller ? root.controller.foreground : Color.foreground
                            fontFamily: root.typography ? root.typography.family : ""
                            rightToLeft: root.controller && root.controller.uiLanguage === "fa"
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
                            ActionButton {
                                visible: root.activeMode === "unicode" && Paths.LocalPath.absolute(root.unicodeFontPath) !== Paths.LocalPath.absolute(root.bundledUnicodeFontPath)
                                text: root.uiText("export.useBundledFont")
                                enabled: !root.exportBusy
                                onClicked: {
                                    root.unicodeFontPath = root.bundledUnicodeFontPath
                                    root.saveSettings()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: optionsCard
                    width: parent.width
                    height: optionsColumn.implicitHeight + Style.space(24)
                    color: Util.alpha(root.controller ? root.controller.foreground : Color.foreground, 0.025)
                    border.color: Util.alpha(root.controller ? root.controller.foreground : Color.foreground, 0.2)
                    border.width: Math.max(1, Style.normalBorderWidth)
                    radius: Style.cornerRadius

                    Column {
                        id: optionsColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                        RowLayout {
                            width: parent.width
                            spacing: Style.space(8)

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                spacing: Style.space(4)
                                SectionHeading {
                                    Layout.fillWidth: true
                                    label: root.uiText("export.fontSize")
                                    foreground: root.controller ? root.controller.foreground : Color.foreground
                                    fontFamily: root.typography ? root.typography.family : ""
                                    rightToLeft: root.controller && root.controller.uiLanguage === "fa"
                                }
                                NumberField { id: fontSizeField; Layout.fillWidth: true; minimumValue: 0.01; maximumValue: Limits.ResourceLimits.values.maxFontSize; text: "48"; onEditingFinished: root.saveSettings() }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                spacing: Style.space(4)
                                SectionHeading {
                                    Layout.fillWidth: true
                                    label: root.uiText("export.lineSpacing")
                                    foreground: root.controller ? root.controller.foreground : Color.foreground
                                    fontFamily: root.typography ? root.typography.family : ""
                                    rightToLeft: root.controller && root.controller.uiLanguage === "fa"
                                }
                                NumberField { id: lineSpacingField; Layout.fillWidth: true; minimumValue: 0.01; maximumValue: Limits.ResourceLimits.values.maxLineSpacing; text: "1.2"; onEditingFinished: root.saveSettings() }
                            }
                        }

                        SectionHeading {
                            width: parent.width
                            label: root.uiText("export.alignment")
                            foreground: root.controller ? root.controller.foreground : Color.foreground
                            fontFamily: root.typography ? root.typography.family : ""
                            rightToLeft: root.controller && root.controller.uiLanguage === "fa"
                        }

                        GridLayout {
                            width: parent.width
                            LayoutMirroring.enabled: false
                            LayoutMirroring.childrenInherit: false
                            columns: 3
                            columnSpacing: Style.space(6)
                            ActionButton { Layout.fillWidth: true; Layout.preferredWidth: 0; text: root.uiText("export.alignLeft"); selected: root.alignment === "left"; onClicked: { root.alignment = "left"; root.saveSettings() } }
                            ActionButton { Layout.fillWidth: true; Layout.preferredWidth: 0; text: root.uiText("export.alignCenter"); selected: root.alignment === "center"; onClicked: { root.alignment = "center"; root.saveSettings() } }
                            ActionButton { Layout.fillWidth: true; Layout.preferredWidth: 0; text: root.uiText("export.alignRight"); selected: root.alignment === "right"; onClicked: { root.alignment = "right"; root.saveSettings() } }
                        }

                        ActionButton {
                            width: parent.width
                            text: root.uiText(root.advancedExpanded ? "export.fewerOptions" : "export.moreOptions") + (root.advancedExpanded ? "  ▲" : "  ▼")
                            selected: root.advancedExpanded
                            enabled: !root.exportBusy
                            onClicked: root.toggleAdvancedOptions()
                        }

                        GridLayout {
                            width: parent.width
                            visible: root.advancedExpanded
                            columns: 3
                            columnSpacing: Style.space(8)
                            rowSpacing: Style.space(8)

                            SectionHeading { label: root.uiText("export.width"); foreground: root.controller ? root.controller.foreground : Color.foreground; fontFamily: root.typography ? root.typography.family : ""; rightToLeft: root.controller && root.controller.uiLanguage === "fa" }
                            NumberField { id: widthField; Layout.fillWidth: true; minimumValue: 0.01; text: "800"; enabled: !root.automaticWidth; onEditingFinished: root.saveSettings() }
                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Style.space(6)
                                layoutDirection: root.controller && root.controller.uiLanguage === "fa" ? Qt.RightToLeft : Qt.LeftToRight

                                Ui.ToggleSwitch {
                                    id: automaticWidthToggle
                                    Layout.alignment: Qt.AlignVCenter
                                    checked: root.automaticWidth
                                    busy: root.exportBusy
                                    foreground: root.controller ? root.controller.foreground : Color.foreground
                                    accent: Color.accent
                                    onToggled: {
                                        root.automaticWidth = !root.automaticWidth
                                        root.saveSettings()
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: root.uiText("export.auto")
                                    color: root.exportBusy ? Color.muted : (root.controller ? root.controller.foreground : Color.foreground)
                                    font.family: root.typography ? root.typography.family : ""
                                    font.pixelSize: Style.font.body
                                }
                            }

                            SectionHeading { label: root.uiText("export.height"); foreground: root.controller ? root.controller.foreground : Color.foreground; fontFamily: root.typography ? root.typography.family : ""; rightToLeft: root.controller && root.controller.uiLanguage === "fa" }
                            NumberField { id: heightField; Layout.fillWidth: true; minimumValue: 0.01; text: "300"; enabled: !root.automaticHeight; onEditingFinished: root.saveSettings() }
                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Style.space(6)
                                layoutDirection: root.controller && root.controller.uiLanguage === "fa" ? Qt.RightToLeft : Qt.LeftToRight

                                Ui.ToggleSwitch {
                                    id: automaticHeightToggle
                                    Layout.alignment: Qt.AlignVCenter
                                    checked: root.automaticHeight
                                    busy: root.exportBusy
                                    foreground: root.controller ? root.controller.foreground : Color.foreground
                                    accent: Color.accent
                                    onToggled: {
                                        root.automaticHeight = !root.automaticHeight
                                        root.saveSettings()
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: root.uiText("export.auto")
                                    color: root.exportBusy ? Color.muted : (root.controller ? root.controller.foreground : Color.foreground)
                                    font.family: root.typography ? root.typography.family : ""
                                    font.pixelSize: Style.font.body
                                }
                            }
                        }

                        GridLayout {
                            width: parent.width
                            visible: root.advancedExpanded
                            columns: 2
                            columnSpacing: Style.space(8)
                            rowSpacing: Style.space(8)

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                SectionHeading { Layout.fillWidth: true; label: root.uiText("export.padding"); foreground: root.controller ? root.controller.foreground : Color.foreground; fontFamily: root.typography ? root.typography.family : ""; rightToLeft: root.controller && root.controller.uiLanguage === "fa" }
                                NumberField { id: paddingField; Layout.fillWidth: true; maximumValue: Limits.ResourceLimits.values.maxPadding; text: "16"; onEditingFinished: root.saveSettings() }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                SectionHeading { Layout.fillWidth: true; label: root.uiText("export.precision"); foreground: root.controller ? root.controller.foreground : Color.foreground; fontFamily: root.typography ? root.typography.family : ""; rightToLeft: root.controller && root.controller.uiLanguage === "fa" }
                                NumberField { id: precisionField; Layout.fillWidth: true; maximumValue: 8; decimalPlaces: 0; text: "3"; onEditingFinished: root.saveSettings() }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                SectionHeading { Layout.fillWidth: true; label: root.uiText("export.fontIndex"); foreground: root.controller ? root.controller.foreground : Color.foreground; fontFamily: root.typography ? root.typography.family : ""; rightToLeft: root.controller && root.controller.uiLanguage === "fa" }
                                NumberField { id: fontIndexField; Layout.fillWidth: true; decimalPlaces: 0; allowEmpty: true; placeholderText: root.uiText("export.default"); onEditingFinished: root.saveSettings() }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                SectionHeading { Layout.fillWidth: true; label: root.uiText("export.fill"); foreground: root.controller ? root.controller.foreground : Color.foreground; fontFamily: root.typography ? root.typography.family : ""; rightToLeft: root.controller && root.controller.uiLanguage === "fa" }
                                ValueField {
                                    id: fillField
                                    Layout.fillWidth: true
                                    text: "#000000"
                                    validValue: root.validFillColor(text)
                                    LayoutMirroring.enabled: false
                                    onEditingFinished: root.saveSettings()
                                }
                            }
                        }

                        ColumnLayout {
                            width: parent.width
                            visible: root.advancedExpanded
                            spacing: Style.space(4)
                            SectionHeading { Layout.fillWidth: true; label: root.uiText("export.axes"); foreground: root.controller ? root.controller.foreground : Color.foreground; fontFamily: root.typography ? root.typography.family : ""; rightToLeft: root.controller && root.controller.uiLanguage === "fa" }
                            ValueField { id: axesField; Layout.fillWidth: true; placeholderText: root.uiText("export.axesHint"); LayoutMirroring.enabled: false; onEditingFinished: root.saveSettings() }
                        }
                    }
                }

                PrimaryAction {
                    width: parent.width
                    label: root.uiText("export.save")
                    enabled: !root.exportBusy && root.controller && root.controller.sourceText.length > 0
                    onClicked: root.chooseDestination()
                }
            }
        }

        Item {
            id: exportStatusSlot
            Layout.fillWidth: true
            Layout.minimumHeight: Style.space(32)
            Layout.preferredHeight: Style.space(32)
            Layout.maximumHeight: Style.space(32)

            StatusMessage {
                objectName: "exportStatus"
                anchors.fill: parent
                message: root.exportStatusText
                error: root.exportStatusError
                warning: root.exportStatusWarning
                busy: root.preparingExport || exportLoader.active
                fontFamily: root.typography ? root.typography.family : ""
                foreground: root.controller ? root.controller.foreground : Color.foreground
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

    Connections {
        target: root.controller
        function onExportConversionReady(output) { root.continueAfterConversion(output) }
        function onExportConversionFailed(code, message) { root.reportError(code, message, []) }
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
                    root.setStatus(root.uiText("export.warning.missingGlyphs") + " " + labels.join(", "), false, true)
                } else {
                    root.setStatus(root.uiText("export.success"), false)
                }
                Qt.callLater(root.cleanupExport)
            })
            item.failed.connect(root.reportError)
            var loadedController = item
            Qt.callLater(function() {
                if (!exportLoader.active || exportLoader.item !== loadedController) return
                if (!loadedController.exportTo(root.pendingText, root.selectedFontPath, root.pendingDestination, root.pendingOptions))
                    Qt.callLater(root.cleanupExport)
            })
        }
    }

    Component.onDestruction: {
        setHostPickerActive(false)
        cleanupExport()
    }
}
