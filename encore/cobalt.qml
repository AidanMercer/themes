import QtQuick

// encore: BACKSTAGE CALL — the Teams client is the tannoy to the outside
// world, and it stays QUIET: Aidan takes calls in here. The rig leans in
// only at the edges — a single foot lane with a few resting notes and the
// teal edge-strip, surfacing through cobalt's stripped transparent regions —
// and every SPA navigation (chat, calendar, activity) cues one note block
// down the lane. No loops at all: the only motion is the one-shot cue.
Item {
    id: chrome

    required property var pal   // snapshot palette (teal/lacquer/magenta/…)
    property var host: null     // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property color teal: pal.neon
    readonly property color crowd: pal.magenta
    readonly property color spot: pal.amber
    function tealA(a) { return Qt.rgba(teal.r, teal.g, teal.b, a) }

    // deterministic hash (its own seed)
    function rnd(n) {
        let x = Math.imul((n + 733) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    readonly property string wordmark: "♪ BACKSTAGE CALL"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the foot lane: one rule, beat ticks, a sparse resting phrase
            Canvas {
                id: lane
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 26
                opacity: 0.7
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const W = width, H = height, y = H * 0.5
                    ctx.fillStyle = String(Qt.alpha(chrome.pal.dim, 0.30))
                    ctx.fillRect(0, y, W, 1)
                    for (let x = 56, i = 1; x < W; x += 56, i++) {
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.dim, i % 4 === 0 ? 0.26 : 0.11))
                        ctx.fillRect(x, y - 4, 1, 8)
                    }
                    let xx = 24
                    for (let i = 0; xx < W - 60; i++) {
                        const wN = 12 + Math.floor(chrome.rnd(i * 31 + 7) * 20)
                        const ghost = chrome.rnd(i * 977 + 11) < 0.12
                        ctx.fillStyle = String(ghost ? Qt.alpha(chrome.pal.magenta, 0.28)
                                                     : chrome.tealA(0.22))
                        ctx.beginPath()
                        ctx.roundedRect(xx, y - 2.5, wN, 5, 2.5, 2.5)
                        ctx.fill()
                        xx += wN + 26 + Math.floor(chrome.rnd(i * 57 + 29) * 44)
                    }
                }
            }
            // the teal edge-strip foot
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 44
                height: 2
                radius: 1
                color: chrome.tealA(0.35)
            }
        }
    }

    // ── every rail navigation: one note takes the lane ──────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov
            Item {
                id: note
                property real t: -1
                visible: t >= 0
                y: ov.height - 17
                x: (ov.width + 50) * Math.max(0, t) - 25
                Rectangle {
                    width: 20; height: 6; radius: 3
                    color: chrome.teal
                    opacity: 0.85
                }
                NumberAnimation {
                    id: run
                    target: note; property: "t"
                    from: 0; to: 1; duration: 600; easing.type: Easing.Linear
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
