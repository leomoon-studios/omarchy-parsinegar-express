import QtQuick
import QtQuick.Layouts
import qs.Commons

Rectangle {
    id: root

    required property string message
    required property bool error
    required property bool warning
    required property bool busy
    required property string fontFamily
    required property color foreground
    readonly property color statusColor: error ? Color.urgent
        : warning || busy ? Color.accent : "#4fb783"

    visible: busy || message !== ""
    implicitHeight: Style.space(32)
    color: Util.alpha(statusColor, 0.12)
    border.color: Util.alpha(statusColor, 0.48)
    border.width: Math.max(1, Style.normalBorderWidth)
    radius: 0

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        spacing: Style.space(6)

        BusySpinner {
            running: root.busy
            fontFamily: root.fontFamily
            foreground: root.statusColor
        }

        Text {
            Layout.fillWidth: true
            text: root.message
            textFormat: Text.PlainText
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            color: root.statusColor
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
        }
    }
}
