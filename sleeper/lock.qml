import QtQuick
import QtQuick.Effects
import Quickshell

// sleeper: bare lock (the bareLock marker tells LockStage we own the chrome).
// Locking is LIGHTS OUT in the berth: the reading lamp clicks off, the city
// keeps sliding past the window sharp and green, and the conductor is at the
// door — a paper ticket slides up into the middle of the screen for TICKET
// CHECK. The passcode is the house punch language: every keystroke punches a
// hole through the ticket (the chad drops), a wrong code slams a red VOID
// stamp across it and knocks the ticket sideways, and the right code lets a
// warm lamp sweep the whole compartment as the ticket tucks away and the
// night lets you back in. Typing/Enter still route through the shell.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color green: pal.neon
    readonly property color moonpale: pal.cyan
    readonly property color stamp: pal.magenta
    readonly property color tea: pal.amber
    readonly property color wood: pal.dim
    readonly property color linen: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    function linenA(a) { return Qt.rgba(linen.r, linen.g, linen.b, a) }
    function teaA(a)   { return Qt.rgba(tea.r, tea.g, tea.b, a) }
    function woodA(a)  { return Qt.rgba(wood.r, wood.g, wood.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── lights out: the compartment darkens, the window stays alive ────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.03, 0.01, 0.40 * root.p)
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * 0.32
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.03, 0.01, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.03, 0.01, 0.5) }
        }
    }

    // ── the ticket ──────────────────────────────────────────────────────────
    readonly property real panelW: Math.round(420 * ui)
    readonly property real panelH: Math.round(310 * ui)

    Item {
        id: ticket
        width: root.panelW
        height: root.panelH
        x: Math.round((root.width - width) / 2)
        // slides up into the conductor's hand as the lock engages; tucks
        // away downward again as it lets go
        y: Math.round((root.height - height) * 0.42) + Math.round(56 * (1 - root.p))
        opacity: root.p
        // the knock leans the paper as it shifts — sx drives both
        rotation: sx * 0.06
        transformOrigin: Item.Bottom

        property int sx: 0
        transform: Translate { x: ticket.sx }

        // the ticket blurs its own slice of the compartment behind it
        ShaderEffectSource {
            id: slice
            sourceItem: root.host.backgroundItem
            sourceRect: Qt.rect(ticket.x, ticket.y, ticket.width, ticket.height)
            live: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            anchors.margins: 4
            source: slice
            blurEnabled: true
            blur: 1.0
            blurMax: 40
            brightness: -0.2
            saturation: -0.2
        }
        Rectangle {   // linen paper over the blur
            anchors.fill: parent
            anchors.margins: 4
            color: Qt.rgba(root.linen.r * 0.24 + root.glass.r, root.linen.g * 0.24 + root.glass.g,
                           root.linen.b * 0.24 + root.glass.b, 0.6)
        }
        Rectangle {   // paper edge
            anchors.fill: parent
            anchors.margins: 4
            color: "transparent"
            border.width: 1
            border.color: root.linenA(0.45)
        }
        // perforation rows down both sides — torn from the conductor's book
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Repeater {
                model: 18
                Rectangle { width: 2; height: 5; color: root.linenA(0.3) }
            }
        }
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Repeater {
                model: 18
                Rectangle { width: 2; height: 5; color: root.linenA(0.3) }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(30 * root.ui)
            spacing: Math.round(14 * root.ui)

            // the inspection header
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.host.unlocking ? "WELCOME ABOARD" : "TICKET CHECK"
                color: root.host.unlocking ? root.moonpale : root.tea
                font.family: root.mono
                font.weight: Font.Bold
                font.pixelSize: Math.round(14 * root.ui)
                font.letterSpacing: 7
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "НОЧНОЙ ПОЕЗД · CAR 7"
                color: root.linenA(0.5)
                font.family: root.mono
                font.pixelSize: Math.round(9 * root.ui)
                font.letterSpacing: 4
            }

            // the time, tall serif linen — the plaque's face carried onto paper
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hhmm
                color: root.linenA(0.95)
                font.family: root.serif
                font.pixelSize: Math.round(58 * root.ui)
                font.weight: Font.Light
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
                color: root.linenA(0.55)
                font.family: root.mono
                font.pixelSize: Math.round(11 * root.ui)
                font.letterSpacing: 5
            }

            // perforation rule across the ticket
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 7
                Repeater {
                    model: 16
                    Rectangle { width: 4 * root.ui; height: 4 * root.ui; radius: 2 * root.ui; color: root.teaA(0.4) }
                }
            }

            // ── the punch row: the passcode ─────────────────────────────────
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
                            readonly property bool punched: index < root.host.pwLength
                            width: Math.round(13 * root.ui)
                            height: width
                            Rectangle {   // printed punch circle
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.width: 1
                                border.color: root.host.failed ? root.stamp
                                            : socket.punched ? root.teaA(0.9) : root.linenA(0.35)
                            }
                            Rectangle {   // the hole, punched to the night behind
                                id: hole
                                anchors.centerIn: parent
                                width: parent.width - 5
                                height: width
                                radius: width / 2
                                color: root.host.failed ? Qt.rgba(root.stamp.r, root.stamp.g, root.stamp.b, 0.7)
                                                        : Qt.rgba(0, 0, 0, 0.7)
                                visible: socket.punched
                                opacity: root.host.busy ? 0.5 : 1
                                onVisibleChanged: if (visible) press.restart()
                                NumberAnimation {
                                    id: press
                                    target: hole; property: "scale"
                                    from: 1.7; to: 1; duration: 140; easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }

                Text {
                    id: prompt
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.host.failed ? "NOT VALID — ONCE MORE"
                        : root.host.busy ? "INSPECTING…"
                        : root.host.pwLength > 0 ? "ENTER TO PUNCH THROUGH"
                        : "PRESENT TICKET"
                    color: root.host.failed ? root.stamp : root.linenA(0.5)
                    font.family: root.mono
                    font.pixelSize: Math.round(10 * root.ui)
                    font.letterSpacing: 4
                    // the empty prompt breathes like a lamp, never blinks hard
                    SequentialAnimation on opacity {
                        running: root.p > 0.9 && root.host.pwLength === 0
                                 && !root.host.unlocking && !root.host.failed
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 1600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
                    }
                    onVisibleChanged: opacity = 1
                }
            }
        }

        // ── VOID — the conductor's stamp on a wrong code ────────────────────
        Text {
            id: voidStamp
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Math.round(30 * root.ui)
            text: "V O I D"
            color: root.stamp
            opacity: 0
            rotation: -14
            font.family: root.mono
            font.weight: Font.Black
            font.pixelSize: Math.round(46 * root.ui)
            font.letterSpacing: 10
            SequentialAnimation {
                id: stampSlam
                ParallelAnimation {
                    NumberAnimation { target: voidStamp; property: "opacity"; from: 0; to: 0.85; duration: 90 }
                    NumberAnimation { target: voidStamp; property: "scale"; from: 1.8; to: 1; duration: 130; easing.type: Easing.OutCubic }
                }
                PauseAnimation { duration: 900 }
                NumberAnimation { target: voidStamp; property: "opacity"; to: 0; duration: 700 }
            }
        }

        // wrong code: the ticket takes the knock — slides, never shakes hard
        SequentialAnimation {
            id: knock
            NumberAnimation { target: ticket; property: "sx"; to: -12; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: ticket; property: "sx"; to: 8; duration: 140; easing.type: Easing.InOutSine }
            NumberAnimation { target: ticket; property: "sx"; to: -3; duration: 140; easing.type: Easing.InOutSine }
            NumberAnimation { target: ticket; property: "sx"; to: 0; duration: 120; easing.type: Easing.OutSine }
        }
        Connections {
            target: root.host
            function onFailedChanged() { if (root.host.failed) { knock.restart(); stampSlam.restart() } }
            function onUnlockingChanged() { if (root.host.unlocking) lampSweep.restart() }
        }
    }

    // whose berth this is
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(28 * root.ui)
        text: "THE OVERNIGHT BERTH · SLEEPER"
        color: root.linenA(0.35)
        font.family: root.mono
        font.pixelSize: Math.round(10 * root.ui)
        font.letterSpacing: 5
        opacity: root.p
    }

    // ── the unlock: a warm lamp sweeps the whole compartment ───────────────
    Rectangle {
        id: lamp
        property real t: -1
        visible: t >= 0
        width: root.width * 0.35
        height: root.height * 1.4
        y: -root.height * 0.2
        x: -width + (root.width + width * 2) * Math.max(0, t)
        rotation: 12
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.teaA(0.0) }
            GradientStop { position: 0.5; color: root.teaA(0.16) }
            GradientStop { position: 1.0; color: root.teaA(0.0) }
        }
        NumberAnimation {
            id: lampSweep
            target: lamp; property: "t"
            from: 0; to: 1; duration: 750; easing.type: Easing.InOutQuad
            onStopped: lamp.t = -1
        }
    }
}
