import QtQuick

// sleeper: luggage-rack chrome for mica. The file manager is the rack over
// the bunk: two leather straps hang down the left margin holding everything
// in place, the brass rail runs along the top, and every directory change is
// a lamp passing across the shelves — the passing-glow law, mica's analog of
// the compartment's other flourishes. Same grammar as popup.qml: invisible
// root, mica mounts backdrop below and overlay above the miller columns.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // mica window — active (focus), navId (cwd)

    readonly property bool awake: host ? host.active === true : false

    function teaA(a)   { return Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, a) }
    function greenA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function linenA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function woodA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    // chassis: paper corners, warm edge
    readonly property color cardBorder: Qt.alpha(pal.amber, 0.4)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    readonly property string wordmark: "◆ the luggage rack"

    // ── backdrop: rail, straps, lamplight ───────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the brass rail along the top
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                height: 1
                color: chrome.teaA(0.4)
            }
            // two leather straps down the left margin, with buckles
            Repeater {
                model: 2
                Item {
                    required property int index
                    x: 12 + index * 16
                    y: 4
                    width: 5
                    height: bd.height * (0.32 - index * 0.06)
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(chrome.pal.dim.r * 1.3, chrome.pal.dim.g * 1.1,
                                       chrome.pal.dim.b * 0.9, 0.4)
                    }
                    Rectangle {   // the buckle
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - 10
                        width: 9; height: 7
                        color: "transparent"
                        border.width: 1
                        border.color: chrome.teaA(0.55)
                    }
                }
            }
            // lamplight pooling in the top-right corner
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                width: parent.width * 0.35
                height: parent.height * 0.25
                opacity: 0.6
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.teaA(0.08) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
            // city green resting at the foot
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * 0.2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.greenA(0.05) }
                }
            }
        }
    }

    // ── overlay: a lamp passes the rack on every directory change ───────────
    readonly property Component overlay: Component {
        Item {
            id: ovl
            clip: true
            Rectangle {
                id: passing
                property real t: -1
                visible: t >= 0
                width: ovl.width * 0.32
                height: ovl.height * 1.6
                y: -ovl.height * 0.3
                x: -width + (ovl.width + width * 2) * Math.max(0, t)
                rotation: 12
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: chrome.teaA(0.0) }
                    GradientStop { position: 0.5; color: chrome.teaA(0.09) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
            SequentialAnimation {
                id: sweep
                NumberAnimation { target: passing; property: "t"; from: 0; to: 1; duration: 900; easing.type: Easing.InOutSine }
                PropertyAction { target: passing; property: "t"; value: -1 }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) sweep.restart() }
            }
        }
    }
}
