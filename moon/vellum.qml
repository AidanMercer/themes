import QtQuick

// moon: Edgerunners chrome for the editor. The HUD brackets hold the chassis
// whether you're writing or reading, but the deck stays dark while you type —
// the CRT only powers up behind a rendered page, and glitches once as it
// resolves. Unlike mica's, the scanline pass sits BEHIND the panes: nothing
// crawls over the glyphs.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // vellum window — active, readingMode, pdfMode

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page

    // chassis: sharper corners, neon edge
    readonly property color cardBorder: Qt.alpha(pal.neon, 0.45)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 10

    readonly property Component backdrop: Component {
        Item {
            // ── chassis: corner L-brackets + a cyan inner rule, sysinfo's HUD grammar ──
            Canvas {
                id: hud
                anchors.fill: parent
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
                    // cyan inner rule under the title row
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

            // ── CRT pass: scanlines drift while a page is up; the page turn
            // spikes `burst` for a short glitch storm. While you're writing the
            // time animation stops and the shader freezes to a static draw. ──
            ShaderEffect {
                id: crt
                anchors.fill: parent
                property real time: 0
                property real burst: 0
                fragmentShader: Qt.resolvedUrl("scanline.frag.qsb")
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.stirring
                }
                NumberAnimation {
                    id: burstAnim
                    target: crt; property: "burst"
                    from: 1; to: 0; duration: 700
                    easing.type: Easing.OutQuad
                }
                Connections {
                    target: chrome
                    function onPageChanged() { if (chrome.stirring) burstAnim.restart() }
                }
            }
        }
    }
}
