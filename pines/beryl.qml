import QtQuick

// pines: beryl is the FAR SIGNALS desk — the glass the lookout reads the
// outside world through. The page owns the middle of the window, so the
// chrome lives in the bands: a ticked bearing rule inked along the seam
// under the tab strip, the benchmark at its head, lamp-warm ticks by the
// status bar. Every committed navigation is a new sighting: one breath of
// condensation blooms over the page and clears (transient overlay — nothing
// resident ever crawls over text). Fullscreen melts it all away.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.cyan, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    readonly property string wordmark: "▵ FAR SIGNALS"

    readonly property Component backdrop: Component {
        Canvas {
            id: chassis
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height, inset = 8
                // benchmark at the head of the tab strip
                ctx.strokeStyle = chrome.pal.cyan
                ctx.globalAlpha = 0.6
                ctx.lineWidth = 1.2
                ctx.beginPath()
                ctx.moveTo(inset + 5, inset)
                ctx.lineTo(inset + 10, inset + 8)
                ctx.lineTo(inset, inset + 8)
                ctx.closePath()
                ctx.stroke()
                // the bearing rule along the seam — the whole band, ticked
                ctx.globalAlpha = 0.30
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(inset + 18, inset + 4); ctx.lineTo(w - inset - 18, inset + 4)
                ctx.stroke()
                const runW = w - 2 * inset - 36
                for (let i = 1; i <= 24; i++) {
                    const x = inset + 18 + runW * i / 25
                    ctx.beginPath()
                    ctx.moveTo(x, inset + (i % 6 === 0 ? 0.5 : 2)); ctx.lineTo(x, inset + 4)
                    ctx.globalAlpha = i % 6 === 0 ? 0.32 : 0.18
                    ctx.stroke()
                }
                // lamp ticks by the status bar, bottom-right
                ctx.strokeStyle = chrome.pal.neon
                ctx.globalAlpha = 0.55
                ctx.lineWidth = 1.4
                ctx.beginPath()
                ctx.moveTo(w - inset, h - inset - 14); ctx.lineTo(w - inset, h - inset)
                ctx.lineTo(w - inset - 14, h - inset)
                ctx.stroke()
                // a whisper of moonlight down the left margin
                ctx.strokeStyle = chrome.pal.cyan
                ctx.globalAlpha = 0.12
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(inset + 0.5, inset + 16); ctx.lineTo(inset + 0.5, h - inset - 16)
                ctx.stroke()
            }
        }
    }

    // ── the sighting: navigation breathes fog over the glass, once ─────────
    readonly property Component overlay: Component {
        ShaderEffect {
            id: breath
            property real time: 0
            property real burst: 0
            property real ember: 0
            fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
            visible: burst > 0.01   // transient by design — no resident fog over text
            NumberAnimation {
                id: breathAnim
                target: breath; property: "burst"
                from: 0.8; to: 0; duration: 750
                easing.type: Easing.OutQuad
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) breathAnim.restart() }
            }
        }
    }
}
