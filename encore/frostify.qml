import QtQuick

// encore: MONITOR MIX — the player is the diva's wedge mix. A five-lane
// piano-roll band runs under the panes with tonight's part printed on it,
// and while the music actually plays (and the window is looked at) the
// PLAYHEAD loops the band in time, its follow-spot head riding the seam.
// A track change is a song change: blackout on the band, then it's re-lit
// (law 2 — a cut and a cue, never a crossfade). Paused = house lights: the
// playhead parks, the band dims, nothing moves. Chrome + voice only.
Item {
    id: chrome

    required property var pal   // snapshot palette (teal/lacquer/magenta/…)
    property var host: null     // frostify window — active (focus), np, npTrackId

    readonly property bool awake: host ? host.active === true : false
    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true

    readonly property color teal: pal.neon
    readonly property color crowd: pal.magenta
    readonly property color spot: pal.amber
    function tealA(a) { return Qt.rgba(teal.r, teal.g, teal.b, a) }
    function crowdA(a) { return Qt.rgba(crowd.r, crowd.g, crowd.b, a) }

    // deterministic hash (its own seed — the wedge sings its own part)
    function rnd(n) {
        let x = Math.imul((n + 313) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    readonly property color cardBorder: Qt.alpha(teal, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 12

    // the wedge's voice
    readonly property string statusPlaying: "▶ SHE'S ON"
    readonly property string statusPaused: "▮▮ BETWEEN SONGS"
    readonly property string statusStopped: "■ HOUSE LIGHTS"
    readonly property string wordmark: "♫ MONITOR MIX"
    readonly property string glyphPrev: "◀◀"
    readonly property string glyphPlay: "▶"
    readonly property string glyphPause: "▮▮"
    readonly property string glyphNext: "▶▶"
    readonly property string glyphNowPlaying: "♪"
    readonly property string glyphLiked: "♥"
    readonly property string glyphPinned: "◆"
    readonly property string glyphRecent: "↺"
    readonly property string glyphDesktop: "⌂"
    readonly property string glyphPlaylist: "♬"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property int band: 76
            readonly property int lanes: 5
            readonly property real laneH: band / (lanes + 1)

            // the song change: hard blackout gate over the band
            property bool lit: true
            SequentialAnimation {
                id: relight
                PropertyAction { target: bd; property: "lit"; value: false }
                PauseAnimation { duration: 120 }
                PropertyAction { target: bd; property: "lit"; value: true }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNpTrackIdChanged() { if (chrome.awake) relight.restart() }
            }

            // ── the roll band ──────────────────────────────────────────────
            Item {
                id: rollBand
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: bd.band
                opacity: bd.lit ? (chrome.playing ? 0.9 : 0.4) : 0   // cut, not fade
                visible: opacity > 0

                Canvas {
                    id: roll
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const W = width, H = height, lh = bd.laneH
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.dim, 0.30))
                        for (let l = 1; l <= bd.lanes; l++) ctx.fillRect(0, l * lh, W, 1)
                        for (let x = 56, i = 1; x < W; x += 56, i++) {
                            ctx.fillStyle = String(Qt.alpha(chrome.pal.dim, i % 4 === 0 ? 0.35 : 0.15))
                            ctx.fillRect(x, lh * 0.5, 1, H - lh)
                        }
                        let lane = 2, xx = 16
                        for (let i = 0; xx < W - 50; i++) {
                            const wN = 16 + Math.floor(chrome.rnd(i * 31 + 7) * 34)
                            const step = Math.floor(chrome.rnd(i * 131 + 3) * 5) - 2
                            lane = Math.max(0, Math.min(bd.lanes - 1, lane + (step === 0 ? 1 : step)))
                            const y = (lane + 1) * lh
                            const ghost = chrome.rnd(i * 977 + 11) < 0.15
                            ctx.fillStyle = String(ghost ? chrome.crowdA(0.55) : chrome.tealA(0.5))
                            ctx.beginPath()
                            ctx.roundedRect(xx, y - 3, wN, 6, 3, 3)
                            ctx.fill()
                            xx += wN + 8 + Math.floor(chrome.rnd(i * 57 + 29) * 22)
                        }
                    }
                }

                // the playhead loops the band while the song runs
                Item {
                    id: playhead
                    property real t: 0
                    x: rollBand.width * t
                    height: parent.height
                    visible: chrome.playing && chrome.awake
                    Rectangle {
                        x: -1; width: 2; height: parent.height
                        color: chrome.spot
                        opacity: 0.85
                    }
                    Rectangle {
                        x: -6; y: -2
                        width: 12; height: 12; radius: 6
                        color: Qt.alpha(chrome.spot, 0.3)
                    }
                    NumberAnimation on t {
                        from: 0; to: 1
                        duration: 8000
                        loops: Animation.Infinite
                        running: chrome.playing && chrome.awake && bd.visible
                    }
                }
            }

            // the wedge's cue lamp, above the band far right — on the count
            Rectangle {
                id: lamp
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: bd.band + 10
                width: 7; height: 7; radius: 3.5
                property bool tick: true
                color: tick ? chrome.teal : Qt.alpha(chrome.pal.dim, 0.8)
                opacity: chrome.playing ? 1 : 0.35
                Timer {
                    interval: 500; repeat: true
                    running: chrome.playing && chrome.awake && bd.visible
                    onTriggered: lamp.tick = !lamp.tick
                }
                onVisibleChanged: if (!visible) tick = true
            }
        }
    }
}
