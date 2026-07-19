import QtQuick

// sleeper: observation-car chrome for beryl. The browser is the big window at
// the end of the train — the page IS the view, so the theme lives in the
// chrome bands: a perforated ticket-edge under the tab strip, the wooden sill
// under the status bar, lamplight resting in the top corners, and on every
// committed navigation a lamp passes along the tab band (the passing-glow
// law — a new stretch of city arriving). The page covers the middle; nothing
// is painted for it. Same grammar as mica.qml: invisible root, pal/host.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    function teaA(a)   { return Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, a) }
    function greenA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function linenA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function woodA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    // chassis: paper corners, warm edge
    readonly property color cardBorder: Qt.alpha(pal.amber, 0.4)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    readonly property string wordmark: "☾ observation car"

    // ── backdrop: the chrome bands ──────────────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // lamplight in the top corners of the car
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                width: parent.width * 0.25
                height: 60
                opacity: 0.5
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.teaA(0.08) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                width: parent.width * 0.25
                height: 60
                opacity: 0.5
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.teaA(0.08) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }

            // the ticket-edge: perforation dashes under the tab strip
            Row {
                anchors.top: parent.top
                anchors.topMargin: 38
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 7
                Repeater {
                    model: Math.max(6, Math.floor((bd.width - 24) / 12))
                    Rectangle { width: 5; height: 1; color: chrome.linenA(0.25) }
                }
            }

            // the wooden sill above the status bar
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 24
                width: parent.width
                height: 1
                color: chrome.teaA(0.3)
            }
            // city green along the very foot
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 24
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.greenA(0.06) }
                }
            }
        }
    }

    // ── overlay: the lamp along the tab band on navigation ──────────────────
    readonly property Component overlay: Component {
        Item {
            id: ovl
            clip: true
            Rectangle {
                id: passing
                property real t: -1
                visible: t >= 0
                // rides the top chrome band only — the page keeps its peace
                width: ovl.width * 0.3
                height: 44
                y: 0
                x: -width + (ovl.width + width * 2) * Math.max(0, t)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: chrome.teaA(0.0) }
                    GradientStop { position: 0.5; color: chrome.teaA(0.10) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
            SequentialAnimation {
                id: sweep
                NumberAnimation { target: passing; property: "t"; from: 0; to: 1; duration: 850; easing.type: Easing.InOutSine }
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
