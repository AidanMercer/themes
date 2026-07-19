import QtQuick

// encore: FRONT OF HOUSE — the browser is the runner between the stage and
// the house. The page owns the middle of the window (an opaque scrim sits
// behind every view), so the rig lives in the chrome bands: the seam under
// the tab strip is one piano-roll lane with its beat ticks, a cue lamp
// holds the top-right corner of the strip on the count, and a small stand
// of resting glowsticks leans behind the status bar corner. Every committed
// navigation is a cue: one note block runs the seam lane and is gone.
// Chrome + voice only; gate everything on focus.
Item {
    id: chrome

    required property var pal   // snapshot palette (teal/lacquer/magenta/…)
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color teal: pal.neon
    readonly property color crowd: pal.magenta
    readonly property color spot: pal.amber
    function tealA(a) { return Qt.rgba(teal.r, teal.g, teal.b, a) }

    readonly property color cardBorder: Qt.alpha(teal, 0.3)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 12

    readonly property string wordmark: "♪ FRONT OF HOUSE"

    // the seam between the tab strip and the page
    readonly property int seamY: 42

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the seam lane: one rule + beat ticks, under the tabs
            Rectangle {
                y: chrome.seamY
                x: 12
                width: bd.width - 24
                height: 1
                color: Qt.alpha(chrome.pal.dim, 0.4)
            }
            Row {
                y: chrome.seamY - 3
                x: 12
                spacing: 55
                Repeater {
                    model: Math.max(0, Math.ceil((bd.width - 24) / 56))
                    Rectangle {
                        required property int index
                        width: 1; height: 7
                        color: Qt.alpha(chrome.pal.dim, (index + 1) % 4 === 0 ? 0.4 : 0.18)
                    }
                }
            }

            // the cue lamp in the tab-strip sky, far right — on the count
            Rectangle {
                id: lamp
                x: bd.width - 24
                y: 12
                width: 6; height: 6; radius: 3
                property bool tick: true
                color: tick ? chrome.teal : Qt.alpha(chrome.pal.dim, 0.8)
                Timer {
                    interval: 500; repeat: true
                    running: chrome.awake && bd.visible
                    onTriggered: lamp.tick = !lamp.tick
                }
                onVisibleChanged: if (!visible) tick = true
            }

            // resting glowsticks behind the status bar corner, bottom-right —
            // printed, still, waiting for the next song
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                spacing: 5
                Repeater {
                    model: 7
                    Rectangle {
                        required property int index
                        readonly property bool magenta: index === 2 || index === 5
                        width: 3
                        height: 14 + ((index * 11) % 3) * 4
                        radius: 1.5
                        rotation: (((index * 37) % 23) / 23 - 0.5) * 34
                        anchors.bottom: parent.bottom
                        color: magenta ? Qt.alpha(chrome.pal.magenta, 0.4)
                                       : chrome.tealA(0.4)
                    }
                }
            }
        }
    }

    // ── every navigation: one note runs the seam ────────────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov
            Item {
                id: note
                property real t: -1
                visible: t >= 0
                y: chrome.seamY - 4
                x: (ov.width + 60) * Math.max(0, t) - 30
                Rectangle {
                    width: 22; height: 7; radius: 3.5
                    color: chrome.teal
                }
                Rectangle {
                    x: 24; y: 1
                    width: 10; height: 5; radius: 2.5
                    color: chrome.tealA(0.4)
                }
                NumberAnimation {
                    id: run
                    target: note; property: "t"
                    from: 0; to: 1; duration: 650; easing.type: Easing.Linear
                    onStopped: note.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) run.restart() }
            }
        }
    }
}
