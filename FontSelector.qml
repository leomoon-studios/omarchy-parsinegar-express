import QtQuick
import QtQuick.Controls
import qs.Commons
import "FontSearch.js" as Search

Control {
    id: control

    property var fonts: []
    property string selectedKey: ""
    property string placeholderText: ""
    property string emptyText: ""
    property string previewUnavailableText: ""
    property string uiFontFamily: ""
    property var filteredFonts: []
    property bool updatingText: false
    readonly property alias searchField: searchField
    signal fontSelected(var fontEntry)

    implicitHeight: Style.space(44)
    focusPolicy: Qt.StrongFocus
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    function filter(query) {
        filteredFonts = Search.FontSearch.filter(fonts, query)
        resultList.currentIndex = filteredFonts.length > 0 ? 0 : -1
    }

    function selectedEntry() {
        for (var index = 0; index < fonts.length; index++) {
            if (fonts[index].key === selectedKey) return fonts[index]
        }
        return null
    }

    function syncText(force) {
        if (!force && (searchField.activeFocus || popup.visible)) return
        var entry = selectedEntry()
        updatingText = true
        searchField.text = entry ? entry.display : ""
        updatingText = false
    }

    function openList() {
        if (!enabled) return
        filter("")
        popup.open()
        searchField.forceActiveFocus()
        searchField.selectAll()
    }

    function choose(index) {
        if (index < 0 || index >= filteredFonts.length) return false
        var entry = filteredFonts[index]
        fontSelected(entry)
        popup.close()
        syncText(true)
        return true
    }

    onFontsChanged: {
        filter(popup.visible ? searchField.text : "")
        if (!popup.visible) syncText(true)
    }
    onSelectedKeyChanged: if (!popup.visible) syncText(true)
    onEnabledChanged: if (!enabled) popup.close()

    contentItem: TextField {
        id: searchField
        objectName: control.objectName + "SearchField"
        leftPadding: Style.space(10)
        rightPadding: Style.space(28)
        placeholderText: control.fonts.length ? control.placeholderText : control.emptyText
        horizontalAlignment: Text.AlignLeft
        font.family: control.uiFontFamily
        font.styleName: ""
        font.pixelSize: Style.font.body
        color: Color.foreground
        selectionColor: Color.accent
        selectedTextColor: Color.background
        enabled: control.enabled
        background: Item {}

        onPressed: if (!popup.visible) control.openList()
        onTextEdited: {
            if (control.updatingText) return
            control.filter(text)
            if (!popup.visible) popup.open()
        }
        onAccepted: control.choose(resultList.currentIndex)

        Keys.onDownPressed: function(event) {
            if (!popup.visible) control.openList()
            else if (resultList.count > 0)
                resultList.currentIndex = Math.min(resultList.count - 1, resultList.currentIndex + 1)
            event.accepted = true
        }
        Keys.onUpPressed: function(event) {
            if (!popup.visible) control.openList()
            else if (resultList.count > 0)
                resultList.currentIndex = Math.max(0, resultList.currentIndex - 1)
            event.accepted = true
        }
        Keys.onEscapePressed: function(event) {
            popup.close()
            control.syncText(true)
            event.accepted = true
        }
        Keys.onReturnPressed: function(event) {
            control.choose(resultList.currentIndex)
            event.accepted = true
        }
        Keys.onEnterPressed: function(event) {
            control.choose(resultList.currentIndex)
            event.accepted = true
        }
    }

    background: Rectangle {
        color: Util.alpha(Color.foreground, 0.025)
        border.color: searchField.activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.2)
        border.width: Math.max(1, Style.normalBorderWidth)
        radius: Style.cornerRadius

        Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            text: "▾"
            color: Color.muted
            font.family: control.uiFontFamily
            font.pixelSize: Style.font.caption
        }
    }

    Popup {
        id: popup
        parent: control
        x: 0
        y: control.height + Style.space(2)
        width: control.width
        height: Math.min(Style.space(300), Math.max(Style.space(48), resultList.contentHeight + Style.space(12)))
        padding: Style.space(6)
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: control.syncText(true)

        background: Rectangle {
            color: Color.background
            border.color: Util.alpha(Color.foreground, 0.2)
            border.width: Math.max(1, Style.normalBorderWidth)
            radius: Style.cornerRadius
        }

        contentItem: ListView {
            id: resultList
            objectName: control.objectName + "ResultList"
            readonly property real gutter: contentHeight > height ? Style.space(12) : 0
            clip: true
            model: control.filteredFonts
            currentIndex: count > 0 ? 0 : -1
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: Style.space(8)
                x: resultList.width - width
            }

            delegate: ItemDelegate {
                id: fontDelegate
                required property var modelData
                required property int index
                x: 0
                width: resultList.width - resultList.gutter
                height: Style.space(46)
                highlighted: ListView.isCurrentItem
                hoverEnabled: true
                onHoveredChanged: if (hovered) resultList.currentIndex = index
                onClicked: control.choose(index)

                background: Rectangle {
                    color: fontDelegate.highlighted || fontDelegate.hovered
                        ? Util.alpha(Color.accent, 0.14) : "transparent"
                    radius: Style.cornerRadius
                }

                contentItem: Row {
                    spacing: Style.space(8)
                    layoutDirection: Qt.LeftToRight

                    Text {
                        width: Math.max(0, fontDelegate.availableWidth * 0.34 - Style.space(8))
                        anchors.verticalCenter: parent.verticalCenter
                        text: fontDelegate.modelData.display
                        textFormat: Text.PlainText
                        font.family: control.uiFontFamily
                        font.pixelSize: Style.font.body
                        color: Color.foreground
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                    }

                    Text {
                        width: Math.max(0, fontDelegate.availableWidth * 0.66 - Style.space(8))
                        anchors.verticalCenter: parent.verticalCenter
                        text: fontDelegate.modelData.custom ? control.previewUnavailableText
                            : (fontDelegate.modelData.family.indexOf("F_") === 0 ||
                               fontDelegate.modelData.family.indexOf("LMN ") === 0)
                                ? fontDelegate.modelData.compatibilityPreview
                                : fontDelegate.modelData.unicodePreview
                        textFormat: Text.PlainText
                        font.family: fontDelegate.modelData.custom ? control.uiFontFamily : fontDelegate.modelData.family
                        font.styleName: fontDelegate.modelData.style
                        font.pixelSize: Style.font.body
                        color: Color.muted
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: resultList.count === 0
                text: control.emptyText
                font.family: control.uiFontFamily
                color: Color.muted
            }
        }
    }
}
