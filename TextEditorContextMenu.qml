import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts
import qs.Commons

Controls.Menu {
    id: root

    required property var editor
    required property var controller
    required property var pasteHandler
    property string fontFamily: Style.font.family
    property color foreground: Color.foreground
    property bool rightToLeft: false
    property real requestedX: 0
    property real requestedY: 0

    objectName: "editorContextMenu"
    implicitWidth: Style.space(224)
    topPadding: Style.space(6)
    bottomPadding: Style.space(6)
    leftPadding: Style.space(6)
    rightPadding: Style.space(6)

    function openAt(item, positionX, positionY) {
        requestedX = positionX
        requestedY = positionY
        popup(item, positionX, positionY)
    }

    component ContextMenuItem: Controls.MenuItem {
        id: control

        property string shortcutText: ""

        implicitHeight: Style.space(38)
        leftPadding: Style.space(12)
        rightPadding: Style.space(12)
        opacity: enabled ? 1 : 0.42

        contentItem: RowLayout {
            spacing: Style.space(14)
            LayoutMirroring.enabled: root.rightToLeft
            LayoutMirroring.childrenInherit: true

            Text {
                Layout.fillWidth: true
                text: control.text
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                horizontalAlignment: root.rightToLeft ? Text.AlignRight : Text.AlignLeft
                elide: Text.ElideRight
            }

            Text {
                visible: text !== ""
                text: control.shortcutText
                color: Util.alpha(root.foreground, 0.68)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
            }
        }

        background: Rectangle {
            color: !control.enabled
                ? Util.alpha(root.foreground, 0.045)
                : control.highlighted
                    ? Util.alpha(root.foreground, 0.1)
                    : "transparent"
            border.color: !control.enabled ? Util.alpha(root.foreground, 0.18) : "transparent"
            border.width: !control.enabled ? Math.max(1, Style.normalBorderWidth) : 0
            radius: Style.cornerRadius
        }
    }

    background: Rectangle {
        color: Color.background
        border.color: Util.alpha(root.foreground, 0.28)
        border.width: Math.max(1, Style.normalBorderWidth)
        radius: Style.cornerRadius
    }

    ContextMenuItem {
        objectName: "contextUndoAction"
        text: root.controller.uiText("history.undo")
        shortcutText: "Ctrl+Z"
        enabled: root.controller.canUndo
        onTriggered: {
            root.controller.undoSourceEdit()
            root.editor.forceActiveFocus()
        }
    }

    ContextMenuItem {
        objectName: "contextRedoAction"
        text: root.controller.uiText("history.redo")
        shortcutText: "Ctrl+Y"
        enabled: root.controller.canRedo
        onTriggered: {
            root.controller.redoSourceEdit()
            root.editor.forceActiveFocus()
        }
    }

    Controls.MenuSeparator {
        contentItem: Rectangle {
            implicitHeight: Math.max(1, Style.normalBorderWidth)
            color: Util.alpha(root.foreground, 0.2)
        }
    }

    ContextMenuItem {
        objectName: "contextCutAction"
        text: root.controller.uiText("edit.cut")
        shortcutText: "Ctrl+X"
        enabled: !root.editor.readOnly && root.editor.selectionStart !== root.editor.selectionEnd
        onTriggered: {
            root.editor.cut()
            root.editor.forceActiveFocus()
        }
    }

    ContextMenuItem {
        objectName: "contextCopyAction"
        text: root.controller.uiText("edit.copy")
        shortcutText: "Ctrl+C"
        enabled: root.editor.selectionStart !== root.editor.selectionEnd
        onTriggered: {
            root.editor.copy()
            root.editor.forceActiveFocus()
        }
    }

    ContextMenuItem {
        objectName: "contextPasteAction"
        text: root.controller.uiText("edit.paste")
        shortcutText: "Ctrl+V"
        enabled: !root.editor.readOnly && root.editor.canPaste
        onTriggered: {
            root.pasteHandler()
            root.editor.forceActiveFocus()
        }
    }

    ContextMenuItem {
        objectName: "contextDeleteAction"
        text: root.controller.uiText("edit.delete")
        shortcutText: "Del"
        enabled: !root.editor.readOnly && root.editor.selectionStart !== root.editor.selectionEnd
        onTriggered: {
            root.editor.remove(root.editor.selectionStart, root.editor.selectionEnd)
            root.editor.forceActiveFocus()
        }
    }

    Controls.MenuSeparator {
        contentItem: Rectangle {
            implicitHeight: Math.max(1, Style.normalBorderWidth)
            color: Util.alpha(root.foreground, 0.2)
        }
    }

    ContextMenuItem {
        objectName: "contextSelectAllAction"
        text: root.controller.uiText("edit.selectAll")
        shortcutText: "Ctrl+A"
        enabled: root.editor.length > 0
        onTriggered: {
            root.editor.selectAll()
            root.editor.forceActiveFocus()
        }
    }
}
