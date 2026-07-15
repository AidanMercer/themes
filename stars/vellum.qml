import QtQuick

// stars: the night sky over the vending machine. The machine's amber shelf-light
// warms the bottom-left corner while you work, but the sky above only wakes for
// a page — stars twinkle, the nebula drifts, and one shooting star crosses as
// the page composes itself.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page

    readonly property color cardBorder: Qt.alpha(pal.dim, 0.60)
    readonly property int cardBorderWidth: 1

    // ── a shooting star crosses the sky as the page turns ──
    readonly property Component overlay: Component {
        Item {
            id: ov
            Rectangle {
                id: streak
                width: 90; height: 1.5; radius: 1
                rotation: 25
                opacity: 0
                property real baseX: 0
                property real baseY: 0
                property real t: 0
                x: baseX + t * 240
                y: baseY + t * 112
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.text, 0.7) }
                }
                SequentialAnimation {
                    id: shoot
                    ScriptAction {
                        script: {
                            // keep it up in the sky, clear of the text below
                            streak.baseX = ov.width * (0.1 + Math.random() * 0.5)
                            streak.baseY = ov.height * (0.04 + Math.random() * 0.18)
                            streak.t = 0
                            streak.opacity = 0.8
                        }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: streak; property: "t"; from: 0; to: 1; duration: 650 }
                        SequentialAnimation {
                            PauseAnimation { duration: 250 }
                            NumberAnimation { target: streak; property: "opacity"; to: 0; duration: 400 }
                        }
                    }
                }
                Connections {
                    target: chrome
                    function onPageChanged() { if (chrome.stirring) shoot.restart() }
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

            // nebula haze drifting behind the starfield
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("nebula.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.stirring
                }
            }

            Repeater {
                model: 46
                Rectangle {
                    property real tw: 1200 + chrome.rnd(index, 3) * 2600
                    width: chrome.rnd(index, 4) < 0.18 ? 3 : 2
                    height: width
                    radius: width / 2
                    x: chrome.rnd(index, 1) * bd.width
                    y: chrome.rnd(index, 2) * bd.height * 0.62
                    color: chrome.rnd(index, 5) < 0.12 ? chrome.pal.neon : chrome.pal.text
                    opacity: 0.22
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: chrome.stirring && bd.visible
                        NumberAnimation { to: 0.65; duration: tw; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.16; duration: tw * 1.3; easing.type: Easing.InOutSine }
                    }
                }
            }

            // vending machine glow, bottom-left
            Canvas {
                width: 320; height: 240
                anchors { left: parent.left; bottom: parent.bottom }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(30, height - 20, 0, 30, height - 20, 290)
                    g.addColorStop(0, Qt.alpha(chrome.pal.neon, 0.12))
                    g.addColorStop(0.6, Qt.alpha(chrome.pal.amber, 0.04))
                    g.addColorStop(1, "transparent")
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                Component.onCompleted: requestPaint()
            }
        }
    }
}
