import QtQuick

// pines: cobalt is the DISTRICT LINE — the crank telephone to the office in
// the valley. This is where calls happen, so the cab holds still: the
// backdrop is one static ink pass (the house benchmark + bearing rule under
// the titlebar, lamp ticks by the status line, a faint contour in the
// corner), no resident motion at all. A rail navigation — chat, calendar,
// activity — is a new connection on the line: the glass takes one soft,
// restrained breath of condensation above the page and clears.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property string wordmark: "▵ DISTRICT LINE"

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
                // benchmark + bearing rule under the titlebar
                ctx.strokeStyle = chrome.pal.cyan
                ctx.globalAlpha = 0.55
                ctx.lineWidth = 1.2
                ctx.beginPath()
                ctx.moveTo(inset + 5, inset)
                ctx.lineTo(inset + 10, inset + 8)
                ctx.lineTo(inset, inset + 8)
                ctx.closePath()
                ctx.stroke()
                ctx.globalAlpha = 0.30
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(inset + 18, inset + 4); ctx.lineTo(w * 0.35, inset + 4)
                ctx.stroke()
                for (let i = 1; i <= 4; i++) {
                    const x = inset + 18 + (w * 0.35 - inset - 18) * i / 5
                    ctx.beginPath()
                    ctx.moveTo(x, inset + (i % 2 ? 2 : 0.5)); ctx.lineTo(x, inset + 4)
                    ctx.stroke()
                }
                // one quiet contour set, bottom-left, under the glass bars
                const ccx = w * 0.08, ccy = h * 0.94
                for (let ring = 0; ring < 3; ring++) {
                    const base = 18 + ring * 16
                    ctx.beginPath()
                    for (let a = 0; a <= 40; a++) {
                        const th = a / 40 * Math.PI * 2
                        const r = base + Math.sin(th * 3 + 2.1 + ring) * base * 0.13
                        const x = ccx + Math.cos(th) * r
                        const y = ccy + Math.sin(th) * r * 0.8
                        if (a === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                    }
                    ctx.closePath()
                    ctx.strokeStyle = chrome.pal.dim
                    ctx.globalAlpha = 0.12 - ring * 0.03
                    ctx.stroke()
                }
                // lamp ticks by the status line
                ctx.strokeStyle = chrome.pal.neon
                ctx.globalAlpha = 0.5
                ctx.lineWidth = 1.4
                ctx.beginPath()
                ctx.moveTo(w - inset, h - inset - 14); ctx.lineTo(w - inset, h - inset)
                ctx.lineTo(w - inset - 14, h - inset)
                ctx.stroke()
            }
        }
    }

    // ── a new connection: one soft breath, then still ──────────────────────
    readonly property Component overlay: Component {
        ShaderEffect {
            id: breath
            property real time: 0
            property real burst: 0
            property real ember: 0
            fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
            // the shader's ambient banks don't scale with burst — dissolve the
            // whole layer over the breath's tail so nothing snaps off
            opacity: Math.min(1, burst / 0.15)
            visible: burst > 0.01   // transient by design — this room takes calls
            NumberAnimation {
                id: breathAnim
                target: breath; property: "burst"
                from: 0.45; to: 0; duration: 650
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
