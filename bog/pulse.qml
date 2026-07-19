import QtQuick

// bog: the deep pool. The system monitor is where the pond is deepest — a
// band of water stands along the bottom of the window and the machine's
// load IS the water level: an idle machine keeps a low, calm pool; a hot
// one swells it high and stains the surface from sunlit amber toward rust.
// The silt (memory) settles beneath as a second, darker layer. The surface
// shimmers only while the window is looked at. Re-sorting the table drops a
// pebble (one ring); actually killing a process is a heavy stone — a wide
// rust ring and a jolt through the surface. No input handlers; chrome only.
Item {
    id: chrome

    required property var pal   // snapshot palette (sun/moss/rust…)
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0
    readonly property real silt: host && host.memLoad !== undefined ? host.memLoad : 0

    readonly property color sun: pal.neon
    readonly property color moss: pal.cyan
    readonly property color rust: pal.magenta
    readonly property color warm: pal.amber
    readonly property color reed: pal.dim
    function sunA(a)  { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function mossA(a) { return Qt.rgba(moss.r, moss.g, moss.b, a) }
    function reedA(a) { return Qt.rgba(reed.r, reed.g, reed.b, a) }
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1)
    }
    // the surface tone climbs with the load: sun → warm → rust
    readonly property color surfaceTone: load < 0.5 ? mix(sun, warm, load * 2)
                                                    : mix(warm, rust, (load - 0.5) * 2)

    // chassis: pebble-smooth glass with a moss lip
    readonly property color cardBorder: Qt.alpha(moss, 0.35)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14

    readonly property string wordmark: "≈ the deep pool"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // water level: 18px calm, up to ~90px at full boil
            // host.load is already smoothed by pulse, so the level glides
            readonly property real depth: 18 + chrome.load * 72
            readonly property real waterY: height - depth
            property real shimmer: 0

            NumberAnimation on shimmer {
                from: 0; to: 2 * Math.PI
                duration: 6000
                loops: Animation.Infinite
                running: chrome.awake && bd.visible
            }

            // the pool
            Rectangle {
                x: 1
                y: bd.waterY
                width: parent.width - 2
                height: bd.depth - 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.mossA(0.14) }
                    GradientStop { position: 1.0; color: chrome.mossA(0.02) }
                }
            }
            // the silt layer resting on the bottom
            Rectangle {
                x: 1
                y: parent.height - 1 - Math.max(3, (bd.depth - 6) * chrome.silt)
                width: parent.width - 2
                height: Math.max(3, (bd.depth - 6) * chrome.silt)
                color: chrome.reedA(0.30)
            }

            // the surface line, stained by the load, shimmering faintly
            Rectangle {
                x: 6
                y: bd.waterY
                width: parent.width - 12
                height: 1.6
                radius: 1
                color: Qt.rgba(chrome.surfaceTone.r, chrome.surfaceTone.g, chrome.surfaceTone.b,
                               0.55 + 0.1 * Math.sin(bd.shimmer))
                Behavior on color { ColorAnimation { duration: 800 } }
            }
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    x: 22 + index * ((bd.width - 56) / 5)
                    y: bd.waterY - 1 + Math.sin(bd.shimmer + index * 1.7) * 1.2
                    width: index % 2 === 0 ? 16 : 8
                    height: 2
                    radius: 1
                    color: Qt.rgba(chrome.surfaceTone.r, chrome.surfaceTone.g, chrome.surfaceTone.b, 0.28)
                }
            }

            // ── the pond answers the table ──────────────────────────────────
            // a re-sort drops a pebble…
            Canvas {
                id: sortRing
                property real t: -1
                visible: t >= 0
                x: bd.width * 0.32 - 45
                y: bd.waterY - 12
                width: 90; height: 26
                onTChanged: requestPaint()
                NumberAnimation {
                    id: sortAnim
                    target: sortRing; property: "t"
                    from: 0; to: 1; duration: 1600; easing.type: Easing.OutSine
                    onStopped: sortRing.t = -1
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (t < 0) return
                    for (let k = 0; k < 2; k++) {
                        const tt = (t - k * 0.2) / (1 - k * 0.2)
                        if (tt <= 0 || tt >= 1) continue
                        const r = (width / 2) * (0.1 + 0.9 * tt)
                        ctx.save()
                        ctx.translate(width / 2, height / 2)
                        ctx.scale(1, 0.3)
                        ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                        ctx.restore()
                        ctx.strokeStyle = String(chrome.sunA(0.32 * (1 - tt)))
                        ctx.lineWidth = 1.4
                        ctx.stroke()
                    }
                }
            }
            // …a kill is a heavy stone
            Canvas {
                id: killRing
                property real t: -1
                visible: t >= 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: bd.waterY - 22
                width: Math.min(340, bd.width * 0.6)
                height: 48
                onTChanged: requestPaint()
                NumberAnimation {
                    id: killAnim
                    target: killRing; property: "t"
                    from: 0; to: 1; duration: 2300; easing.type: Easing.OutSine
                    onStopped: killRing.t = -1
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (t < 0) return
                    for (let k = 0; k < 4; k++) {
                        const tt = (t - k * 0.13) / (1 - k * 0.13)
                        if (tt <= 0 || tt >= 1) continue
                        const r = (width / 2) * (0.06 + 0.94 * tt)
                        ctx.save()
                        ctx.translate(width / 2, height / 2)
                        ctx.scale(1, 0.26)
                        ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                        ctx.restore()
                        ctx.strokeStyle = String(Qt.rgba(chrome.rust.r, chrome.rust.g, chrome.rust.b, 0.45 * (1 - tt)))
                        ctx.lineWidth = Math.max(0.8, 2.4 * (1 - tt))
                        ctx.stroke()
                    }
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) sortAnim.restart() }
                function onKillPulseChanged() { if (chrome.awake) killAnim.restart() }
            }
        }
    }
}
