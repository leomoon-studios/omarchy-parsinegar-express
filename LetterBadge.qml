import QtQuick

// Text badge content; Panel.qml supplies the shell WidgetButton and theme.
Item {
    id: root
    required property Typography typography
    property color foreground: typography.foreground
    property color background: "#9b8cff"
    property real spacingScale: 1
    property bool framed: false
    property real frameSize: 26 * spacingScale
    property int compactPixelSize: 12
    implicitWidth: framed ? frameSize : letter.implicitWidth + 4 * spacingScale
    implicitHeight: framed ? frameSize : Math.max(12 * spacingScale, letter.font.pixelSize + 3 * spacingScale)
    visible: typography.ready

    Rectangle {
        anchors.fill: parent
        radius: root.framed ? root.frameSize / 4 : 7 * root.spacingScale
        color: root.background
        visible: root.framed
    }

    TextMetrics {
        id: glyphMetrics
        font: letter.font
        text: letter.text
    }

    Text {
        id: letter
        objectName: "badgeLetter"
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: (width - glyphMetrics.tightBoundingRect.width) / 2 - glyphMetrics.tightBoundingRect.x
        text: "پ"
        font: root.framed ? root.typography.badgeFont : Qt.font({
            family: root.typography.family,
            pixelSize: root.compactPixelSize,
            weight: Font.Bold
        })
        color: root.foreground
        renderType: Text.NativeRendering
    }
}
