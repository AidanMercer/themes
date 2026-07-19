import QtQuick

// encore: THE SCORE — the editor is the diva's music stand. The page owns
// the window; the rig only leans in from the edges: a single quiet lane of
// roll along the very foot with a few resting notes, a stand light pooling
// faintly from the top, and a metronome lamp that ticks the count while a
// page is actually up. The page turn is the event: as a page composes the
// playhead makes ONE sweep across the foot lane — the part being cued —
// then the stand is still again. Writing mode never moves: the reading gate
// (awake && page) guards every animation, so a buffer being typed into sits
// on a dead-still stand.
Item {
    id: chrome

    required property var pal   // snapshot palette (teal/lacquer/magenta/…)
    property var host: null     // vellum window — active, readingMode, pdfMode

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page   // the only thing that may animate

    readonly property color teal: pal.neon
    readonly property color crowd: pal.magenta
    readonly property color spot: pal.amber
    function tealA(a) { return Qt.rgba(teal.r, teal.g, teal.b, a) }
    function spotA(a) { return Qt.rgba(spot.r, spot.g, spot.b, a) }

    // deterministic hash (its own seed — the stand holds its own part)
    function rnd(n) {
        let x = Math.imul((n + 577) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    readonly property color cardBorder: Qt.alpha(teal, 0.26)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 10

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property int band: 30    // one quiet lane — the page rules here

            // the stand light: a faint warm pool from the top edge, on with
            // the page, off for writing (one state fade, then still)
            Canvas {
                id: standLight
                width: 340
                height: 120
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: chrome.page ? 0.5 : 0
                Behavior on opacity { NumberAnimation { duration: 400 } }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const a = width / 2
                    ctx.save()
                    ctx.scale(1, height / a)
                    const g = ctx.createRadialGradient(a, 0, 0, a, 0, a)
                    g.addColorStop(0, String(chrome.spotA(0.13)))
                    g.addColorStop(1, String(chrome.spotA(0)))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, a)
                    ctx.restore()
                }
                Component.onCompleted: requestPaint()
            }

            // ── the foot lane: one rule, beat ticks, a few resting notes ──
            Canvas {
                id: lane
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: bd.band
                opacity: 0.8
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const W = width, H = height, y = H * 0.55
                    ctx.fillStyle = String(Qt.alpha(chrome.pal.dim, 0.30))
                    ctx.fillRect(0, y, W, 1)
                    for (let x = 56, i = 1; x < W; x += 56, i++) {
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.dim, i % 4 === 0 ? 0.28 : 0.12))
                        ctx.fillRect(x, y - 5, 1, 10)
                    }
                    // a sparse resting phrase, printed
                    let xx = 30
                    for (let i = 0; xx < W - 60; i++) {
                        const wN = 14 + Math.floor(chrome.rnd(i * 31 + 7) * 22)
                        const ghost = chrome.rnd(i * 977 + 11) < 0.12
                        ctx.fillStyle = String(ghost ? Qt.alpha(chrome.pal.magenta, 0.30)
                                                     : chrome.tealA(0.25))
                        ctx.beginPath()
                        ctx.roundedRect(xx, y - 3, wN, 5, 2.5, 2.5)
                        ctx.fill()
                        xx += wN + 22 + Math.floor(chrome.rnd(i * 57 + 29) * 40)
                    }
                }
            }

            // the metronome lamp, foot right — ticks only while reading
            Rectangle {
                id: metro
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: bd.band + 6
                width: 6; height: 6; radius: 3
                property bool tick: true
                color: tick ? chrome.teal : Qt.alpha(chrome.pal.dim, 0.7)
                opacity: chrome.page ? 0.8 : 0.25
                Timer {
                    interval: 500; repeat: true
                    running: chrome.stirring && bd.visible
                    onTriggered: metro.tick = !metro.tick
                }
                onVisibleChanged: if (!visible) tick = true
            }

            // ── the page turn: one playhead sweep along the foot lane ──
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
                    opacity: 0.75
                }
                NumberAnimation {
                    id: sweep
                    target: playhead; property: "t"
                    from: 0; to: 1; duration: 550; easing.type: Easing.Linear
                    onStopped: playhead.t = -1
                }
            }
            // gate on `page`, NOT `stirring` — alt-tab must not re-cue the part
            Connections {
                target: chrome
                function onPageChanged() { if (chrome.stirring) sweep.restart() }
            }
        }
    }
}
