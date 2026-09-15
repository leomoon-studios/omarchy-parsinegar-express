import QtQuick

// Instantiated once in Panel.qml and shared with the lazy menu.
// Shell theme values are injected by the owner, without importing shell services.
QtObject {
    id: root

    property url fontSource: Qt.resolvedUrl("assets/fonts/Vazirmatn[wght].ttf")
    property url iconFontSource: Qt.resolvedUrl("assets/fonts/MaterialSymbolsRounded.ttf")
    property real basePixelSize: 12
    property color foreground: "#cacccc"
    property color muted: "#707880"
    property color errorColor: "#a55555"

    readonly property bool ready: bundledFont.status === FontLoader.Ready
    readonly property bool failed: bundledFont.status === FontLoader.Error
    readonly property string family: ready ? bundledFont.name : ""
    readonly property bool iconReady: bundledIconFont.status === FontLoader.Ready
    readonly property bool iconFailed: bundledIconFont.status === FontLoader.Error
    readonly property string iconFamily: iconReady ? bundledIconFont.name : family
    readonly property string iconSettings: "\ue8b8"
    readonly property string iconExport: "\ue2c4"
    readonly property string iconTools: "\uf10b"
    readonly property string iconBack: "\ue5c4"
    readonly property string iconForward: "\ue5c8"
    readonly property string iconUndo: "\ue166"
    readonly property string iconRedo: "\ue15a"
    readonly property string iconHelp: "\ue8fd"
    readonly property string errorMessage: failed ? "Unable to load the bundled Vazirmatn font." : ""
    signal loadFailed(string message)

    readonly property FontLoader fontLoader: FontLoader {
        id: bundledFont
        source: root.fontSource
        onStatusChanged: {
            if (status === FontLoader.Error) {
                // Status-dependent bindings may not have reevaluated yet.
                var message = "Unable to load the bundled Vazirmatn font.";
                console.error("ParsiNegar Express: " + message);
                root.loadFailed(message);
            }
        }
    }

    readonly property FontLoader iconFontLoader: FontLoader {
        id: bundledIconFont
        source: root.iconFontSource
    }

    function sizedFont(ratio, weight) {
        return Qt.font({family: root.family, pixelSize: Math.max(1, Math.round(root.basePixelSize * ratio)), weight: weight});
    }

    readonly property font titleFont: sizedFont(1.333, Font.DemiBold)
    readonly property font bodyFont: sizedFont(1, Font.Normal)
    readonly property font controlFont: sizedFont(1, Font.Normal)
    readonly property font editorFont: sizedFont(1.167, Font.Normal)
    readonly property font placeholderFont: editorFont
    readonly property font tooltipFont: sizedFont(0.917, Font.Normal)
    readonly property font statusFont: bodyFont
    readonly property font badgeFont: sizedFont(0.917, Font.Bold)
}
