import QtQuick

// stars: the vending machine's own vitals — the same night sky, but wired to
// the compressor. the nebula deepens and the stars flicker faster as the
// machine strains; a re-sort sends one star across the sky, and a kill drops
// a star clean out of it while the shelf light stutters signal-red.
Item {
    id: chrome

    required property var pal
    property var host: null   // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0

    readonly property color cardBorder: Qt.alpha(pal.dim, 0.60)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "✦ midnight hum"

    // deterministic scatter — same sky every launch
    function rnd(i, salt) {
        var x = Math.sin(i * 127.1 + salt * 311.7) * 43758.5453
        return x - Math.floor(x)
    }

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // nebula haze — the sky deepens as the machine strains
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("nebula.frag.qsb")
                property real time: 0
                opacity: 0.6 + chrome.load * 0.4
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // starfield — the twinkle quickens with load; a strained machine
            // makes the whole night jitter
            Repeater {
                model: 42
                Rectangle {
                    property real tw: 1200 + chrome.rnd(index, 3) * 2600
                    width: chrome.rnd(index, 4) < 0.18 ? 3 : 2
                    height: width
                    radius: width / 2
                    x: chrome.rnd(index, 1) * bd.width
                    y: chrome.rnd(index, 2) * bd.height * 0.62
                    color: chrome.rnd(index, 5) < 0.12 ? chrome.pal.neon : chrome.pal.text
                    opacity: 0.25
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: chrome.awake && bd.visible
                        NumberAnimation { to: 0.75; duration: tw / (1 + chrome.load * 1.5); easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.18; duration: tw * 1.3 / (1 + chrome.load * 1.5); easing.type: Easing.InOutSine }
                    }
                }
            }

            // vending machine glow, bottom-left — burns a touch brighter under load
            Canvas {
                width: 320; height: 240
                anchors { left: parent.left; bottom: parent.bottom }
                opacity: 0.8 + chrome.load * 0.2
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

    readonly property Component overlay: Component {
        Item {
            id: ov

            // ── re-sort: one star crosses the sky ──
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
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.text, 0.8) }
                }
                SequentialAnimation {
                    id: shoot
                    ScriptAction {
                        script: {
                            streak.baseX = ov.width * (0.1 + Math.random() * 0.5)
                            streak.baseY = ov.height * (0.05 + Math.random() * 0.25)
                            streak.t = 0
                            streak.opacity = 0.9
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
            }

            // ── kill: a star falls straight out of the sky… ──
            Rectangle {
                id: faller
                width: 1.5; height: 70; radius: 1
                opacity: 0
                property real fx: 0
                property real fy: 0
                property real t: 0
                x: fx
                y: fy + t * (ov.height * 0.45)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.text, 0.9) }
                }
            }

            // …and the shelf light stutters signal-red
            Canvas {
                id: redGlow
                width: 320; height: 240
                anchors { left: parent.left; bottom: parent.bottom }
                opacity: 0
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(30, height - 20, 0, 30, height - 20, 290)
                    g.addColorStop(0, Qt.alpha(chrome.pal.magenta, 0.30))
                    g.addColorStop(0.6, Qt.alpha(chrome.pal.magenta, 0.08))
                    g.addColorStop(1, "transparent")
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                Component.onCompleted: requestPaint()
            }

            SequentialAnimation {
                id: killFall
                ScriptAction {
                    script: {
                        faller.fx = ov.width * (0.15 + Math.random() * 0.7)
                        faller.fy = ov.height * (0.05 + Math.random() * 0.2)
                        faller.t = 0
                        faller.opacity = 0.95
                    }
                }
                ParallelAnimation {
                    NumberAnimation { target: faller; property: "t"; from: 0; to: 1; duration: 750; easing.type: Easing.InQuad }
                    SequentialAnimation {
                        PauseAnimation { duration: 420 }
                        NumberAnimation { target: faller; property: "opacity"; to: 0; duration: 330 }
                    }
                    SequentialAnimation {
                        NumberAnimation { target: redGlow; property: "opacity"; to: 0.85; duration: 70 }
                        NumberAnimation { target: redGlow; property: "opacity"; to: 0.20; duration: 90 }
                        NumberAnimation { target: redGlow; property: "opacity"; to: 0.65; duration: 80 }
                        NumberAnimation { target: redGlow; property: "opacity"; to: 0; duration: 480 }
                    }
                }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) shoot.restart() }
                function onKillPulseChanged() { if (chrome.awake) killFall.restart() }
            }
        }
    }
}
