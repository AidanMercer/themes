import QtQuick

// sailing: dusk at sea behind the miller columns — a lavender horizon low in
// the frame and one long swell rolling through it while the window is awake;
// the water goes still when you look away.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.dim, 0.55)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "⚓ adrift"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the whole sea in one pass: horizon blush, rolling wave contours,
            // deep water at the hull — becalmed to a static draw when you look away
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("sea.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake && bd.visible
                }
            }
        }
    }
}
