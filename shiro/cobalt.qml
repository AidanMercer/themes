import QtQuick

// shiro: the letters page for cobalt — calls happen on quiet paper. washi
// fibers and a whisper of blush at the head sit UNDER the glass bars and the
// stripped teams regions; a faint wisteria spine runs the left edge, where the
// rail binds the page. the enso rests small in the corner and re-brushes
// itself when you turn to another channel — everything under the glass, never
// over a call. restraint is the whole gesture here: no overlay at all.
Item {
    id: chrome

    required property var pal
    property var host: null    // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property string wordmark: "koe · shiro"

    readonly property Component backdrop: Component {
        Item {
            // washi fibers; the head blush breathes only while the window is
            // awake, and even then slow as drying ink
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

            // whisper of blush over the titlebar band
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 110
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.cyan, 0.05) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // the spine — wisteria bound along the rail edge
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 70
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.neon, 0.05) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // enso resting small in the corner, quieter than the other pages;
            // a channel turn re-inks it under the glass
            Canvas {
                id: enso
                width: 180; height: 180
                anchors { right: parent.right; bottom: parent.bottom; margins: -30 }
                property real sweep: 0
                onSweepChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2, r = 68
                    const start = -Math.PI * 0.62
                    const end = start + sweep * Math.PI * 1.72
                    ctx.lineCap = "round"
                    // two offset strokes fake the dry-brush body
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.globalAlpha = 0.08
                    ctx.lineWidth = 9
                    ctx.beginPath(); ctx.arc(cx, cy, r, start, end); ctx.stroke()
                    ctx.globalAlpha = 0.05
                    ctx.lineWidth = 4
                    ctx.beginPath(); ctx.arc(cx + 2, cy - 2, r + 3, start, end); ctx.stroke()
                }
                // brushed in once when the page opens
                NumberAnimation {
                    id: inkIn
                    target: enso; property: "sweep"
                    from: 0; to: 1; duration: 1100
                    easing.type: Easing.OutCubic
                }
                Component.onCompleted: inkIn.restart()
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) inkIn.restart() }
            }
        }
    }
}
