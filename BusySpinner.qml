import QtQuick
import qs.Commons

Item {
    id: root
    required property bool running
    required property string fontFamily
    required property color foreground

    visible: running
    implicitWidth: Style.font.body
    implicitHeight: Style.font.body

    Item {
        id: ring
        anchors.centerIn: parent
        width: Math.max(12, Math.min(parent.width, parent.height))
        height: width

        Repeater {
            model: 8

            Rectangle {
                required property int index
                readonly property real angle: index * Math.PI / 4
                width: Math.max(2, ring.width * 0.16)
                height: width
                radius: width / 2
                color: root.foreground
                opacity: 0.25 + index * 0.095
                x: ring.width / 2 + Math.sin(angle) * ring.width * 0.36 - width / 2
                y: ring.height / 2 - Math.cos(angle) * ring.height * 0.36 - height / 2
            }
        }

        RotationAnimator on rotation {
            running: root.running && root.visible
            from: 0
            to: 360
            duration: 700
            loops: Animation.Infinite
        }
    }
}
