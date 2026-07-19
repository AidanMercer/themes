import QtQuick

// sleeper: samovar chrome for pulse. The system monitor is the samovar at the
// end of the car — the machine's warmth made visible. The brass glow at the
// foot of the window rises with CPU load (a hot machine is a boiling
// samovar), thin steam threads climb faster as it works, a re-sort is a
// small stir of the glass, and actually killing a process slams the
// conductor's red VOID stamp across the panels. Same grammar as mica.qml:
// invisible root, pulse mounts backdrop below and overlay above its panels.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0

    function teaA(a)   { return Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, a) }
    function greenA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function linenA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function stampA(a) { return Qt.rgba(pal.magenta.r, pal.magenta.g, pal.magenta.b, a) }

    // chassis: paper corners, warm edge
    readonly property color cardBorder: Qt.alpha(pal.amber, 0.4)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    readonly property string wordmark: "♨ the samovar"

    // ── backdrop: the samovar's warmth, riding the load ─────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the boiler glow at the foot — brighter as the machine works
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * 0.35
                opacity: 0.35 + chrome.load * 0.65
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.teaA(0.0) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.06 + chrome.load * 0.14) }
                }
            }
            // steam threads climbing the right margin, quicker under load
            Repeater {
                model: 3
                Rectangle {
                    id: thread
                    required property int index
                    x: bd.width - 30 - index * 14
                    width: 1
                    height: 26 + index * 8
                    color: chrome.linenA(0.16)
                    property real rise: 0
                    y: bd.height - 40 - rise * (bd.height * 0.5) - index * 20
                    opacity: rise < 0.15 ? rise * 5 : (1 - rise) * 0.9
                    SequentialAnimation on rise {
                        running: chrome.awake
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 0; to: 1
                            duration: Math.max(2400, 7000 - chrome.load * 4200) + index * 900
                            easing.type: Easing.InSine
                        }
                    }
                }
            }
            // the brass rail along the top
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                height: 1
                color: chrome.teaA(0.35)
            }
        }
    }

    // ── overlay: the stir, and the stamp ────────────────────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ovl
            clip: true

            // re-sort: a small lamp stirs across
            Rectangle {
                id: stir
                property real t: -1
                visible: t >= 0
                width: ovl.width * 0.25
                height: ovl.height * 1.5
                y: -ovl.height * 0.25
                rotation: 12
                x: -width + (ovl.width + width * 2) * Math.max(0, t)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: chrome.teaA(0.0) }
                    GradientStop { position: 0.5; color: chrome.teaA(0.07) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
            SequentialAnimation {
                id: stirSweep
                NumberAnimation { target: stir; property: "t"; from: 0; to: 1; duration: 700; easing.type: Easing.InOutSine }
                PropertyAction { target: stir; property: "t"; value: -1 }
            }

            // a kill: the conductor's VOID stamp slams over the panels
            Text {
                id: voidStamp
                anchors.centerIn: parent
                text: "V O I D"
                color: chrome.pal.magenta
                opacity: 0
                rotation: -12
                font.family: chrome.pal.fontMono
                font.weight: Font.Black
                font.pixelSize: 54
                font.letterSpacing: 12
            }
            Rectangle {   // the stamp's red flush at the edges
                id: flush
                anchors.fill: parent
                color: "transparent"
                border.width: 3
                border.color: chrome.stampA(0)
            }
            SequentialAnimation {
                id: stampSlam
                ParallelAnimation {
                    NumberAnimation { target: voidStamp; property: "opacity"; from: 0; to: 0.7; duration: 90 }
                    NumberAnimation { target: voidStamp; property: "scale"; from: 1.9; to: 1; duration: 140; easing.type: Easing.OutCubic }
                    ColorAnimation { target: flush; property: "border.color"; from: chrome.stampA(0); to: chrome.stampA(0.5); duration: 120 }
                }
                PauseAnimation { duration: 500 }
                ParallelAnimation {
                    NumberAnimation { target: voidStamp; property: "opacity"; to: 0; duration: 600 }
                    ColorAnimation { target: flush; property: "border.color"; to: chrome.stampA(0); duration: 600 }
                }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) stirSweep.restart() }
                function onKillPulseChanged() { if (chrome.awake) stampSlam.restart() }
            }
        }
    }
}
