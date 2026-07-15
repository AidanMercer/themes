import QtQuick

// shiro: the poem page — the theme vellum was always going to suit. Washi fibers
// in the sheet, a blush wash at the top, and an enso that inks itself in
// bottom-right each time the page composes. Calm by contract: the only motion
// in the whole file is that one brush stroke, and it never runs while you write.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page

    // ink hairline instead of the stock white-on-white
    readonly property color cardBorder: Qt.alpha(pal.text, 0.16)
    readonly property int cardBorderWidth: 1

    readonly property Component backdrop: Component {
        Item {
            // washi fibers in the sheet; the top blush breathes over a page,
            // still as dried ink while you're writing
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("washi.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.stirring
                }
            }

            // blush wash drifting down from the top edge
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 170
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.cyan, 0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // enso, brushed in when the page opens and re-inked on every turn
            Canvas {
                id: enso
                width: 230; height: 230
                anchors { right: parent.right; bottom: parent.bottom; margins: -40 }
                property real sweep: 0
                onSweepChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2, r = 88
                    const start = -Math.PI * 0.62
                    const end = start + sweep * Math.PI * 1.72
                    ctx.lineCap = "round"
                    // two offset strokes fake the dry-brush body
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.globalAlpha = 0.10
                    ctx.lineWidth = 11
                    ctx.beginPath(); ctx.arc(cx, cy, r, start, end); ctx.stroke()
                    ctx.globalAlpha = 0.07
                    ctx.lineWidth = 5
                    ctx.beginPath(); ctx.arc(cx + 3, cy - 2, r + 4, start, end); ctx.stroke()
                }
                NumberAnimation on sweep {
                    id: inkIn
                    from: 0; to: 1; duration: 1500
                    easing.type: Easing.OutCubic
                    running: true
                }
                Connections {
                    target: chrome
                    function onPageChanged() { if (chrome.stirring) inkIn.restart() }
                }
            }
        }
    }
}
