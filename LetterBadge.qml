import QtQuick

// Text badge content; Panel.qml supplies the shell WidgetButton and theme.
Item {
    id: root
    required property Typography typography
    property color foreground: typography.foreground
    property real spacingScale: 1
    // Keep the compact bar slot without drawing an outline.
    implicitWidth: letter.implicitWidth + 4 * spacingScale
    implicitHeight: Math.max(12 * spacingScale, letter.font.pixelSize + 3 * spacingScale)
    visible: typography.ready

    TextMetrics {
        id: glyphMetrics
        font: letter.font
        text: letter.text
    }

    Text {
        id: letter
        objectName: "badgeLetter"
        anchors.centerIn: parent
        // Center the visible glyph, excluding the font's side bearings.
        anchors.horizontalCenterOffset: (width - glyphMetrics.tightBoundingRect.width) / 2 - glyphMetrics.tightBoundingRect.x
        text: "پ"
        font: root.typography.badgeFont
        color: root.foreground
        renderType: Text.NativeRendering
    }
}
