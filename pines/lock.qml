import QtQuick
import QtQuick.Effects
import Quickshell

// pines: bare lock (the bareLock marker tells LockStage we own the chrome).
// Locking the station doesn't black the windows — the rain keeps falling and
// the video stays sharp; only a pane of the cab glass fogs over. A sheet of
// breath-condensation condenses mid-screen (its own blurred, desaturated
// slice of the mountain), carrying the station heading, the time in thin
// serif, and the passcode as a survey: each keystroke plots a benchmark
// triangle onto a bearing line, condensing out of fog as it lands. A wrong
// code LOSES FIX — the marks flash ember and the line is knocked off its
// bearing before it damps level again — and when the code lands, the line
// closes with one warm sweep of lamplight and the watch resumes.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color lamp: pal.neon
    readonly property color fogSilver: pal.cyan
    readonly property color ember: pal.magenta
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    function lampA(a)   { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function silverA(a) { return Qt.rgba(fogSilver.r, fogSilver.g, fogSilver.b, a) }
    function inkA(a)    { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function slateA(a)  { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a)  { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── the night leans in: a cold vignette, the rain stays sharp ──────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.01, 0.04, 0.08, 0.24 * root.p)
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * 0.32
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.01, 0.03, 0.06, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.03, 0.06, 0.5) }
        }
    }

    // ── the fogged pane ────────────────────────────────────────────────────
    readonly property real panelW: Math.round(440 * ui)
    readonly property real panelH: Math.round(316 * ui)

    Item {
        id: pane
        width: root.panelW
        height: root.panelH
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) * 0.44)
        opacity: root.p
        // condensation, not arrival: the pane sharpens from a soft ghost
        scale: 1.045 - 0.045 * root.p

        // the pane fogs its own slice of the mountain
        ShaderEffectSource {
            id: slice
            sourceItem: root.host.backgroundItem
            sourceRect: Qt.rect(pane.x, pane.y, pane.width, pane.height)
            live: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: slice
            blurEnabled: true
            blur: 1.0
            blurMax: 44
            brightness: -0.18
            saturation: -0.45
        }
        Rectangle {
            anchors.fill: parent
            color: root.glassA(0.42)
        }
        // hairline frame + corner ticks — pencil on glass, no chamfer
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: root.silverA(0.4)
        }
        Repeater {
            model: [
                { lx: true,  ty: true  }, { lx: false, ty: true  },
                { lx: true,  ty: false }, { lx: false, ty: false }
            ]
            delegate: Item {
                required property var modelData
                width: 12; height: 12
                x: modelData.lx ? -1 : pane.width - width + 1
                y: modelData.ty ? -1 : pane.height - height + 1
                Rectangle {
                    width: parent.width; height: 1.4
                    color: root.lampA(0.7)
                    y: parent.modelData.ty ? 0 : parent.height - height
                }
                Rectangle {
                    width: 1.4; height: parent.height
                    color: root.lampA(0.7)
                    x: parent.modelData.lx ? 0 : parent.width - width
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(30 * root.ui)
            spacing: Math.round(14 * root.ui)

            // the heading
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6 * root.ui; height: 6 * root.ui; radius: 3 * root.ui
                    color: root.host.unlocking ? root.fogSilver : root.lamp
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.host.unlocking ? "WATCH RESUMED" : "STANDING WATCH"
                    color: root.host.unlocking ? root.fogSilver : root.lampA(0.95)
                    font.family: root.serif
                    font.pixelSize: Math.round(14 * root.ui)
                    font.letterSpacing: 6
                }
            }

            // the time, thin serif
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hhmm
                color: root.inkA(0.95)
                font.family: root.serif
                font.pixelSize: Math.round(74 * root.ui)
                font.weight: Font.Light
                font.letterSpacing: 4
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
                color: root.inkA(0.55)
                font.family: root.mono
                font.pixelSize: Math.round(11 * root.ui)
                font.letterSpacing: 5
            }

            // ── the survey: passcode as plotted stations on a bearing ──────
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(12 * root.ui)

                Item {
                    id: traverse
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property int slots: Math.max(8, Math.min(14, root.host.pwLength))
                    readonly property real slotW: Math.round(22 * root.ui)
                    width: slots * slotW
                    height: Math.round(16 * root.ui)

                    // the bearing line the stations sit on
                    Rectangle {
                        y: parent.height - 2
                        width: parent.width; height: 1
                        color: root.slateA(0.9)
                    }
                    // the closure sweep — lamplight runs the line on unlock
                    Rectangle {
                        y: parent.height - 2.5
                        width: parent.width * (root.host.unlocking ? 1 : 0)
                        height: 2
                        color: root.lampA(0.95)
                        Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        Repeater {
                            model: traverse.slots
                            delegate: Item {
                                id: statn
                                required property int index
                                readonly property bool plotted: index < root.host.pwLength
                                width: traverse.slotW
                                height: traverse.height - 2

                                // the un-plotted tick
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: 1; height: 4
                                    color: root.slateA(0.9)
                                    visible: !statn.plotted
                                }
                                // the plotted benchmark, condensing in
                                Canvas {
                                    id: mark
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: Math.round(12 * root.ui) + 2
                                    height: Math.round(10 * root.ui)
                                    visible: statn.plotted
                                    property color tone: root.host.failed ? root.ember : root.lamp
                                    opacity: root.host.busy ? 0.5 : 1
                                    onToneChanged: requestPaint()
                                    onVisibleChanged: if (visible) { requestPaint(); condense.restart() }
                                    onPaint: {
                                        const ctx = getContext("2d")
                                        ctx.reset()
                                        ctx.strokeStyle = String(tone)
                                        ctx.lineWidth = 1.3
                                        ctx.beginPath()
                                        ctx.moveTo(width / 2, 1)
                                        ctx.lineTo(width - 1, height - 1.5)
                                        ctx.lineTo(1, height - 1.5)
                                        ctx.closePath()
                                        ctx.stroke()
                                        ctx.fillStyle = String(tone)
                                        ctx.fillRect(width / 2 - 1, height * 0.5, 2, 2)
                                    }
                                    SequentialAnimation {
                                        id: condense
                                        ParallelAnimation {
                                            NumberAnimation { target: mark; property: "scale"; from: 1.7; to: 1; duration: 220; easing.type: Easing.OutCubic }
                                            NumberAnimation { target: mark; property: "opacity"; from: 0.15; to: 1; duration: 200 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    id: prompt
                    anchors.horizontalCenter: parent.horizontalCenter
                    property bool breathe: true
                    text: root.host.failed ? "NO FIX — RE-SIGHT AND ENTER"
                        : root.host.busy ? "PLOTTING…"
                        : root.host.unlocking ? "FIX ESTABLISHED"
                        : root.host.pwLength > 0 ? "ENTER TO CLOSE THE TRAVERSE"
                        : "SIGHT YOUR BEARING"
                    color: root.host.failed ? root.ember
                         : root.host.unlocking ? root.fogSilver : root.inkA(0.5)
                    opacity: (root.host.pwLength === 0 && !root.host.failed && !root.host.unlocking)
                             ? (breathe ? 0.9 : 0.3) : 1
                    Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }
                    font.family: root.mono
                    font.pixelSize: Math.round(10 * root.ui)
                    font.letterSpacing: 4
                    Timer {
                        interval: 1100; repeat: true
                        running: root.p > 0.9 && root.host.pwLength === 0 && !root.host.unlocking
                        onTriggered: prompt.breathe = !prompt.breathe
                    }
                }
            }
        }

        // a wrong code knocks the pane off its bearing; it damps level
        Connections {
            target: root.host
            function onFailedChanged() { if (root.host.failed) jolt.restart() }
        }
        property int sx: 0
        transform: Translate { x: pane.sx }
        SequentialAnimation {
            id: jolt
            NumberAnimation { target: pane; property: "sx"; to: -9; duration: 60; easing.type: Easing.OutQuad }
            NumberAnimation { target: pane; property: "sx"; to: 7; duration: 90; easing.type: Easing.InOutSine }
            NumberAnimation { target: pane; property: "sx"; to: -3; duration: 110; easing.type: Easing.InOutSine }
            NumberAnimation { target: pane; property: "sx"; to: 0; duration: 140; easing.type: Easing.OutSine }
        }
    }

    // whose mountain this is
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(30 * root.ui)
        text: "▵ PINES-9 LOOKOUT · ELEV 2130 M"
        color: root.inkA(0.35)
        font.family: root.mono
        font.pixelSize: Math.round(10 * root.ui)
        font.letterSpacing: 5
        opacity: root.p
    }
}
