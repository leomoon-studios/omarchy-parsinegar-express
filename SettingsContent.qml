import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Ui as Ui
import qs.Commons
import "InterfaceStrings.js" as Strings

FocusScope {
    id: root
    required property var controller
    required property Typography typography
    property string ligatureGroupId: ""
    readonly property color foreground: controller.foreground
    readonly property string fontFamily: typography.family
    readonly property Item focusItem: ligatureGroupId === "" ? backButton : groupBackButton
    signal backRequested()
    LayoutMirroring.enabled: controller.uiLanguage === "fa"
    LayoutMirroring.childrenInherit: true

    function uiText(key) { return Strings.InterfaceStrings.text(controller.uiLanguage, key) }
    function languageLabel(language) { return uiText("settings.languageLabel." + language) }
    function languageDescription(language) { return uiText("settings.languageDescription." + language) }
    function groupLabel(group) { return uiText("settings.group." + group.id) }

    function groupById(id) {
        var groups = controller.reshaperMetadata.ligatureGroups
        for (var i = 0; i < groups.length; i++) if (groups[i].id === id) return groups[i]
        return null
    }
    function showGroup(id) {
        ligatureGroupId = id
        Qt.callLater(function() { if (root.focusItem) root.focusItem.forceActiveFocus() })
    }
    function closeGroup() {
        ligatureGroupId = ""
        Qt.callLater(function() { if (root.focusItem) root.focusItem.forceActiveFocus() })
    }

    Keys.onEscapePressed: function(event) {
        if (root.ligatureGroupId !== "") root.closeGroup()
        else root.backRequested()
        event.accepted = true
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
        anchors.fill: parent
        visible: root.ligatureGroupId === ""
        enabled: visible
        spacing: Style.space(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            ActionButton {
                id: backButton
                text: root.uiText("button.back")
                onClicked: root.backRequested()
            }
            Text {
                Layout.fillWidth: true
                text: root.uiText("settings.title")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
                horizontalAlignment: Text.AlignRight
            }
        }

        ScrollView {
            id: settingsScroll
            readonly property bool overflowing: settingsContent.implicitHeight > height + 0.5
            readonly property real scrollGutter: overflowing ? settingsScroll.ScrollBar.vertical.width + Style.space(6) : 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            leftPadding: root.controller.uiLanguage === "fa" ? scrollGutter : 0
            rightPadding: root.controller.uiLanguage === "fa" ? 0 : scrollGutter
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Column {
                id: settingsContent
                width: settingsScroll.availableWidth
                spacing: Style.space(10)

                Text {
                    width: parent.width
                    text: root.uiText("settings.interfaceLanguage")
                    color: Qt.darker(root.foreground, 1.45)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }

                Text {
                    width: parent.width
                    text: root.uiText("settings.interfaceLanguageDescription")
                    color: Qt.darker(root.foreground, 1.45)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }

                GridLayout {
                    width: parent.width
                    columns: 2
                    columnSpacing: Style.space(8)
                    Repeater {
                        model: Strings.InterfaceStrings.languages
                        ActionButton {
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            text: modelData === "fa" ? root.uiText("language.persian") : root.uiText("language.english")
                            selected: root.controller.uiLanguage === modelData
                            onClicked: root.controller.setUiLanguage(modelData)
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: root.uiText("settings.language")
                    color: Qt.darker(root.foreground, 1.45)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }

                GridLayout {
                    width: parent.width
                    columns: 2
                    columnSpacing: Style.space(8)
                    Repeater {
                        model: root.controller.reshaperMetadata.languages
                        ActionButton {
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            text: root.languageLabel(modelData)
                            selected: root.controller.baseOption("language") === modelData
                            onClicked: root.controller.setBaseOption("language", modelData)
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: root.languageDescription(root.controller.baseOption("language"))
                    color: Qt.darker(root.foreground, 1.45)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: root.uiText("settings.textShaping")
                    color: Qt.darker(root.foreground, 1.45)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }

                Ui.Toggle {
                    width: parent.width
                    label: root.uiText("toggle.reverse")
                    description: root.uiText("toggle.reverseDescription")
                    checked: root.controller.host ? root.controller.host.reverseWords : true
                    foreground: root.foreground
                    accent: Color.accent
                    fontFamily: root.fontFamily
                    onClicked: if (root.controller.host) root.controller.host.reverseWords = !root.controller.host.reverseWords
                }
                Ui.Toggle {
                    width: parent.width
                    label: root.uiText("toggle.video")
                    description: root.uiText("toggle.videoDescription")
                    checked: root.controller.host ? root.controller.host.videoStudioPro : false
                    enabled: root.controller.host && root.controller.host.conversionMode === "compatibility"
                    opacity: enabled ? 1 : 0.45
                    foreground: root.foreground
                    accent: Color.accent
                    fontFamily: root.fontFamily
                    onClicked: if (root.controller.host) root.controller.host.videoStudioPro = !root.controller.host.videoStudioPro
                }

                Ui.Toggle {
                    width: parent.width
                    label: root.uiText("settings.deleteHarakat")
                    description: root.uiText("settings.deleteHarakatDescription")
                    checked: root.controller.baseOption("deleteHarakat")
                    foreground: root.foreground
                    accent: Color.accent
                    fontFamily: root.fontFamily
                    onClicked: root.controller.toggleBaseOption("deleteHarakat")
                }
                Ui.Toggle {
                    width: parent.width
                    label: root.uiText("settings.shiftHarakat")
                    description: root.uiText("settings.shiftHarakatDescription")
                    checked: root.controller.baseOption("shiftHarakatPosition")
                    foreground: root.foreground
                    accent: Color.accent
                    fontFamily: root.fontFamily
                    onClicked: root.controller.toggleBaseOption("shiftHarakatPosition")
                }
                Ui.Toggle {
                    width: parent.width
                    label: root.uiText("settings.deleteTatweel")
                    description: root.uiText("settings.deleteTatweelDescription")
                    checked: root.controller.baseOption("deleteTatweel")
                    foreground: root.foreground
                    accent: Color.accent
                    fontFamily: root.fontFamily
                    onClicked: root.controller.toggleBaseOption("deleteTatweel")
                }
                Ui.Toggle {
                    width: parent.width
                    label: root.uiText("settings.supportZWJ")
                    description: root.uiText("settings.supportZWJDescription")
                    checked: root.controller.baseOption("supportZWJ")
                    foreground: root.foreground
                    accent: Color.accent
                    fontFamily: root.fontFamily
                    onClicked: root.controller.toggleBaseOption("supportZWJ")
                }
                Ui.Toggle {
                    width: parent.width
                    label: root.uiText("settings.unshapedIsolated")
                    description: root.uiText("settings.unshapedIsolatedDescription")
                    checked: root.controller.baseOption("useUnshapedInsteadOfIsolated")
                    foreground: root.foreground
                    accent: Color.accent
                    fontFamily: root.fontFamily
                    onClicked: root.controller.toggleBaseOption("useUnshapedInsteadOfIsolated")
                }
                Ui.Toggle {
                    width: parent.width
                    label: root.uiText("settings.supportLigatures")
                    description: root.uiText("settings.supportLigaturesDescription")
                    checked: root.controller.baseOption("supportLigatures")
                    foreground: root.foreground
                    accent: Color.accent
                    fontFamily: root.fontFamily
                    onClicked: root.controller.toggleBaseOption("supportLigatures")
                }

                Text {
                    width: parent.width
                    text: root.uiText("settings.namedLigatures")
                    color: Qt.darker(root.foreground, 1.45)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }

                Text {
                    width: parent.width
                    text: root.uiText("settings.fontNotice")
                    textFormat: Text.PlainText
                    color: Qt.darker(root.foreground, 1.45)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: root.controller.reshaperMetadata.ligatureGroups
                    ActionButton {
                        required property var modelData
                        width: parent.width
                        text: root.groupLabel(modelData) + " (" + modelData.ligatures.length + ")"
                        enabled: root.controller.baseOption("supportLigatures")
                        onClicked: root.showGroup(modelData.id)
                    }
                }

                ActionButton {
                    width: parent.width
                    text: root.uiText("settings.reset")
                    onClicked: root.controller.resetReshaperSettings()
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: root.ligatureGroupId !== ""
        enabled: visible
        spacing: Style.space(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            ActionButton {
                id: groupBackButton
                text: root.uiText("button.back")
                onClicked: root.closeGroup()
            }
            Text {
                Layout.fillWidth: true
                text: {
                    var group = root.groupById(root.ligatureGroupId)
                    return root.uiText("settings.breadcrumb") + (group ? root.groupLabel(group) : root.uiText("settings.namedLigatures"))
                }
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
                horizontalAlignment: Text.AlignRight
            }
        }

        ListView {
            id: ligatureList
            readonly property bool overflowing: contentHeight > height + 0.5
            readonly property real scrollGutter: overflowing ? ligatureVerticalBar.width + Style.space(6) : 0

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Style.space(8)
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                id: ligatureVerticalBar
                policy: ScrollBar.AsNeeded
                active: ligatureList.overflowing
            }
            model: {
                var group = root.groupById(root.ligatureGroupId)
                return group ? group.ligatures : []
            }
            delegate: Item {
                required property var modelData
                width: ligatureList.width
                height: ligatureToggle.implicitHeight
                LayoutMirroring.enabled: false
                LayoutMirroring.childrenInherit: false

                Ui.Toggle {
                    id: ligatureToggle
                    property bool pointerHovered: false
                    x: root.controller.uiLanguage === "fa" ? ligatureList.scrollGutter : 0
                    width: Math.max(0, parent.width - ligatureList.scrollGutter)
                    LayoutMirroring.enabled: root.controller.uiLanguage === "fa"
                    LayoutMirroring.childrenInherit: true
                    label: modelData.name
                    description: modelData.name === "RIAL SIGN" ? root.uiText("settings.rialDescription") : ""
                    checked: root.controller.ligatureEnabled(modelData.name)
                    enabled: root.controller.baseOption("supportLigatures")
                    foreground: root.foreground
                    accent: Color.accent
                    fontFamily: root.fontFamily
                    onClicked: root.controller.toggleLigature(modelData.name)
                    onHovered: function(isHovered) { pointerHovered = isHovered }

                    Ui.PanelToolTip {
                        visible: ligatureToggle.pointerHovered
                        text: ligatureToggle.modelData.name
                        fontFamily: root.fontFamily
                    }
                }
            }
        }
    }
}
