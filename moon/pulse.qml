import QtQuick

// moon: Edgerunners chrome for pulse — the vitals deck. Neon HUD brackets
// behind the gauges, the CRT scanline pass over them, and the machine's own
// heartbeat wired into the glass: the glitch baseline rides host.load, so a
// hot CPU makes the deck itself run dirty. Re-sorting the table fires a short
// glitch; killing a process fires the full storm. Same grammar as mica.qml:
// invisible root, pulse mounts backdrop below and overlay above its panels.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0

    // chassis: sharper corners, neon edge
    readonly property color cardBorder: Qt.alpha(pal.neon, 0.45)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 10

    readonly property string wordmark: "⏚ NET.VITALS"

    // ── chassis: corner L-brackets + a cyan inner rule, sysinfo's HUD grammar ──
    readonly property Component backdrop: Component {
        Canvas {
            id: hud
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                const w = width, h = height, L = 26, inset = 7
                ctx.reset()
                ctx.lineWidth = 1.6
                ctx.globalAlpha = 0.65
                ctx.strokeStyle = chrome.pal.neon
                // top-left bracket
                ctx.beginPath()
                ctx.moveTo(inset, inset + L); ctx.lineTo(inset, inset); ctx.lineTo(inset + L, inset)
                ctx.stroke()
                // bottom-right bracket
                ctx.beginPath()
                ctx.moveTo(w - inset, h - inset - L); ctx.lineTo(w - inset, h - inset)
                ctx.lineTo(w - inset - L, h - inset)
                ctx.stroke()
                // cyan inner rule under the header row
                ctx.beginPath()
                ctx.moveTo(inset + L + 8, inset + 3); ctx.lineTo(w * 0.42, inset + 3)
                ctx.strokeStyle = chrome.pal.cyan
                ctx.lineWidth = 1
                ctx.globalAlpha = 0.4
                ctx.stroke()
                // magenta corner tick
                ctx.beginPath()
                ctx.moveTo(w - inset - L - 12, h - inset - 3); ctx.lineTo(w - inset - L - 32, h - inset - 3)
                ctx.strokeStyle = chrome.pal.magenta
                ctx.globalAlpha = 0.55
                ctx.stroke()
            }
        }
    }

    // ── CRT pass: scanlines drift while the deck is awake; the glitch floor
    // follows the CPU (an idle machine runs clean, a pinned one runs dirty).
    // A re-sort blips the glass; a kill fires the full storm. ──
    readonly property Component overlay: Component {
        ShaderEffect {
            id: crt
            property real time: 0
            property real spike: 0
            // burst = event spike riding on the load floor — the shader reads
            // one uniform; the deck's dirt level IS the machine's load
            property real burst: Math.min(1, spike + chrome.load * 0.3)
            fragmentShader: Qt.resolvedUrl("scanline.frag.qsb")
            NumberAnimation on time {
                from: 0; to: 3600; duration: 3600000
                loops: Animation.Infinite
                running: chrome.awake
            }
            NumberAnimation {
                id: sortBlip
                target: crt; property: "spike"
                from: 0.45; to: 0; duration: 450
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                id: killStorm
                target: crt; property: "spike"
                from: 1; to: 0; duration: 800
                easing.type: Easing.OutQuad
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) sortBlip.restart() }
                function onKillPulseChanged() { if (chrome.awake) killStorm.restart() }
            }
        }
    }
}
