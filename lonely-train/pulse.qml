import QtQuick

// lonely-train: the engine car — pulse is the machine hauling the night line.
// sodium lamplight pools over the gauges, dusk settles at the floor, and the
// glass answers the engine: a second sheet of rain blows in as host.load
// climbs, and the floor runs warm over the traction motors. a re-sort is the
// points lamp blinking past as the train switches tracks; a kill is the
// brakes biting — a hard red signal hammers by on the other track and
// tail-light red floods up from under the floor.
Item {
    id: chrome

    required property var pal
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.20)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "🚃 engine car"

    // ── behind the gauges: the carriage itself ──
    readonly property Component backdrop: Component {
        Item {
            // sodium lamp glow, top-right
            Canvas {
                width: 340; height: 260
                anchors { top: parent.top; right: parent.right }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(width - 40, 20, 0, width - 40, 20, 300)
                    g.addColorStop(0, Qt.alpha(chrome.pal.neon, 0.13))
                    g.addColorStop(1, "transparent")
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                Component.onCompleted: requestPaint()
            }

            // dusk settling at the floor of the carriage
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 140
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.08) }
                }
            }

            // the traction motors run under this floor — it glows warm as the
            // engine works, dusk blue giving way to sodium amber
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 140
                opacity: Math.min(0.8, chrome.load)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.11) }
                }
            }
        }
    }

    // ── over the gauges: the window glass, and what passes beyond it ──
    readonly property Component overlay: Component {
        Item {
            id: ov

            // rain on the window while someone's in the cab
            ShaderEffect {
                id: rainA
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("rain.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // the second sheet — blown in faster and harder as the engine
            // works (rides rainA's gated clock, so it freezes with it)
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("rain.frag.qsb")
                property real time: rainA.time * 1.4 + 47
                opacity: Math.min(1, chrome.load * 1.3)
                visible: opacity > 0.02
            }

            // the points lamp — a re-sort switches tracks, its caution-yellow
            // light blinks past the window
            Rectangle {
                id: pointsBeam
                width: 90
                height: parent.height * 1.3
                y: -parent.height * 0.15
                x: -width
                rotation: 10
                opacity: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.alpha(chrome.pal.amber, 0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            SequentialAnimation {
                id: pointsBlink
                PropertyAction { target: pointsBeam; property: "opacity"; value: 1 }
                NumberAnimation {
                    target: pointsBeam; property: "x"
                    from: -pointsBeam.width; to: ov.width + pointsBeam.width
                    duration: 550
                    easing.type: Easing.InOutSine
                }
                PropertyAction { target: pointsBeam; property: "opacity"; value: 0 }
            }

            // the red signal — a kill actually lands: the brakes bite,
            // tail-light red floods up from under the floor while a hard red
            // lamp hammers past on the other track, leaning the other way
            Rectangle {
                id: redBeam
                width: 120
                height: parent.height * 1.3
                y: -parent.height * 0.15
                x: parent.width + width
                rotation: -10
                opacity: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.alpha(chrome.pal.magenta, 0.14) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle {
                id: brakeGlow
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 160
                opacity: 0
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.magenta, 0.20) }
                }
            }
            SequentialAnimation {
                id: redSignal
                PropertyAction { target: redBeam; property: "opacity"; value: 1 }
                ParallelAnimation {
                    NumberAnimation {
                        target: redBeam; property: "x"
                        from: ov.width + redBeam.width; to: -redBeam.width * 2
                        duration: 650
                        easing.type: Easing.InOutSine
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: brakeGlow; property: "opacity"
                            from: 0; to: 1; duration: 150
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: brakeGlow; property: "opacity"
                            from: 1; to: 0; duration: 850
                            easing.type: Easing.OutQuad
                        }
                    }
                }
                PropertyAction { target: redBeam; property: "opacity"; value: 0 }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) pointsBlink.restart() }
                function onKillPulseChanged() { if (chrome.awake) redSignal.restart() }
            }
        }
    }
}
