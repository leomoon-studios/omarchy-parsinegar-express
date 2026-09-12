import QtQuick
import Quickshell
import qs.Ui as Ui
import qs.Commons

Ui.Panel {
    id: root
    moduleName: "leomoon-studios.omarchy-parsinegar-express"
    ipcTarget: moduleName
    implicitWidth: iconButton.implicitWidth
    implicitHeight: iconButton.implicitHeight

    // Only draft/options survive menu closure; no conversion imports here.
    property string draftText: ""
    property bool editorRtl: true
    property bool reverseWords: true
    property bool videoStudioPro: false
    property string conversionMode: "unicode"
    // Loaded on first menu open; kept in memory after the lazy menu closes.
    property bool reshaperSettingsLoaded: false
    property var reshaperSettings: ({})
    property string shapingProfile: "standardPersianArabic"
    property string uiLanguage: "en"
    // Keep the menu loaded, but move its popup out of the way while an
    // out-of-process desktop file chooser owns the keyboard focus.
    property bool filePickerActive: false

    onFilePickerActiveChanged: {
        if (!filePickerActive && opened) {
            Qt.callLater(function() {
                if (menuLoader.item) menuLoader.item.focusEditor()
            })
        }
    }

    Typography {
        id: uiTypography
        basePixelSize: Style.font.baseSize
        foreground: Color.foreground
        muted: Color.muted
        errorColor: Color.urgent
    }

    Ui.WidgetButton {
        id: iconButton
        anchors.fill: parent
        bar: root.bar
        text: " "
        labelVisible: false
        fontFamily: uiTypography.family
        fixedWidth: vertical ? -1 : Math.max(Style.bar.iconSlot, badge.width + Style.space(4))
        fixedHeight: vertical ? Math.max(Style.bar.iconSlot, badge.height + Style.space(4)) : -1
        active: root.opened
        activeColor: uiTypography.foreground
        onPressed: root.toggle()

        LetterBadge {
            id: badge
            anchors.centerIn: parent
            typography: uiTypography
            spacingScale: Style.effectiveSpacingScale
            foreground: iconButton.active ? iconButton.activeColor : iconButton.foreground
        }
        Text {
            anchors.centerIn: parent
            visible: uiTypography.failed
            text: "!"
            color: Color.urgent
            font.pixelSize: Style.font.body
        }
    }

    // Own tooltip so it uses Vazirmatn without changing the bar's global font.
    PopupWindow {
        id: tooltip
        visible: iconButton.tooltipHovered && !root.opened
        color: "transparent"
        implicitWidth: tooltipText.implicitWidth + Style.space(16)
        implicitHeight: tooltipText.implicitHeight + Style.space(12)
        anchor.item: iconButton
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.Slide
        anchor.rect.x: root.bar && root.bar.position === "left" ? iconButton.width + Style.space(6)
            : root.bar && root.bar.position === "right" ? -width - Style.space(6) : (iconButton.width - width) / 2
        anchor.rect.y: root.bar && root.bar.position === "bottom" ? -height - Style.space(6)
            : iconButton.vertical ? (iconButton.height - height) / 2 : iconButton.height + Style.space(6)
        Rectangle {
            anchors.fill: parent
            color: Color.tooltip.background
            border.color: Color.tooltip.border
            radius: Style.cornerRadius
            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: uiTypography.failed ? uiTypography.errorMessage : "ParsiNegar Express"
                textFormat: Text.PlainText
                font: uiTypography.tooltipFont
                color: Color.tooltip.text
            }
        }
    }

    Ui.KeyboardPanel {
        id: popup
        anchorItem: iconButton
        owner: root
        bar: root.bar
        open: root.opened && !root.filePickerActive
        popoutSwitching: root.popoutSwitching
        popoutSwitchClosing: root.popoutSwitchClosing
        contentWidth: fittedContentWidth(Style.space(500))
        contentHeight: fittedContentHeight(menuLoader.item ? menuLoader.item.implicitHeight : Style.space(360))
        focusTarget: menuLoader.item ? menuLoader.item.editorItem : null

        // Installed plugins only see their own registered click targets. Keep
        // the physical bar outside this popup's input region so the real bar
        // receives clicks and performs its normal one-click panel handoff.
        mask: Region {
            x: popup.barPos === "left" ? popup.barW : 0
            y: popup.barPos === "top" ? popup.barH : 0
            width: Math.max(0, popup.screenW
                - ((popup.barPos === "left" || popup.barPos === "right") ? popup.barW : 0))
            height: Math.max(0, popup.screenH
                - ((popup.barPos === "top" || popup.barPos === "bottom") ? popup.barH : 0))
        }

        Loader {
            id: menuLoader
            anchors.fill: parent
            active: root.opened || root.filePickerActive
            visible: active
            enabled: active
            source: "MenuContent.qml"
            onLoaded: {
                item.host = root
                item.typography = uiTypography
                item.closeRequested.connect(root.close)
                item.initialize()
                Qt.callLater(function() {
                    if (root.opened && !root.filePickerActive && menuLoader.item)
                        menuLoader.item.focusEditor()
                })
            }
        }
    }
}
