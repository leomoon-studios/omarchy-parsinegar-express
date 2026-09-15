import QtQuick
import qs.Commons

Text {
    id: root

    property string label: ""
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family
    property bool rightToLeft: false

    text: label
    textFormat: Text.PlainText
    color: foreground
    font.family: fontFamily
    font.pixelSize: Style.font.body
    font.bold: true
    wrapMode: Text.WordWrap
    // Parent pages mirror their whole layout for Persian. Text alignment is
    // mirrored too, so retaining AlignLeft gives the required physical right
    // alignment in Persian and left alignment in English.
    horizontalAlignment: Text.AlignLeft
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: false
}
