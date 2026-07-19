import QtQuick
import QtQuick.Effects
import Quickshell

// encore: bare lock (the bareLock marker tells LockStage we own the chrome).
// Locking is the house going half-dark between songs: the video keeps
// playing sharp — she's still on stage — while the hall dims and the STAGE
// DOOR panel irises up center (law 2: lit, not faded). The time is the call
// time, the passcode is a row of PASS lamps that light teal one keystroke at
// a time (whole lamps — law 1), a wrong pass flashes the whole row crowd
// magenta and knocks the door in hard steps, and the moment the pass lands
// the sign flips to ENCORE! and a spotlight iris opens across the whole
// screen to let you back out front.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color teal: pal.neon
    readonly property color lacquer: pal.cyan
    readonly property color crowd: pal.magenta
    readonly property color spot: pal.amber
    readonly property color rest: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    function tealA(a) { return Qt.rgba(teal.r, teal.g, teal.b, a) }
    function inkA(a)  { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function restA(a) { return Qt.rgba(rest.r, rest.g, rest.b, a) }
    function glassA(a){ return Qt.rgba(glass.r, glass.g, glass.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── the house dims — she stays lit ──────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.01, 0.02, 0.05, 0.30 * root.p)
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * 0.32
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.01, 0.02, 0.05, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.02, 0.05, 0.5) }
        }
    }

    // ── the stage door ──────────────────────────────────────────────────────
    readonly property real panelW: Math.round(430 * ui)
    readonly property real panelH: Math.round(298 * ui)

    Item {
        id: panel
        width: root.panelW
        height: root.panelH
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) * 0.44)
        // the iris: the panel is a cut of light — opacity is a hard gate,
        // the scale opens with the lock's own progress
        opacity: root.p < 0.25 ? 0 : 1
        scale: 0.8 + 0.2 * root.p
        transformOrigin: Item.Center

        // the door blurs its own slice of the stage behind it
        ShaderEffectSource {
            id: slice
            sourceItem: root.host.backgroundItem
            sourceRect: Qt.rect(panel.x, panel.y, panel.width, panel.height)
            live: true
            visible: false
        }
        // rounded mask so the blurred slice keeps the capsule corners
        Rectangle {
            id: doorMask
            anchors.fill: parent
            radius: Math.round(16 * root.ui)
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            source: slice
            blurEnabled: true
            blur: 1.0
            blurMax: 40
            brightness: -0.24
            saturation: -0.1
            maskEnabled: true
            maskSource: doorMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        Rectangle {
            anchors.fill: parent
            radius: Math.round(16 * root.ui)
            color: root.glassA(0.6)
            border.width: 1
            border.color: root.tealA(0.4)
        }
        // the teal edge-strip foot — the rig's signature
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 60 * root.ui
            height: 2
            radius: 1
            color: root.tealA(root.host.unlocking ? 0.9 : 0.5)
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(30 * root.ui)
            spacing: Math.round(16 * root.ui)

            // the sign over the door
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.host.unlocking ? "✳ ENCORE! ✳" : "STAGE DOOR"
                color: root.host.unlocking ? root.spot : root.teal
                font.family: root.mono
                font.weight: Font.Bold
                font.pixelSize: Math.round(16 * root.ui)
                font.letterSpacing: 8
            }

            // call time
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hhmm
                color: root.ink
                font.family: root.mono
                font.pixelSize: Math.round(64 * root.ui)
                font.weight: Font.Black
                font.letterSpacing: 3
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "ON STAGE · " + Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
                color: root.inkA(0.6)
                font.family: root.mono
                font.pixelSize: Math.round(11 * root.ui)
                font.letterSpacing: 6
            }

            // ── the pass lamps ──────────────────────────────────────────────
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(12 * root.ui)

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(10 * root.ui)
                    Repeater {
                        model: Math.max(8, Math.min(14, root.host.pwLength))
                        delegate: Item {
                            id: socket
                            required property int index
                            readonly property bool filled: index < root.host.pwLength
                            width: Math.round(12 * root.ui)
                            height: width
                            // the housing
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.width: 1
                                border.color: root.restA(0.9)
                            }
                            // the lamp — lights the moment the key lands
                            Rectangle {
                                id: lamp
                                anchors.centerIn: parent
                                width: parent.width - 4
                                height: width
                                radius: width / 2
                                color: root.host.failed ? root.crowd : root.teal
                                visible: socket.filled
                                opacity: root.host.busy ? 0.5 : 1
                                onVisibleChanged: if (visible) hit.restart()
                                SequentialAnimation {
                                    id: hit
                                    NumberAnimation { target: lamp; property: "scale"; from: 1.7; to: 1; duration: 110; easing.type: Easing.OutQuad }
                                }
                            }
                        }
                    }
                }

                Text {
                    id: prompt
                    anchors.horizontalCenter: parent.horizontalCenter
                    property bool tick: true
                    text: root.host.failed ? "NOT ON THE LIST — AGAIN"
                        : root.host.busy ? "CHECKING THE LIST…"
                        : root.host.pwLength > 0 ? "ENTER — TAKE THE STAGE"
                        : "PASS REQUIRED"
                    color: root.host.failed ? root.crowd : root.inkA(0.55)
                    // PASS REQUIRED blinks on the count: hard on, hard off
                    opacity: (root.host.pwLength === 0 && !root.host.failed && prompt.tick) || root.host.pwLength > 0 || root.host.failed
                             ? 1 : 0.15
                    font.family: root.mono
                    font.pixelSize: Math.round(11 * root.ui)
                    font.letterSpacing: 4
                    Timer {
                        interval: 500; repeat: true
                        running: root.p > 0.9 && root.host.pwLength === 0 && !root.host.unlocking
                        onTriggered: prompt.tick = !prompt.tick
                    }
                }
            }
        }

        // wrong pass: the door takes the knock — hard steps, no easing
        Connections {
            target: root.host
            function onFailedChanged() { if (root.host.failed) knock.restart() }
            function onUnlockingChanged() { if (root.host.unlocking) irisAnim.restart() }
        }
        SequentialAnimation {
            id: knock
            PropertyAction { target: panel; property: "sx"; value: -10 }
            PauseAnimation { duration: 55 }
            PropertyAction { target: panel; property: "sx"; value: 8 }
            PauseAnimation { duration: 55 }
            PropertyAction { target: panel; property: "sx"; value: -4 }
            PauseAnimation { duration: 55 }
            PropertyAction { target: panel; property: "sx"; value: 0 }
        }
        property int sx: 0
        transform: Translate { x: panel.sx }
    }

    // whose stage this is
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(30 * root.ui)
        text: "V// ENCORE · FROM THE DIVA'S SIDE"
        color: root.inkA(0.35)
        font.family: root.mono
        font.pixelSize: Math.round(10 * root.ui)
        font.letterSpacing: 5
        opacity: root.p
    }

    // ── the unlock: a spotlight iris opens across the whole night ──────────
    Rectangle {
        id: iris
        property real t: -1
        visible: t >= 0
        anchors.centerIn: parent
        readonly property real maxR: Math.sqrt(root.width * root.width + root.height * root.height) / 2
        width: 2 * (20 + maxR * Math.max(0, t))
        height: width
        radius: width / 2
        color: "transparent"
        border.width: Math.max(2, 60 * (1 - Math.max(0, t)))
        border.color: Qt.rgba(root.spot.r, root.spot.g, root.spot.b, 0.5 * (1 - Math.max(0, t)))
        NumberAnimation {
            id: irisAnim
            target: iris; property: "t"
            from: 0; to: 1; duration: 600; easing.type: Easing.OutQuad
            onStopped: iris.t = -1
        }
    }
}
