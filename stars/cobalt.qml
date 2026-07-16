import QtQuick

// stars: the quiet end of the night — cobalt is where the calls happen, so
// the sky keeps its voice down. a handful of slow stars, a thin nebula, the
// vending glow turned low; a rail hop sends one soft star drifting across,
// and that is all the drama this window is allowed.
Item {
    id: chrome

    required property var pal
    property var host: null   // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property string wordmark: "✦ night shift"

    // ── channel hop: one soft star, slower than anywhere else ──
    readonly property Component overlay: Component {
        Item {
            id: ov
            Rectangle {
                id: streak
                width: 80; height: 1.5; radius: 1
                rotation: 20
                opacity: 0
                property real baseX: 0
                property real baseY: 0
                property real t: 0
                x: baseX + t * 200
                y: baseY + t * 74
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.text, 0.6) }
                }
                SequentialAnimation {
                    id: shoot
                    ScriptAction {
                        script: {
                            streak.baseX = ov.width * (0.1 + Math.random() * 0.5)
                            streak.baseY = ov.height * (0.04 + Math.random() * 0.18)
                            streak.t = 0
                            streak.opacity = 0.55
                        }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: streak; property: "t"; from: 0; to: 1; duration: 800 }
                        SequentialAnimation {
                            PauseAnimation { duration: 350 }
                            NumberAnimation { target: streak; property: "opacity"; to: 0; duration: 400 }
                        }
                    }
                }
                Connections {
                    target: chrome.host
                    enabled: chrome.host !== null
                    function onNavIdChanged() { if (chrome.awake) shoot.restart() }
                }
            }
        }
    }

    // deterministic scatter — same sky every launch
    function rnd(i, salt) {
        var x = Math.sin(i * 127.1 + salt * 311.7) * 43758.5453
        return x - Math.floor(x)
    }

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // thin nebula — surfaces through the stripped Teams regions
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("nebula.frag.qsb")
                property real time: 0
                opacity: 0.65
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // fewer stars, breathing slower — a meeting-room sky
            Repeater {
                model: 18
                Rectangle {
                    property real tw: 2600 + chrome.rnd(index, 3) * 4200
                    width: chrome.rnd(index, 4) < 0.15 ? 3 : 2
                    height: width
                    radius: width / 2
                    x: chrome.rnd(index, 1) * bd.width
                    y: chrome.rnd(index, 2) * bd.height * 0.6
                    color: chrome.rnd(index, 5) < 0.1 ? chrome.pal.neon : chrome.pal.text
                    opacity: 0.16
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: chrome.awake && bd.visible
                        NumberAnimation { to: 0.45; duration: tw; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.12; duration: tw * 1.3; easing.type: Easing.InOutSine }
                    }
                }
            }

            // vending machine glow, bottom-left, turned low for the call
            Canvas {
                width: 300; height: 220
                anchors { left: parent.left; bottom: parent.bottom }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(28, height - 18, 0, 28, height - 18, 270)
                    g.addColorStop(0, Qt.alpha(chrome.pal.neon, 0.09))
                    g.addColorStop(0.6, Qt.alpha(chrome.pal.amber, 0.03))
                    g.addColorStop(1, "transparent")
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                Component.onCompleted: requestPaint()
            }
        }
    }
}
