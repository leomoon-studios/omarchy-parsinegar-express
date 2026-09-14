import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Ui as Ui
import qs.Commons
import "TextTools.js" as TextTools

FocusScope {
    id: root

    required property var controller
    required property Typography typography
    readonly property color foreground: controller.foreground
    readonly property string fontFamily: typography.family
    readonly property Item focusItem: backButton
    signal backRequested()
    LayoutMirroring.enabled: controller.uiLanguage === "fa"
    LayoutMirroring.childrenInherit: true

    function uiText(key) { return controller.uiText(key) }
    function toolsForGroup(group) { return TextTools.TextTools.groups(group) }
    function focusPage() { backButton.forceActiveFocus() }

    component ActionButton: Ui.Button {
        fontFamily: root.fontFamily
        fontSize: Style.font.body
        foreground: root.foreground
        accent: Color.accent
        bordered: true
        focusable: true
    }

    Keys.onEscapePressed: function(event) {
        root.backRequested()
        event.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Text {
                Layout.fillWidth: true
                LayoutMirroring.enabled: false
                LayoutMirroring.childrenInherit: false
                text: root.uiText("tools.title")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
                horizontalAlignment: root.controller.uiLanguage === "fa" ? Text.AlignRight : Text.AlignLeft
            }

            HeaderActionButton {
                id: backButton
                objectName: "textToolsBackButton"
                iconText: root.controller.uiLanguage === "fa" ? root.typography.iconForward : root.typography.iconBack
                fontFamily: root.typography.iconFamily
                fontSize: Style.font.heading
                size: Style.space(42)
                toolTipText: root.uiText("button.back")
                toolTipFontFamily: root.fontFamily
                Accessible.name: root.uiText("button.back")
                onClicked: root.backRequested()
            }
        }

        ScrollView {
            id: toolsScroll
            readonly property bool overflowing: toolsContent.implicitHeight > height + 0.5
            readonly property real scrollGutter: overflowing ? toolsScroll.ScrollBar.vertical.width + Style.space(6) : 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            leftPadding: root.controller.uiLanguage === "fa" ? scrollGutter : 0
            rightPadding: root.controller.uiLanguage === "fa" ? 0 : scrollGutter
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Column {
                id: toolsContent
                width: toolsScroll.availableWidth
                spacing: Style.space(10)

                Rectangle {
                    width: parent.width
                    implicitHeight: intro.implicitHeight + Style.space(10) * 2
                    color: Util.alpha(root.foreground, 0.06)
                    border.color: Util.alpha(root.foreground, 0.35)
                    border.width: Math.max(1, Style.normalBorderWidth)
                    radius: Style.cornerRadius

                    Text {
                        id: intro
                        anchors.fill: parent
                        anchors.margins: Style.space(10)
                        text: root.uiText("tools.intro")
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        wrapMode: Text.WordWrap
                    }
                }

                RowLayout {
                    width: parent.width
                    layoutDirection: Qt.RightToLeft
                    ActionButton {
                        visible: root.controller.textToolsUndoText !== ""
                        text: root.uiText("tools.undo")
                        onClicked: root.controller.undoTextTools()
                    }
                }

                Repeater {
                    model: ["persian", "cleanup", "alternate"]

                    delegate: Column {
                        required property string modelData
                        width: parent.width
                        spacing: Style.space(6)

                        SectionHeading {
                            width: parent.width
                            label: root.uiText("tools.group." + modelData)
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            rightToLeft: root.controller.uiLanguage === "fa"
                        }

                        Repeater {
                            model: root.toolsForGroup(modelData)

                            delegate: Ui.Toggle {
                                required property var modelData
                                width: parent.width
                                label: root.uiText(modelData.labelKey)
                                description: root.uiText(modelData.descriptionKey)
                                checked: root.controller.textToolEnabled(modelData.id)
                                foreground: root.foreground
                                accent: Color.accent
                                fontFamily: root.fontFamily
                                onClicked: root.controller.toggleTextTool(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
