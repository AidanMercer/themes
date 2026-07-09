import QtQuick

// moon: Edgerunners chrome for mica — neon HUD brackets behind the miller
// columns, a CRT scanline/glitch shader over them, and a glitch storm on every
// directory change. Same grammar as popup.qml: invisible root, mica mounts
// backdrop below and overlay above its panes.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // mica window — active (focus), navId (cwd)

    readonly property bool awake: host ? host.active === true : false

    // chassis: sharper corners, neon edge
    readonly property color cardBorder: Qt.alpha(pal.neon, 0.45)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 10

    readonly property string wordmark: "⏚ NET.FILES"

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
                // cyan inner rule under the breadcrumb row
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

    // ── CRT pass: scanlines drift and glitch lines fire while the window is
    // awake; a directory change spikes `burst` for a short glitch storm.
    // Unfocused the shader freezes into a single static draw. ──
    readonly property Component overlay: Component {
        ShaderEffect {
            id: crt
            property real time: 0
            property real burst: 0
            // `height` is the item's own height — the shader reads it for pixel pitch
            fragmentShader: Qt.resolvedUrl("scanline.frag.qsb")
            NumberAnimation on time {
                from: 0; to: 3600; duration: 3600000
                loops: Animation.Infinite
                running: chrome.awake
            }
            NumberAnimation {
                id: burstAnim
                target: crt; property: "burst"
                from: 1; to: 0; duration: 700
                easing.type: Easing.OutQuad
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) burstAnim.restart() }
            }
        }
    }
}
