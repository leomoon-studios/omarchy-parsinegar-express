import QtQuick
import qs.Ui as Ui
import qs.Commons

Ui.PanelActionButton {
    id: root

    property string toolTipText: ""
    property string toolTipFontFamily: fontFamily
    property bool pointerHovered: false

    bordered: true
    focusable: true
    onHovered: function(isHovered) { pointerHovered = isHovered }

    Ui.PanelToolTip {
        visible: root.pointerHovered && root.toolTipText !== ""
        text: root.toolTipText
        fontFamily: root.toolTipFontFamily
    }
}
