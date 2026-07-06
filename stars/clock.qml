import QtQuick
import Quickshell

// stars: the sign over the sea. A warm glowing sign-plate hung from two long
// wires that run up out of the top of the sky (under the bar's catenary),
// parked in the open upper-right air, clear of the cloud bank and the
// shelter. Soft amber digits like the vending machine's display, a gentle
// pool of light spilling below the plate, a few slow star sparkles around
// it, and once a minute a tiny shooting star streaks past behind the
// digits. On load the sign flickers on like a fluorescent tube warming up.
// Also shown on the lock screen over the blurred wallpaper — the dark glass
// plate keeps it legible there.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color amber: pal.neon
    readonly property color coral: pal.cyan
    readonly property color slate: pal.dim
    readonly property color ink:   pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ── flicker-on: the tube stutters, then holds ───────────────────────────
    property real lit: 0
    SequentialAnimation {
        running: true
        PauseAnimation { duration: 250 }
        NumberAnimation { target: root; property: "lit"; to: 0.55; duration: 60 }
        NumberAnimation { target: root; property: "lit"; to: 0.08; duration: 70 }
        PauseAnimation { duration: 120 }
        NumberAnimation { target: root; property: "lit"; to: 0.8; duration: 50 }
        NumberAnimation { target: root; property: "lit"; to: 0.25; duration: 90 }
        NumberAnimation { target: root; property: "lit"; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
    }

    // ── minute flourish: a tiny shooting star behind the digits ─────────────
    property real streakT: -1     // -1 idle, 0..1 flying
    SequentialAnimation {
        id: streakAnim
        NumberAnimation { target: root; property: "streakT"; from: 0; to: 1; duration: 750; easing.type: Easing.InOutQuad }
        PropertyAction { target: root; property: "streakT"; value: -1 }
    }
    Connections {
        target: clock
        function onDateChanged() { if (root.lit >= 1) streakAnim.restart() }
    }

    // ── the ensemble, upper-right sky ───────────────────────────────────────
    Item {
        id: sign
        readonly property real cx: root.width * 0.745
        readonly property real cy: root.height * 0.225
        width: plate.width
        height: plate.height
        x: cx - width / 2
        y: cy - height / 2
        scale: pal.uiScale
        transformOrigin: Item.Center
        opacity: root.lit

        // hanging wires up and out of the sky
        Rectangle {
            x: 26; width: 1
            height: sign.y + 8
            y: -sign.y
            color: root.slateA(0.55)
        }
        Rectangle {
            x: sign.width - 26; width: 1
            height: sign.y + 8
            y: -sign.y
            color: root.slateA(0.55)
        }
        // eyelets where the wires meet the plate
        Rectangle { x: 24; y: -2; width: 5; height: 5; radius: 2.5; color: root.slate }
        Rectangle { x: sign.width - 29; y: -2; width: 5; height: 5; radius: 2.5; color: root.slate }

        // the pool of light spilling below the sign — radial so no hard seams
        Canvas {
            id: lightPool
            anchors.top: plate.bottom
            anchors.topMargin: -4
            anchors.horizontalCenter: plate.horizontalCenter
            width: plate.width * 1.6
            height: 110
            opacity: 0.75
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const a = width / 2
                ctx.save()
                ctx.scale(1, height / a)
                const g = ctx.createRadialGradient(a, 0, 0, a, 0, a)
                g.addColorStop(0, Qt.rgba(root.amber.r, root.amber.g, root.amber.b, 0.14))
                g.addColorStop(1, Qt.rgba(root.amber.r, root.amber.g, root.amber.b, 0))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, a)
                ctx.restore()
            }
            Component.onCompleted: requestPaint()
            Connections { target: root; function onPalChanged() { lightPool.requestPaint() } }
        }

        // the plate: night glass with a warm lit face
        Rectangle {
            id: plate
            width: timeCol.width + 64
            height: timeCol.height + 30
            radius: 10
            color: root.glassA(0.72)
            border.width: 1
            border.color: root.amberA(0.55)

            // wide soft edge glow (a fatter, fainter border behind the crisp one)
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: 13
                color: "transparent"
                border.width: 3
                border.color: root.amberA(0.10)
            }
            // warm wash inside the top of the plate, like a tube along the lip
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: parent.height * 0.55
                radius: 9
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.amberA(0.10) }
                    GradientStop { position: 1.0; color: root.amberA(0.0) }
                }
            }

            // the tiny shooting star crossing behind the digits
            Item {
                anchors.fill: parent
                clip: true
                Item {
                    visible: root.streakT >= 0
                    x: -60 + (plate.width + 120) * Math.max(0, root.streakT)
                    y: plate.height * (0.62 - 0.38 * Math.max(0, root.streakT))
                    rotation: -14
                    Rectangle {
                        width: 54; height: 1.4; radius: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.inkA(0.0) }
                            GradientStop { position: 1.0; color: root.inkA(0.85) }
                        }
                    }
                    Rectangle { x: 52; y: -1; width: 3.2; height: 3.2; radius: 1.6; color: root.ink }
                }
            }

            Column {
                id: timeCol
                anchors.centerIn: parent
                spacing: 6

                // header strip: what the sign is selling
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✦"
                        color: root.coral
                        font.pixelSize: 10
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "COLD DRINKS · 24H"
                        color: root.inkA(0.62)
                        font.family: root.mono
                        font.pixelSize: 11
                        font.letterSpacing: 5
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✦"
                        color: root.coral
                        font.pixelSize: 10
                    }
                }

                // the time — warm tube digits with a soft double glow
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: timeText.width
                    height: timeText.height

                    Text {   // wide soft glow
                        anchors.centerIn: parent
                        text: timeText.text
                        font: timeText.font
                        color: root.amber
                        opacity: 0.28
                        scale: 1.045
                    }
                    Text {
                        id: timeText
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: root.amber
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 84
                        font.letterSpacing: 4
                        style: Text.Raised
                        styleColor: root.amberA(0.35)
                    }
                }

                // dotted rule, like the price row on the machine
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Repeater {
                        model: 14
                        Rectangle {
                            required property int index
                            width: index % 7 === 3 ? 6 : 3
                            height: index % 7 === 3 ? 6 : 3
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: index % 7 === 3 ? root.amberA(0.75) : root.slateA(0.8)
                        }
                    }
                }

                // the date, pale starlight
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "ddd dd MMM").toUpperCase()
                    color: root.inkA(0.78)
                    font.family: root.mono
                    font.pixelSize: 16
                    font.letterSpacing: 8
                }
            }
        }

        // ── slow sparkles in the air around the sign ────────────────────────
        Repeater {
            model: [
                { fx: -0.16, fy: 0.10, s: 9,  d: 4600 },
                { fx: 1.10,  fy: 0.24, s: 7,  d: 5400 },
                { fx: -0.09, fy: 0.86, s: 6,  d: 6200 },
                { fx: 1.16,  fy: 0.78, s: 8,  d: 5000 },
                { fx: 0.50,  fy: -0.34, s: 6, d: 7000 },
                { fx: 1.28,  fy: -0.12, s: 5, d: 5800 }
            ]
            delegate: Text {
                required property var modelData
                x: plate.width * modelData.fx
                y: plate.height * modelData.fy
                text: modelData.s > 7 ? "✦" : "✧"
                color: modelData.s > 7 ? root.amberA(0.8) : root.inkA(0.7)
                font.pixelSize: modelData.s
                opacity: 0.25
                SequentialAnimation on opacity {
                    running: root.lit >= 1 && root.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.75; duration: modelData.d; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.22; duration: modelData.d * 1.2; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
