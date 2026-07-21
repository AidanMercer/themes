import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris

// gunsmoke: the bar is the loading gate of the dead man's revolver, laid
// along the top edge under a double ledger rule. Center: THE CYLINDER —
// every workspace a chamber. Occupied chambers hold a seated primer (bone),
// the chamber under the hammer carries the theme's one red dot, and chambers
// you emptied this session stay struck (a spent ✕). The firing pin rides
// above the gate and STRIKES on every switch — one-frame drop, chamber
// flash, powder smoke curling off the gate (hammer + smoke laws).
//   left  — the media plate: hard-ticking powder pip while the band plays,
//           the track in the ledger's data hand, and a fuse line burning
//           across the plate's foot for progress.
//   right — the belt: skull trigger for the condition report, the telegraph
//           pole, the powder flask (battery), the time stamped in serif, and
//           the sheriff's star for the control popup.
// Panels are riveted iron plates — flat, double-ruled, no rounded glass.
// Self-contained: hyprland via Quickshell.Hyprland, /proc + nmcli.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while the session is locked — parks the pollers
    property bool occluded: false

    readonly property color bone: pal.neon
    readonly property color blood: pal.magenta
    readonly property color brass: pal.amber
    readonly property color ash: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string serif: "Noto Serif"
    readonly property string mono: pal.fontMono
    function boneA(a)  { return Qt.rgba(bone.r, bone.g, bone.b, a) }
    function ashA(a)   { return Qt.rgba(ash.r, ash.g, ash.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // boot: the gate blooms out of the fog — fade + settle down (smoke law)
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 800; easing.type: Easing.OutQuad }
    readonly property real bootLift: -4 * (1 - bootT)

    // ── iron plate: flat panel, hairline edge, four corner rivets ──────────
    component IronPlate: Item {
        id: plate
        property color edge: root.ashA(0.6)
        Rectangle {
            anchors.fill: parent
            color: root.glassA(0.85)
            border.width: 1
            border.color: plate.edge
        }
        Repeater {
            model: 4
            Rectangle {
                required property int index
                width: 2; height: 2; radius: 1
                x: index % 2 === 0 ? 3 : plate.width - 5
                y: index < 2 ? 3 : plate.height - 5
                color: root.boneA(0.35)
            }
        }
    }

    // ── the gate itself: dark iron + the double ledger rule at its foot ────
    Rectangle { anchors.fill: parent; color: root.glassA(0.6) }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        width: parent.width; height: 1
        color: root.boneA(0.28)
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: root.boneA(0.10)
    }
    Rectangle {
        anchors.top: parent.top
        width: parent.width; height: 1
        color: root.ashA(0.4)
    }

    // ── powder smoke off the gate — the shared one-shot ────────────────────
    component SmokePuff: Item {
        id: puff
        property real t: -1
        visible: t >= 0
        function fire() { anim.restart() }
        readonly property real tt: Math.max(0, t)
        Repeater {
            model: 3
            Rectangle {
                required property int index
                x: (index - 1) * 4 + Math.sin((puff.tt + index * 0.4) * 6) * 3
                y: -puff.tt * (14 + index * 5)
                width: (3 + index) * (1 + puff.tt * 1.4)
                height: width
                radius: width / 2
                color: root.boneA(0.25 * (1 - puff.tt))
            }
        }
        NumberAnimation {
            id: anim
            target: puff; property: "t"
            from: 0; to: 1; duration: 750; easing.type: Easing.OutQuad
            onStopped: puff.t = -1
        }
    }

    // ── center: THE CYLINDER ───────────────────────────────────────────────
    Item {
        id: gate
        readonly property int wsCount: 10
        readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
        readonly property int pageBase: activeWsId >= 1
            ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
            : 1
        readonly property real slotW: 32
        readonly property int activeSlot: activeWsId - pageBase
        // chambers fired and since emptied stay marked this session
        property var struck: ({})
        width: wsCount * slotW
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: root.bootT

        Repeater {
            model: gate.wsCount
            delegate: Item {
                id: slot
                required property int index
                readonly property int wsId: gate.pageBase + index
                readonly property bool isActive: gate.activeWsId === wsId
                readonly property bool isOccupied: Hyprland.toplevels.values
                    .filter(t => (t.workspace?.id ?? -1) === wsId).length > 0
                readonly property bool isStruck: !isActive && !isOccupied
                                                 && gate.struck[wsId] === true
                // reassign so the var property notifies and isStruck re-evaluates
                onIsActiveChanged: if (isActive) {
                    const s = Object.assign({}, gate.struck)
                    s[wsId] = true
                    gate.struck = s
                }

                x: index * gate.slotW
                width: gate.slotW
                height: parent.height

                // the chamber ring
                Rectangle {
                    id: ring
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 3
                    width: 16; height: 16; radius: 8
                    color: slot.isActive ? Qt.rgba(0, 0, 0, 0.5) : "transparent"
                    border.width: slot.isActive ? 2 : 1
                    border.color: slot.isActive ? root.boneA(0.9)
                                : slot.isOccupied ? root.boneA(0.55)
                                : root.ashA(0.6)
                }
                // seated primer — bone when loaded; the ONE red dot rides the
                // chamber under the hammer (active = the accent is spent here)
                Rectangle {
                    anchors.centerIn: ring
                    width: slot.isActive ? 7 : 5
                    height: width; radius: width / 2
                    visible: slot.isActive || slot.isOccupied
                    color: slot.isActive ? root.blood : root.boneA(0.75)
                }
                // spent chamber: the strike mark
                Item {
                    anchors.centerIn: ring
                    width: 8; height: 8
                    visible: slot.isStruck
                    Rectangle { anchors.centerIn: parent; width: 9; height: 1; rotation: 45; color: root.ashA(0.9) }
                    Rectangle { anchors.centerIn: parent; width: 9; height: 1; rotation: -45; color: root.ashA(0.9) }
                }
                // chamber flash on strike (one frame, hammer law)
                Rectangle {
                    id: chFlash
                    anchors.centerIn: ring
                    width: 20; height: 20; radius: 10
                    color: root.boneA(0.6)
                    opacity: 0
                }
                SequentialAnimation {
                    id: chFlashAnim
                    PropertyAction { target: chFlash; property: "opacity"; value: 0.7 }
                    PauseAnimation { duration: 50 }
                    PropertyAction { target: chFlash; property: "opacity"; value: 0 }
                }
                SmokePuff {
                    id: chSmoke
                    x: slot.width / 2
                    y: slot.height / 2 - 4
                }
                Connections {
                    target: gate
                    // watch the ws id, not the slot: a cross-page switch can
                    // land on the same slot index and must still strike
                    function onActiveWsIdChanged() {
                        if (gate.activeSlot === slot.index && root.bootT > 0.9 && !root.occluded) {
                            chFlashAnim.restart()
                            chSmoke.fire()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                }
            }
        }

        // the firing pin, indexed above the active chamber. It does not
        // glide — it snaps to the chamber and strikes.
        Item {
            id: pin
            x: gate.activeSlot * gate.slotW + gate.slotW / 2 - 3
            y: 1
            property real drop: 0
            Rectangle { x: 0; y: pin.drop; width: 6; height: 3; color: root.boneA(0.9) }
            Rectangle { x: 2; y: 3 + pin.drop; width: 2; height: 5; color: root.boneA(0.9) }
            SequentialAnimation {
                id: strike
                PropertyAction { target: pin; property: "drop"; value: 3 }
                PauseAnimation { duration: 60 }
                PropertyAction { target: pin; property: "drop"; value: 0 }
            }
            Connections {
                target: gate
                function onActiveWsIdChanged() { if (!root.occluded) strike.restart() }
            }
        }
    }

    // keep workspace occupancy fresh — toplevels are empty until refreshed
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "movewindow":
            case "movewindowv2":
            case "activewindowv2":
                Hyprland.refreshToplevels()
            }
        }
    }
    Component.onCompleted: Hyprland.refreshToplevels()

    // ── left: the media plate ──────────────────────────────────────────────
    Item {
        id: media
        readonly property var player: {
            const ps = Mpris.players.values
            if (ps.length === 0) return null
            return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]
        }
        readonly property bool active: player !== null
        readonly property bool playing: active && player.playbackState === MprisPlaybackState.Playing

        visible: active
        x: 12
        y: Math.round((parent.height - height) / 2) + root.bootLift
        width: mediaRow.width + 24
        height: 28
        opacity: root.bootT

        IronPlate { anchors.fill: parent }

        Row {
            id: mediaRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            spacing: 8

            // the powder pip: hard tick while the band plays (hammer blink)
            Rectangle {
                id: pip
                anchors.verticalCenter: parent.verticalCenter
                width: 5; height: 5; radius: 2.5
                property bool tick: true
                color: media.playing ? root.boneA(tick ? 0.95 : 0.25) : root.ashA(0.8)
                Timer {
                    interval: 800; repeat: true
                    running: media.playing && !root.occluded
                    onTriggered: pip.tick = !pip.tick
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 220)
                elide: Text.ElideRight
                text: {
                    if (!media.active) return ""
                    const t = media.player.trackTitle || "—"
                    const a = media.player.trackArtist
                    return a ? t + " · " + a : t
                }
                textFormat: Text.PlainText
                color: root.inkA(0.85)
                font.family: root.mono
                font.pixelSize: 10
            }
        }

        // the fuse: progress burns across the plate's foot, a spark at the tip
        property real progress: 0
        Timer {
            interval: 1000; repeat: true
            running: media.playing && !root.occluded
            triggeredOnStart: true
            onTriggered: {
                const p = media.player
                media.progress = (p && p.length > 0 && p.position >= 0)
                    ? Math.min(1, p.position / p.length) : 0
            }
        }
        Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.bottomMargin: 4
            height: 2
            Rectangle { anchors.fill: parent; color: root.ashA(0.5) }
            Rectangle {
                width: parent.width * media.progress
                height: 2
                color: root.boneA(0.8)
            }
            Rectangle {   // the burning tip
                x: Math.max(0, parent.width * media.progress - 2)
                y: -1
                width: 3; height: 4
                visible: media.playing && media.progress > 0
                color: root.boneA(1)
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (media.active && media.player.canTogglePlaying) media.player.togglePlaying()
            onWheel: (w) => {
                if (!media.active) return
                if (w.modifiers & Qt.ShiftModifier) {
                    Quickshell.execDetached(["qs", "ipc", "call", "lyricOffset",
                        w.angleDelta.y > 0 ? "earlier" : "later"])
                    return
                }
                if (w.angleDelta.y > 0 && media.player.canGoNext) media.player.next()
                else if (w.angleDelta.y < 0 && media.player.canGoPrevious) media.player.previous()
            }
        }
    }

    // ── right: the belt ────────────────────────────────────────────────────
    property bool online: false
    property string connType: ""
    property int batteryPercent: -1
    property bool batteryCharging: false
    property bool hasBattery: false

    Timer {
        interval: 10000; running: !root.occluded; repeat: true; triggeredOnStart: true
        onTriggered: { netProc.running = true; batProc.running = true }
    }
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -vi ':loopback\\|:bridge\\|:tun' | head -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim()
                if (!line) { root.online = false; root.connType = ""; return }
                const t = line.slice(line.lastIndexOf(":") + 1)
                root.connType = t.indexOf("wireless") >= 0 ? "wifi" : t.indexOf("ethernet") >= 0 ? "eth" : "net"
                root.online = true
            }
        }
    }
    Process {
        id: batProc
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -e \"$b/capacity\" ] && { cat \"$b/capacity\" \"$b/status\"; break; }; done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const cap = parseInt(lines[0])
                if (lines[0] === "" || isNaN(cap)) { root.hasBattery = false; return }
                root.hasBattery = true
                root.batteryPercent = cap
                root.batteryCharging = (lines[1] || "").trim() === "Charging"
            }
        }
    }

    // hover flag shared with sysinfo.qml — the skull writes "1"/"0" here
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

    Row {
        id: beltRow
        spacing: 8
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: root.bootLift
        height: parent.height
        opacity: root.bootT

        // the skull at his belt — hover for the condition report.
        // gone while the readout is toggled off in settings.
        IronPlate {
            visible: root.pal.sysinfoOn !== false
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 24
            edge: skullMa.containsMouse ? root.boneA(0.9) : root.ashA(0.6)
            // a little bone skull, built from plates
            Item {
                anchors.centerIn: parent
                width: 12; height: 12
                readonly property color c: skullMa.containsMouse ? root.boneA(1) : root.boneA(0.5)
                Rectangle { x: 1; y: 0; width: 10; height: 8; radius: 3; color: parent.c }
                Rectangle { x: 3; y: 8; width: 6; height: 3; color: parent.c }
                Rectangle { x: 3; y: 3; width: 2; height: 3; color: Qt.rgba(0.03, 0.05, 0.06, 1) }
                Rectangle { x: 7; y: 3; width: 2; height: 3; color: Qt.rgba(0.03, 0.05, 0.06, 1) }
                Rectangle { x: 5; y: 9; width: 1; height: 2; color: Qt.rgba(0.03, 0.05, 0.06, 0.8) }
            }
            MouseArea {
                id: skullMa
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: sysFlag.setText(containsMouse ? "1" : "0")
            }
        }

        // the telegraph pole: crossarm + drop wires, lit while the wire's up
        IronPlate {
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 24
            Item {
                anchors.centerIn: parent
                width: 14; height: 14
                readonly property color c: root.online ? root.boneA(0.85) : root.ashA(0.9)
                Rectangle { x: 6; y: 0; width: 2; height: 14; color: parent.c }
                Rectangle { x: 0; y: 2; width: 14; height: 2; color: parent.c }
                Rectangle { x: 1; y: 4; width: 2; height: 2; color: parent.c }
                Rectangle { x: 11; y: 4; width: 2; height: 2; color: parent.c }
            }
            // the wire is down: the one red pixel of bad news
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 4
                width: 4; height: 4; radius: 2
                color: root.blood
                visible: !root.online
            }
        }

        // the powder flask (laptops only) — fill sinks as powder is spent
        IronPlate {
            visible: root.hasBattery
            anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 24
            Item {
                anchors.centerIn: parent
                width: 12; height: 16
                Rectangle {   // the flask body
                    x: 0; y: 4; width: 12; height: 12; radius: 3
                    color: "transparent"
                    border.width: 1
                    border.color: root.ashA(1)
                }
                Rectangle { x: 4; y: 0; width: 4; height: 4; color: root.ashA(1) }   // the spout
                Rectangle {   // the powder inside
                    x: 2
                    width: 8
                    height: Math.max(1, Math.round(8 * Math.max(0, root.batteryPercent) / 100))
                    y: 14 - height
                    color: root.batteryPercent <= 15 ? root.blood
                         : root.batteryPercent <= 30 ? root.brass
                         : root.boneA(0.8)
                }
                Rectangle {   // charging: a spark at the spout
                    x: 5; y: -3; width: 2; height: 2
                    color: root.boneA(1)
                    visible: root.batteryCharging
                }
            }
        }

        // the time, stamped
        IronPlate {
            anchors.verticalCenter: parent.verticalCenter
            width: timeText.implicitWidth + 20
            height: 26
            Text {
                id: timeText
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.boneA(0.92)
                font.family: root.serif
                font.pixelSize: 13
                font.weight: Font.Black
                font.letterSpacing: 2
            }
        }

        // the sheriff's star — the control popup
        IronPlate {
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 24
            edge: starMa.containsMouse ? root.boneA(0.9) : root.ashA(0.6)
            Text {
                anchors.centerIn: parent
                text: "✦"
                color: starMa.containsMouse ? root.boneA(1) : root.boneA(0.55)
                font.pixelSize: 13
            }
            MouseArea {
                id: starMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
            }
        }
    }
}
