import QtQuick

// encore: ROADCASES — the file manager is the band's case room backstage.
// Along the foot of the window runs a three-lane strip of piano roll with
// tonight's part printed on it (deterministic — the same melody every
// mount), a cue lamp ticking the count while you're in the room, and a TAKE
// counter. Every directory change is a TAKE: the playhead sweeps the roll
// once, lighting the notes as it crosses, and the counter steps. Everything
// holds still the moment you look away (idle-cheap: loops gate on focus).
// Chrome + voice only; the miller columns stay mica's own.
Item {
    id: chrome

    required property var pal   // snapshot palette (teal/lacquer/magenta/…)
    property var host: null     // mica window — active (focus), navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color teal: pal.neon
    readonly property color crowd: pal.magenta
    readonly property color spot: pal.amber
    function tealA(a) { return Qt.rgba(teal.r, teal.g, teal.b, a) }
    function crowdA(a) { return Qt.rgba(crowd.r, crowd.g, crowd.b, a) }

    // deterministic hash — the same printed part on every mount
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: capsule hardware with the teal lip
    readonly property color cardBorder: Qt.alpha(teal, 0.3)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 12

    readonly property string wordmark: "♬ ROADCASES"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property int band: 54       // the roll strip's height
            readonly property int lanes: 3
            readonly property real laneH: band / (lanes + 1)
            property int takes: 0                // directories opened this mount

            // ── the roll strip: lane rules + beat grid + the printed part ──
            Canvas {
                id: roll
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: bd.band
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const W = width, H = height, lh = bd.laneH
                    // lane rules
                    ctx.fillStyle = String(Qt.alpha(chrome.pal.dim, 0.30))
                    for (let l = 1; l <= bd.lanes; l++) ctx.fillRect(0, l * lh, W, 1)
                    // beat ticks every 56px, stronger each 4th
                    for (let x = 56, i = 1; x < W; x += 56, i++) {
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.dim, i % 4 === 0 ? 0.35 : 0.16))
                        ctx.fillRect(x, lh * 0.5, 1, H - lh)
                    }
                    // the printed part: capsule notes walking the lanes
                    let lane = 1, xx = 20
                    for (let i = 0; xx < W - 60; i++) {
                        const wN = 18 + Math.floor(chrome.rnd(i * 31 + 7) * 30)
                        const step = Math.floor(chrome.rnd(i * 131 + 3) * 3) - 1
                        lane = Math.max(0, Math.min(bd.lanes - 1, lane + step))
                        const y = (lane + 1) * lh - 3
                        const ghost = chrome.rnd(i * 977 + 11) < 0.14
                        const col = ghost ? chrome.crowdA(0.5) : chrome.tealA(0.4)
                        ctx.fillStyle = String(col)
                        ctx.beginPath()
                        ctx.roundedRect(xx, y - 3, wN, 6, 3, 3)
                        ctx.fill()
                        xx += wN + 10 + Math.floor(chrome.rnd(i * 57 + 29) * 26)
                    }
                }
            }

            // the cue lamp, top-right of the strip — ticking while you work
            Rectangle {
                id: lamp
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: bd.band + 8
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

            // TAKE counter beside the lamp
            Text {
                anchors.right: lamp.left
                anchors.rightMargin: 8
                anchors.verticalCenter: lamp.verticalCenter
                text: "TAKE " + String(bd.takes % 1000).padStart(3, "0")
                color: Qt.alpha(chrome.pal.text, 0.45)
                font.family: chrome.pal.fontMono
                font.pixelSize: 8
                font.letterSpacing: 2
            }

            // ── the playhead: one sweep of the roll per directory change ──
            Item {
                id: playhead
                property real t: -1
                visible: t >= 0
                x: bd.width * Math.max(0, t)
                anchors.bottom: parent.bottom
                height: bd.band
                Rectangle {
                    x: -1; width: 2; height: parent.height
                    color: chrome.spot
                    opacity: 0.8
                }
                Rectangle {
                    x: -5; y: -3
                    width: 10; height: 10; radius: 5
                    color: Qt.alpha(chrome.spot, 0.35)
                }
                NumberAnimation {
                    id: sweep
                    target: playhead; property: "t"
                    from: 0; to: 1; duration: 600; easing.type: Easing.Linear
                    onStopped: playhead.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() {
                    bd.takes++                             // the count always runs
                    if (chrome.awake) sweep.restart()      // the light only when seen
                }
            }
        }
    }
}
