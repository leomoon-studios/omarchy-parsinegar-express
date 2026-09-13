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
    readonly property string sourceText: editor.text
    readonly property color foreground: host && host.bar ? host.bar.foreground : Color.foreground
    readonly property string fontFamily: typography ? typography.family : ""
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
    function automaticEditorAlignment(value) {
        var text = String(value || "")
        for (var index = 0; index < text.length; index++) {
            var code = text.charCodeAt(index)
            if (isRtlStrong(code)) return TextEdit.AlignRight
            if (isLtrStrong(code)) return TextEdit.AlignLeft
        }
        return uiLanguage === "fa" ? TextEdit.AlignRight : TextEdit.AlignLeft
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
        Limits.ResourceLimits.assertTextLength(editor.text, Limits.ResourceLimits.values.maxSvgTextLength, "EXPORT_TEXT_TOO_LARGE")
        conversionInFlight = true
        conversionPurpose = "export"
        conversionRequestId++
        conversionWorker.sendMessage({
            id: conversionRequestId,
            text: editor.text,
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
            Limits.ResourceLimits.assertTextLength(editor.text, Limits.ResourceLimits.values.maxConversionTextLength, "CONVERSION_TEXT_TOO_LARGE")
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
            text: editor.text,
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
                            if (root.host && root.host.draftText !== text) root.host.draftText = text
                            root.statusText = ""
                        }
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        placeholderText: root.uiText("placeholder")
                        placeholderTextColor: Qt.darker(root.foreground, 1.45)
                        color: root.foreground
                        selectionColor: Color.accent
                        selectedTextColor: Color.background
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        selectByMouse: true
                        persistentSelection: true
                        horizontalAlignment: root.automaticEditorAlignment(text)
                        padding: Style.space(10)
                        background: Rectangle {
                            color: Util.alpha(root.foreground, 0.03)
                            border.color: editor.activeFocus ? Color.accent : Util.alpha(root.foreground, 0.25)
                            border.width: Math.max(1, Style.normalBorderWidth)
                            radius: Style.cornerRadius
                        }
                    }
                }

                GridLayout {
                    width: parent.width
                    columns: 2
                    columnSpacing: Style.space(8)
                    ActionButton {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        text: root.uiText("mode.unicode")
                        selected: root.host && root.host.conversionMode === "unicode"
                        onClicked: root.host.conversionMode = "unicode"
                    }
                    ActionButton {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        text: root.uiText("mode.compatibility")
                        selected: root.host && root.host.conversionMode === "compatibility"
                        enabled: !root.hebrewProfile
                        onClicked: if (!root.hebrewProfile) root.host.conversionMode = "compatibility"
                    }
                }

                ActionButton {
                    width: parent.width
                    text: root.uiText("button.convert")
                    enabled: root.settingsReady && !root.busy && !exportSection.exportBusy && root.typography && root.typography.ready
                    onClicked: root.convertAndCopy()
                }

                ExportSection {
                    id: exportSection
                    controller: root
                    host: root.host
                    typography: root.typography
                }

                ActionButton {
                    width: parent.width
                    text: root.uiText("button.settings")
                    enabled: root.settingsReady
                    onClicked: root.openSettings()
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
