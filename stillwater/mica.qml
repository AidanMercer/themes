import QtQuick

// stillwater: the far shore. Below the miller columns the evening keeps
// still — a waterline runs across the foot of the window with a handful of
// distant lamps standing on it, every one doubled beneath as a broken
// streak, and a whisper of dusk-rose pooling above the line. While the
// window is looked at, two of the lamps breathe; look away and the water
// holds perfectly still. Every directory change is a crossing: one light
// glides the line from right to left, streak trailing in the water, and a
// small tally counts the crossings. Chrome + voice only; mica's layout
// stays its own.
Item {
    id: chrome

    required property var pal   // snapshot palette (lamp/twilight/rose…)
    property var host: null     // mica window — active (focus), navId (cwd)

    readonly property bool awake: host ? host.active === true : false

    readonly property color lamp: pal.neon
    readonly property color sky: pal.cyan
    readonly property color rose: pal.magenta
    function lampA(a) { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function skyA(a)  { return Qt.rgba(sky.r, sky.g, sky.b, a) }
    function roseA(a) { return Qt.rgba(rose.r, rose.g, rose.b, a) }

    // deterministic hash — the same shore on every mount; a reload must
    // never reshuffle the lights under the user
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: soft water glass, a thin twilight lip
    readonly property color cardBorder: Qt.alpha(sky, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 10

    readonly property string wordmark: "◦ the far shore"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property real wl: height - 52   // the waterline
            property int crossings: 0                // directories this mount

            // dusk pooling above the line
            Rectangle {
                x: 0; y: bd.wl - 60
                width: parent.width
                height: 60
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.roseA(0.05) }
                }
            }
            // the water below holds a little light
            Rectangle {
                x: 0; y: bd.wl
                width: parent.width
                height: parent.height - bd.wl
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.skyA(0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle { x: 0; y: bd.wl; width: parent.width; height: 1; color: chrome.skyA(0.24) }

            // ── the shore: lamps + broken streaks, one static draw ──────────
            Canvas {
                id: shore
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()   // wl rides height
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const wl = bd.wl, W = width
                    const n = Math.max(5, Math.floor(W / 110))
                    for (let i = 0; i < n; i++) {
                        const fx = 0.04 + chrome.rnd(i * 17 + 3) * 0.92
                        const lv = 0.3 + chrome.rnd(i * 29 + 7) * 0.6
                        const cx = Math.round(W * fx)
                        // the rare rose window on the shore
                        const tone = chrome.rnd(i * 41 + 11) < 0.14 ? chrome.rose : chrome.lamp
                        ctx.fillStyle = String(Qt.rgba(tone.r, tone.g, tone.b, 0.25 + 0.5 * lv))
                        ctx.fillRect(cx - 1.5, wl - 3, 3, 3)
                        // streak: broken slivers dying with depth
                        let y = wl + 4, k = 0
                        while (y < wl + 5 + lv * 22 && y < height - 3) {
                            const depth = (y - wl) / 30
                            ctx.fillStyle = String(Qt.rgba(tone.r, tone.g, tone.b, lv * 0.35 * (1 - depth)))
                            ctx.fillRect(cx - 1, y, 2, 2)
                            y += 4 + k * 2
                            k++
                        }
                    }
                }
            }

            // two lamps breathe while you're here — the shore acknowledges you
            Repeater {
                model: 2
                Rectangle {
                    id: breathLamp
                    required property int index
                    x: Math.round(bd.width * (0.2 + index * 0.45)) - 2
                    y: bd.wl - 4
                    width: 4; height: 4
                    radius: 2
                    color: chrome.lamp
                    opacity: 0.5
                    SequentialAnimation on opacity {
                        running: chrome.awake && bd.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 2600 + breathLamp.index * 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.75; duration: 2600 + breathLamp.index * 700; easing.type: Easing.InOutSine }
                    }
                }
            }

            // the tally, top-left, quiet
            Text {
                x: 14; y: 10
                text: "crossings " + String(bd.crossings % 1000).padStart(3, "0")
                font.family: chrome.pal.fontMono
                font.pixelSize: 8
                font.letterSpacing: 2
                color: chrome.skyA(0.45)
            }

            // ── a crossing: one light glides the line, streak trailing ──────
            Item {
                id: ferry
                property real t: -1
                visible: t >= 0
                y: bd.wl
                x: bd.width * (1 - Math.max(0, t)) - 10
                Rectangle { x: -2; y: -3; width: 4; height: 4; radius: 2; color: chrome.lamp }
                Rectangle { x: 4; y: -1; width: 14; height: 1; color: chrome.lampA(0.25) }
                Rectangle { x: -1; y: 3; width: 2; height: 2; color: chrome.lampA(0.35) }
                Rectangle { x: 0; y: 7; width: 2; height: 2; color: chrome.lampA(0.18) }
                NumberAnimation {
                    id: ferryAnim
                    target: ferry; property: "t"
                    from: 0; to: 1; duration: 1400; easing.type: Easing.InOutSine
                    onStopped: ferry.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() {
                    bd.crossings++                          // the tally always counts
                    if (chrome.awake) ferryAnim.restart()   // the light shows when seen
                }
            }
        }
    }
}
