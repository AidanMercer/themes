import QtQuick

// moon: Edgerunners chrome for beryl — the dive rig. Neon HUD brackets and the
// CRT pass live in the BACKDROP, so they surface through beryl's transparent
// pages (glass chrome, stripped sites) without crawling over text; every tab
// switch or committed navigation is a dive — a glitch storm fires briefly
// ABOVE the page and is gone. Page fullscreen melts all of it away (the app
// unmounts both layers). Same grammar as mica.qml: invisible root, pal/host.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    // chassis: sharper corners, neon edge
    readonly property color cardBorder: Qt.alpha(pal.neon, 0.45)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 10

    readonly property string wordmark: "⏚ NET.DIVE"

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
                    // cyan inner rule under the tab strip
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

            // ── CRT pass, under the page: scanlines drift while the rig is
            // awake, surfacing wherever a stripped site lets the glass show ──
            ShaderEffect {
                anchors.fill: parent
                property real time: 0
                property real burst: 0
                fragmentShader: Qt.resolvedUrl("scanline.frag.qsb")
                opacity: 0.7
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }
        }
    }

    // ── the dive: a navigation fires one short glitch storm above the page,
    // then the overlay goes fully quiet (burst 0 draws nothing here) ──
    readonly property Component overlay: Component {
        ShaderEffect {
            id: crt
            property real time: 0
            property real burst: 0
            fragmentShader: Qt.resolvedUrl("scanline.frag.qsb")
            visible: burst > 0.01   // transient by design — no resident crawl over text
            // the storm slices key off floor(time*24) — advance time only while
            // the storm shows, so they actually tear instead of freezing in place
            NumberAnimation on time {
                from: 0; to: 3600; duration: 3600000
                loops: Animation.Infinite
                running: chrome.awake && crt.visible
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
