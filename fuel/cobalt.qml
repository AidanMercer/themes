import QtQuick

// fuel: the station after midnight, kept quiet for the shift. cobalt is where
// the calls happen, so the forecourt behaves itself — the canopy stripe holds
// a steady burn under the status line, a faint icy haze barely breathes, and
// there's no flicker, no mist, nothing to catch the eye mid-meeting. a rail
// hop still re-strikes the tube: one soft cold stutter, then steady again.
Item {
    id: chrome

    required property var pal
    property var host: null   // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property string wordmark: "⛽ ON SHIFT"

    readonly property Component backdrop: Component {
        Item {
            // faint icy haze — one long slow breath, the only resident motion
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 90
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.06) }
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: chrome.awake
                    NumberAnimation { to: 0.75; duration: 6800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 6800; easing.type: Easing.InOutSine }
                }
            }

            // the stripe + its bloom — dimmed to a working glow, and it does
            // NOT flicker here: the tube holds steady while you're on a call
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 22
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.14) }
                }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors.bottomMargin: 2; anchors.leftMargin: 10; anchors.rightMargin: 10
                height: 2
                radius: 1
                color: Qt.alpha(chrome.pal.neon, 0.55)
            }

            // soft re-strike — switching rails (chat, calendar, activity) arcs
            // the tube once, quieter than anywhere else on the lot
            Item {
                id: strike
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 10
                opacity: 0
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    height: 10
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.20) }
                    }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    anchors.bottomMargin: 2; anchors.leftMargin: 10; anchors.rightMargin: 10
                    height: 2
                    radius: 1
                    color: Qt.alpha(chrome.pal.cyan, 0.70)
                }
            }
            SequentialAnimation {
                id: restrike
                PropertyAction { target: strike; property: "opacity"; value: 0.7 }
                PauseAnimation { duration: 50 }
                PropertyAction { target: strike; property: "opacity"; value: 0 }
                PauseAnimation { duration: 90 }
                PropertyAction { target: strike; property: "opacity"; value: 0.55 }
                NumberAnimation { target: strike; property: "opacity"; to: 0; duration: 300; easing.type: Easing.OutQuad }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) restrike.restart() }
            }
        }
    }
}
