import QtQuick

// encore: THE MAIN VU — the system monitor is the desk's master meter
// bridge. Along the foot of the window runs a wide LED ladder: the house
// meter, lit lamp by whole lamp with the machine's own load (law 1 — a
// meter steps, it never glides), teal through the follow-spot warm caps
// into the crowd's magenta clip lamps (law 4). A re-sort is a light cue —
// the playhead sweeps the meter once. A kill is the heavy cue: the whole
// window takes a two-frame magenta blackout, the desk's cut-the-feed
// button. Loops gate on focus; an unwatched meter holds still.
Item {
    id: chrome

    required property var pal   // snapshot palette (teal/lacquer/magenta/…)
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0
    readonly property real memLoad: host && host.memLoad !== undefined ? host.memLoad : 0

    readonly property color teal: pal.neon
    readonly property color crowd: pal.magenta
    readonly property color spot: pal.amber
    function tealA(a) { return Qt.rgba(teal.r, teal.g, teal.b, a) }

    readonly property color cardBorder: Qt.alpha(teal, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 12

    readonly property string wordmark: "◍ MAIN VU"

    // ── backdrop: the meter bridge ──────────────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property int lamps: 28
            readonly property int litCpu: Math.round(chrome.load * lamps)
            readonly property int litMem: Math.round(chrome.memLoad * lamps)

            // CPU: the big house ladder along the foot
            Row {
                id: cpuRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 10
                spacing: 4
                Repeater {
                    model: bd.lamps
                    Rectangle {
                        required property int index
                        readonly property bool lit: index < bd.litCpu
                        readonly property color lampCol: index >= bd.lamps - 3 ? chrome.crowd
                                                       : index >= bd.lamps - 8 ? chrome.spot
                                                       : chrome.teal
                        width: (cpuRow.width - (bd.lamps - 1) * 4) / bd.lamps
                        height: 6
                        radius: 3
                        anchors.bottom: parent.bottom
                        color: lit ? Qt.alpha(lampCol, 0.85) : Qt.alpha(chrome.pal.dim, 0.30)
                        // no Behavior — lamps cut on and off
                    }
                }
            }
            // MEM: a slimmer ladder above it
            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: cpuRow.top
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 4
                spacing: 4
                Repeater {
                    model: bd.lamps
                    Rectangle {
                        required property int index
                        width: (cpuRow.width - (bd.lamps - 1) * 4) / bd.lamps
                        height: 3
                        radius: 1.5
                        color: index < bd.litMem ? Qt.alpha(chrome.pal.cyan, 0.6)
                                                 : Qt.alpha(chrome.pal.dim, 0.22)
                    }
                }
            }
            // meter labels, tiny, in the desk's dialect
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.bottom: cpuRow.top
                anchors.bottomMargin: 12
                text: "HOUSE " + Math.round(chrome.load * 100) + "%"
                color: Qt.alpha(chrome.pal.text, 0.4)
                font.family: chrome.pal.fontMono
                font.pixelSize: 8
                font.letterSpacing: 2
            }

            // ── re-sort: the playhead takes one pass over the bridge ──
            Item {
                id: playhead
                property real t: -1
                visible: t >= 0
                x: bd.width * Math.max(0, t)
                anchors.bottom: parent.bottom
                height: 30
                Rectangle {
                    x: -1; width: 2; height: parent.height
                    color: chrome.spot
                    opacity: 0.8
                }
                NumberAnimation {
                    id: sortSweep
                    target: playhead; property: "t"
                    from: 0; to: 1; duration: 450; easing.type: Easing.Linear
                    onStopped: playhead.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) sortSweep.restart() }
            }
        }
    }

    // ── the kill cue: a hard magenta blackout, two frames, gone ─────────────
    readonly property Component overlay: Component {
        Item {
            id: ov
            Rectangle {
                id: cut
                anchors.fill: parent
                color: chrome.crowd
                opacity: 0
                visible: opacity > 0
            }
            SequentialAnimation {
                id: killCue
                PropertyAction { target: cut; property: "opacity"; value: 0.28 }
                PauseAnimation { duration: 70 }
                PropertyAction { target: cut; property: "opacity"; value: 0 }
                PauseAnimation { duration: 70 }
                PropertyAction { target: cut; property: "opacity"; value: 0.14 }
                PauseAnimation { duration: 60 }
                PropertyAction { target: cut; property: "opacity"; value: 0 }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onKillPulseChanged() { if (chrome.awake) killCue.restart() }
            }
        }
    }
}
