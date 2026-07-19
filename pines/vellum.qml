import QtQuick

// pines: vellum is the LOG BOOK — the ledger open under the kerosene lamp.
// While you WRITE, the cab holds absolutely still: a static chassis (the
// house benchmark + bearing rule), nothing else. Only when a rendered page
// or a pdf is up does the room breathe — lamplight pools warm across the
// head of the page, fog drifts on the glass behind it, and each page that
// composes draws one breath of condensation that clears as the page
// sharpens. Everything sits BEHIND the panes so the glyphs stay crisp.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // vellum window — active, readingMode, pdfMode

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page   // the only thing that may animate

    readonly property color cardBorder: Qt.alpha(pal.cyan, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    readonly property Component backdrop: Component {
        Item {
            // ── chassis: benchmark + bearing rule + lamp corner ticks ──────
            Canvas {
                id: chassis
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height, inset = 8
                    ctx.strokeStyle = chrome.pal.cyan
                    ctx.globalAlpha = 0.6
                    ctx.lineWidth = 1.2
                    ctx.beginPath()
                    ctx.moveTo(inset + 5, inset)
                    ctx.lineTo(inset + 10, inset + 8)
                    ctx.lineTo(inset, inset + 8)
                    ctx.closePath()
                    ctx.stroke()
                    ctx.globalAlpha = 0.35
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(inset + 18, inset + 4); ctx.lineTo(w * 0.4, inset + 4)
                    ctx.stroke()
                    for (let i = 1; i <= 5; i++) {
                        const x = inset + 18 + (w * 0.4 - inset - 18) * i / 6
                        ctx.beginPath()
                        ctx.moveTo(x, inset + (i % 2 ? 2 : 0.5)); ctx.lineTo(x, inset + 4)
                        ctx.stroke()
                    }
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.globalAlpha = 0.55
                    ctx.lineWidth = 1.4
                    ctx.beginPath()
                    ctx.moveTo(w - inset, h - inset - 14); ctx.lineTo(w - inset, h - inset)
                    ctx.lineTo(w - inset - 14, h - inset)
                    ctx.stroke()
                }
            }

            // the lamp's pool on a page being read — appears only with a page
            Rectangle {
                width: parent.width
                height: 90
                opacity: chrome.page ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.neon, 0.06) }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.0) }
                }
            }

            // fog on the glass, only while a page is up and the room awake
            ShaderEffect {
                id: fogPane
                anchors.fill: parent
                property real time: 0
                property real burst: 0
                property real ember: 0
                fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
                opacity: chrome.page ? 0.7 : 0
                Behavior on opacity { NumberAnimation { duration: 600 } }
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.stirring
                }
                // the page composes: one breath of condensation, then clarity.
                // Gated on `page`, not `stirring`, so alt-tab can't re-fire it.
                NumberAnimation {
                    id: pageBreath
                    target: fogPane; property: "burst"
                    from: 1; to: 0; duration: 1000
                    easing.type: Easing.OutQuad
                }
                Connections {
                    target: chrome
                    function onPageChanged() { if (chrome.page) pageBreath.restart() }
                }
            }
        }
    }
}
