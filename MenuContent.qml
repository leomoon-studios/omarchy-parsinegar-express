import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import qs.Commons
import "ReshaperSettings.js" as Settings
import "InterfaceStrings.js" as Strings
import "ResourceLimits.js" as Limits

FocusScope {
    id: root
    property var host: null
    property Typography typography: null
    readonly property alias editorItem: editor
    readonly property alias exportItem: exportSection
    readonly property alias editorPageScroll: formScroll
    readonly property string sourceText: conversionText()
    readonly property color foreground: host && host.bar ? host.bar.foreground : Color.foreground
    readonly property string fontFamily: typography ? typography.family : ""
    readonly property string iconFontFamily: typography ? typography.iconFamily : fontFamily
    readonly property var reshaperMetadata: Settings.ReshaperSettings.metadata
    readonly property string configDirectory: Quickshell.env("HOME") + "/.config/leomoon-studios.omarchy-parsinegar-express"
    readonly property string configPath: configDirectory + "/settings.json"
    property var reshaperSettings: Settings.ReshaperSettings.defaults(reshaperMetadata)
    property string shapingProfile: "standardPersianArabic"
    readonly property bool hebrewProfile: shapingProfile === "hebrew"
    property string uiLanguage: "en"
    property int settingsRevision: 0
    property bool settingsReady: false
    property string page: "editor"
    implicitHeight: page === "settings" || exportSection.expanded
        ? Style.space(500)
        : editorHeader.implicitHeight + Style.space(14) + formColumn.implicitHeight
    property bool busy: false
    property bool conversionInFlight: false
    property int conversionRequestId: 0
    property string conversionPurpose: ""
    property string statusText: ""
    property bool statusError: false
    property bool statusWarning: false
    property bool formattingEditor: false
    property string editorDirectionSignature: ""
    signal closeRequested()
    signal exportConversionReady(string output)
    signal exportConversionFailed(string code, string message)

    function uiText(key) { return Strings.InterfaceStrings.text(uiLanguage, key) }
    function isRtlStrong(code) {
        return (code >= 0x05d0 && code <= 0x05ea) ||
            (code >= 0x0621 && code <= 0x064a) ||
            (code >= 0x066e && code <= 0x06d3) ||
            (code >= 0x06fa && code <= 0x06ff) ||
            (code >= 0x0700 && code <= 0x074f) ||
            (code >= 0x0750 && code <= 0x077f) ||
            (code >= 0x08a0 && code <= 0x08ff) ||
            (code >= 0xfb1d && code <= 0xfdff) ||
            (code >= 0xfe70 && code <= 0xfeff)
    }
    function isLtrStrong(code) {
        return (code >= 0x0041 && code <= 0x005a) ||
            (code >= 0x0061 && code <= 0x007a) ||
            (code >= 0x00c0 && code <= 0x02af)
    }
    function paragraphAlignment(value) {
        var text = String(value || "")
        for (var index = 0; index < text.length; index++) {
            var code = text.charCodeAt(index)
            if (isRtlStrong(code)) return "right"
            if (isLtrStrong(code)) return "left"
        }
        return ""
    }
    function paragraphDirections(value) {
        var paragraphs = String(value || "").split(/\r\n|[\r\n\u2029]/)
        // Match the desktop editor: neutral paragraphs inherit the preceding direction.
        var inheritedAlignment = "left"
        var directions = []
        for (var index = 0; index < paragraphs.length; index++) {
            var detectedAlignment = paragraphAlignment(paragraphs[index])
            if (detectedAlignment !== "") inheritedAlignment = detectedAlignment
            directions.push(inheritedAlignment)
        }
        return directions
    }
    function directionSignature(directions) {
        return directions.join("|")
    }
    function rawEditorText() {
        return editor.textFormat === TextEdit.RichText ? editor.getText(0, editor.length) : editor.text
    }
    function conversionText() {
        return rawEditorText().replace(/\u2029/g, "\n")
    }
    function escapeHtml(value) {
        return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;")
            .replace(/>/g, "&gt;").replace(/\"/g, "&quot;")
    }
    function formattedEditorText(value, directions) {
        var paragraphs = String(value || "").split(/\r\n|[\r\n\u2029]/)
        var effectiveDirections = directions || paragraphDirections(value)
        var markup = []
        for (var index = 0; index < paragraphs.length; index++) {
            var paragraph = paragraphs[index]
            var alignment = effectiveDirections[index]
            markup.push("<p dir=\"" + (alignment === "right" ? "rtl" : "ltr") +
                "\" align=\"" + alignment + "\" style=\"margin:0\">" + escapeHtml(paragraph) + "</p>")
        }
        return markup.join("")
    }
    function reformatEditor(value, directions) {
        var plain = value === undefined ? rawEditorText() : String(value)
        var effectiveDirections = directions || paragraphDirections(plain)
        var cursor = editor.cursorPosition
        var selectionStart = editor.selectionStart
        var selectionEnd = editor.selectionEnd
        formattingEditor = true
        editor.text = formattedEditorText(plain, effectiveDirections)
        editor.cursorPosition = Math.min(cursor, editor.length)
        if (selectionStart !== selectionEnd) {
            editor.select(Math.min(selectionStart, editor.length), Math.min(selectionEnd, editor.length))
        }
        editorDirectionSignature = directionSignature(effectiveDirections)
        formattingEditor = false
    }

    function applySettings(value, save) {
        reshaperSettings = Settings.ReshaperSettings.sanitize(reshaperMetadata, value)
        settingsRevision++
        settingsReady = true
        if (host) {
            host.reshaperSettings = reshaperSettings
            host.reshaperSettingsLoaded = true
            host.shapingProfile = shapingProfile
            host.uiLanguage = uiLanguage
        }
        if (save) saveSettings()
    }
    function loadSettings(raw) {
        var result
        try {
            Limits.ResourceLimits.assertSettingsSize(raw)
            result = Settings.ReshaperSettings.parse(reshaperMetadata, raw)
        } catch (error) {
            result = { settings: Settings.ReshaperSettings.defaults(reshaperMetadata), shapingProfile: "standardPersianArabic", uiLanguage: "en", recovered: true }
        }
        if (result.recovered) console.warn("ParsiNegar Express: resetting invalid settings")
        uiLanguage = result.uiLanguage
        shapingProfile = Settings.ReshaperSettings.sanitizeShapingProfile(reshaperMetadata, result.shapingProfile)
        applySettings(result.settings, result.recovered)
        ensureProfileMode()
    }
    function saveSettings() {
        if (!settingsReady) return
        settingsFile.setText(Settings.ReshaperSettings.serialize(reshaperMetadata, reshaperSettings, uiLanguage, shapingProfile))
    }
    function setUiLanguage(language) {
        var next = Settings.ReshaperSettings.sanitizeUiLanguage(language)
        if (uiLanguage === next) return
        uiLanguage = next
        if (host) host.uiLanguage = uiLanguage
        saveSettings()
    }
    function baseOption(name) { settingsRevision; return reshaperSettings[name] }
    function profileForLanguage(language) { return Settings.ReshaperSettings.profileForLanguage(language) }
    function setShapingProfile(value, save) {
        var nextProfile = Settings.ReshaperSettings.sanitizeShapingProfile(reshaperMetadata, value)
        var nextSettings = Settings.ReshaperSettings.copy(reshaperSettings)
        var language = Settings.ReshaperSettings.profileLanguage(reshaperMetadata, nextProfile)
        if (language !== null) nextSettings.language = language
        shapingProfile = nextProfile
        applySettings(nextSettings, false)
        ensureProfileMode()
        if (save) saveSettings()
    }
    function setShapingLanguage(language) { setShapingProfile(profileForLanguage(language), true) }
    function ensureProfileMode() {
        if (hebrewProfile && host && host.conversionMode !== "unicode") host.conversionMode = "unicode"
    }
    function setBaseOption(name, value) {
        if (baseOption(name) === value) return
        var next = Settings.ReshaperSettings.copy(reshaperSettings)
        next[name] = value
        applySettings(next, true)
    }
    function toggleBaseOption(name) { setBaseOption(name, !baseOption(name)) }
    function ligatureEnabled(name) { settingsRevision; return reshaperSettings.ligatures[name] === true }
    function toggleLigature(name) {
        var next = Settings.ReshaperSettings.copy(reshaperSettings)
        next.ligatures[name] = !ligatureEnabled(name)
        applySettings(next, true)
    }
    function resetReshaperSettings() {
        shapingProfile = "standardPersianArabic"
        applySettings(Settings.ReshaperSettings.defaults(reshaperMetadata), true)
        ensureProfileMode()
    }
    function initialize() {
        if (host && host.reshaperSettingsLoaded) {
            uiLanguage = Settings.ReshaperSettings.sanitizeUiLanguage(host.uiLanguage)
            shapingProfile = Settings.ReshaperSettings.sanitizeShapingProfile(
                reshaperMetadata, host.shapingProfile, host.reshaperSettings.language)
            applySettings(host.reshaperSettings, false)
            ensureProfileMode()
        }
        else settingsDirectoryCreator.running = true
        Qt.callLater(function() { if (editor.textFormat === TextEdit.RichText) reformatEditor() })
    }
    function focusEditor() { page = "editor"; editor.forceActiveFocus() }
    function openSettings() {
        page = "settings"
        Qt.callLater(function() {
            if (page === "settings" && settingsContent.focusItem) settingsContent.focusItem.forceActiveFocus()
        })
    }
    function conversionOptions() {
        return {
            reverseWords: host.reverseWords,
            autoParagraphDirection: true,
            videoStudioPro: host.videoStudioPro,
            shapingProfile: shapingProfile,
            reshaperOptions: reshaperSettings
        }
    }
    function requestExportConversion() {
        if (!settingsReady || !host || !host.opened || !typography || !typography.ready)
            return false
        ensureProfileMode()
        if (conversionInFlight) return false
        Limits.ResourceLimits.assertTextLength(sourceText, Limits.ResourceLimits.values.maxSvgTextLength, "EXPORT_TEXT_TOO_LARGE")
        conversionInFlight = true
        conversionPurpose = "export"
        conversionRequestId++
        conversionWorker.sendMessage({
            id: conversionRequestId,
            text: sourceText,
            mode: host.conversionMode,
            options: conversionOptions(),
            maxOutputLength: Limits.ResourceLimits.values.maxSvgTextLength,
            sizeErrorCode: "EXPORT_TEXT_TOO_LARGE"
        })
        return true
    }
    function setExportStatus(message, isError, isWarning) {
        statusText = message
        statusError = isError
        statusWarning = isWarning === true
    }
    function convertAndCopy() {
        if (conversionInFlight || exportSection.exportBusy || !settingsReady || !host || !host.opened || !typography || !typography.ready) return
        ensureProfileMode()
        try {
            Limits.ResourceLimits.assertTextLength(sourceText, Limits.ResourceLimits.values.maxConversionTextLength, "CONVERSION_TEXT_TOO_LARGE")
        } catch (error) {
            statusError = true
            statusWarning = false
            statusText = uiText("status.textTooLarge")
            return
        }
        busy = true
        conversionInFlight = true
        conversionPurpose = "clipboard"
        conversionRequestId++
        statusError = false
        statusWarning = false
        statusText = uiText("status.converting")
        focusEditor()
        conversionWorker.sendMessage({
            id: conversionRequestId,
            text: sourceText,
            mode: host.conversionMode,
            options: conversionOptions(),
            maxOutputLength: Limits.ResourceLimits.values.maxConversionTextLength,
            sizeErrorCode: "CONVERSION_TEXT_TOO_LARGE"
        })
    }
    function finishConversion(message) {
        if (!conversionInFlight || message.id !== conversionRequestId) return
        var purpose = conversionPurpose
        conversionInFlight = false
        conversionPurpose = ""
        busy = false
        if (message.ok) {
            if (purpose === "export") {
                exportConversionReady(message.output)
                return
            }
            Quickshell.clipboardText = message.output
            statusError = false
            statusWarning = false
            statusText = uiText("status.converted")
        } else if (purpose === "export") {
            exportConversionFailed(message.code || "CONVERSION_FAILED", message.message || "Conversion failed")
        } else {
            statusError = true
            statusWarning = false
            statusText = message.code === "CONVERSION_TEXT_TOO_LARGE"
                ? uiText("status.textTooLarge") : uiText("status.failure") + String(message.message || "")
        }
    }

    WorkerScript {
        id: conversionWorker
        source: "ConversionWorker.js"
        onMessage: function(message) { root.finishConversion(message) }
    }

    Keys.onEscapePressed: function(event) {
        if (page === "settings") focusEditor()
        else if (exportSection.expanded) {
            exportSection.collapse()
            editor.forceActiveFocus()
        }
        else root.closeRequested()
        event.accepted = true
    }

    Process {
        id: settingsDirectoryCreator
        command: ["/usr/bin/mkdir", "-p", root.configDirectory]
        onExited: function(exitCode) {
            if (exitCode === 0) settingsFile.reload()
            else {
                root.settingsReady = true
                root.statusError = true
                root.statusWarning = false
                root.statusText = root.uiText("status.settingsDirectory")
            }
        }
    }

    FileView {
        id: settingsFile
        path: root.configPath
        watchChanges: false
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadSettings(text())
        onLoadFailed: root.applySettings(Settings.ReshaperSettings.defaults(root.reshaperMetadata), true)
        onSaveFailed: function(error) {
            root.statusError = true
            root.statusWarning = false
            root.statusText = "Could not save reshaper settings."
        }
    }

    component ActionButton: Ui.Button {
        fontFamily: root.fontFamily
        fontSize: Style.font.body
        foreground: root.foreground
        accent: Color.accent
        bordered: true
        focusable: true
    }

    component ConvertButton: Ui.Button {
        id: convertControl
        property string label: ""

        fontFamily: root.fontFamily
        foreground: root.foreground
        accent: Color.accent
        bordered: true
        focusable: true
        text: ""
        Accessible.role: Accessible.Button
        Accessible.name: label

        Text {
            anchors.centerIn: parent
            text: convertControl.label
            textFormat: Text.PlainText
            color: convertControl.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
        }
    }

    component ModeCard: Item {
        id: modeCard
        property string title: ""
        property string description: ""
        property bool selected: false
        property color foreground: root.foreground
        property color accent: Color.accent
        property bool hovered: cardMouseArea.containsMouse
        property bool pressed: cardMouseArea.pressed
        signal clicked()

        implicitHeight: cardContent.implicitHeight + Style.space(20)
        implicitWidth: Style.space(280)
        opacity: enabled ? 1 : 0.5
        activeFocusOnTab: true
        Accessible.role: Accessible.RadioButton
        Accessible.name: title
        Accessible.description: description
        Accessible.checked: selected
        Keys.onReturnPressed: modeCard.clicked()
        Keys.onEnterPressed: modeCard.clicked()
        Keys.onSpacePressed: modeCard.clicked()

        Rectangle {
            anchors.fill: parent
            color: modeCard.selected
                ? Util.alpha(modeCard.accent, 0.14)
                : modeCard.pressed || modeCard.hovered
                    ? Util.alpha(modeCard.foreground, 0.08)
                    : Util.alpha(modeCard.foreground, 0.03)
            border.color: modeCard.activeFocus || modeCard.selected
                ? modeCard.accent
                : Util.alpha(modeCard.foreground, 0.25)
            border.width: modeCard.activeFocus || modeCard.selected
                ? Math.max(2, Style.normalBorderWidth)
                : Math.max(1, Style.normalBorderWidth)
            radius: Style.cornerRadius
        }

        RowLayout {
            id: cardContent
            anchors.fill: parent
            anchors.leftMargin: Style.space(14)
            anchors.rightMargin: Style.space(14)
            anchors.topMargin: Style.space(10)
            anchors.bottomMargin: Style.space(10)
            spacing: Style.space(12)
            LayoutMirroring.enabled: root.uiLanguage === "fa"
            LayoutMirroring.childrenInherit: true

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Style.space(18)
                implicitHeight: Style.space(18)
                radius: width / 2
                color: "transparent"
                border.color: modeCard.selected ? modeCard.accent : Util.alpha(modeCard.foreground, 0.7)
                border.width: modeCard.selected ? Math.max(2, Style.normalBorderWidth) : Math.max(1, Style.normalBorderWidth)

                Rectangle {
                    anchors.centerIn: parent
                    width: Style.space(8)
                    height: Style.space(8)
                    radius: width / 2
                    visible: modeCard.selected
                    color: modeCard.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Style.space(2)

                Text {
                    Layout.fillWidth: true
                    text: modeCard.title
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    color: modeCard.foreground
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                Text {
                    id: descriptionLabel
                    Layout.fillWidth: true
                    text: modeCard.description
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(modeCard.foreground, 0.72)
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    elide: Text.ElideRight
                }
            }
        }

        Ui.PanelToolTip {
            visible: modeCard.hovered && descriptionLabel.truncated
            text: modeCard.description
            fontFamily: root.fontFamily
        }

        MouseArea {
            id: cardMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                modeCard.forceActiveFocus()
                modeCard.clicked()
            }
        }
    }

    ColumnLayout {
        id: editorPage
        anchors.fill: parent
        visible: root.page === "editor"
        enabled: visible
        spacing: Style.space(14)

        RowLayout {
            id: editorHeader
            Layout.fillWidth: true
            spacing: Style.space(6)
            LayoutMirroring.enabled: root.uiLanguage === "fa"
            LayoutMirroring.childrenInherit: true
            Text {
                Layout.fillWidth: true
                text: root.uiText("editor.title")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
                elide: Text.ElideRight
            }

            Ui.PanelActionButton {
                id: settingsHeaderButton
                property bool pointerHovered: false
                objectName: "settingsButton"
                iconText: root.typography ? root.typography.iconSettings : "\ue8b8"
                fontFamily: root.iconFontFamily
                fontSize: Style.font.heading
                size: Style.space(42)
                bordered: true
                focusable: true
                enabled: root.settingsReady
                Accessible.name: root.uiText("button.settings")
                onHovered: function(isHovered) { pointerHovered = isHovered }
                onClicked: {
                    pointerHovered = false
                    root.openSettings()
                }

                Ui.PanelToolTip {
                    visible: settingsHeaderButton.pointerHovered
                    text: root.uiText("button.settings")
                    fontFamily: root.fontFamily
                }
            }
        }

        Controls.ScrollView {
            id: formScroll
            readonly property bool overflowing: formColumn.implicitHeight > height + 0.5
            readonly property real scrollGutter: overflowing ? Style.space(18) : 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            leftPadding: root.uiLanguage === "fa" ? scrollGutter : 0
            rightPadding: root.uiLanguage === "fa" ? 0 : scrollGutter
            LayoutMirroring.enabled: root.uiLanguage === "fa"
            LayoutMirroring.childrenInherit: true
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
            Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded

            Column {
                id: formColumn
                width: formScroll.availableWidth
                spacing: Style.space(14)

                Text {
                    width: parent.width
                    visible: root.typography && root.typography.failed
                    text: root.typography ? root.typography.errorMessage : ""
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: Color.urgent
                    wrapMode: Text.WordWrap
                }

                Controls.ScrollView {
                    id: editorScroll
                    width: parent.width
                    height: Style.space(180)
                    clip: true
                    LayoutMirroring.enabled: false
                    LayoutMirroring.childrenInherit: true
                    Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff

                    Controls.TextArea {
                        id: editor
                        text: root.host ? root.host.draftText : ""
                        onTextChanged: {
                            if (root.formattingEditor) return
                            var plain = root.rawEditorText()
                            if (root.host && root.host.draftText !== plain) root.host.draftText = plain
                            root.statusText = ""
                            var requested = plain
                            var requestedDirections = root.paragraphDirections(requested)
                            var requestedSignature = root.directionSignature(requestedDirections)
                            if (requestedSignature !== root.editorDirectionSignature) {
                                Qt.callLater(function() {
                                    if (!root.formattingEditor && root.rawEditorText() === requested)
                                        root.reformatEditor(requested, requestedDirections)
                                })
                            }
                        }
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        placeholderText: root.uiText("placeholder")
                        placeholderTextColor: Qt.darker(root.foreground, 1.45)
                        color: root.foreground
                        selectionColor: Color.accent
                        selectedTextColor: Color.background
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.RichText
                        selectByMouse: true
                        persistentSelection: true
                        horizontalAlignment: TextEdit.AlignLeft
                        padding: Style.space(10)
                        background: Rectangle {
                            color: Util.alpha(root.foreground, 0.03)
                            border.color: editor.activeFocus ? Color.accent : Util.alpha(root.foreground, 0.25)
                            border.width: Math.max(1, Style.normalBorderWidth)
                            radius: Style.cornerRadius
                        }
                    }
                }

                RowLayout {
                    id: conversionActions
                    width: parent.width
                    spacing: Style.space(8)
                    layoutDirection: root.uiLanguage === "fa" ? Qt.RightToLeft : Qt.LeftToRight
                    LayoutMirroring.enabled: false
                    LayoutMirroring.childrenInherit: false

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        spacing: Style.space(8)

                        ModeCard {
                            Layout.fillWidth: true
                            LayoutMirroring.enabled: root.uiLanguage === "fa"
                            LayoutMirroring.childrenInherit: true
                            objectName: "unicodeButton"
                            title: root.uiText("mode.unicode")
                            description: root.uiText("mode.unicodeDescription")
                            selected: root.host && root.host.conversionMode === "unicode"
                            onClicked: root.host.conversionMode = "unicode"
                        }
                        ModeCard {
                            Layout.fillWidth: true
                            LayoutMirroring.enabled: root.uiLanguage === "fa"
                            LayoutMirroring.childrenInherit: true
                            objectName: "compatibilityButton"
                            title: root.uiText("mode.compatibility")
                            description: root.uiText("mode.compatibilityDescription")
                            selected: root.host && root.host.conversionMode === "compatibility"
                            enabled: !root.hebrewProfile
                            onClicked: if (!root.hebrewProfile) root.host.conversionMode = "compatibility"
                        }
                    }

                    ConvertButton {
                        id: convertButton
                        objectName: "convertButton"
                        Layout.fillHeight: true
                        Layout.minimumWidth: Style.space(120)
                        Layout.preferredWidth: Style.space(170)
                        Layout.maximumWidth: Style.space(200)
                        label: root.uiText("button.convert")
                        enabled: root.settingsReady && !root.busy && !exportSection.exportBusy && root.typography && root.typography.ready
                        onClicked: root.convertAndCopy()
                    }
                }

                ExportSection {
                    id: exportSection
                    controller: root
                    host: root.host
                    typography: root.typography
                }

                RowLayout {
                    width: parent.width
                    visible: (root.busy || root.statusText !== "") && !exportSection.expanded
                    spacing: Style.space(6)
                    BusySpinner {
                        running: root.busy
                        fontFamily: root.fontFamily
                        foreground: root.foreground
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.statusText
                        textFormat: Text.PlainText
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        color: root.statusError ? Color.urgent : root.statusWarning ? Color.accent : root.foreground
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    SettingsContent {
        id: settingsContent
        anchors.fill: parent
        visible: root.page === "settings"
        enabled: visible
        controller: root
        typography: root.typography
        onBackRequested: root.focusEditor()
    }
}
