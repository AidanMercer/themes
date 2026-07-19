import QtQuick

// sleeper: quiet-berth chrome for cobalt. The Teams client is the one place
// the outside world reaches the compartment, so it gets the theme at its most
// restrained: lamplight resting along the titlebar, the city's green settled
// at the floor where the stripped regions let it through, a thin wooden sill
// over the status line — and on every rail navigation one soft lamp passes
// under the glass. Nothing loops while a call is on; this is where Aidan
// takes calls. Same grammar as beryl.qml minus the frame overrides.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    function teaA(a)   { return Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, a) }
    function greenA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function linenA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }

    readonly property string wordmark: "☾ car 7"

    // ── backdrop: under the glass bars and the page ─────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // lamplight along the titlebar
            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 46
                opacity: 0.5
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.teaA(0.07) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
            // the city's green at the floor
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * 0.22
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.greenA(0.05) }
                }
            }
            // the sill over the status line
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 22
                width: parent.width
                height: 1
                color: chrome.teaA(0.25)
            }
            // a lamp passing under the glass on each rail navigation
            Rectangle {
                id: passing
                property real t: -1
                visible: t >= 0
                width: bd.width * 0.3
                height: bd.height * 1.5
                y: -bd.height * 0.25
                rotation: 12
                x: -width + (bd.width + width * 2) * Math.max(0, t)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: chrome.teaA(0.0) }
                    GradientStop { position: 0.5; color: chrome.teaA(0.06) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
            SequentialAnimation {
                id: sweep
                NumberAnimation { target: passing; property: "t"; from: 0; to: 1; duration: 950; easing.type: Easing.InOutSine }
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
