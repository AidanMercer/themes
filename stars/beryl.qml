import QtQuick

// stars: the night sky wrapped around the page — stars gather in the tab
// strip and settle low along the platform edge by the status bar, the nebula
// drifts behind the chrome (and across any page that lets the night through),
// and the vending machine hums in the bottom-left corner. every committed
// navigation sends one star skimming flat across the top of the page.
Item {
    id: chrome

    required property var pal
    property var host: null   // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.dim, 0.60)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "✦ night drift"

    // ── the page turn: one star skims the tab strip and the top of the page ──
    readonly property Component overlay: Component {
        Item {
            id: ov
            Rectangle {
                id: streak
                width: 90; height: 1.5; radius: 1
                rotation: 12
                opacity: 0
                property real baseX: 0
                property real baseY: 0
                property real t: 0
                x: baseX + t * 280
                y: baseY + t * 60
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.text, 0.8) }
                }
                SequentialAnimation {
                    id: shoot
                    ScriptAction {
                        script: {
                            // stay up in the chrome band — the page below keeps reading
                            streak.baseX = ov.width * (0.08 + Math.random() * 0.5)
                            streak.baseY = 10 + Math.random() * 44
                            streak.t = 0
                            streak.opacity = 0.85
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

            // nebula haze — its upper-sky mask puts it right behind the tab
            // strip, and it crosses the middle only where a page runs clear
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("nebula.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // stars in the tab strip — the sky the chrome actually shows
            Repeater {
                model: 22
                Rectangle {
                    property real tw: 1200 + chrome.rnd(index, 3) * 2600
                    width: chrome.rnd(index, 4) < 0.18 ? 3 : 2
                    height: width
                    radius: width / 2
                    x: chrome.rnd(index, 1) * bd.width
                    y: 4 + chrome.rnd(index, 2) * 62
                    color: chrome.rnd(index, 5) < 0.12 ? chrome.pal.neon : chrome.pal.text
                    opacity: 0.25
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: chrome.awake && bd.visible
                        NumberAnimation { to: 0.75; duration: tw; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.18; duration: tw * 1.3; easing.type: Easing.InOutSine }
                    }
                }
            }

            // the deep sky behind the page — only surfaces when a site
            // runs transparent, so it stays sparse and faint
            Repeater {
                model: 16
                Rectangle {
                    property real tw: 1600 + chrome.rnd(index, 13) * 2800
                    width: 2; height: 2; radius: 1
                    x: chrome.rnd(index, 11) * bd.width
                    y: 84 + chrome.rnd(index, 12) * bd.height * 0.5
                    color: chrome.rnd(index, 15) < 0.12 ? chrome.pal.neon : chrome.pal.text
                    opacity: 0.18
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: chrome.awake && bd.visible
                        NumberAnimation { to: 0.5; duration: tw; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.12; duration: tw * 1.3; easing.type: Easing.InOutSine }
                    }
                }
            }

            // a few stars settled on the platform edge, by the status bar
            Repeater {
                model: 6
                Rectangle {
                    property real tw: 1800 + chrome.rnd(index, 23) * 2400
                    width: 2; height: 2; radius: 1
                    x: bd.width * (0.45 + chrome.rnd(index, 21) * 0.5)
                    y: bd.height - 8 - chrome.rnd(index, 22) * 26
                    color: chrome.pal.text
                    opacity: 0.2
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: chrome.awake && bd.visible
                        NumberAnimation { to: 0.55; duration: tw; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.14; duration: tw * 1.3; easing.type: Easing.InOutSine }
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
                    g.addColorStop(0, Qt.alpha(chrome.pal.neon, 0.13))
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
