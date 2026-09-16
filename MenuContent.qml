import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import qs.Commons
import "EditorDirection.js" as Direction
import "ReshaperSettings.js" as Settings
import "SourceHistory.js" as History
import "TextTools.js" as TextTools
import "InterfaceStrings.js" as Strings
import "ResourceLimits.js" as Limits

FocusScope {
    id: root
    property var host: null
    property Typography typography: null
    readonly property alias editorItem: editor
    readonly property alias exportItem: exportSection
    readonly property alias editorPageScroll: formScroll
    readonly property Item focusItem: page === "settings"
        ? settingsContent.focusItem
        : page === "export" ? exportSection.focusItem
        : page === "tools" ? textToolsPage.focusItem
        : page === "help" ? helpPage.focusItem : editor
    readonly property string sourceText: conversionText()
    readonly property bool canUndo: host && host.sourceHistory
        ? History.SourceHistory.canUndo(host.sourceHistory) : false
    readonly property bool canRedo: host && host.sourceHistory
        ? History.SourceHistory.canRedo(host.sourceHistory) : false
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
    implicitHeight: Style.space(500)
    property bool busy: false
    property bool conversionInFlight: false
    property int conversionRequestId: 0
    property string conversionPurpose: ""
    property string statusText: ""
    property bool statusError: false
    property bool statusWarning: false
    property bool formattingEditor: false
    property string editorDirectionSignature: ""
    property string editorPlainSnapshot: ""
    property var lastAppliedTextTools: []
    signal closeRequested()
    signal exportConversionReady(string output)
    signal exportConversionFailed(string code, string message)

    function uiText(key) { return Strings.InterfaceStrings.text(uiLanguage, key) }
    function paragraphLayout(value) {
        return Direction.EditorDirection.paragraphLayout(value)
    }
    function rawEditorText() {
        var text = editor.textFormat === TextEdit.RichText ? editor.getText(0, editor.length) : editor.text
        return text.replace(/\u200b/g, "")
    }
    function conversionText() {
        return rawEditorText().replace(/\u2029/g, "\n")
    }
    function escapeHtml(value) {
        return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;")
            .replace(/>/g, "&gt;").replace(/\"/g, "&quot;")
    }
    function formattedEditorText(value, layout) {
        var effectiveLayout = layout || paragraphLayout(value)
        var markup = []
        for (var index = 0; index < effectiveLayout.paragraphs.length; index++) {
            var paragraph = effectiveLayout.paragraphs[index]
            var alignment = effectiveLayout.directions[index]
            markup.push("<p dir=\"" + (alignment === "right" ? "rtl" : "ltr") +
                "\" align=\"" + alignment + "\" style=\"margin:0\">" +
                (paragraph === "" ? "&#8203;" : escapeHtml(paragraph)) + "</p>")
        }
        return markup.join("")
    }
    function reformatEditor(value, layout, restoredCursor, restoredAnchor) {
        var plain = value === undefined ? rawEditorText() : String(value)
        var effectiveLayout = layout || paragraphLayout(plain)
        var documentText = editor.getText(0, editor.length)
        var cursor = restoredCursor === undefined
            ? Direction.EditorDirection.logicalPosition(documentText, editor.cursorPosition)
            : restoredCursor
        var anchor
        if (restoredAnchor !== undefined) {
            anchor = restoredAnchor
        } else {
            var selectionStart = Direction.EditorDirection.logicalPosition(documentText, editor.selectionStart)
            var selectionEnd = Direction.EditorDirection.logicalPosition(documentText, editor.selectionEnd)
            anchor = selectionStart === selectionEnd
                ? cursor : cursor === selectionStart ? selectionEnd : selectionStart
        }
        formattingEditor = true
        editor.text = formattedEditorText(plain, effectiveLayout)
        documentText = editor.getText(0, editor.length)
        editor.cursorPosition = Direction.EditorDirection.documentPosition(documentText, anchor)
        if (cursor !== anchor)
            editor.moveCursorSelection(
                Direction.EditorDirection.documentPosition(documentText, cursor),
                TextEdit.SelectCharacters)
        editorDirectionSignature = effectiveLayout.signature
        editorPlainSnapshot = plain
        formattingEditor = false
    }

    function reportEditorSelection() {
        if (formattingEditor || !host || !host.sourceHistory) return
        var documentText = editor.getText(0, editor.length)
        var cursor = Direction.EditorDirection.logicalPosition(documentText, editor.cursorPosition)
        var selectionStart = Direction.EditorDirection.logicalPosition(documentText, editor.selectionStart)
        var selectionEnd = Direction.EditorDirection.logicalPosition(documentText, editor.selectionEnd)
        var anchor = selectionStart === selectionEnd
            ? cursor : cursor === selectionStart ? selectionEnd : selectionStart
        host.sourceHistory = History.SourceHistory.updateSelection(host.sourceHistory, cursor, anchor)
    }

    function replaceSourceText(value, cursor, anchor) {
        if (!host || !host.sourceHistory) return false
        var text = String(value === undefined || value === null ? "" : value)
        var next = History.SourceHistory.record(host.sourceHistory, {
            text: text,
            cursor: cursor,
            anchor: anchor
        })
        if (next === host.sourceHistory) return false
        host.sourceHistory = next
        host.draftText = text
        reformatEditor(text, null, next.current.cursor, next.current.anchor)
        return true
    }

    function restoreSourceHistory(result) {
        if (!result.changed || !host) return false
        host.sourceHistory = result.history
        host.draftText = result.state.text
        reformatEditor(result.state.text, null, result.state.cursor, result.state.anchor)
        return true
    }

    function undoSourceEdit() {
        return host && host.sourceHistory
            ? restoreSourceHistory(History.SourceHistory.undo(host.sourceHistory)) : false
    }

    function redoSourceEdit() {
        return host && host.sourceHistory
            ? restoreSourceHistory(History.SourceHistory.redo(host.sourceHistory)) : false
    }
    function pastePlainText() {
        var clipboardText = Quickshell.clipboardText
        if (clipboardText === undefined || clipboardText === null || clipboardText === "")
            return false

        var source = conversionText()
        var documentText = editor.getText(0, editor.length)
        var selectionStart = Direction.EditorDirection.logicalPosition(documentText, editor.selectionStart)
        var selectionEnd = Direction.EditorDirection.logicalPosition(documentText, editor.selectionEnd)
        var start = Math.min(selectionStart, selectionEnd)
        var end = Math.max(selectionStart, selectionEnd)
        var pastedText = String(clipboardText)
        var cursor = start + pastedText.length

        if (!replaceSourceText(source.slice(0, start) + pastedText + source.slice(end), cursor, cursor))
            return false
        editor.forceActiveFocus()
        return true
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
            result = { settings: Settings.ReshaperSettings.defaults(reshaperMetadata), shapingProfile: "standardPersianArabic", uiLanguage: "en", textTools: {}, appState: Settings.ReshaperSettings.defaultAppState(), recovered: true }
        }
        if (result.recovered) console.warn("ParsiNegar Express: resetting invalid settings")
        uiLanguage = result.uiLanguage
        shapingProfile = Settings.ReshaperSettings.sanitizeShapingProfile(reshaperMetadata, result.shapingProfile)
        applyAppState(result.appState)
        if (host) host.textTools = TextTools.TextTools.copyState(result.textTools)
        applySettings(result.settings, result.recovered)
        ensureProfileMode()
    }
    function saveSettings() {
        if (!settingsReady) return
        settingsFile.setText(Settings.ReshaperSettings.serialize(
            reshaperMetadata, reshaperSettings, uiLanguage, shapingProfile,
            TextTools.TextTools.copyState(host ? host.textTools : {}), appState()))
    }
    function appState() {
        return {
            conversionMode: host ? host.conversionMode : "unicode",
            reverseWords: host ? host.reverseWords : true,
            videoStudioPro: host ? host.videoStudioPro : false,
            editorFontSize: host ? host.editorFontSize : Style.font.body,
            exportSettings: host ? host.exportSettings : ({})
        }
    }
    function applyAppState(value) {
        var state = Settings.ReshaperSettings.sanitizeAppState(value)
        if (!host) return
        host.conversionMode = state.conversionMode
        host.reverseWords = state.reverseWords
        host.videoStudioPro = state.videoStudioPro
        host.editorFontSize = state.editorFontSize >= 10
            ? state.editorFontSize : Style.font.body
        host.exportSettings = state.exportSettings
    }

    function setEditorFontSize(value) {
        if (!host) return false
        var next = Math.max(10, Math.min(48, Math.round(Number(value))))
        if (!isFinite(next) || host.editorFontSize === next) return false
        host.editorFontSize = next
        saveSettings()
        return true
    }

    function adjustEditorFontSize(delta) {
        return setEditorFontSize(host.editorFontSize + (delta < 0 ? -1 : 1))
    }
    function setConversionMode(value) {
        if (!host || (value !== "unicode" && value !== "compatibility") || (value === "compatibility" && hebrewProfile)) return
        if (host.conversionMode === value) return
        host.conversionMode = value
        saveSettings()
    }
    function setReverseWords(value) {
        if (!host || host.reverseWords === value) return
        host.reverseWords = value
        saveSettings()
    }
    function setVideoStudioPro(value) {
        if (!host || host.videoStudioPro === value) return
        host.videoStudioPro = value
        saveSettings()
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
        if (hebrewProfile && host && host.conversionMode !== "unicode") {
            host.conversionMode = "unicode"
            if (settingsReady) saveSettings()
        }
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
        if (host) host.textTools = TextTools.TextTools.copyState(host.textTools)
        if (host && host.reshaperSettingsLoaded) {
            uiLanguage = Settings.ReshaperSettings.sanitizeUiLanguage(host.uiLanguage)
            shapingProfile = Settings.ReshaperSettings.sanitizeShapingProfile(
                reshaperMetadata, host.shapingProfile, host.reshaperSettings.language)
            applySettings(host.reshaperSettings, false)
            ensureProfileMode()
        }
        else settingsDirectoryCreator.running = true
        var draft = host ? String(host.draftText || "").replace(/\u2029/g, "\n") : ""
        if (host) {
            host.draftText = draft
            if (!host.sourceHistory || host.sourceHistory.current.text !== draft)
                host.sourceHistory = History.SourceHistory.create({ text: draft, cursor: draft.length, anchor: draft.length }, host.sourceHistoryLimit)
            reformatEditor(draft, null, host.sourceHistory.current.cursor, host.sourceHistory.current.anchor)
        } else {
            reformatEditor("")
        }
    }
    function focusEditor() { page = "editor"; editor.forceActiveFocus() }
    function focusCurrentPage() {
        if (focusItem) focusItem.forceActiveFocus()
    }
    function openSettings() {
        page = "settings"
        Qt.callLater(function() {
            if (page === "settings" && settingsContent.focusItem) settingsContent.focusItem.forceActiveFocus()
        })
    }
    function openExport() {
        page = "export"
        Qt.callLater(function() {
            if (page === "export") {
                exportSection.loadSavedSettings(host ? host.exportSettings : {})
                exportSection.focusPage()
            }
        })
    }
    function openTextTools() {
        page = "tools"
        Qt.callLater(function() {
            if (page === "tools") textToolsPage.focusPage()
        })
    }
    function openHelp() {
        page = "help"
        Qt.callLater(function() {
            if (page === "help") helpPage.focusPage()
        })
    }
    function togglePage(target) {
        if (page === target) {
            if (target === "settings") settingsContent.closeGroup()
            focusEditor()
            return
        }
        if (target === "settings") {
            settingsContent.closeGroup()
            openSettings()
        } else if (target === "export") {
            openExport()
        } else if (target === "tools") {
            openTextTools()
        } else if (target === "help") {
            openHelp()
        }
    }
    function textToolEnabled(id) { return host && host.textTools && host.textTools[id] === true }
    function toggleTextTool(id) {
        if (!host) return
        host.textTools = TextTools.TextTools.withToggled(host.textTools, id)
        saveSettings()
    }
    function applyTextToolsToSource() {
        var input = conversionText()
        var result = TextTools.TextTools.applyEnabled(input, host ? host.textTools : {})
        lastAppliedTextTools = result.applied
        if (result.text === input) return result
        replaceSourceText(result.text, host.sourceHistory.current.cursor, host.sourceHistory.current.anchor)
        return result
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
    function convertAndCopy() {
        if (conversionInFlight || exportSection.exportBusy || !settingsReady || !host || !host.opened || !typography || !typography.ready) return
        ensureProfileMode()
        var prepared = applyTextToolsToSource()
        try {
            Limits.ResourceLimits.assertTextLength(prepared.text, Limits.ResourceLimits.values.maxConversionTextLength, "CONVERSION_TEXT_TOO_LARGE")
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
            text: prepared.text,
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
            statusText = lastAppliedTextTools.length
                ? uiText("status.converted") + " " + uiText("tools.appliedStatus")
                : uiText("status.converted")
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

    Shortcut {
        objectName: "convertShortcut"
        sequences: ["Ctrl+Return", "Ctrl+Enter"]
        context: Qt.WindowShortcut
        enabled: root.page === "editor" && root.settingsReady && !root.busy
            && !exportSection.exportBusy && root.host && root.host.opened
            && root.typography && root.typography.ready
        onActivated: root.convertAndCopy()
    }

    Shortcut {
        objectName: "settingsShortcut"
        sequence: "Ctrl+,"
        context: Qt.WindowShortcut
        enabled: root.settingsReady && !root.busy && !exportSection.exportBusy
        onActivated: root.togglePage("settings")
    }

    Shortcut {
        objectName: "textToolsShortcut"
        sequence: "Ctrl+T"
        context: Qt.WindowShortcut
        enabled: root.settingsReady && !root.busy && !exportSection.exportBusy
        onActivated: root.togglePage("tools")
    }

    Shortcut {
        objectName: "exportShortcut"
        sequence: "Ctrl+E"
        context: Qt.WindowShortcut
        enabled: root.settingsReady && !root.busy && !exportSection.exportBusy
        onActivated: root.togglePage("export")
    }

    Shortcut {
        objectName: "helpShortcut"
        sequence: "Ctrl+H"
        context: Qt.WindowShortcut
        enabled: root.settingsReady && !root.busy && !exportSection.exportBusy
        onActivated: root.togglePage("help")
    }

    Keys.onEscapePressed: function(event) {
        if (page === "settings") focusEditor()
        else if (page === "export" && !exportSection.exportBusy) focusEditor()
        else if (page === "tools") focusEditor()
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

            HeaderActionButton {
                id: undoHeaderButton
                objectName: "undoButton"
                iconText: root.typography ? root.typography.iconUndo : "\ue166"
                fontFamily: root.iconFontFamily
                fontSize: Style.font.heading
                size: Style.space(42)
                enabled: root.canUndo && !root.busy && !exportSection.exportBusy
                toolTipText: root.uiText("history.undo")
                toolTipFontFamily: root.fontFamily
                Accessible.name: root.uiText("history.undo")
                onClicked: {
                    pointerHovered = false
                    root.undoSourceEdit()
                    root.focusEditor()
                }
            }

            HeaderActionButton {
                id: redoHeaderButton
                objectName: "redoButton"
                iconText: root.typography ? root.typography.iconRedo : "\ue15a"
                fontFamily: root.iconFontFamily
                fontSize: Style.font.heading
                size: Style.space(42)
                enabled: root.canRedo && !root.busy && !exportSection.exportBusy
                toolTipText: root.uiText("history.redo")
                toolTipFontFamily: root.fontFamily
                Accessible.name: root.uiText("history.redo")
                onClicked: {
                    pointerHovered = false
                    root.redoSourceEdit()
                    root.focusEditor()
                }
            }

            HeaderActionButton {
                id: exportHeaderButton
                objectName: "exportButton"
                iconText: root.typography ? root.typography.iconExport : "\ue2c4"
                fontFamily: root.iconFontFamily
                fontSize: Style.font.heading
                size: Style.space(42)
                enabled: root.settingsReady && !root.busy && !exportSection.exportBusy
                toolTipText: root.uiText("export.title") + " (Ctrl+E)"
                toolTipFontFamily: root.fontFamily
                Accessible.name: root.uiText("export.title")
                onClicked: {
                    pointerHovered = false
                    root.openExport()
                }
            }

            HeaderActionButton {
                id: textToolsHeaderButton
                objectName: "textToolsButton"
                iconText: root.typography ? root.typography.iconTools : "\uf10b"
                fontFamily: root.iconFontFamily
                fontSize: Style.font.heading
                size: Style.space(42)
                enabled: root.settingsReady && !root.busy && !exportSection.exportBusy
                toolTipText: root.uiText("tools.title") + " (Ctrl+T)"
                toolTipFontFamily: root.fontFamily
                Accessible.name: root.uiText("tools.title")
                onClicked: {
                    pointerHovered = false
                    root.openTextTools()
                }
            }

            HeaderActionButton {
                id: settingsHeaderButton
                objectName: "settingsButton"
                iconText: root.typography ? root.typography.iconSettings : "\ue8b8"
                fontFamily: root.iconFontFamily
                fontSize: Style.font.heading
                size: Style.space(42)
                enabled: root.settingsReady && !root.busy && !exportSection.exportBusy
                toolTipText: root.uiText("button.settings") + " (Ctrl+,)"
                toolTipFontFamily: root.fontFamily
                Accessible.name: root.uiText("button.settings")
                onClicked: {
                    pointerHovered = false
                    root.openSettings()
                }
            }

            HeaderActionButton {
                id: helpHeaderButton
                objectName: "helpButton"
                iconText: root.typography ? root.typography.iconHelp : "\ue8fd"
                fontFamily: root.iconFontFamily
                fontSize: Style.font.heading
                size: Style.space(42)
                enabled: root.settingsReady && !root.busy && !exportSection.exportBusy
                toolTipText: root.uiText("help.title") + " (Ctrl+H)"
                toolTipFontFamily: root.fontFamily
                Accessible.name: root.uiText("help.title")
                onClicked: {
                    pointerHovered = false
                    root.openHelp()
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
            contentHeight: formColumn.height
            clip: true
            leftPadding: root.uiLanguage === "fa" ? scrollGutter : 0
            rightPadding: root.uiLanguage === "fa" ? 0 : scrollGutter
            LayoutMirroring.enabled: root.uiLanguage === "fa"
            LayoutMirroring.childrenInherit: true
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
            Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded

            ColumnLayout {
                id: formColumn
                width: formScroll.availableWidth
                height: Math.max(implicitHeight, formScroll.availableHeight)
                spacing: Style.space(14)

                Text {
                    Layout.fillWidth: true
                    visible: root.typography && root.typography.failed
                    text: root.typography ? root.typography.errorMessage : ""
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: Color.urgent
                    wrapMode: Text.WordWrap
                }

                Controls.ScrollView {
                    id: editorScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: Style.space(180)
                    Layout.preferredHeight: Style.space(180)
                    clip: true
                    LayoutMirroring.enabled: false
                    LayoutMirroring.childrenInherit: true
                    Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff

                    Controls.TextArea {
                        id: editor
                        text: ""
                        onTextChanged: {
                            if (root.formattingEditor) return
                            var plain = root.conversionText()
                            var previousPlain = root.editorPlainSnapshot
                            root.editorPlainSnapshot = plain
                            if (root.host && root.host.draftText !== plain) {
                                var current = root.host.sourceHistory.current
                                root.host.sourceHistory = History.SourceHistory.record(root.host.sourceHistory, {
                                    text: plain,
                                    cursor: current.cursor,
                                    anchor: current.anchor
                                })
                                root.host.draftText = plain
                            }
                            root.statusText = ""
                            var requested = plain
                            var requestedLayout = root.paragraphLayout(requested)
                            if (Direction.EditorDirection.isParagraphBreakInsertion(previousPlain, requested)) {
                                root.editorDirectionSignature = requestedLayout.signature
                                return
                            }
                            if (requestedLayout.signature !== root.editorDirectionSignature) {
                                Qt.callLater(function() {
                                    if (!root.formattingEditor && root.conversionText() === requested)
                                        root.reformatEditor(requested, requestedLayout)
                                })
                            }
                        }
                        onCursorPositionChanged: root.reportEditorSelection()
                        onSelectionStartChanged: root.reportEditorSelection()
                        onSelectionEndChanged: root.reportEditorSelection()
                        font.family: root.fontFamily
                        font.pixelSize: root.host ? root.host.editorFontSize : Style.font.body
                        placeholderText: root.uiText("placeholder")
                        placeholderTextColor: Qt.darker(root.foreground, 1.45)
                        color: root.foreground
                        selectionColor: Color.accent
                        selectedTextColor: Color.background
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.RichText
                        selectByMouse: true
                        persistentSelection: true
                        horizontalAlignment: TextEdit.AlignRight
                        padding: Style.space(10)
                        Keys.onPressed: function(event) {
                            var primaryModifier = Qt.platform.os === "osx" ? Qt.MetaModifier : Qt.ControlModifier
                            var hasPrimaryModifier = (event.modifiers & primaryModifier) !== 0
                            var hasShift = (event.modifiers & Qt.ShiftModifier) !== 0
                            var undoShortcut = event.matches(StandardKey.Undo)
                                || (hasPrimaryModifier && !hasShift && event.key === Qt.Key_Z)
                            var redoShortcut = event.matches(StandardKey.Redo)
                                || (hasPrimaryModifier && !hasShift && event.key === Qt.Key_Y)
                                || (hasPrimaryModifier && hasShift && event.key === Qt.Key_Z)

                            if (undoShortcut) {
                                root.undoSourceEdit()
                                event.accepted = true
                            } else if (redoShortcut) {
                                root.redoSourceEdit()
                                event.accepted = true
                            } else if (event.matches(StandardKey.Paste)
                                    || (hasPrimaryModifier && !hasShift && event.key === Qt.Key_V)) {
                                root.pastePlainText()
                                event.accepted = true
                            }
                        }
                        background: Rectangle {
                            color: Util.alpha(root.foreground, 0.03)
                            border.color: editor.activeFocus ? Color.accent : Util.alpha(root.foreground, 0.25)
                            border.width: Math.max(1, Style.normalBorderWidth)
                            radius: Style.cornerRadius
                        }

                        TextEditorContextMenu {
                            id: editorContextMenu
                            editor: editor
                            controller: root
                            pasteHandler: root.pastePlainText
                            fontFamily: root.fontFamily
                            foreground: root.foreground
                            rightToLeft: root.uiLanguage === "fa"
                        }

                        MouseArea {
                            id: contextMenuMouseArea
                            objectName: "editorContextMenuMouseArea"
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            preventStealing: true
                            z: 2
                            onPressed: function(mouse) {
                                editor.forceActiveFocus()
                                editorContextMenu.openAt(editor, mouse.x, mouse.y)
                                mouse.accepted = true
                            }
                            onWheel: function(wheel) {
                                var primaryModifier = Qt.platform.os === "osx"
                                    ? Qt.MetaModifier : Qt.ControlModifier
                                if ((wheel.modifiers & primaryModifier) === 0) {
                                    wheel.accepted = false
                                    return
                                }
                                var delta = wheel.angleDelta.y !== 0
                                    ? wheel.angleDelta.y : wheel.pixelDelta.y
                                if (delta === 0) {
                                    wheel.accepted = false
                                    return
                                }
                                root.adjustEditorFontSize(delta)
                                wheel.accepted = true
                            }
                        }
                    }
                }

                RowLayout {
                    id: conversionActions
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.minimumHeight: implicitHeight
                    Layout.preferredHeight: implicitHeight
                    Layout.maximumHeight: implicitHeight
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
                            onClicked: root.setConversionMode("unicode")
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
                            onClicked: root.setConversionMode("compatibility")
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

                Item {
                    id: statusSlot
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.minimumHeight: Style.space(32)
                    Layout.preferredHeight: Style.space(32)
                    Layout.maximumHeight: Style.space(32)
                    StatusMessage {
                        objectName: "conversionStatus"
                        anchors.fill: parent
                        message: root.statusText
                        error: root.statusError
                        warning: root.statusWarning
                        busy: root.busy
                        fontFamily: root.fontFamily
                        foreground: root.foreground
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

    ExportSection {
        id: exportSection
        anchors.fill: parent
        visible: root.page === "export"
        enabled: visible
        controller: root
        host: root.host
        typography: root.typography
        onBackRequested: root.focusEditor()
    }

    TextToolsPage {
        id: textToolsPage
        anchors.fill: parent
        visible: root.page === "tools"
        enabled: visible
        controller: root
        typography: root.typography
        onBackRequested: root.focusEditor()
    }

    HelpPage {
        id: helpPage
        anchors.fill: parent
        visible: root.page === "help"
        enabled: visible
        controller: root
        typography: root.typography
        onBackRequested: root.focusEditor()
    }
}
