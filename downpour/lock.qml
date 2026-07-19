import QtQuick
import QtQuick.Effects
import Quickshell

// downpour: bare lock (the bareLock marker tells LockStage we own the
// chrome). Locking doesn't dim this desktop — the storm simply gets the
// whole pane. The video keeps rolling sharp; a breath-fog pane blooms in
// the middle of the glass, genuinely blurring its own slice of the night
// (ShaderEffectSource + MultiEffect), beads riding its rim. The time is
// finger-written across the fog; the passcode is a waterline of beads that
// condense one per keystroke. A wrong code warms them rose and every bead
// breaks and runs at once — the glass keeps nothing. On unlock the fog
// re-clears and the pane hands the night back.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color paneLight: pal.neon
    readonly property color warmth: pal.magenta
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string serif: "Noto Serif"
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function paneA(a)  { return Qt.rgba(paneLight.r, paneLight.g, paneLight.b, a) }
    function warmA(a)  { return Qt.rgba(warmth.r, warmth.g, warmth.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── the night deepens a little — never goes dark ────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.045, 0.10, 0.30 * root.p)
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * 0.32
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.045, 0.10, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.045, 0.10, 0.42) }
        }
    }

    // ── the breath-fog pane ─────────────────────────────────────────────────
    readonly property real panelW: Math.round(470 * ui)
    readonly property real panelH: Math.round(330 * ui)

    Item {
        id: panel
        width: root.panelW
        height: root.panelH
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) * 0.42)
        opacity: root.host.unlocking ? 0 : root.p
        Behavior on opacity { NumberAnimation { duration: 650; easing.type: Easing.InOutSine } }
        scale: root.host.unlocking ? 1.03 : 0.985 + 0.015 * root.p
        Behavior on scale { NumberAnimation { duration: 650; easing.type: Easing.InOutSine } }

        // the pane breathes its own slice of the storm into fog
        ShaderEffectSource {
            id: slice
            sourceItem: root.host.backgroundItem
            sourceRect: Qt.rect(panel.x, panel.y, panel.width, panel.height)
            live: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: slice
            maskEnabled: true
            maskSource: paneMask
            blurEnabled: true
            blur: 1.0
            blurMax: 46
            brightness: -0.10
            saturation: -0.22
        }
        Item {
            id: paneMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true
            Rectangle { anchors.fill: parent; radius: 34 * root.ui; color: "#ffffff" }
        }
        // the breath itself: pale wash over the blur
        Rectangle {
            anchors.fill: parent
            radius: 34 * root.ui
            color: root.inkA(0.055)
            border.width: 1
            border.color: root.inkA(0.13)
        }
        Rectangle {
            anchors.fill: parent
            radius: 34 * root.ui
            color: root.glassA(0.30)
        }

        // beads riding the pane's rim
        Repeater {
            model: 7
            Rectangle {
                required property int index
                readonly property real along: root.rnd(index * 29 + 5)
                x: index % 2 === 0 ? 6 + along * (panel.width - 20)
                                   : (index % 3 === 0 ? 4 : panel.width - 10)
                y: index % 2 === 0 ? (index % 4 === 0 ? 4 : panel.height - 11)
                                   : 10 + along * (panel.height - 30)
                width: (3.6 + 2.6 * root.rnd(index * 13 + 2)) * root.ui
                height: width * 1.25
                radius: width / 2
                color: root.paneA(0.42)
                Rectangle {
                    x: parent.width * 0.22; y: parent.width * 0.22
                    width: parent.width * 0.26; height: parent.width * 0.26
                    radius: width / 2
                    color: root.inkA(0.7)
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(36 * root.ui)
            spacing: Math.round(16 * root.ui)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.host.unlocking ? "the glass clears" : "the storm can wait"
                color: root.host.unlocking ? root.paneA(0.95) : root.inkA(0.5)
                font.family: root.serif
                font.italic: true
                font.pixelSize: Math.round(16 * root.ui)
                font.letterSpacing: 3
            }

            // the hour, finger-written across the fog
            Item {
                id: timeWrap
                anchors.horizontalCenter: parent.horizontalCenter
                width: timeMeas.implicitWidth
                height: timeMeas.implicitHeight
                property real reveal: 0
                Text {   // metrics only
                    id: timeMeas
                    visible: false
                    text: root.hhmm
                    font.family: root.serif
                    font.weight: Font.Light
                    font.pixelSize: Math.round(92 * root.ui)
                }
                Item {
                    width: Math.max(0, timeWrap.reveal * timeWrap.width)
                    height: timeWrap.height
                    clip: true
                    Text {
                        text: root.hhmm
                        color: root.inkA(0.94)
                        font.family: root.serif
                        font.weight: Font.Light
                        font.pixelSize: Math.round(92 * root.ui)
                    }
                }
                Rectangle {
                    visible: timeWrap.reveal > 0.02 && timeWrap.reveal < 0.98
                    x: timeWrap.reveal * timeWrap.width - width / 2
                    width: Math.round(20 * root.ui)
                    height: timeWrap.height * 0.9
                    radius: width / 2
                    opacity: 0.55
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.inkA(0.0) }
                        GradientStop { position: 0.45; color: root.inkA(0.30) }
                        GradientStop { position: 1.0; color: root.inkA(0.0) }
                    }
                }
                NumberAnimation {
                    id: timeWrite
                    target: timeWrap; property: "reveal"
                    from: 0; to: 1; duration: 1100; easing.type: Easing.InOutSine
                }
                // written when the fog settles; re-written on the minute
                property bool wrote: false
                readonly property bool fogged: root.p > 0.6
                onFoggedChanged: if (fogged && !wrote) { wrote = true; timeWrite.restart() }
                Connections {
                    target: clock
                    function onDateChanged() { if (timeWrap.wrote) timeWrite.restart() }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd d MMMM").toLowerCase()
                color: root.inkA(0.55)
                font.family: root.serif
                font.italic: true
                font.pixelSize: Math.round(15 * root.ui)
                font.letterSpacing: 2
            }

            // ── the passcode waterline ──────────────────────────────────────
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(14 * root.ui)

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: beadRow.width + 40 * root.ui
                    height: Math.round(30 * root.ui)

                    // the hairline the beads condense on
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.round(8 * root.ui)
                        width: parent.width
                        height: 1
                        color: root.slateA(0.8)
                    }

                    Row {
                        id: beadRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.round(9 * root.ui)
                        spacing: Math.round(14 * root.ui)
                        Repeater {
                            model: Math.max(8, Math.min(14, root.host.pwLength))
                            delegate: Item {
                                id: socket
                                required property int index
                                readonly property bool filled: index < root.host.pwLength
                                width: Math.round(9 * root.ui)
                                height: Math.round(22 * root.ui)

                                // the bead, condensing under the line
                                Rectangle {
                                    id: bead
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    height: width * 1.3
                                    radius: width / 2
                                    color: root.host.failed ? root.warmA(0.9) : root.paneA(0.85)
                                    opacity: socket.filled
                                        ? (root.host.busy ? 0.5 : 1) * (1 - spill.y2 * 0.85) : 0
                                    y: spill.y2 * 26 * root.ui
                                    scale: socket.filled ? 1 : 0.3
                                    Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.InOutSine } }
                                    Behavior on opacity { NumberAnimation { duration: 250 } }
                                    Rectangle {
                                        x: 1.6 * root.ui; y: 1.8 * root.ui
                                        width: 2.2 * root.ui; height: 2.2 * root.ui
                                        radius: width / 2
                                        color: root.inkA(0.85)
                                    }
                                }
                                // the run when the glass rejects the code
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 0
                                    width: 1.4
                                    height: spill.y2 * 26 * root.ui
                                    opacity: socket.filled ? 0.5 * (1 - spill.y2) : 0
                                    color: root.warmA(0.9)
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.host.failed ? "not that — breathe, try again"
                        : root.host.busy ? "listening…"
                        : root.host.pwLength > 0 ? "enter, when you're ready"
                        : "write it on the glass"
                    textFormat: Text.PlainText
                    color: root.host.failed ? root.warmA(0.95) : root.inkA(0.48)
                    font.family: root.serif
                    font.italic: true
                    font.pixelSize: Math.round(13 * root.ui)
                    font.letterSpacing: 2
                }
            }
        }

        // wrong code: every bead breaks and runs at once
        Item { id: spill; property real y2: 0 }
        SequentialAnimation {
            id: spillAnim
            NumberAnimation { target: spill; property: "y2"; from: 0; to: 1; duration: 560; easing.type: Easing.InQuad }
            PauseAnimation { duration: 300 }
            PropertyAction { target: spill; property: "y2"; value: 0 }
        }
        Connections {
            target: root.host
            function onFailedChanged() { if (root.host.failed) spillAnim.restart() }
        }
    }

    // whose window this is
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(32 * root.ui)
        text: "downpour · the last quiet hour before the storm"
        color: root.inkA(0.32)
        font.family: root.serif
        font.italic: true
        font.pixelSize: Math.round(12 * root.ui)
        font.letterSpacing: 3
        opacity: root.p
    }
}
