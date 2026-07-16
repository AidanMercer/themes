import QtQuick

// shiro: the vitals page — pulse as a sheet of washi where the machine's
// condition reads like ink saturation. a calm machine is a blank page; as the
// cpu warms, the blush at the head of the sheet deepens, slow as ink spreading
// in wet paper. re-sorting the table draws one light brush stroke; sending a
// signal closes the enso — the circle completes in deep rose, then the gap
// breathes back open. nothing else moves.
Item {
    id: chrome

    required property var pal
    property var host: null    // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0

    // ink hairline instead of the stock white-on-white
    readonly property color cardBorder: Qt.alpha(pal.text, 0.16)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "脈 shiro"

    // ── the sheet: fibers below the gauges, warmth at the head ──
    readonly property Component backdrop: Component {
        Item {
            // washi fibers; the head blush breathes only while the page is
            // awake — near-stillness is the resting state
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

            // blush wash at the head of the page — the machine's warmth,
            // deepening as host.load climbs (a slow drifting bind, no loop)
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 170
                opacity: 0.5 + chrome.load * 0.5
                Behavior on opacity { NumberAnimation { duration: 2400; easing.type: Easing.InOutSine } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.cyan, 0.11) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    // ── the gestures ride above the gauges, whisper-faint, click-through ──
    readonly property Component overlay: Component {
        Item {
            // one light brush stroke under the header when the table re-sorts
            Rectangle {
                id: stroke
                anchors { left: parent.left; top: parent.top; leftMargin: 22; topMargin: 46 }
                height: 2; radius: 1
                width: parent.width * 0.34 * sweep
                color: Qt.alpha(chrome.pal.text, 0.32)
                opacity: 0
                property real sweep: 0
                SequentialAnimation {
                    id: sortStroke
                    ParallelAnimation {
                        NumberAnimation { target: stroke; property: "sweep"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
                        NumberAnimation { target: stroke; property: "opacity"; from: 0; to: 1; duration: 120 }
                    }
                    NumberAnimation { target: stroke; property: "opacity"; from: 1; to: 0; duration: 360; easing.type: Easing.InQuad }
                }
            }

            // the enso rests bottom-right, open like every other page's. a
            // kill seals the circle — completion, in deep rose — then it
            // breathes back open and the ink pales to wisteria again
            Canvas {
                id: enso
                width: 230; height: 230
                anchors { right: parent.right; bottom: parent.bottom; margins: -40 }
                property real sweep: 0
                property real seal: 0     // 0 open circle … 1 sealed, inked in rose
                onSweepChanged: requestPaint()
                onSealChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2, r = 88
                    const start = -Math.PI * 0.62
                    const end = start + sweep * Math.PI * (1.72 + 0.28 * seal)
                    // wisteria at rest, deep rose as the circle seals
                    const w = chrome.pal.neon, d = chrome.pal.magenta, k = seal
                    const ink = Qt.rgba(w.r + (d.r - w.r) * k,
                                        w.g + (d.g - w.g) * k,
                                        w.b + (d.b - w.b) * k, 1)
                    ctx.lineCap = "round"
                    // two offset strokes fake the dry-brush body
                    ctx.strokeStyle = ink
                    ctx.globalAlpha = 0.10 + 0.24 * k
                    ctx.lineWidth = 11
                    ctx.beginPath(); ctx.arc(cx, cy, r, start, end); ctx.stroke()
                    ctx.globalAlpha = 0.07 + 0.14 * k
                    ctx.lineWidth = 5
                    ctx.beginPath(); ctx.arc(cx + 3, cy - 2, r + 4, start, end); ctx.stroke()
                }
                // brushed in once when the monitor opens
                NumberAnimation {
                    id: inkIn
                    target: enso; property: "sweep"
                    from: 0; to: 1; duration: 1500
                    easing.type: Easing.OutCubic
                }
                Component.onCompleted: inkIn.restart()
                // the kill: circle snaps shut, holds a breath, reopens
                SequentialAnimation {
                    id: killSeal
                    ParallelAnimation {
                        NumberAnimation { target: enso; property: "seal"; from: 0; to: 1; duration: 340; easing.type: Easing.OutCubic }
                        NumberAnimation { target: enso; property: "sweep"; to: 1; duration: 340; easing.type: Easing.OutCubic }
                    }
                    PauseAnimation { duration: 240 }
                    NumberAnimation { target: enso; property: "seal"; from: 1; to: 0; duration: 620; easing.type: Easing.InOutSine }
                }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) sortStroke.restart() }
                function onKillPulseChanged() { if (chrome.awake) killSeal.restart() }
            }
        }
    }
}
