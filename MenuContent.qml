import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import qs.Commons
import "LibraryAdapter.js" as Conversion
import "ReshaperSettings.js" as Settings
import "InterfaceStrings.js" as Strings

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
    property string uiLanguage: "en"
    property int settingsRevision: 0
    property bool settingsReady: false
    property string page: "editor"
    implicitHeight: page === "settings" || exportSection.expanded
        ? Style.space(500)
        : editorHeader.implicitHeight + Style.space(14) + formColumn.implicitHeight
    property bool busy: false
    property string statusText: ""
    property bool statusError: false
    property bool statusWarning: false
    signal closeRequested()

    function uiText(key) { return Strings.InterfaceStrings.text(uiLanguage, key) }

    function applySettings(value, save) {
        reshaperSettings = Settings.ReshaperSettings.sanitize(reshaperMetadata, value)
        settingsRevision++
        settingsReady = true
        if (host) {
            host.reshaperSettings = reshaperSettings
            host.reshaperSettingsLoaded = true
            host.uiLanguage = uiLanguage
        }
        if (save) saveSettings()
    }
    function loadSettings(raw) {
        var result = Settings.ReshaperSettings.parse(reshaperMetadata, raw)
        if (result.recovered) console.warn("ParsiNegar Express: resetting invalid settings")
        uiLanguage = result.uiLanguage
        applySettings(result.settings, result.recovered)
    }
    function saveSettings() {
        if (!settingsReady) return
        settingsFile.setText(Settings.ReshaperSettings.serialize(reshaperMetadata, reshaperSettings, uiLanguage))
    }
    function setUiLanguage(language) {
        var next = Settings.ReshaperSettings.sanitizeUiLanguage(language)
        if (uiLanguage === next) return
        uiLanguage = next
        if (host) host.uiLanguage = uiLanguage
        saveSettings()
    }
    function baseOption(name) { settingsRevision; return reshaperSettings[name] }
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
    function resetReshaperSettings() { applySettings(Settings.ReshaperSettings.defaults(reshaperMetadata), true) }
    function initialize() {
        if (host && host.reshaperSettingsLoaded) {
            uiLanguage = Settings.ReshaperSettings.sanitizeUiLanguage(host.uiLanguage)
            applySettings(host.reshaperSettings, false)
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
            videoStudioPro: host.videoStudioPro,
            reshaperOptions: reshaperSettings
        }
    }
    function convertForExport() {
        if (!settingsReady || !host || !host.opened || !typography || !typography.ready)
            throw new Error("Export is not ready")
        return Conversion.convert(editor.text, host.conversionMode, conversionOptions())
    }
    function setExportStatus(message, isError, isWarning) {
        statusText = message
        statusError = isError
        statusWarning = isWarning === true
    }
    function convertAndCopy() {
        if (busy || exportSection.exportBusy || !settingsReady || !host || !host.opened || !typography || !typography.ready) return
        busy = true
        try {
            focusEditor()
            var output = Conversion.convert(editor.text, host.conversionMode, conversionOptions())
            Quickshell.clipboardText = output
            statusError = false
            statusWarning = false
            statusText = uiText("status.converted")
        } catch (error) {
            statusError = true
            statusWarning = false
            statusText = uiText("status.failure") + error.message
        } finally {
            busy = false
        }
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
            RowLayout {
                id: directionButtons
                spacing: Style.space(6)
                LayoutMirroring.enabled: false
                LayoutMirroring.childrenInherit: true
                ActionButton {
                    text: root.uiText("button.ltr")
                    selected: root.host ? !root.host.editorRtl : false
                    onClicked: { root.host.editorRtl = false; root.focusEditor() }
                }
                ActionButton {
                    text: root.uiText("button.rtl")
                    selected: root.host ? root.host.editorRtl : true
                    onClicked: { root.host.editorRtl = true; root.focusEditor() }
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
                        horizontalAlignment: root.host && !root.host.editorRtl ? TextEdit.AlignLeft : TextEdit.AlignRight
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
                        onClicked: root.host.conversionMode = "compatibility"
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

                Text {
                    width: parent.width
                    text: root.statusText
                    textFormat: Text.PlainText
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.statusError ? Color.urgent : root.statusWarning ? Color.accent : root.foreground
                    wrapMode: Text.WordWrap
                    visible: text !== "" && !exportSection.expanded
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
