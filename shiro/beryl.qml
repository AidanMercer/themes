import QtQuick

// shiro: the poem page for beryl — the browser is a book you leaf through.
// washi fibers and the head blush live UNDER the chrome, surfacing in the tab
// strip, the window margins and whatever pages run transparent; ink pools
// faintly at the foot where the status line rests. the page center belongs to
// the page. turning a leaf — any tab switch or committed navigation — brushes
// the enso in above the fresh page for one breath, then it dries away. no
// resident motion ever sits over text.
Item {
    id: chrome

    required property var pal
    property var host: null    // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    // ink hairline instead of the stock white-on-white
    readonly property color cardBorder: Qt.alpha(pal.text, 0.16)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "頁 shiro"

    // ── the sheet, composed for the chrome bands ──
    readonly property Component backdrop: Component {
        Item {
            // washi fibers; the shader's slow blush breath lands exactly on
            // the tab strip — the head of the page — and only while awake
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("washi.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // blush wash over the tab strip and the seam beneath it
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 120
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.cyan, 0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // ink pooled at the foot of the page, under the status line
            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 90
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.text, 0.06) }
                }
            }
        }
    }

    // ── the page turn: the enso inks itself in over the new page, holds a
    // breath, and dries into the paper — gone until the next leaf ──
    readonly property Component overlay: Component {
        Item {
            Canvas {
                id: enso
                width: 230; height: 230
                anchors { right: parent.right; bottom: parent.bottom; margins: -40 }
                visible: opacity > 0.01   // costs nothing between page turns
                opacity: 0
                property real sweep: 0
                onSweepChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2, r = 88
                    const start = -Math.PI * 0.62
                    const end = start + sweep * Math.PI * 1.72
                    ctx.lineCap = "round"
                    // two offset strokes fake the dry-brush body; a touch
                    // bolder than the resting enso — it has to read over a
                    // page, but only for a breath
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.globalAlpha = 0.14
                    ctx.lineWidth = 11
                    ctx.beginPath(); ctx.arc(cx, cy, r, start, end); ctx.stroke()
                    ctx.globalAlpha = 0.09
                    ctx.lineWidth = 5
                    ctx.beginPath(); ctx.arc(cx + 3, cy - 2, r + 4, start, end); ctx.stroke()
                }
                SequentialAnimation {
                    id: navInk
                    ParallelAnimation {
                        NumberAnimation { target: enso; property: "sweep"; from: 0; to: 1; duration: 650; easing.type: Easing.OutCubic }
                        NumberAnimation { target: enso; property: "opacity"; from: 0; to: 1; duration: 180 }
                    }
                    PauseAnimation { duration: 150 }
                    NumberAnimation { target: enso; property: "opacity"; from: 1; to: 0; duration: 400; easing.type: Easing.InQuad }
                }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) navInk.restart() }
            }
        }
    }
}
